FRAME_SIZE = 600 --equivalent ms position at 1x SV
FRAME_RATE = 60 --fps
BPM = 1
INCREMENT = .015625 --ms

DISPLACE_INCREMENT = .5 --ms
LINE_TIME_INCREMENT = -2 --ms
LINE_TIME_START = -10000 --ms

action_queue = {}
sv_queue = {}

position_cache = {}

debug = 0

function draw()
    imgui.Begin("Line Animation")

    state.IsWindowHovered = imgui.IsWindowHovered()

    ResetQueue()

    local line_function = state.GetValue("line_function") or "local i  = ...\nlocal results = {}\nreturn results"
    local start = state.GetValue("start") or 0
    local stop = state.GetValue("stop") or 0
    local advanced = state.GetValue("advanced") or false

    if imgui.Button("Current") then start = state.SongTime end imgui.SameLine() _, start = imgui.InputFloat("Start", start, 1)
    if imgui.Button("Current##0") then stop = state.SongTime end imgui.SameLine() _, stop = imgui.InputFloat("Stop", stop, 1)
    _, line_function = imgui.InputTextMultiline("Function", line_function, 69420, {300, 100})

    if imgui.Button("Setup") then
        SetUpAnimation(start, stop)
    end

    imgui.SameLine()
    if imgui.Button("Add") then
        AddToAnimation(start, stop, line_function)
    end

    imgui.SameLine()
    _, advanced = imgui.Checkbox("Advanced Settings", advanced)
    if advanced then DrawAdvancedSettings() end

    if imgui.Button("debug") then
        local f = load(line_function)
        f()
    end
    imgui.Text(debug)

    PerformQueue()

    state.SetValue("line_function", line_function)
    state.SetValue("start", start)
    state.SetValue("stop", stop)
    state.SetValue("advanced", advanced)

    imgui.End()
end

function DrawAdvancedSettings()
    imgui.Begin("Advanced Settings")
    state.IsWindowHovered = imgui.IsWindowHovered()
    _, FRAME_SIZE = imgui.InputInt("FRAME_SIZE", FRAME_SIZE)
    _, FRAME_RATE = imgui.InputFloat("FRAME_RATE", FRAME_RATE, 10)
    _, BPM = imgui.InputFloat("BPM", BPM, 1)
    _, INCREMENT = imgui.InputFloat("INCREMENT", INCREMENT, .015625)
    _, DISPLACE_INCREMENT = imgui.InputFloat("DISPLACE_INCREMENT", DISPLACE_INCREMENT, .015625)
    _, LINE_TIME_START = imgui.InputFloat("LINE_TIME_START", LINE_TIME_START, 1000)
    _, LINE_TIME_INCREMENT = imgui.InputFloat("LINE_TIME_INCREMENT", LINE_TIME_INCREMENT, 1)
    imgui.End()
end

function SetUpAnimation(start, stop)
    local MSPF = 1000 / FRAME_RATE
    local frame_count = (stop - start) / MSPF

    for i = 0, frame_count - 1 do
        local frame_time = start + MSPF * i
        table.insert(sv_queue, utils.CreateScrollVelocity(frame_time - INCREMENT, FRAME_SIZE / INCREMENT))
        table.insert(sv_queue, utils.CreateScrollVelocity(frame_time, 0))
    end

    table.insert(sv_queue, utils.CreateScrollVelocity(stop - INCREMENT, FRAME_SIZE / INCREMENT))
    IncreaseSV(stop, 0)
end

function AddToAnimation(start, stop, line_function)
    local MSPF = 1000 / FRAME_RATE
    local frame_count = (stop - start) / MSPF
    local f = load(line_function)
    local line_time = LoadFromLayer("Line Time") or LINE_TIME_START

    local origin_frame_position = GetPositionFromTime(start) / 100
    local original_diff = origin_frame_position - LINE_TIME_START * map.InitialScrollVelocity

    for i = 0, frame_count - 1 do
        local line_offsets = f(i / frame_count)
        for _, line_offset in pairs(line_offsets) do
            table.insert(tp_queue, utils.CreateTimingPoint(line_time, BPM))
            Displace(line_time, original_diff + i * FRAME_SIZE + line_offset * FRAME_SIZE + (LINE_TIME_START - line_time) * map.InitialScrollVelocity)
            line_time = line_time + LINE_TIME_INCREMENT
        end
    end

    SaveInLayer("Line Time", line_time)
    table.insert(tp_queue, utils.CreateTimingPoint(stop, map.GetTimingPointAt(stop).Bpm))
end

function ResetQueue()
    action_queue = {}
    sv_queue = {}
    tp_queue = {}
end

function PerformQueue()
    if #sv_queue > 0 then Queue(action_type.AddScrollVelocityBatch, sv_queue) end
    if #tp_queue > 0 then Queue(action_type.AddTimingPointBatch, tp_queue) end

    if #action_queue > 0 then
        actions.PerformBatch(action_queue)
    end
end

function Queue(type, arg1, arg2, arg3, arg4)
    local action = utils.CreateEditorAction(type, arg1, arg2, arg3, arg4)
    table.insert(action_queue, action)
end

function IncreaseSV(time, multiplier)
    local sv = map.GetScrollVelocityAt(time) or utils.CreateScrollVelocity(-1e304, map.InitialScrollVelocity)

    if sv.StartTime == time then
        Queue(action_type.ChangeScrollVelocityMultiplierBatch, {sv}, sv.Multiplier + multiplier)
    else
        local newsv = utils.CreateScrollVelocity(time, sv.Multiplier + multiplier)
        table.insert(sv_queue, newsv)
    end
end

function Displace(time, displacement)
    IncreaseSV(time - DISPLACE_INCREMENT, displacement / DISPLACE_INCREMENT)
    IncreaseSV(time, -1 * displacement / DISPLACE_INCREMENT)
    IncreaseSV(time + DISPLACE_INCREMENT, 0)
end

function SaveInLayer(name, data)
    local data_layer = FindLayerThatStartsWith(name .. ": ")

    if data_layer then
        Queue(action_type.RenameLayer, data_layer, name .. ": " .. data)
    else
        data_layer = utils.CreateEditorLayer(name .. ": " .. data)
        Queue(action_type.CreateLayer, data_layer)
    end
end

function LoadFromLayer(name)
    local data_layer = FindLayerThatStartsWith(name .. ": ")

    if data_layer then
        return tonumber(data_layer.Name:sub(#name + 3, #data_layer.Name))
    end
end

function FindLayerThatStartsWith(str)
    for _, layer in pairs(map.EditorLayers) do
        if StartsWith(layer.Name, str) then
            return layer
        end
    end
end

--http://lua-users.org/wiki/StringRecipes
function StartsWith(str, start)
   return str:sub(1, #start) == start
end

function GetPositionFromTime(time)
    --[[
        if using this function multiple times in one frame,
        it may be faster to set ScrollVelocities = map.ScrollVelocities in draw()
        and then set local svs = ScrollVelocities inside this function
    ]]
    local svs = map.ScrollVelocities

    if #svs == 0 or time < svs[1].StartTime then
        return math.floor(time * 100 * map.InitialScrollVelocity)
    end

    local position = math.floor(svs[1].StartTime * 100 * map.InitialScrollVelocity)

    local i = 2

    while i <= #svs do
        if time < svs[i].StartTime then
            break
        else
            position = position + math.floor((svs[i].StartTime - svs[i - 1].StartTime) * svs[i - 1].Multiplier * 100)
        end

        i = i + 1
    end

    i = i - 1

    position = position + math.floor((time - svs[i].StartTime) * svs[i].Multiplier * 100)
    return position
end
# LineAnimation
Make lines that move

# Requirements
- A Quaver build that
  - Doesn't sandbox plugins (allows the load() function)
  - Has map.InitialScrollVelocity
- A map with BPM affects SV disabled
  
# Recommended
- Knowledge of algebraic functions
- Knowledge of expressing such functions in Lua
- A graphing calculator
- A way to backup .qua files
- Maybe knowledge of basic calculus

# How to Use
1. Select a time period for an animation to occur during
2. Adjust advanced settings if desired
3. Press the "Setup" button to place the base animation SVs
4. Express the desired paths of lines as algebraic functions written in lua
5. Press the "Add" button to place timing points and SVs so that moving lines appear during the selected time period

# Writing a Function
- The function should take one number as an input representing the progress through an animation
- The function should return a table/list of numbers as an output representing the position of lines in a frame
- The function's domain is \[0, 1\)
  - 0 represents the start of the animation
  - 1 represents the end of the animation
- The function's range should be \[0, 1\]
  - 0 represents the bottom of the playfield
  - 1 represents the top of the frame
    - Frame size defaults to 600 ms equivalent distance at 1x SV
  - Numbers outside of this range will result in lines under or overflowing into adjacent frames

# Important Notes
- Changing the SVs anytime before an animation is likely to mess it up
- Once the base animation SVs are placed, the advanced settings should not be changed
- A note present during an animation will show for only a single frame before it gets hit
- Separate lines can be added one at a time instead of in a batch, if desired
- Do not delete the layer this plugin creates, as it contains important data for it to function
- The .qua file will dramatically increase in size
- The gameplay preview playfield in the editor is taller than during gameplay
- Make backups, as it is somewhat painful to edit/remove animations after being saved

# Example
- Map: https://quavergame.com/mapset/4689
- Functions: https://www.desmos.com/calculator/gff6gawyfe

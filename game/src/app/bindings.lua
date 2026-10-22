-- Keys of play as data (plan v5 G2): what app/input.lua reads for movement
-- and the gameplay actions. A rebinding screen or a new ability slot changes
-- this table, not the input code. Menus keep their keys in app/screens.lua.
--   held      keys sampled every step (any key of the list holds it)
--   actions   keys pressed once (any key of the list)
--   abilities ability slots in order: the n-th key casts slot n
return {
  held = {
    forward = { 'w', 'up' },
    back = { 's', 'down' },
    right = { 'd' },
    left = { 'a' },
    turnRight = { 'right' },
    turnLeft = { 'left' },
    jump = { 'space' },
  },
  actions = {
    pause = { 'escape' },
    dash = { 'lshift', 'rshift' },
    slide = { 'lctrl', 'rctrl' },
    jump = { 'space' },
    interact = { 'e' },
    reload = { 'r' },
    map = { 'tab' },
    ready = { 'return' },
  },
  abilities = { 'q', 'f', 'c' },
}

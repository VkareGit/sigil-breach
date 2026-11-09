-- Presentation preferences and the extra row on the pause page.
local Settings = {
  -- A sound level moves a tenth at a time, between silence and full (0.45, owner D17).
  levelSteps = 10,
  -- Mouse sensitivity and field of view (degrees): first value, range, step.
  sensitivity = { default = 1, low = 0.2, high = 3, step = 0.1 },
  fov = { default = 100, low = 85, high = 115, step = 5 },
  -- The first music and ambience levels.
  music = 0.65,
  ambience = 0.65,
  renderScale = { default = 1, choices = { 1, 0.75, 0.5 }, percent = 100 },
  pause = {
    -- Rows 44 apart from 238 (0.45: four sound levels in two rows of two).
    rowY = 238,
    rowStep = 44,
    scale = { x = 670, y = 506, w = 230, h = 34, labelX = 384, labelY = 508, font = 22 },
    helpY = 550,
    footerY = 600,
    fieldHeight = 534,
    -- The page: its veil, panel, title, writing field, the saved note, the
    -- two columns of names and values, the font of a row and of a level,
    -- the four sound levels (left and right column, rows three and four),
    -- the motion label's box and its smallest font, and the tip.
    veil = 0.88,
    panel = { 350, 62, 580, 586 },
    title = { 430, 100, 420, 40 },
    field = { x = 382, y = 100, w = 516 },
    savedY = 221,
    small = 14,
    nameX = 384,
    valueX = 704,
    font = 22,
    levelFont = 20,
    levels = { left = { 384, 470 }, right = { 630, 758 }, first = 3, second = 4 },
    motion = { w = 272, h = 32, smallest = 16 },
    tipY = 667,
    tipFont = 16,
    -- Its buttons (ui/views.lua): the way back; the steppers of sensitivity
    -- and field of view; the sound levels' steppers (left and right column,
    -- each a minus and a plus); the toggles (raised a little); the wide
    -- buttons of the last rows.
    resume = { x = 380, y = 164, w = 520, h = 46 },
    stepper = { w = 48, h = 34, minus = 784, plus = 852 },
    level = { w = 40, h = 34, left = { 530, 576 }, right = { 814, 860 } },
    toggle = { x = 670, w = 230, h = 42, raise = 2 },
    wide = { w = 252, h = 42, left = 380, right = 648 },
  },
}
function Settings.stepLevel(level, up)
  local steps = Settings.levelSteps
  local step = math.floor(level * steps + 0.5) + (up and 1 or -1)
  return math.max(0, math.min(steps, step)) / steps
end
return Settings

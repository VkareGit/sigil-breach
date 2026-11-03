-- Presentation preferences and the extra row on the pause page.
local Settings = {
  -- A sound level moves a tenth at a time, between silence and full (0.45, owner D17).
  levelSteps = 10,
  renderScale = { default = 1, choices = { 1, 0.75, 0.5 }, percent = 100 },
  pause = {
    -- Rows 44 apart from 238 (0.45: four sound levels in two rows of two).
    rowY = 238,
    rowStep = 44,
    scale = { x = 670, y = 506, w = 230, h = 34, labelX = 384, labelY = 508, font = 22 },
    helpY = 550,
    footerY = 600,
    fieldHeight = 534,
  },
}
function Settings.stepLevel(level, up)
  local steps = Settings.levelSteps
  local step = math.floor(level * steps + 0.5) + (up and 1 or -1)
  return math.max(0, math.min(steps, step)) / steps
end
return Settings

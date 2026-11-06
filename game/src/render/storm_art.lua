-- Sparse painted fractures stand on the real footprint, visible from inside it.
-- All panels share one bounded mesh; the source paintings remain unchanged.
local Art = require('src.render.hazard_art')
local Rites = require('src.content.art.rites')
local Storm = {}
local panels = require('src.render.painted_panels').draw
function Storm.ground(r, g, h)
  local style = Rites.lightnings[h.art]
  if not style then
    return false
  end
  if h.delay > 0 then
    Art.circle(r, g, h, 'circle', h.radius, style.warningAlpha)
  end
  return true
end
function Storm.air(r, g, h)
  local style = Rites.lightnings[h.art]
  if not style then
    return false
  end
  local preparing = h.delay > 0
  local progress = preparing and 1 - h.delay / math.max(h.maxDelay, 0.001)
    or 1 - h.life / style.flash
  local top = h.volume.top
  local cell = Art.sequence(style.frames, progress)
  local alpha = preparing and style.warningAlpha + (1 - style.warningAlpha) * progress
    or style.edgeAlpha
  panels(
    r,
    g,
    h,
    style,
    cell,
    style.columns,
    h.radius,
    style.warningWidth,
    style.warningWidth,
    alpha,
    style.warningBase
  )
  if not preparing then
    panels(r, g, h, style, cell, 1, 0, style.strikeWidth, top, 1 - math.max(0, progress) * 0.5)
  end
  return true
end
function Storm.residue(r, g, h, age)
  local style = Rites.lightnings[h.art]
  if style and age >= 0 and age < style.embers then
    Art.circle(r, g, h, style.spent, h.radius * 0.5, 0.45 * (1 - age / style.embers))
  end
end
return Storm

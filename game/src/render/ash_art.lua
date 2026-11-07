-- Ash warns above the true rim; living coals remain as low as their contact volume.
local HazardArt = require('src.render.hazard_art')
local Rites = require('src.content.art.rites')
local Panels = require('src.render.painted_panels')
local Ash = {}
function Ash.ground(r, g, h)
  local style = Rites.pools[h.art]
  if not style then
    return false
  end
  HazardArt.ribbon(
    r,
    g,
    h,
    style.spent,
    'ring',
    h.radius,
    math.min(h.radius, style.width),
    0,
    0,
    h.delay > 0 and 0.65 or 0.85
  )
  return true
end
function Ash.air(r, g, h)
  local style = Rites.pools[h.art]
  if not style then
    return false
  end
  if h.delay > 0 then
    local progress = 1 - h.delay / math.max(h.maxDelay, 0.001)
    Panels.draw(
      r,
      g,
      h,
      style,
      style.spent,
      style.columns,
      h.radius,
      style.warningWidth,
      style.warningHeight,
      0.55 + progress * 0.45,
      style.warningBase
    )
  else
    local frame = style.frames[1 + math.floor(-h.delay * style.rate) % #style.frames]
    HazardArt.ribbon(
      r,
      g,
      h,
      frame,
      'ring',
      h.radius,
      math.min(h.radius, style.width),
      h.volume.top,
      0,
      1,
      style
    )
    Panels.draw(
      r,
      g,
      h,
      style,
      frame,
      style.columns,
      h.radius * 0.5,
      style.flameWidth,
      h.volume.top,
      1,
      0
    )
  end
  return true
end
function Ash.residue(r, g, h, age)
  local style = Rites.pools[h.art]
  if style and age >= 0 and age < style.embers then
    HazardArt.ribbon(
      r,
      g,
      h,
      style.spent,
      'ring',
      h.radius,
      math.min(h.radius, style.width),
      0,
      0,
      0.65 * (1 - age / style.embers)
    )
  end
end
return Ash

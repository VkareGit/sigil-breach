-- Short painted debris follows the actual contact footprint, never a predicted target.
local Art = require('src.render.hazard_art')
local Rites = require('src.content.art.rites')
local Impact = {}
function Impact.draw(r, g, h, age)
  local style = Rites.impacts[h.art]
  if not style or age < 0 or age >= style.life then
    return
  end
  local progress = age / style.life
  Art.ribbon(
    r,
    g,
    h,
    Art.sequence(style.frames, progress),
    'ring',
    h.radius,
    math.min(h.radius, style.width),
    style.height * (1 - progress),
    0,
    1 - progress
  )
end
return Impact

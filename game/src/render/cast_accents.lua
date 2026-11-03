-- Energy belongs to the presentation, never to a body's alpha or hit mask.
local Surface = require('src.enemies.surface')
local ActionPhase = require('src.enemies.action_phase')
local Rites = require('src.content.art.rites')
local Accents = {}
local posed = {}
local function centre(g, e, id)
  local p = Surface.prepare(g, e, posed)
  for _, part in ipairs(p.parts) do
    if part.id == id then
      local left, top, right, bottom = 1, 1, 0, 0
      for i = 1, #part.polygon, 2 do
        left, right = math.min(left, part.polygon[i]), math.max(right, part.polygon[i])
        top, bottom = math.min(top, part.polygon[i + 1]), math.max(bottom, part.polygon[i + 1])
      end
      return Surface.point(p, (left + right) * 0.5, (top + bottom) * 0.5)
    end
  end
end
function Accents.draw(r, g, e, effects)
  local spec = e.attackSpec
  if not spec or e.hp <= 0 then
    return false
  end
  local windup = e.ai == 'windup'
  if spec.id == 'star-lance' and windup then
    local t = ActionPhase.sample(e)
    local x, y, z = centre(g, e, 'head')
    if x then
      effects.spell(r, g, 0, t, x, y - 0.09, z + 0.03, 0.18 + 0.35 * t, 0.45 + t * 0.5, false)
    end
    return true
  end
  if Rites.antlerCasts[spec.id] and (windup or e.ai == 'strike') then
    local t = ActionPhase.sample(e)
    local charge = windup and t or math.max(0, 1 - (e.phase or 0) / 0.16)
    if not windup and spec.kind == 'storm' then
      -- These are the marking instants, not the later strikes of each ground mark.
      local beat = (e.phase or 0) % spec.interval
      charge = math.max(0, 1 - beat / 0.16)
    end
    local x, y, z = centre(g, e, 'antlers')
    if x then
      local p = posed
      for i = 1, 4 do
        local side = (i - 2.5) * 0.17
        effects.spell(
          r,
          g,
          0,
          (t + i * 0.19) % 1,
          x + p.rx * side,
          y + (i % 2) * 0.13,
          z + p.rz * side,
          0.13 + charge * 0.35,
          0.22 + charge * 0.70,
          false
        )
      end
    end
    return true
  end
  return false
end
return Accents

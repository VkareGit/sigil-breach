-- Flat painted cels. The measured solid core contains the authoritative
-- collision sphere; peripheral flames/ice are an accent, never a new hit area.
local Shape = require('src.combat.projectile_shape')
local Pools = require('src.session.world')
local Context = require('src.session.context')
local Rites = require('src.content.art.rites')
local HazardArt = require('src.render.hazard_art')
local GardenArt = require('src.render.garden_art')
local Pass = {}
function Pass.draw(r, g)
  local art = Rites.projectiles
  local viewer = Context.viewer(g)
  local frame = 1 + math.floor(g.time * art.rate) % 4
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    if not GardenArt.projectile(r, g, b) then
      local style = art.styles[b.packet and b.packet.damageType] or art.default
      local radius = Shape.radius(b)
      local size = radius * 2 / style.core
      HazardArt.upright(
        r,
        b.x,
        b.y - size * 0.5,
        b.z,
        style.prefix .. frame,
        size,
        math.atan2(viewer.x - b.x, viewer.z - b.z),
        1
      )
    end
  end
end
return Pass

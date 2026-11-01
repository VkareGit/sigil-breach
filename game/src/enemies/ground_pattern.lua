-- Reusable ground pattern delivery. A release places a bounded set of marks;
-- the existing hazard system owns warning time, contact volume and lifetime.
local Hazards = require('src.enemies.hazards')
local Rules = require('src.combat.rules')
local Bodies = require('src.combat.bodies')
local World = require('src.world.arena')
local Pattern = {}
function Pattern.release(g, e, attack, angle)
  local x, z, level = e.aimX, e.aimZ, e.aimLevel
  if attack.origin == 'caster' then
    x, z, level = e.x, e.z, e.level
  end
  local forwardX, forwardZ = math.sin(angle), math.cos(angle)
  local packet = attack.packet
  for _, mark in ipairs(attack.marks) do
    local mx = x + forwardX * mark.forward + forwardZ * mark.lateral
    local mz = z + forwardZ * mark.forward - forwardX * mark.lateral
    if World.visible(g.world, e.x, e.z, mx, mz) then
      Hazards.add(g, mx, mz, mark.delay, attack.radius, attack.life, {
        kind = attack.hazard,
        packet = packet,
        pulse = attack.pulse,
        condition = attack.condition,
        volume = attack.volume,
        owner = e.id,
        side = Bodies.side(g, e),
        level = level,
      })
    end
  end
end
return Pattern

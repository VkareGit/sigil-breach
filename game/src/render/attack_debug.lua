-- Diagnostic contact painters, separate from attack art and damage handlers.
-- They read the simulation's current reach/window; drawing never advances it.
local Registry = require('src.core.registry')
local Melee = require('src.combat.melee')
local Ground = require('src.physics.ground')
local AttackDebug = {}
local painters = Registry:new('attack contact diagnostic', function(draw, id)
  assert(type(draw) == 'function', 'attack contact diagnostic ' .. id .. ': expected painter')
end)
function AttackDebug.register(id, draw)
  assert(not painters:has(id), 'attack contact diagnostic already registered: ' .. id)
  return painters:register(id, draw)
end
function AttackDebug.unregister(id)
  return painters:unregister(id)
end
AttackDebug.register('lunge', function(r, g, e, atk, colors)
  local from, to = Melee.window(atk)
  local live = e.phase >= from and e.phase <= to and not e.didHit
  local x, y, z, dx, dz = Melee.reach(g, e, e.phase, e.x, e.z, atk)
  y = y + Ground.height(g.world)
  for _, depth in ipairs(Melee.depths(atk)) do
    r:object(
      r.spark,
      x + dx * depth,
      y,
      z + dz * depth,
      0,
      live and 1.1 or 0.6,
      live and colors.attack or colors.idle
    )
  end
end)
AttackDebug.register('charge', function(r, g, e, atk, colors)
  if e.lungeX then
    r:object(
      r.spark,
      e.x + e.lungeX * atk.reach,
      Ground.height(g.world, e.x, e.z) + atk.contactY,
      e.z + e.lungeZ * atk.reach,
      0,
      e.didHit and 0.6 or 1.1,
      e.didHit and colors.idle or colors.attack
    )
  end
end)
AttackDebug.register('leap', function(r, g, e, atk, colors)
  if e.leaping then
    r:object(
      r.warning,
      e.x,
      Ground.height(g.world, e.x, e.z) + 0.03,
      e.z,
      0,
      atk.landRadius,
      colors.attack,
      0.85
    )
  end
end)
function AttackDebug.draw(r, g, e, colors)
  local atk = e.attackSpec
  if not atk or e.ai ~= 'strike' then
    return
  end
  local draw = painters:find(atk.kind)
  if draw then
    draw(r, g, e, atk, colors)
  end
end
return AttackDebug

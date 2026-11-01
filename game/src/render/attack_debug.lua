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
      Ground.of(g.world, e) + atk.contactY,
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
      Ground.of(g.world, e) + 0.03,
      e.z,
      0,
      atk.landRadius,
      colors.attack,
      0.85
    )
  end
end)
-- A swung blow: its path or its arc as dots, and the blade where it is now.
local PATH_DOTS = 9
local function swung(r, g, e, atk, colors)
  local floor = Ground.of(g.world, e)
  local from = atk.active[1]
  local span = atk.active[2] - from
  for dot = 0, PATH_DOTS do
    local at = from + span * dot / PATH_DOTS
    local x, y, z, dx, dz = Melee.reach(g, e, at, e.x, e.z, atk)
    if not atk.trace then
      y, dx, dz = floor + 1, e.lungeX * atk.reach, e.lungeZ * atk.reach
      local yaw = math.atan2(dx, dz) + atk.arc * (dot / PATH_DOTS - 0.5)
      dx, dz = math.sin(yaw) * atk.reach, math.cos(yaw) * atk.reach
    else
      y = y + Ground.height(g.world)
    end
    r:object(r.spark, x + dx, y, z + dz, 0, 0.5, colors.idle)
  end
  if atk.trace and e.phase >= from and e.phase <= atk.active[2] then
    local x, y, z, dx, dz = Melee.reach(g, e, e.phase, e.x, e.z, atk)
    y = y + Ground.height(g.world)
    for _, share in ipairs(atk.blade) do
      r:object(
        r.spark,
        x + dx * share,
        y,
        z + dz * share,
        0,
        e.didHit and 0.7 or 1.2,
        e.didHit and colors.idle or colors.attack
      )
    end
  end
end
AttackDebug.register('sweep', swung)
AttackDebug.register('seize', swung)
-- The way a body in its windup faces: gold while it can still turn, red once locked.
local LOCK_DOTS = 4
local function windup(r, g, e, atk, colors)
  local turning = atk.turn and e.windup >= e.windupDuration * (1 - atk.lockAt)
  local yaw = atk.turn and e.facing or math.atan2(e.aimX - e.x, e.aimZ - e.z)
  for dot = 1, LOCK_DOTS do
    r:object(
      r.spark,
      e.x + math.sin(yaw) * dot,
      Ground.of(g.world, e) + 1,
      e.z + math.cos(yaw) * dot,
      0,
      0.8,
      turning and colors.idle or colors.attack
    )
  end
end
function AttackDebug.draw(r, g, e, colors)
  local atk = e.attackSpec
  if not atk then
    return
  end
  if e.ai == 'windup' and e.aimX then
    return windup(r, g, e, atk, colors)
  end
  if e.ai ~= 'strike' then
    return
  end
  local draw = painters:find(atk.kind)
  if draw then
    draw(r, g, e, atk, colors)
  end
end
return AttackDebug

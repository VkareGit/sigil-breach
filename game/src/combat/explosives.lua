-- Limited physical ordnance: fuse, wall sweep and blast share simulation time.
local Signal = require('src.session.signal')
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local B = require('src.combat.ballistics')
local D = require('src.combat.damage')
local Tuning = require('src.content.tuning')
local Flight = require('src.physics.ordnance_flight')
local Ground = require('src.physics.ground')
local chest = require('src.content.combat_defaults').missiles.chest
-- The behaviour of the 'throw' delivery; the powder charge itself is data
-- (content/abilities.lua: powder), in the same format as demon attacks.
local Abilities = require('src.content.abilities')
local function defaultAction()
  return Abilities:get('powder').action
end
local K = Tuning.explosives
-- Legacy inspection values; flight and blast read the action of each charge.
local X = { radius = defaultAction().radius, fuse = defaultAction().fuse }
local function clear(g, b, x, y, z)
  local dx, dy, dz = x - b.x, y - b.y, z - b.z
  local d = math.sqrt(dx * dx + dy * dy + dz * dz)
  if d < 0.001 then
    return true, d
  end
  local hit, _, kind = B.world(g.world, b.x, b.y, b.z, dx / d, dy / d, dz / d, d)
  return kind == 'range' or hit >= d - 1e-5, d
end
-- The 'throw' delivery: a charge leaves the eye along the aim (gates and
-- uses are the caster's: combat/abilities.lua).
function X.launch(g, action)
  action = action or defaultAction()
  -- Every throw uses the same gravity, scaled from its authored reference.
  local throwScale = math.sqrt(Tuning.gravity / action.referenceGravity)
  local throwSpeed, throwLift = action.speed * throwScale, action.lift * throwScale
  local p = g.player
  local x, y, z = B.origin(g)
  local dx, dy, dz = B.direction(p.yaw, p.pitch)
  local spawn = B.world(g.world, x, y, z, dx, dy, dz, K.spawnReach)
  spawn = math.max(0, spawn - K.spawnClearance)
  g.charges = g.charges or {}
  Spawn.make(g, 'charge', {
    action = action,
    x = x + dx * spawn,
    y = y + dy * spawn,
    z = z + dz * spawn,
    vx = dx * throwSpeed,
    vy = dy * throwSpeed + throwLift,
    vz = dz * throwSpeed,
    fuse = action.fuse,
    maxFuse = action.fuse,
    spin = 0,
  })
  Signal(g, 'ChargeThrown', {})
  require('src.enemies.ai').noise(g, p.x, p.z, action.noise)
  return true
end
function X.explode(g, b)
  local action = b.action or defaultAction()
  local report =
    { targets = 0, kills = 0, healthDamage = 0, blocked = 0, impact = 0, selfDamage = 0 }
  local ground = Ground.height(g.world)
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      -- The blast samples the physical body anchor. A leap moves it; visual bob
      -- and hover do not change exposure or damage.
      local y = ground
        + (require('src.combat.rules').body(e).aimY or Tuning.explosives.aimHeight)
        + (e.leapY or 0)
      local visible, d = clear(g, b, e.x, y, e.z)
      if visible and d < action.radius then
        local dealt, blocked, impact, push = D.resolve(action.blast, e, d)
        local health = math.min(e.hp, dealt)
        g:damageEnemy(e, dealt, 'charge')
        require('src.combat.combat').react(
          g,
          e,
          impact,
          true,
          { e.x, y, e.z },
          nil,
          health,
          { push = push, direction = { e.x - b.x, e.z - b.z } },
          { value = health, kill = e.hp <= 0 }
        )
        report.targets = report.targets + 1
        report.kills = report.kills + (e.hp <= 0 and 1 or 0)
        report.healthDamage = report.healthDamage + health
        report.blocked = report.blocked + blocked
        report.impact = report.impact + impact
      end
    end
  end
  local p = g.player
  -- The blast meets the knight at his chest, as a missile does (0.25).
  local visible, d = clear(g, b, p.x, ground + chest + p.jump - (p.crouch or 0), p.z)
  if visible and d < action.radius then
    local before = p.hp
    local own = action.selfBlast
    local f = D.falloff(d, own.falloffStart, own.falloffEnd, own.minPower)
    -- source 'self': the knight's own charge is never a perfect dodge.
    g:damagePlayer(
      own.base * f,
      b.x,
      b.z,
      { base = own.base * f, impact = own.impact * f, damageType = own.damageType },
      'self'
    )
    report.selfDamage = math.max(0, before - p.hp)
  end
  g.explosionReport = report
  Signal(g, 'ChargeExploded', { charge = b })
  require('src.enemies.ai').noise(g, b.x, b.z, Tuning.explosives.blastNoise)
end
local finite, floorHeight = MathX.finite, Tuning.floorSurface
function X.update(g, dt)
  if not finite(dt) or dt <= 0 then
    return
  end
  local list = g.charges or {}
  for i = #list, 1, -1 do
    local b = list[i]
    if
      not (
        finite(b.x)
        and finite(b.y)
        and finite(b.z)
        and finite(b.vx)
        and finite(b.vy)
        and finite(b.vz)
        and finite(b.fuse)
      )
    then
      table.remove(list, i)
    else
      -- Its flight is solved in heights above the ground (physics/ground.lua).
      local ground = Ground.height(g.world)
      b.y = b.y - ground
      if b.y < floorHeight then
        b.y = floorHeight
      end
      local step = math.max(0, math.min(dt, b.fuse))
      b.fuse = math.max(0, b.fuse - step)
      b.spin = (b.spin or 0) + step * K.spin
      Flight.advance(g.world, b, step, Tuning.gravity, floorHeight, K)
      b.y = b.y + ground
      if b.fuse <= 1e-9 then
        table.remove(list, i)
        X.explode(g, b)
        if g.state ~= 'playing' then
          break
        end
      end
    end
  end
end
return X

-- Limited physical ordnance: fuse, wall sweep and blast share simulation time.
local Rules = require('src.combat.rules')
local AI = require('src.enemies.ai')
local Entities = require('src.session.entities')
local Signal = require('src.session.signal')
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local Ballistics = require('src.combat.ballistics')
local Damage = require('src.combat.damage')
local Tuning = require('src.content.tuning')
local OrdnanceFlight = require('src.physics.ordnance_flight')
local Ground = require('src.physics.ground')
local chest = require('src.content.combat_defaults').missiles.chest
-- The behaviour of the 'throw' delivery; the powder charge itself is data
-- (content/abilities.lua: powder), in the same format as demon attacks.
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Effects = require('src.combat.effects')
local Hit = require('src.combat.hit')
local K = Tuning.explosives
-- Flight and blast read the action of each charge (its fuse, radius, blast).
local X = {}
local function clear(g, b, x, y, z)
  local dx, dy, dz = x - b.x, y - b.y, z - b.z
  local d = math.sqrt(dx * dx + dy * dy + dz * dz)
  if d < 1e-3 then
    return true, d
  end
  local hit, _, kind = Ballistics.world(g.world, b.x, b.y, b.z, dx / d, dy / d, dz / d, d)
  return kind == 'range' or hit >= d - 1e-5, d
end
-- The 'throw' delivery: a charge leaves the eye along the aim (gates and
-- uses are the caster's: combat/abilities.lua).
-- caster: who throws (combat/caster.lua).
function X.launch(g, action, caster)
  -- Every throw uses the same gravity, scaled from its authored reference.
  local throwScale = math.sqrt(Tuning.gravity / action.referenceGravity)
  local throwSpeed, throwLift = action.speed * throwScale, action.lift * throwScale
  local x, y, z, dx, dy, dz = caster.x, caster.y, caster.z, caster.dx, caster.dy, caster.dz
  local spawn = Ballistics.world(g.world, x, y, z, dx, dy, dz, K.spawnReach)
  spawn = math.max(0, spawn - K.spawnClearance)
  Spawn.make(g, 'charge', {
    action = action,
    -- The thrower owns the blast and every consequence of it (plan v11 E3d).
    owner = caster.owner,
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
  Signal(g, 'ChargeThrown', { actor = caster.owner })
  local at = caster.body or caster
  AI.noise(g, at.x, at.z, action.noise)
  return true
end
-- A blast from point b (x, y, z, owner) on every creature it reaches. Returns
-- its tally.
function X.strike(g, b, radius, blast, source)
  local report =
    { targets = 0, kills = 0, healthDamage = 0, blocked = 0, impact = 0, selfDamage = 0 }
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      -- The blast samples the physical body anchor. A leap moves it; visual bob
      -- and hover do not change exposure or damage.
      local y = Ground.of(g.world, e)
        + (Rules.body(e).aimY or Tuning.explosives.aimHeight)
        + (e.leapY or 0)
      local visible, d = clear(g, b, e.x, y, e.z)
      if visible and d < radius then
        local dealt, blocked, impact, push = Hit.measure(blast, e, d)
        local health = Hit.land(g, e, { damage = dealt, impact = impact }, {
          source = source,
          payload = blast,
          owner = b.owner,
          strong = true,
          point = { e.x, y, e.z },
          extra = { push = push, direction = { e.x - b.x, e.z - b.z }, origin = b },
          numbered = true,
        })
        report.targets = report.targets + 1
        report.kills = report.kills + (e.hp <= 0 and 1 or 0)
        report.healthDamage = report.healthDamage + health
        report.blocked = report.blocked + blocked
        report.impact = report.impact + impact
      end
    end
  end
  Entities.within(g, b.x, b.z, radius, function(thing, d)
    Entities.hurt(g, thing, (Hit.measure(blast, thing, d)), b.owner)
  end)
  return report
end
function X.explode(g, b)
  local action = b.action
  local report = X.strike(g, b, action.radius, action.blast, 'charge')
  -- A blast hurts every knight in reach (content/factions.lua: indiscriminate),
  -- its thrower included, at his chest as a missile meets him (0.25), by the
  -- knights' own rule of the charge (selfBlast). Report the actual thrower's
  -- loss, even after control changes; an absent owner is not another knight.
  local thrower = b.owner and Bodies.actor(g, b.owner)
  for _, p in ipairs(Bodies.knights(g)) do
    if p == thrower or p.hp > 0 then
      local sampleY = Ground.of(g.world, p) + chest + p.jump - (p.crouch or 0)
      local visible, d = clear(g, b, p.x, sampleY, p.z)
      if visible and d < action.radius then
        local before = p.hp
        local own = action.selfBlast
        local f = Damage.falloff(d, own.falloffStart, own.falloffEnd, own.minPower)
        -- All knight charges retain the existing no-perfect-dodge policy.
        -- The effect source is separate, so it still names the actual caster.
        g:damageBody(
          p,
          own.base * f,
          b.x,
          b.z,
          {
            base = own.base * f,
            impact = own.impact * f,
            damageType = own.damageType,
            effects = own.effects,
          },
          'self',
          {
            effectSource = own.effects and Effects.origin(g, b.owner) or nil,
            contact = {
              kind = 'explosion',
              id = b.id,
              owner = b.owner,
              target = p.id,
              geometry = 'sphere-anchor',
              sourcePoint = { x = b.x, y = b.y, z = b.z },
              samplePoint = { x = p.x, y = sampleY, z = p.z },
              radius = action.radius,
              distance = d,
            },
          }
        )
        if p == thrower then
          report.selfDamage = math.max(0, before - p.hp)
        end
      end
    end
  end
  g.explosionReport = report
  Signal(g, 'ChargeExploded', { charge = b })
  AI.noise(g, b.x, b.z, Tuning.explosives.blastNoise)
end
local finite, floorHeight = MathX.finite, Tuning.floorSurface
function X.update(g, dt)
  if not finite(dt) or dt <= 0 then
    return
  end
  local list = Pools.of(g, 'charges')
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
      Pools.removeAt(g, 'charges', i)
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
      OrdnanceFlight.advance(g.world, b, step, Tuning.gravity, floorHeight, K)
      b.y = b.y + ground
      if b.fuse <= 1e-9 then
        Pools.removeAt(g, 'charges', i)
        X.explode(g, b)
        if g.state ~= 'playing' then
          break
        end
      end
    end
  end
end
return X

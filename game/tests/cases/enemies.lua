-- Regression fixtures are deliberately renderer-free: they exercise collision
-- times, attack clocks and hazards without depending on a screenshot or RNG.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(check)
  local AI = require('src.enemies.ai')
  local M = require('src.combat.melee')
  local A = require('src.audio.audio')
  local W = require('src.world.arena')
  local previousMuted = A.muted
  A.muted = true
  local near = Fixtures.within(1e-7, true)
  local function fixture(kind)
    local w = { size = 21, map = {} }
    for z = 1, 21 do
      w.map[z] = {}
      for x = 1, 21 do
        w.map[z][x] = (x == 1 or z == 1 or x == 21 or z == 21) and 1 or 0
      end
    end
    local g = {
      world = w,
      enemies = {},
      hazards = {},
      bullets = {},
      elapsed = 1,
      impactSlow = 0,
      damage = 0,
      hitCount = 0,
      player = { x = 10, z = 16, jump = 0, crouch = 0, yaw = math.pi },
    }
    function g:damagePlayer(amount)
      self.damage = self.damage + amount
      self.hitCount = self.hitCount + 1
    end
    local e = {
      kind = kind or 'imp',
      id = 1,
      x = 10,
      z = 10,
      hp = 100,
      maxHp = 100,
      hit = 0,
      attack = 99,
      speed = 0,
      walk = 0,
      deathTime = 0,
      stun = 0,
      pushX = 0,
      pushZ = 0,
    }
    AI.init(e)
    e.awake = false
    e.aimX, e.aimZ = g.player.x, g.player.z
    g.enemies[1] = e
    return g, e
  end
  local function advance(g, seconds, dt)
    local remaining = seconds
    while remaining > 1e-9 do
      local step = math.min(dt, remaining)
      g.elapsed = g.elapsed + step
      AI.update(g, step)
      remaining = remaining - step
    end
  end
  local g, e = fixture()
  e.lungeX, e.lungeZ = 0, 1
  g.player.x, g.player.z = 10, 10.65
  check(
    'v10 claw cannot damage before the authored active window',
    not M.claw(g, e, 10, 10, nil, 0, 0.05)
  )
  g.player.x = 12
  check(
    'v10 a player crossing before claw activation is not hit retroactively',
    not M.claw(g, e, 10, 10, { x = 9, z = 10.65, jump = 0, crouch = 0 }, 0, 0.06)
  )
  g.player.x = 11.5
  check(
    'v10 a player crossing after claw expiration is not hit retroactively',
    not M.claw(g, e, 10, 10, { x = 8, z = 10.65, jump = 0, crouch = 0 }, 0.17, 0.30)
  )
  g.player.x = 11
  check(
    'v10 crossing the real active claw arc still produces a hit',
    M.claw(g, e, 10, 10, { x = 9, z = 10.65, jump = 0, crouch = 0 }, 0.07, 0.15)
  )
  g.player.x = 10
  g.player.z = 10
  g.player.crouch = 0.8
  check(
    'v10 crouching before reaching a high strike clears its actual trajectory',
    not M.contact(g, 10, 10, 10, 10, 1.6, 0.05, { x = 8, z = 10, jump = 0, crouch = 0 })
  )
  g.player.x = 12
  g.player.crouch = 0
  check(
    'v10 standing up after leaving a high strike does not invent earlier contact',
    not M.contact(g, 10, 10, 10, 10, 1.6, 0.05, { x = 10, z = 10, jump = 0, crouch = 0.8 })
  )
  g.player.x = 10
  g.player.crouch = 0.8
  check(
    'v10 crouch cannot evade a low strike that intersects the body',
    M.contact(g, 10, 10, 10, 10, 0.7, 0.05, { x = 8, z = 10, jump = 0, crouch = 0 })
  )
  g.player.crouch = 0
  g.player.jump = 2
  check(
    'v10 jumping above a strike before horizontal contact is an actual dodge',
    not M.contact(g, 10, 10, 10, 10, 0.94, 0.05, { x = 8, z = 10, jump = 0, crouch = 0 })
  )
  g.player.jump = 0
  local hit, time = M.contact(g, 10, 10, 10, 10, 0.94, 0.05)
  check('v10 an initial contact is reported at exact time zero', hit and time == 0)
  g.player.x = 12
  g.world.map[10][10] = 1
  check(
    'v10 moving melee volumes cannot cross a solid wall',
    not M.contact(g, 8, 10, 12, 10, 0.94, 0.18)
  )
  g, e = fixture('furfur')
  e.ai = 'strike'
  e.attackKind = 'melee'
  e.phase = 0.04
  e.hitPause = 0.2
  e.lungeX, e.lungeZ = 0, 1
  AI.update(g, 0.05)
  check(
    'v10 hit pause freezes the attack phase and movement together',
    near(e.phase, 0.04) and e.z == 10 and near(e.hitPause, 0.15)
  )
  e.hitPause = 0
  e.stun = 0.2
  e.ai = 'recover'
  e.recover = 0.6
  AI.update(g, 0.1)
  check(
    'v10 stun cannot silently consume the visible recovery window',
    near(e.recover, 0.6) and near(e.phase, 0.04)
  )
  g, e = fixture('furfur')
  e.ai = 'strike'
  e.attackKind = 'melee'
  e.phase = 0.19
  e.lungeX, e.lungeZ = 0, 1
  AI.update(g, 0.1)
  check(
    'v10 Furfur melee advances only the remaining movement window',
    near(e.z, 10.03) and g.hitCount == 0
  )
  g, e = fixture('furfur')
  e.ai = 'strike'
  e.attackKind = 'charge'
  e.phase = 0.49
  e.chargeTime = 0.5
  e.lungeX, e.lungeZ = 0, 1
  g.player.x, g.player.z = 10, 10.8
  AI.update(g, 0.1, { x = 8, z = 10.8, jump = 0, crouch = 0 })
  check(
    'v10 entering a charge lane after the charge ends is safe',
    near(e.z, 10.12) and g.hitCount == 0
  )
  g, e = fixture()
  e.z = 14.6
  e.awake = true
  e.attack = 0
  advance(g, 0.7, 1 / 120)
  check(
    'v10 a stationary player still receives the readable close imp attack',
    g.hitCount == 1 and g.damage == 15
  )
  g, e = fixture('furfur')
  e.awake = true
  e.attack = 0
  advance(g, 1.65, 1 / 120)
  check(
    'v10 remaining in Furfur charge lane takes exactly one committed hit',
    g.hitCount == 1 and g.damage == 28
  )
  g, e = fixture('furfur')
  e.awake = true
  e.attack = 0
  AI.update(g, 1 / 120)
  local aimX, aimZ = e.aimX, e.aimZ
  g.player.x = 14
  advance(g, 1.65, 1 / 120)
  check(
    'v10 sidestepping a charging boss remains safe without target magnetism',
    g.hitCount == 0 and e.aimX == aimX and e.aimZ == aimZ and near(e.x, 10)
  )
  g, e = fixture('furfur')
  e.awake = true
  e.attack = 0
  e.attackCount = 1
  AI.update(g, 0.01)
  local h = g.hazards[1]
  local delay = e.windup
  e.stun = 0.5
  advance(g, 0.2, 0.01)
  check(
    'v10 lightning telegraph shares the staggered caster clock',
    h and h.waitForCast and near(h.delay, delay) and near(e.windup, delay) and g.hitCount == 0
  )
  e.stun = 0
  advance(g, delay + 0.3, 0.01)
  check(
    'v10 lightning releases once after the completed casting animation',
    g.hitCount == 1 and g.damage == 30 and #g.hazards == 0
  )
  g, e = fixture('furfur')
  e.awake = true
  e.attack = 0
  e.attackCount = 1
  AI.update(g, 0.01)
  e.hp = 0
  advance(g, 2, 0.02)
  check(
    'v10 killing a paused or pending lightning caster cancels the footprint',
    g.hitCount == 0 and #g.hazards == 0
  )
  g, e = fixture('furfur')
  e.awake = true
  e.attack = 0
  e.attackCount = 1
  AI.update(g, 0.01)
  g.world.map[13][10] = 1
  advance(g, 2, 0.02)
  check(
    'v10 a newly blocked casting path cancels the pending lightning',
    g.hitCount == 0 and #g.hazards == 0
  )
  local function poison(dt)
    local trial = fixture()
    trial.enemies = {}
    trial.hazards =
      { { x = 10, z = 16, radius = 2, delay = 0.1, maxDelay = 0.1, life = 0.7, pulse = 0 } }
    advance(trial, 0.8, dt)
    return trial
  end
  local fine, coarse = poison(0.01), poison(0.2)
  check(
    'v10 poison pulses keep their authored cadence across frame rates',
    fine.hitCount == 2 and coarse.hitCount == fine.hitCount and coarse.damage == 16
  )
  g = fixture()
  g.enemies = {}
  g.hazards = { { x = 10, z = 16, radius = 2, delay = 0.1, maxDelay = 0.1, life = 1, pulse = 0 } }
  AI.update(g, 0.12)
  check(
    'v10 crossing a hazard delay consumes only its actual active lifetime',
    near(g.hazards[1].life, 0.98) and near(g.hazards[1].pulse, 0.43) and g.hitCount == 1
  )
  g = fixture()
  g.enemies = {}
  g.player.x, g.player.z = 11, 10
  g.world.map[10][10] = 1
  g.hazards = { { x = 9, z = 10, radius = 3, delay = 0, maxDelay = 0, life = 1, pulse = 0 } }
  AI.update(g, 0.02)
  check('v10 poison cannot damage through a solid pillar inside its radius', g.hitCount == 0)
  g = fixture()
  g.enemies = {}
  g.player.x, g.player.z = 10, 16
  g.hazards =
    { { x = 10, z = 16, radius = 0.3, delay = 0.05, maxDelay = 0.05, life = 1, pulse = 0 } }
  AI.update(g, 0.1, { x = 8, z = 16, jump = 0, crouch = 0 })
  check('v10 hazard pulses sample player position at the actual event time', g.hitCount == 0)
  local function knockback(dead, dt)
    local trial, foe = fixture()
    foe.pushX = 8
    foe.hp = dead and 0 or 100
    advance(trial, dead and 1.0 or 0.2, dt)
    return foe.x, foe.pushX
  end
  local x1, v1 = knockback(false, 0.01)
  local x2, v2 = knockback(false, 0.2)
  check(
    'v10 living enemy impulse uses the analytic exponential displacement',
    near(x1, x2) and near(v1, v2) and near(x1, 10 + 8 * (1 - math.exp(-14 * 0.2)) / 14)
  )
  x1, v1 = knockback(true, 0.01)
  x2, v2 = knockback(true, 0.5)
  -- 0.14: a body that is not lifted slides with ground drag for the fall life.
  local F = require('src.content.enemies').defaults.fall
  check(
    'v10 corpse impulse stops at the exact lifetime even across a long frame',
    near(x1, x2)
      and near(v1, v2)
      and near(x1, 10 + 8 * (1 - math.exp(-F.groundDrag * F.life)) / F.groundDrag)
  )
  g, e = fixture('furfur')
  e.awake = true
  e.speed = 2.6
  g.player.x, g.player.z = 18, 10
  g.world.map[11][12] = 1
  local clear = true
  for _ = 1, 120 do
    AI.update(g, 1 / 120)
    clear = clear and not W.solid(g.world, e.x, e.z, 0.55)
  end
  check(
    'v10 Furfur walking and routing preserve the full charge footprint around pillars',
    clear and (e.x - 10) ^ 2 + (e.z - 10) ^ 2 > 0.25
  )
  local startX, startZ = e.x, e.z
  e.ai = 'strike'
  e.phase = 0
  e.attackKind = 'charge'
  e.chargeTime = 0.5
  e.lungeX, e.lungeZ = 1, 0
  AI.update(g, 1e-6)
  check(
    'v10 switching from walking to charge cannot suddenly depenetrate the boss',
    math.sqrt((e.x - startX) ^ 2 + (e.z - startZ) ^ 2) < 0.00002
      and not W.solid(g.world, e.x, e.z, 0.55)
  )
  g, e = fixture('furfur')
  e.x = 10.94
  g.world.map[10][12] = 1
  local _, other = fixture()
  other.id = 2
  other.x = 10.4
  g.enemies[2] = other
  advance(g, 0.5, 1 / 120)
  check(
    'v10 crowd separation cannot push the boss footprint into an adjacent pillar',
    not W.solid(g.world, e.x, e.z, 0.55) and e.x <= 10.95001
  )
  g, e = fixture('furfur')
  local _, second = fixture('furfur')
  second.id = 2
  second.x = 10.9
  g.enemies[2] = second
  advance(g, 0.5, 1 / 120)
  check(
    'v10 two large demons separate by the sum of their real collision radii',
    math.abs(second.x - e.x) >= 1.1 - 1e-7
  )
  g, e = fixture()
  local phase = e.phase
  AI.update(g, 0 / 0)
  AI.update(g, -1)
  AI.update(g, math.huge)
  check(
    'v10 invalid enemy simulation delta cannot corrupt clocks',
    e.phase == phase and g.hitCount == 0
  )
  A.muted = previousMuted
end
return Tests

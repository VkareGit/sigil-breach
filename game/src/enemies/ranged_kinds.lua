-- The attack kinds that send something across the floor (plan v10 V6:
local ActionKinds = require('src.combat.action_kinds')
local act = ActionKinds.act
-- enemies/actions.lua split by responsibility): the marked thunderbolt, the
-- pool, the fan and the bolt. Each kind's fields and defaults:
-- content/defs/action.lua.
local Archetypes = require('src.content.enemies')
local Spawn = require('src.session.spawn')
local Rules = require('src.combat.rules')
local Bodies = require('src.combat.bodies')
local Contact = require('src.enemies.attack_contact')
local Schema = require('src.core.schema')
local Caster = require('src.combat.caster')
local Defaults = require('src.content.combat_defaults')
local K = Defaults.attacks
local Pools = require('src.session.world')
local Signal = require('src.session.signal')
local Arena = require('src.world.arena')
local sin, cos = math.sin, math.cos
local Mechanics = require('src.enemies.mechanics')
local Kinds = {}
Kinds.pattern = { execute = require('src.enemies.ground_pattern').release }
-- Missiles and marks are the engine's blocks (enemies/mechanics.lua).
local launch, origin, deposit = Mechanics.launch, Mechanics.origin, Mechanics.deposit
local series = Mechanics.series
Kinds.strike = {
  -- A strike falls on a marked place: its mark never moves (no retargeting
  -- at commitment or release). A wall between caster and mark at release
  -- still cancels it (v10 rule).
  unseen = true,
  state = { mark = 'the hazard marked on the ground, waiting for the cast' },
  -- A broken cast takes its mark with it.
  abandon = function(e)
    local mark = act(e).mark
    if mark then
      mark.cancelled = true
      act(e).mark = nil
    end
  end,
  forget = function(e)
    act(e).mark = nil
  end,
  -- The thunderbolt is marked during the windup and released at execution.
  commit = function(g, e, atk)
    local packet = atk.packet
    act(e).mark = Spawn.make(g, 'hazard', {
      kind = 'lightning',
      art = atk.art,
      impactSound = atk.impactSound,
      owner = e.id,
      side = Bodies.side(g, e),
      x = e.aimX,
      z = e.aimZ,
      level = e.aimLevel,
      radius = atk.radius,
      volume = Schema.copy(atk.volume),
      delay = e.windupDuration,
      maxDelay = e.windupDuration,
      life = atk.life,
      pulse = 0,
      damage = packet.base,
      packet = packet,
      waitForCast = true,
    })
  end,
  -- It waits for the cast; the mark is released with it.
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    local mark = act(e).mark
    if mark then
      mark.waitForCast, mark.delay, mark.justReleased = false, 0, true
      act(e).mark = nil
    end
  end,
}
Kinds.pool = {
  execute = function(g, e, atk, a)
    local pool = atk.pool
    deposit(g, e, e.aimX, e.aimZ, e.aimLevel, pool.delay, pool.radius, pool.life, {
      packet = pool.packet,
      pulse = pool.pulse,
      condition = pool.condition,
      volume = pool.volume,
    })
    launch(g, atk.bolt, atk.bolt.speed, origin(g, e, a, atk.bolt))
  end,
}
Kinds.fan = {
  execute = function(g, e, atk, a)
    local rage = Archetypes.furious(e)
    local n = rage and atk.rageCount or atk.count
    for j = 1, n do
      local angle = a + (j - (n + 1) / 2) * atk.spread
      launch(g, atk, rage and atk.rageSpeed or atk.speed, origin(g, e, angle, atk))
    end
    local line = atk.line
    if line and e.attackCount % line.every == 0 then
      for j = 1, line.count do
        local d = j * line.step
        deposit(
          g,
          e,
          e.aimX + cos(a) * d - 3 * cos(a),
          e.aimZ - sin(a) * d + 3 * sin(a),
          e.aimLevel,
          line.delay,
          line.radius,
          line.life,
          { packet = line.packet, pulse = line.pulse, volume = line.volume }
        )
      end
    end
  end,
}
-- A ring from the body, a ray around it, the room around a circle: their
-- whole life is the hazard's (enemies/hazards.lua).
Kinds.wave = {
  unseen = true,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    Spawn.make(g, 'hazard', {
      kind = 'wave',
      art = atk.art,
      owner = e.id,
      side = Bodies.side(g, e),
      x = e.x,
      z = e.z,
      level = e.level,
      delay = atk.delay,
      maxDelay = atk.delay,
      radius = atk.start,
      reach = atk.reach,
      spread = atk.speed,
      width = atk.width,
      volume = Schema.copy(atk.volume),
      life = 1,
      packet = atk.packet,
    })
  end,
}
Kinds.beam = {
  unseen = true,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    -- It crosses the target from one side, then from the other.
    local turn = e.attackCount % 2 == 0 and 1 or -1
    Spawn.make(g, 'hazard', {
      kind = 'sweepline',
      art = atk.art,
      owner = e.id,
      side = Bodies.side(g, e),
      x = e.x,
      z = e.z,
      level = e.level,
      delay = atk.delay,
      maxDelay = atk.delay,
      radius = atk.length,
      width = atk.width,
      angle = a - turn * atk.arc * 0.5,
      spin = turn * atk.spin,
      volume = Schema.copy(atk.volume),
      life = atk.arc / atk.spin,
      packet = atk.packet,
    })
  end,
}
Kinds.tempest = {
  unseen = true,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    Spawn.make(g, 'hazard', {
      kind = 'tempest',
      owner = e.id,
      side = Bodies.side(g, e),
      x = e.aimX + sin(a) * atk.orbit,
      z = e.aimZ + cos(a) * atk.orbit,
      centerX = e.aimX,
      centerZ = e.aimZ,
      orbit = atk.orbit,
      angle = a,
      spin = atk.spin,
      level = e.aimLevel,
      delay = atk.delay,
      maxDelay = atk.delay,
      radius = atk.radius,
      life = atk.life,
      interval = atk.pulse,
      packet = atk.packet,
    })
  end,
}
-- Missiles let go in turn, each at where the target is by then.
local function missile(g, e, atk, t)
  e.aimX, e.aimZ, e.aimLevel = t.x, t.z, t.level
  local a = math.atan2(e.aimX - e.x, e.aimZ - e.z)
  launch(g, atk, atk.speed, origin(g, e, a, atk))
end
Kinds.salvo = {
  state = series.state,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    series.start(e)
  end,
  strike = function(g, e, atk)
    series.step(g, e, atk, missile)
  end,
  duration = series.duration,
}
-- Bolts marked where the target stands, falling when it may have left.
local function bolt(g, e, atk, t)
  if not atk.requireSight or Rules.sees(g, e, t) then
    deposit(g, e, t.x, t.z, t.level, atk.delay, atk.radius, atk.life, {
      kind = 'lightning',
      art = atk.art,
      impactSound = atk.impactSound,
      packet = atk.packet,
      volume = atk.volume,
    })
  end
end
Kinds.storm = {
  state = series.state,
  unseen = true,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    series.start(e)
  end,
  strike = function(g, e, atk)
    series.step(g, e, atk, bolt)
  end,
  duration = series.duration,
}
-- The body is gone and stands where the target must turn to find it: the first
-- free place on a fixed list of bearings, so its path can be learnt.
local bearings = K.blinkBearings
Kinds.blink = {
  unseen = true,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    local t = Contact.victim(g, e)
    local from = math.atan2(e.x - t.x, e.z - t.z)
    for i = 1, #bearings do
      local b = from + bearings[(e.attackCount + i) % #bearings + 1]
      local x, z = t.x + sin(b) * atk.distance, t.z + cos(b) * atk.distance
      if
        not Arena.solid(g.world, x, z, K.aimClearance) and Arena.visible(g.world, t.x, t.z, x, z)
      then
        local fromX, fromZ = e.x, e.z
        e.x, e.z = x, z
        e.lastX, e.lastZ = t.x, t.z
        Signal(g, 'Blinked', {
          enemy = e,
          attack = atk,
          fromX = fromX,
          fromZ = fromZ,
          toX = x,
          toZ = z,
          level = e.level,
          at = g.elapsed,
        })
        break
      end
    end
  end,
}
-- Its own, gathered beside it; a limit counts the living ones it called.
Kinds.summon = {
  unseen = true,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    local alive = 0
    for _, other in ipairs(Pools.of(g, 'enemies')) do
      if other.summoner == e.id and other.hp > 0 then
        alive = alive + 1
      end
    end
    local count = math.min(atk.count, atk.limit - alive)
    for i = 1, count do
      local b = a + (i - (count + 1) * 0.5) * atk.spread
      local x, z = e.x + sin(b) * atk.distance, e.z + cos(b) * atk.distance
      if not Arena.solid(g.world, x, z, K.aimClearance) then
        local called = g:spawn(atk.creature, x, z)
        called.summoner, called.awake, called.spawnAge = e.id, true, 0
        called.memory = Defaults.senses.memory
        called.lastX, called.lastZ = e.aimX, e.aimZ
        Signal(g, 'EnemyArrived', { enemy = called, gate = { x = x, z = z } })
      end
    end
  end,
}
Kinds.bolt = {
  cast = function(g, action, caster)
    return launch(g, action, action.speed, caster)
  end,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    launch(g, atk, atk.speed, origin(g, e, a, atk))
  end,
}
return Kinds

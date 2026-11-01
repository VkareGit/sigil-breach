-- The attack kinds that send something across the floor (plan v10 V6:
-- enemies/actions.lua split by responsibility): the marked thunderbolt, the
-- pool, the fan and the bolt. Each kind's fields and defaults:
-- content/defs/action.lua.
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local Ground = require('src.physics.ground')
local Rules = require('src.combat.rules')
local Hazards = require('src.enemies.hazards')
local Bodies = require('src.combat.bodies')
local Contact = require('src.enemies.attack_contact')
local Shape = require('src.combat.projectile_shape')
local Schema = require('src.core.schema')
local Caster = require('src.combat.caster')
local Defaults = require('src.content.combat_defaults')
local K = Defaults.attacks
local Pools = require('src.session.world')
local Signal = require('src.session.signal')
local World = require('src.world.arena')
local sin, cos = math.sin, math.cos
local len = MathX.len
local Kinds = {}
Kinds.pattern = { execute = require('src.enemies.ground_pattern').release }
-- A missile leaves a caster's mouth along its aim. radius: its own collision
-- radius, also its painted size.
local function launch(g, spec, speed, caster)
  Spawn.make(g, 'projectile', {
    x = caster.mx,
    y = caster.my,
    z = caster.mz,
    vx = caster.dx * speed,
    vz = caster.dz * speed,
    vy = caster.rise * speed / caster.run,
    life = K.boltLife,
    big = spec.big or false,
    color = spec.color,
    owner = caster.owner,
    side = caster.side,
    packet = Caster.packet(caster, spec.packet),
    radius = Shape.radius(spec),
  })
  return true
end
-- A creature casts from its body at the mark it took, angle a.
local function aimed(g, e, a, spec)
  -- Launched and aimed at heights above the ground (physics/ground.lua).
  local ground = Ground.of(g.world, e)
  local y = ground + (e.leapY or 0) + spec.height
  local d = len(e.aimX - e.x, e.aimZ - e.z)
  return {
    body = e,
    scaled = true,
    owner = e.id,
    side = Bodies.side(g, e),
    mx = e.x + sin(a) * K.muzzle,
    my = y,
    mz = e.z + cos(a) * K.muzzle,
    dx = sin(a),
    dz = cos(a),
    rise = Ground.height(g.world, e.aimX, e.aimZ, e.aimLevel) + (spec.aimHeight or K.aimHeight) - y,
    run = math.max(1, d - K.muzzle),
  }
end
Kinds.strike = {
  -- A strike falls on a marked place: its mark never moves (no retargeting
  -- at commitment or release). A wall between caster and mark at release
  -- still cancels it (v10 rule).
  unseen = true,
  -- The thunderbolt is marked during the windup and released at execution.
  commit = function(g, e, atk)
    local packet = Rules.packet(e, atk.packet)
    e.pendingHazard = Spawn.make(g, 'hazard', {
      kind = 'lightning',
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
    local mark = e.pendingHazard
    if mark then
      mark.waitForCast, mark.delay, mark.justReleased = false, 0, true
      e.pendingHazard = nil
    end
  end,
}
Kinds.pool = {
  execute = function(g, e, atk, a)
    local pool = atk.pool
    Hazards.add(g, e.aimX, e.aimZ, pool.delay, pool.radius, pool.life, {
      packet = Rules.packet(e, pool.packet),
      pulse = pool.pulse,
      condition = pool.condition,
      volume = pool.volume,
      owner = e.id,
      level = e.aimLevel,
      side = Bodies.side(g, e),
    })
    launch(g, atk.bolt, atk.bolt.speed, aimed(g, e, a, atk.bolt))
  end,
}
Kinds.fan = {
  execute = function(g, e, atk, a)
    local rage = require('src.content.enemies').furious(e)
    local n = rage and atk.rageCount or atk.count
    for j = 1, n do
      local angle = a + (j - (n + 1) / 2) * atk.spread
      launch(g, atk, rage and atk.rageSpeed or atk.speed, aimed(g, e, angle, atk))
    end
    local line = atk.line
    if line and e.attackCount % line.every == 0 then
      for j = 1, line.count do
        local d = j * line.step
        Hazards.add(
          g,
          e.aimX + cos(a) * d - 3 * cos(a),
          e.aimZ - sin(a) * d + 3 * sin(a),
          line.delay,
          line.radius,
          line.life,
          {
            packet = Rules.packet(e, line.packet),
            pulse = line.pulse,
            volume = line.volume,
            owner = e.id,
            side = Bodies.side(g, e),
            level = e.aimLevel,
          }
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
      packet = Rules.packet(e, atk.packet),
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
      owner = e.id,
      side = Bodies.side(g, e),
      x = e.x,
      z = e.z,
      level = e.level,
      delay = atk.delay,
      maxDelay = atk.delay,
      radius = atk.length,
      angle = a - turn * atk.arc * 0.5,
      spin = turn * atk.spin,
      volume = Schema.copy(atk.volume),
      life = atk.arc / atk.spin,
      packet = Rules.packet(e, atk.packet),
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
      packet = Rules.packet(e, atk.packet),
    })
  end,
}
-- Missiles let go in turn, each at where the target is by then.
Kinds.salvo = {
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    e.released = 0
  end,
  strike = function(g, e, atk)
    while e.released < atk.count and e.phase >= e.released * atk.interval do
      local t = Contact.victim(g, e)
      e.released = e.released + 1
      e.aimX, e.aimZ, e.aimLevel = t.x, t.z, t.level
      local a = math.atan2(e.aimX - e.x, e.aimZ - e.z)
      launch(g, atk, atk.speed, aimed(g, e, a, atk))
    end
  end,
  duration = function(e, atk)
    return (atk.count - 1) * atk.interval + atk.duration
  end,
}
-- Bolts marked where the target stands, falling when it may have left.
Kinds.storm = {
  unseen = true,
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
    e.released = 0
  end,
  strike = function(g, e, atk)
    while e.released < atk.count and e.phase >= e.released * atk.interval do
      local t = Contact.victim(g, e)
      e.released = e.released + 1
      Hazards.add(g, t.x, t.z, atk.delay, atk.radius, atk.life, {
        kind = 'lightning',
        packet = Rules.packet(e, atk.packet),
        volume = atk.volume,
        owner = e.id,
        side = Bodies.side(g, e),
        level = t.level,
      })
    end
  end,
  duration = function(e, atk)
    return (atk.count - 1) * atk.interval + atk.duration
  end,
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
        not World.solid(g.world, x, z, K.aimClearance) and World.visible(g.world, t.x, t.z, x, z)
      then
        Signal(g, 'Blinked', { enemy = e, fromX = e.x, fromZ = e.z })
        e.x, e.z = x, z
        e.lastX, e.lastZ = t.x, t.z
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
      if not World.solid(g.world, x, z, K.aimClearance) then
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
    launch(g, atk, atk.speed, aimed(g, e, a, atk))
  end,
}
return Kinds

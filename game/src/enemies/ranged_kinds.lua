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
local K = require('src.content.combat_defaults').attacks
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
Kinds.bolt = {
  cast = function(g, action, caster)
    return launch(g, action, action.speed, caster)
  end,
  execute = function(g, e, atk, a)
    launch(g, atk, atk.speed, aimed(g, e, a, atk))
  end,
}
return Kinds

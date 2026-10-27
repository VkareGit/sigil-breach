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
local K = require('src.content.combat_defaults').attacks
local sin, cos = math.sin, math.cos
local len = MathX.len
local Kinds = {}
-- A bolt carries its archetype's damage packet to the projectile system.
local function projectile(g, e, a, speed, spec)
  -- Launched and aimed at heights above the ground (physics/ground.lua).
  local ground = Ground.of(g.world, e)
  local y = ground + (e.leapY or 0) + spec.height
  local d = len(e.aimX - e.x, e.aimZ - e.z)
  -- radius: the projectile's own collision radius, also its painted size.
  Spawn.make(g, 'projectile', {
    x = e.x + sin(a) * K.muzzle,
    y = y,
    z = e.z + cos(a) * K.muzzle,
    vx = sin(a) * speed,
    vz = cos(a) * speed,
    vy = (Ground.height(g.world, e.aimX, e.aimZ, e.aimLevel) + (spec.aimHeight or K.aimHeight) - y)
      * speed
      / math.max(1, d - K.muzzle),
    life = K.boltLife,
    big = spec.big or false,
    color = spec.color,
    owner = e.id,
    side = Bodies.side(g, e),
    packet = Rules.packet(e, spec.packet),
    radius = Shape.radius(spec),
  })
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
  execute = Contact.face,
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
    projectile(g, e, a, atk.bolt.speed, atk.bolt)
  end,
}
Kinds.fan = {
  execute = function(g, e, atk, a)
    local rage = e.hp < e.maxHp * K.rageAt
    local n = rage and atk.rageCount or atk.count
    for j = 1, n do
      projectile(g, e, a + (j - (n + 1) / 2) * atk.spread, rage and atk.rageSpeed or atk.speed, atk)
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
  execute = function(g, e, atk, a)
    projectile(g, e, a, atk.speed, atk)
  end,
}
return Kinds

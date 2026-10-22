-- Contact: momentum meets the world (wall slam) and other bodies (domino).
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local Physics = require('src.physics.body_physics')
local Archetypes = require('src.content.enemies')
local defaults = Archetypes.defaults
local max = math.max
return function(R)
  -- Momentum meets the world (Warhammer falling damage / souls wall splat).
  -- A shoved body that stops against a wall faster than slamSpeed takes the
  -- excess speed as impact on its guard and as harm. Bosses only shrug.
  -- Returns the excess speed (0 = no slam).
  function R.slam(g, e, speed)
    local over = speed - defaults.slamSpeed
    if over <= 0 or (e.slamLock or 0) > 0 then
      return 0
    end
    e.slamLock = defaults.slamLock
    local b = R.body(e)
    if e.hp > 0 and not b.boss then
      local harm = over * defaults.slamDamage / b.mass ^ 0.5
      g:damageEnemy(e, harm, 'slam')
      R.guard(e, over * defaults.slamPoise)
      e.flinch = 1
      e.hit = max(e.hit or 0, defaults.hitFlash)
    end
    g.slams = (g.slams or 0) + 1
    g.lastSlam = { x = e.x, z = e.z, speed = speed }
    return over
  end
  -- Inelastic body contact. Equal stationary masses still share a direct
  -- shove equally. Different masses conserve momentum; a graze retains its
  -- tangent and bodies already moving apart never exchange another impulse.
  -- A body struck faster than slamSpeed is hurt like a wall slam (domino).
  function R.collide(g, e, other)
    if (other.collideLock or 0) > 0 then
      return false
    end
    local mass = R.body(other).mass or 1
    local vx, vz, ox, oz, received, closing = Physics.contact(
      e.pushX or 0,
      e.pushZ or 0,
      other.pushX or 0,
      other.pushZ or 0,
      R.body(e).mass or 1,
      mass,
      other.x - e.x,
      other.z - e.z
    )
    if closing < defaults.collideSpeed then
      return false
    end
    e.pushX, e.pushZ, other.pushX, other.pushZ = vx, vz, ox, oz
    other.collideLock = defaults.collideLock
    other.flinch = max(other.flinch or 0, defaults.collideFlinch)
    R.guard(other, received * defaults.collidePoise)
    local over = received - defaults.slamSpeed
    if over > 0 and other.hp > 0 and not R.body(other).boss then
      g:damageEnemy(other, over * defaults.slamDamage / mass ^ 0.5, 'collision')
    end
    g.collisions = (g.collisions or 0) + 1
    return true
  end
end

-- Impulse: one law of shove for every body, momentum that adds, and a
-- blow meeting a body's own rush (the counter as a collision of momenta).
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local Archetypes = require('src.content.enemies')
local defaults = Archetypes.defaults
local sqrt, max = math.sqrt, math.max
return function(R)
  -- One impulse law for every body (player, demons, corpses): a blow of
  -- impulse J moves a body of mass m at v = vmax * (1 - exp(-J / scale)) / m.
  -- Returns the speed and the saturation n in [0, 1) of the blow itself.
  function R.shove(J, mass)
    local law = defaults.impulse
    local n = 1 - math.exp(-max(0, J or 0) / law.scale)
    return law.vmax * n / max(0.05, mass or 1), n
  end
  -- Momentum adds (two blows throw further than one) but the sum is capped by
  -- the same ceiling as a single blow: vmax / mass, or the new blow itself when
  -- a killing throw is faster. One law for demons and the knight.
  function R.addPush(body, dx, dz, speed, mass)
    local vx = (body.pushX or 0) + dx * speed
    local vz = (body.pushZ or 0) + dz * speed
    local cap = math.max(speed, defaults.impulse.vmax / (mass or 1))
    local v = sqrt(vx * vx + vz * vz)
    if v > cap then
      vx, vz = vx / v * cap, vz / v * cap
    end
    body.pushX, body.pushZ = vx, vz
  end
  -- Velocity of the body's own committed rush (a lunge, charge or leap that is
  -- moving it now), written by the attack each step; nil when not rushing.
  function R.rush(e)
    if e.leaping and e.leapVX then
      return e.leapVX, e.leapVZ or 0
    end
    if e.rushVX and e.ai == 'strike' then
      return e.rushVX, e.rushVZ or 0
    end
    return nil
  end
  -- A shove (sx, sz) meets a rush (rx, rz): the velocities add as vectors.
  -- A leap simply flies on with the sum. A ground rush keeps the part of the
  -- sum along its own direction (slowed) and the sideways part becomes a
  -- shove; if the blow reverses it, the rush stops and the remainder throws
  -- the body back. Returns true when the rush was stopped.
  function R.meetRush(e, rx, rz, sx, sz, mass)
    local vx, vz = rx + sx, rz + sz
    if e.leaping then
      e.leapVX, e.leapVZ = vx, vz
      return false
    end
    -- The same blow already broke the body out of its attack: the rush no
    -- longer drives it, so the whole momentum carries it as a shove.
    if e.ai ~= 'strike' then
      e.pushX, e.pushZ = (e.pushX or 0) + vx, (e.pushZ or 0) + vz
      -- A zero blow only applies the shared ceiling of R.addPush.
      R.addPush(e, 1, 0, 0, mass)
      return vx * rx + vz * rz <= 0
    end
    local speed = sqrt(rx * rx + rz * rz)
    if speed < 1e-6 then
      R.addPush(e, 1, 0, 0, mass)
      return false
    end
    local ux, uz = rx / speed, rz / speed
    local forward = vx * ux + vz * uz
    if forward <= 0 then
      e.rushScale = 0
      e.rushVX, e.rushVZ = nil, nil
      if e.chargeTime then
        e.chargeTime = math.min(e.chargeTime, e.phase or 0)
      end
      e.pushX, e.pushZ = (e.pushX or 0) + vx, (e.pushZ or 0) + vz
      return true
    end
    e.rushScale = (e.rushScale or 1) * forward / speed
    local lx, lz = vx - forward * ux, vz - forward * uz
    e.pushX, e.pushZ = (e.pushX or 0) + lx, (e.pushZ or 0) + lz
    return false
  end
end

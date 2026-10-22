-- Pure body math: no world, audio, renderer or game state.
local MathX = require('src.core.mathx')
local P = {}
local sqrt, max = math.sqrt, math.max
local finite = MathX.finite
function P.drag(rate, dt)
  if not finite(rate) or not finite(dt) or rate < 0 or dt <= 0 then
    return 1, 0
  end
  if rate == 0 then
    return 1, dt
  end
  local decay = math.exp(-rate * dt)
  return decay, (1 - decay) / rate
end
-- Perfectly inelastic contact in the normal direction. Tangential velocity
-- survives. J=(u1-u2)/(1/m1+1/m2) conserves total linear momentum and cannot
-- create kinetic energy. Return the recipient's velocity change for poise.
function P.contact(vx, vz, ox, oz, mass, otherMass, nx, nz)
  if
    not (
      finite(vx)
      and finite(vz)
      and finite(ox)
      and finite(oz)
      and finite(mass)
      and finite(otherMass)
      and mass > 0
      and otherMass > 0
      and finite(nx)
      and finite(nz)
    )
  then
    return vx, vz, ox, oz, 0, 0
  end
  local distance = sqrt(nx * nx + nz * nz)
  if distance <= 1e-9 then
    return vx, vz, ox, oz, 0, 0
  end
  nx, nz = nx / distance, nz / distance
  local closing = max(0, (vx - ox) * nx + (vz - oz) * nz)
  if closing == 0 then
    return vx, vz, ox, oz, 0, 0
  end
  local impulse = closing / (1 / mass + 1 / otherMass)
  local give, take = impulse / mass, impulse / otherMass
  return vx - nx * give, vz - nz * give, ox + nx * take, oz + nz * take, take, closing
end
return P

-- Visual consequences of an already resolved contact, never another attack.
-- Damage units are a retained-power proxy, not invented real-world joules.
local Rules = require('src.combat.rules')
local Materials = require('src.content.ballistic_surfaces')
local SurfaceMarkFeedback = require('src.feedback.surface_marks')
local MathX = require('src.core.mathx')
local Damage = require('src.combat.damage')
local FX = require('src.feedback.effects')
local Splash = require('src.content.impact_response')
local I = { particleLimit = Splash.particleLimit }
local sqrt, abs, sin, cos = math.sqrt, math.abs, math.sin, math.cos
local clamp = MathX.clamp
local function unit(x, y, z, fx, fy, fz)
  local length = sqrt(x * x + y * y + z * z)
  if length < 1e-8 then
    return fx or 0, fy or 0, fz or 1
  end
  return x / length, y / length, z / length
end
local materials = Splash.materials
-- The armour arithmetic is the damage model's (combat/damage.lua).
I.retained = Damage.retained
I.armorLoss = Damage.armorLoss
function I.measure(energy, contact, material)
  energy = math.max(0, energy or 0)
  local dx, dy, dz = unit(contact.dx or 0, contact.dy or 0, contact.dz or 0)
  local n = contact.normal or {}
  local nx, ny, nz = unit(n[1] or 0, n[2] or 0, n[3] or 0, -dx, -dy, -dz)
  -- A winding error in a supplied normal cannot fire debris into its wall.
  if dx * nx + dy * ny + dz * nz > 0 then
    nx, ny, nz = -nx, -ny, -nz
  end
  local incidence = clamp(-(dx * nx + dy * ny + dz * nz), 0, 1)
  local normalEnergy = energy * incidence * incidence
  local tangentialEnergy = math.max(0, energy - normalEnergy)
  local tx, ty, tz = dx + incidence * nx, dy + incidence * ny, dz + incidence * nz
  local tangentLength = sqrt(tx * tx + ty * ty + tz * tz)
  if tangentLength > 1e-8 then
    tx, ty, tz = tx / tangentLength, ty / tangentLength, tz / tangentLength
  else
    tx, ty, tz = 0, 0, 0
  end
  local spec = materials[material or 'plaster']
  local normalRoot = sqrt(normalEnergy)
  return {
    material = material or 'plaster',
    energy = energy,
    normalEnergy = normalEnergy,
    tangentialEnergy = tangentialEnergy,
    incidence = incidence,
    nx = nx,
    ny = ny,
    nz = nz,
    tx = tx,
    ty = ty,
    tz = tz,
    -- Collision is the tile face, while its painted niche fillet projects
    -- 8.25 cm in front. Start the art beyond that trim immediately.
    offset = contact.kind == 'wall' and Splash.offset.wall or Splash.offset.other,
    -- At glancing incidence a small scrape survives, but the dense impact plume
    -- follows normal energy. Speed follows sqrt(energy), with artistic caps.
    size = clamp(
      Splash.size.base + spec.size * normalRoot + Splash.size.tangent * sqrt(tangentialEnergy),
      Splash.size.base,
      Splash.size.high
    ),
    normalSpeed = clamp(
      Splash.normalSpeed.base + spec.speed * normalRoot,
      Splash.normalSpeed.base,
      Splash.normalSpeed.high
    ),
    tangentSpeed = clamp(
      spec.speed * Splash.tangentSpeed.share * sqrt(tangentialEnergy),
      0,
      Splash.tangentSpeed.high
    ),
    count = energy > 0
        and clamp(
          math.ceil(
            Splash.count.gain
              * sqrt(energy)
              * (Splash.count.flat + Splash.count.incidence * incidence)
          ),
          1,
          Splash.count.high
        )
      or 0,
  }
end
local function particles(g, c, r, color, blood)
  g.view.particles = g.view.particles or {}
  -- Build an orthogonal fan around the contact normal. Every initial velocity
  -- has a strictly outward component; tangential scatter cannot enter a wall.
  local ax, ay, az = 0, 1, 0
  if abs(r.ny) > Splash.vertical then
    ax, ay, az = 1, 0, 0
  end
  local ux, uy, uz = unit(r.ny * az - r.nz * ay, r.nz * ax - r.nx * az, r.nx * ay - r.ny * ax)
  local vx, vy, vz = r.ny * uz - r.nz * uy, r.nz * ux - r.nx * uz, r.nx * uy - r.ny * ux
  local seed = (c.seed or 0) + (c.x or 0) * Splash.seed.x + (c.z or 0) * Splash.seed.z
  for i = 1, r.count do
    local turn = i * Splash.turn + seed
    local variation = Splash.variation.base
      + Splash.variation.spread * ((i * Splash.ratio + seed * Splash.seed.scale) % 1)
    local normalSpeed = r.normalSpeed * variation
    local spread = normalSpeed * (blood and Splash.spread.blood or Splash.spread.debris)
    local su, sv = sin(turn) * spread, cos(turn) * spread
    local life = (blood and Splash.bloodLife or materials[r.material].life)
      * (Splash.life.base + Splash.life.spread * variation)
    if #g.view.particles >= I.particleLimit then
      table.remove(g.view.particles, 1)
    end
    g.view.particles[#g.view.particles + 1] = {
      x = c.x + r.nx * r.offset,
      y = c.y + r.ny * r.offset,
      z = c.z + r.nz * r.offset,
      vx = r.nx * normalSpeed + r.tx * r.tangentSpeed + ux * su + vx * sv,
      vy = r.ny * normalSpeed + r.ty * r.tangentSpeed + uy * su + vy * sv,
      vz = r.nz * normalSpeed + r.tz * r.tangentSpeed + uz * su + vz * sv,
      life = life,
      color = color,
      size = clamp(
        Splash.speckSize.base + sqrt(r.energy) * Splash.speckSize.gain,
        Splash.speckSize.base,
        Splash.speckSize.high
      ),
      material = blood and 'blood' or r.material,
    }
  end
end
local function solid(g, energy, contact, material, paintSprite)
  local r = I.measure(energy, contact, material)
  if r.count == 0 then
    return r
  end
  local spec = materials[material]
  particles(g, contact, r, spec.color, false)
  if paintSprite then
    FX.emit(
      g,
      'stone',
      contact.x + r.nx * r.offset,
      contact.y + r.ny * r.offset,
      contact.z + r.nz * r.offset,
      r.size,
      {
        tint = spec.tint,
        material = material,
        energy = energy,
        incidence = r.incidence,
        duration = spec.life,
        vx = r.nx * r.normalSpeed * Splash.sprite.normal
          + r.tx * r.tangentSpeed * Splash.sprite.tangent,
        vy = r.ny * r.normalSpeed * Splash.sprite.normal
          + r.ty * r.tangentSpeed * Splash.sprite.tangent,
        vz = r.nz * r.normalSpeed * Splash.sprite.normal
          + r.tz * r.tangentSpeed * Splash.sprite.tangent,
      }
    )
  end
  return r
end
I.solid = solid
-- A compact mark of the resolved ray, distinct from the volley's averaged
-- spray origin. In particular, an average of two wing contacts may be air.
function I.contact(g, c, blood, energy)
  local r = I.measure(energy, c, 'plaster')
  local size =
    clamp(Splash.mark.base + sqrt(energy) * Splash.mark.gain, Splash.mark.low, Splash.mark.high)
  return FX.emit(
    g,
    blood and 'contact_blood' or 'contact_stone',
    c.x + r.nx * r.offset,
    c.y + r.ny * r.offset,
    c.z + r.nz * r.offset,
    size,
    { material = blood and 'blood' or c.material, energy = energy }
  )
end
function I.surface(g, attack, contact, paintSprite)
  local material = contact.kind == 'floor' and 'stone' or 'plaster'
  local response = solid(g, I.retained(attack, contact.distance), contact, material, paintSprite)
  SurfaceMarkFeedback.emit(g, contact, response)
  if paintSprite then
    I.contact(g, contact, false, response.energy)
  end
  return response
end
function I.body(g, e, point, healthDamage, armorAbsorbed, contact)
  local c = {
    x = point[1],
    y = point[2],
    z = point[3],
    dx = contact.dx,
    dy = contact.dy,
    dz = contact.dz,
    normal = contact.normal,
    seed = contact.seed,
  }
  if armorAbsorbed > 0 then
    -- What absorbed it throws its debris (iron sparks, horn and bone chips);
    -- a soft surface that still absorbed armour shows chips of bone.
    local struck = contact.material or Rules.body(e).struck
    local surface = Materials[struck]
    solid(g, armorAbsorbed, c, surface and surface.debris or 'bone', true)
  end
  if healthDamage <= 0 then
    return
  end
  local color = Rules.body(e).blood or Splash.blood
  local r = I.measure(healthDamage, c, 'plaster')
  local W = Splash.wound
  r.count = clamp(math.ceil(sqrt(healthDamage) * W.count), 1, W.most)
  r.normalSpeed = clamp(W.speed + sqrt(healthDamage) * W.speedGain, W.speed, W.speedHigh)
  r.tangentSpeed = r.tangentSpeed * W.tangent
  particles(g, c, r, color, true)
  FX.emit(
    g,
    'blood',
    c.x + r.nx * W.offset,
    c.y + r.ny * W.offset,
    c.z + r.nz * W.offset,
    clamp(W.size + sqrt(healthDamage) * W.sizeGain, W.size, W.sizeHigh),
    {
      material = 'blood',
      energy = healthDamage,
      vx = r.nx * r.normalSpeed * W.drift,
      vy = r.ny * r.normalSpeed * W.drift,
      vz = r.nz * r.normalSpeed * W.drift,
    }
  )
end
return I

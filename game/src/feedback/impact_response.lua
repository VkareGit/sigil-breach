-- Visual consequences of an already resolved contact, never another attack.
-- Damage units are a retained-power proxy, not invented real-world joules.
local Rules = require('src.combat.rules')
local Materials = require('src.content.ballistic_surfaces')
local SurfaceMarkFeedback = require('src.feedback.surface_marks')
local MathX = require('src.core.mathx')
local Damage = require('src.combat.damage')
local FX = require('src.feedback.effects')
local I = { particleLimit = 240 }
local sqrt, abs, sin, cos = math.sqrt, math.abs, math.sin, math.cos
local clamp = MathX.clamp
local function unit(x, y, z, fx, fy, fz)
  local length = sqrt(x * x + y * y + z * z)
  if length < 1e-8 then
    return fx or 0, fy or 0, fz or 1
  end
  return x / length, y / length, z / length
end
local materials = {
  plaster = {
    color = { 0.65, 0.51, 0.34 },
    tint = { 1.03, 0.98, 0.87 },
    size = 0.031,
    speed = 0.27,
    life = 0.28,
  },
  stone = {
    color = { 0.36, 0.35, 0.31 },
    tint = { 0.77, 0.87, 0.98 },
    size = 0.024,
    speed = 0.22,
    life = 0.25,
  },
  metal = {
    color = { 0.53, 0.55, 0.53 },
    tint = { 0.66, 0.82, 1.10 },
    size = 0.022,
    speed = 0.36,
    life = 0.18,
  },
  bone = {
    color = { 0.40, 0.29, 0.18 },
    tint = { 0.82, 0.69, 0.52 },
    size = 0.026,
    speed = 0.24,
    life = 0.24,
  },
}
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
    offset = contact.kind == 'wall' and 0.095 or 0.028,
    -- At glancing incidence a small scrape survives, but the dense impact plume
    -- follows normal energy. Speed follows sqrt(energy), with artistic caps.
    size = clamp(0.07 + spec.size * normalRoot + 0.004 * sqrt(tangentialEnergy), 0.07, 0.58),
    normalSpeed = clamp(0.12 + spec.speed * normalRoot, 0.12, 3.1),
    tangentSpeed = clamp(spec.speed * 0.62 * sqrt(tangentialEnergy), 0, 2.1),
    count = energy > 0 and clamp(math.ceil(0.40 * sqrt(energy) * (0.45 + 0.55 * incidence)), 1, 6)
      or 0,
  }
end
local function particles(g, c, r, color, blood)
  g.view.particles = g.view.particles or {}
  -- Build an orthogonal fan around the contact normal. Every initial velocity
  -- has a strictly outward component; tangential scatter cannot enter a wall.
  local ax, ay, az = 0, 1, 0
  if abs(r.ny) > 0.85 then
    ax, ay, az = 1, 0, 0
  end
  local ux, uy, uz = unit(r.ny * az - r.nz * ay, r.nz * ax - r.nx * az, r.nx * ay - r.ny * ax)
  local vx, vy, vz = r.ny * uz - r.nz * uy, r.nz * ux - r.nx * uz, r.nx * uy - r.ny * ux
  local seed = (c.seed or 0) + (c.x or 0) * 0.137 + (c.z or 0) * 0.191
  for i = 1, r.count do
    local turn = i * 2.3999632297287 + seed
    local variation = 0.64 + 0.36 * ((i * 0.61803398875 + seed * 0.117) % 1)
    local normalSpeed = r.normalSpeed * variation
    local spread = normalSpeed * (blood and 0.31 or 0.48)
    local su, sv = sin(turn) * spread, cos(turn) * spread
    local life = (blood and 0.27 or materials[r.material].life) * (0.78 + 0.22 * variation)
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
      size = clamp(0.20 + sqrt(r.energy) * 0.040, 0.20, 0.82),
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
        vx = r.nx * r.normalSpeed * 0.16 + r.tx * r.tangentSpeed * 0.12,
        vy = r.ny * r.normalSpeed * 0.16 + r.ty * r.tangentSpeed * 0.12,
        vz = r.nz * r.normalSpeed * 0.16 + r.tz * r.tangentSpeed * 0.12,
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
  local size = clamp(0.12 + sqrt(energy) * 0.012, 0.14, 0.25)
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
  local color = Rules.body(e).blood or { 0.26, 0.025, 0.016 }
  local r = I.measure(healthDamage, c, 'plaster')
  r.count = clamp(math.ceil(sqrt(healthDamage) * 0.46), 1, 8)
  r.normalSpeed = clamp(0.18 + sqrt(healthDamage) * 0.13, 0.18, 1.5)
  r.tangentSpeed = r.tangentSpeed * 0.18
  particles(g, c, r, color, true)
  FX.emit(
    g,
    'blood',
    c.x + r.nx * 0.025,
    c.y + r.ny * 0.025,
    c.z + r.nz * 0.025,
    clamp(0.13 + sqrt(healthDamage) * 0.035, 0.13, 0.58),
    {
      material = 'blood',
      energy = healthDamage,
      vx = r.nx * r.normalSpeed * 0.09,
      vy = r.ny * r.normalSpeed * 0.09,
      vz = r.nz * r.normalSpeed * 0.09,
    }
  )
end
return I

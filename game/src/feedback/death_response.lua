local Context = require('src.session.context')
-- Presentation of an already resolved death. This module cannot deal damage,
-- move a body or award a kill. Contact power selects pigment and timing only.
-- The death itself (strength, contact, landing, collapse pose) is simulation:
-- enemies/corpse.lua, which calls the hooks registered here.
local MathX = require('src.core.mathx')
local FX = require('src.feedback.effects')
local Audio = require('src.audio.audio')
local Corpse = require('src.enemies.corpse')
local Presentation = require('src.session.presentation')
local Profiles = require('src.audio.creature_profiles')
local Death = {}
local sqrt, max = math.sqrt, math.max
local clamp = MathX.clamp
local body = Corpse.body
-- The simulation's entry points, kept under their presentation names.
Death.begin = Corpse.begin
Death.contact = Corpse.struck
Death.land = Corpse.land
Death.landing = Corpse.landing
Death.pose = Corpse.pose

-- Deterministic clots: no random-number draws can change the next AI choice.
-- A narrow fan follows the projectile through the wound instead of filling
-- the whole silhouette with the same radial particle cloud on every kill.
function Death.clots(g, e, strong, point, contact)
  local response = e.deathResponse
  local dx, dz = e.x - Context.viewer(g).x, e.z - Context.viewer(g).z
  if contact then
    dx, dz = contact.dx or dx, contact.dz or dz
  end
  local length = sqrt(dx * dx + dz * dz)
  if length > 1e-8 then
    dx, dz = dx / length, dz / length
  else
    dx, dz = 0, 1
  end
  local color = body(e).blood or { 0.26, 0.025, 0.016 }
  local count = 3 + math.floor(response.strength * (strong and 5 or 3))
  local speed = 0.65 + response.strength * 1.25
  g.view.particles = g.view.particles or {}
  for i = 1, count do
    local spread = (i / (count + 1) - 0.5) * 0.8
    if #g.view.particles >= 240 then
      table.remove(g.view.particles, 1)
    end
    g.view.particles[#g.view.particles + 1] = {
      x = point[1],
      y = point[2],
      z = point[3],
      vx = dx * speed - dz * spread,
      vy = 0.35 + 0.18 * (i % 3),
      vz = dz * speed + dx * spread,
      life = 0.24 + (i % 3) * 0.025,
      color = color,
      size = 0.30 + response.strength * 0.26,
      material = 'blood',
    }
  end
end

-- The landing's thud, dust and (for a thrown body) a second stain.
function Death.landed(g, e, energy)
  local response = e.deathResponse
  local size = clamp(0.16 + sqrt(energy) * 0.065, 0.16, 0.66)
  Audio.playAt(
    Profiles.body(e, 'fall', 'thud'),
    e.x,
    e.z,
    Context.viewer(g),
    clamp(0.16 + sqrt(energy) * 0.065, 0.16, 0.58),
    1,
    g.world
  )
  -- Two low, lateral pigment strokes leave the falling face and hands visible.
  for _, side in ipairs({ -1, 1 }) do
    FX.emit(g, 'stone', e.x + side * size * 0.33, 0.10, e.z, size, {
      tint = { 0.58, 0.49, 0.36 },
      material = 'corpse-contact',
      energy = energy,
      duration = 0.22,
      vx = side * size * 0.65,
      vy = 0.10,
    })
  end
  -- The original wound already stains its tile. A thrown body leaves a second
  -- contact patch only after travelling far enough to make that distinction.
  local dx, dz = e.x - response.originX, e.z - response.originZ
  if dx * dx + dz * dz > 0.0625 then
    FX.stain(g, e.x, e.z, clamp(0.34 + size * 0.45, 0.34, 0.64), e.kind)
  end
end

function Death.shade(e)
  -- Retain the painted form through the wound/fall; let it settle into the
  -- floor's shadow afterwards, instead of instantly losing a quarter of it.
  local t = max(0, (e.deathTime or 0) - 0.11)
  return 0.72 + 0.28 * math.exp(-t * 5)
end

function Death.pain(e)
  local response = e.deathResponse
  return response and 0.5 * response.strength * max(0, 1 - (e.deathTime or 0) / 0.085) or 0
end

Presentation.hook('corpseStruck', Death.clots)
Presentation.hook('corpseLanded', Death.landed)
return Death

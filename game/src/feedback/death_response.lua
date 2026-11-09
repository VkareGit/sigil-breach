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
local DeathLook = require('src.content.death_look')
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
  local C = DeathLook.clots
  local color = body(e).blood or DeathLook.blood
  local count = C.least + math.floor(response.strength * (strong and C.strong or C.weak))
  local speed = C.speed + response.strength * C.speedGain
  g.view.particles = g.view.particles or {}
  for i = 1, count do
    local spread = (i / (count + 1) - 0.5) * C.fan
    if #g.view.particles >= DeathLook.speckLimit then
      table.remove(g.view.particles, 1)
    end
    g.view.particles[#g.view.particles + 1] = {
      x = point[1],
      y = point[2],
      z = point[3],
      vx = dx * speed - dz * spread,
      vy = C.rise + C.riseStep * (i % C.rises),
      vz = dz * speed + dx * spread,
      life = C.life + (i % C.rises) * C.lifeStep,
      color = color,
      size = C.size + response.strength * C.sizeGain,
      material = 'blood',
    }
  end
end

-- The landing's thud, dust and (for a thrown body) a second stain.
function Death.landed(g, e, energy)
  local response = e.deathResponse
  local L = DeathLook.landing
  local size = clamp(L.size + sqrt(energy) * L.sizeGain, L.size, L.sizeHigh)
  Audio.playAt(
    Profiles.body(e, 'fall', 'thud'),
    e.x,
    e.z,
    Context.viewer(g),
    clamp(L.size + sqrt(energy) * L.sizeGain, L.size, L.loudHigh),
    1,
    g.world
  )
  -- Two low, lateral pigment strokes leave the falling face and hands visible.
  for _, side in ipairs({ -1, 1 }) do
    FX.emit(g, 'stone', e.x + side * size * L.stroke, L.strokeHeight, e.z, size, {
      tint = L.tint,
      material = 'corpse-contact',
      energy = energy,
      duration = L.duration,
      vx = side * size * L.drift,
      vy = L.rise,
    })
  end
  -- The original wound already stains its tile. A thrown body leaves a second
  -- contact patch only after travelling far enough to make that distinction.
  local dx, dz = e.x - response.originX, e.z - response.originZ
  if dx * dx + dz * dz > L.travelled then
    FX.stain(g, e.x, e.z, clamp(L.stain + size * L.stainGain, L.stain, L.stainHigh), e.kind)
  end
end

function Death.shade(e)
  -- Retain the painted form through the wound/fall; let it settle into the
  -- floor's shadow afterwards, instead of instantly losing a quarter of it.
  local S = DeathLook.shade
  local t = max(0, (e.deathTime or 0) - S.after)
  return S.floor + S.rest * math.exp(-t * S.rate)
end

function Death.pain(e)
  local response = e.deathResponse
  local P = DeathLook.pain
  return response and P.share * response.strength * max(0, 1 - (e.deathTime or 0) / P.lasts) or 0
end

Presentation.hook('corpseStruck', Death.clots)
Presentation.hook('corpseLanded', Death.landed)
return Death

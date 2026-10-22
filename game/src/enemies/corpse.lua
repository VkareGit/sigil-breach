-- A killed body as simulation (0.24 F1): the record of its death (strength,
-- side, contact, landing), when it first touches the floor and the painted
-- collapse pose its hit volumes follow. What it looks and sounds like (clots,
-- thud, dust, stain) is feedback/death_response.lua, reached through the
-- presentation hooks 'corpseStruck' and 'corpseLanded'.
local MathX = require('src.core.mathx')
local Archetypes = require('src.content.enemies')
local Presentation = require('src.session.presentation')
local K = Archetypes.defaults.corpse
local Corpse = {}
local sqrt, min, max = math.sqrt, math.min, math.max
local clamp = MathX.clamp
local function body(e)
  return Archetypes.of(e).body
end
Corpse.body = body
function Corpse.begin(e, healthDamage, overkill, source)
  if e.deathResponse then
    return e.deathResponse
  end
  local hp = max(1, e.maxHp or body(e).hp or 1)
  local response = {
    source = source,
    -- A sliver of remaining HP must not hide the force of a close killing blow.
    strength = sqrt(clamp((healthDamage + min(overkill, hp * K.overkill)) / hp, 0, 1)),
    originX = e.x,
    originZ = e.z,
    contacts = 0,
  }
  e.deathResponse = response
  return response
end
-- The killing blow's contact, once: its strength and side. Returns true when
-- this blow was the corpse's first contact.
function Corpse.struck(g, e, impact, strong, point, contact)
  local response = e.deathResponse
  if e.hp > 0 or not response or response.contacted then
    return false
  end
  response.contacted = true
  response.impact = max(0, impact or 0)
  response.strength = max(response.strength, clamp(sqrt(response.impact / K.impactRef), 0, 1))
  response.side = e.flinchSide or 0
  Presentation.call(g, 'corpseStruck', e, strong, point, contact)
  return true
end
-- extended: the body's atlas has the extended layout (enemies/animation.lua).
function Corpse.contactTime(extended)
  return extended and K.contact.extended or K.contact.compact
end
-- Landing is a separate beat, after the wound. Airborne bodies use their
-- calculated ground speed; a grounded collapse uses the torso's fall height.
-- The first contact alone counts: a small rebound cannot repeat it.
function Corpse.land(g, e, speed, age)
  local response = e.deathResponse or Corpse.begin(e, e.maxHp or 1, 0, 'fall')
  if response.landedAt then
    return false
  end
  local b = body(e)
  if not speed then
    local height = (b.aimY or K.aimHeight) * K.fallShare
    speed = sqrt(2 * Archetypes.defaults.fall.gravity * height)
  end
  local horizontal = (e.pushX or 0) ^ 2 + (e.pushZ or 0) ^ 2
  local energy = 0.5 * (b.mass or 1) * (speed * speed + horizontal * K.pushShare)
  response.landedAt, response.landingEnergy = age, energy
  response.contacts = response.contacts + 1
  response.landingX, response.landingZ = e.x, e.z
  Presentation.call(g, 'corpseLanded', e, energy)
  return true
end
-- Settled: the painted collapse shows its last frame and has stopped leaning,
-- and the body is on the floor (not thrown up). Until then a killed body is
-- falling. The death clock and the fall are simulation state, so every query
-- (a shot, a missile) gets the same answer at the same step.
function Corpse.settled(e)
  local layout = Archetypes.look(e).layout == 'extended' and K.extended or K.compact
  local collapse = (layout.last - layout.first) * layout.frame
  return (e.deathTime or 0) >= max(collapse, K.settle)
    and (e.fallY or 0) <= 0
    and (e.fallVY or 0) <= 0
end
-- The one rule of a dead body in the way of the knight's shots and missiles:
-- a falling body shields what is behind it (no wound, no reward: the dead
-- take no damage); a settled one lets them pass. Blasts keep their own rule
-- (combat/explosives.lua: exposure of living bodies).
function Corpse.shields(e)
  return e.hp <= 0 and not Corpse.settled(e)
end
-- The painted collapse. Death advances while flying; landing never restarts it.
function Corpse.pose(e, extended)
  local t = max(0, e.deathTime or 0)
  local layout = extended and K.extended or K.compact
  local frame = min(layout.last, layout.first + math.floor(t / layout.frame))
  local response = e.deathResponse
  local strength = response and response.strength or 0
  local side = response and response.side or e.flinchSide or 0
  local lean = -side * (K.lean + strength * K.leanGain) * max(0, 1 - t / K.settle)
  return frame, e.fallY or 0, lean, 1, 1
end
return Corpse

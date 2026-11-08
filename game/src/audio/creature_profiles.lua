local CreatureAudio = require('src.content.creature_audio')
local Archetypes = require('src.content.enemies')
local Pools = require('src.session.world')
local DamageTypes = require('src.content.damage_types')
local P = {}
local empty = {}
-- The sections a creature audio profile (content/creature_audio.lua) may
-- hold, each declared beside the reader that plays it.
P.sections = {}
function P.of(body)
  local def = body and Archetypes.of(body)
  return def and CreatureAudio[def.id] or empty
end
P.sections.body = true
function P.body(body, role, fallback)
  local profile = P.of(body)
  local def = body and Archetypes.of(body)
  return (profile.body and profile.body[role]) or (def and def.sounds[role]) or fallback
end
P.sections.actions = true
function P.action(body, action, role, fallback)
  local actions = P.of(body).actions
  local profile = actions and actions[action.id]
  return profile and profile[role] or fallback
end
P.sections.projectile, P.sections.projectiles = true, true
function P.projectile(g, projectile, role)
  local profile = P.of(Pools.get(g, projectile.owner))
  local specific = profile.projectiles and profile.projectiles[projectile.art]
  local voices = specific or profile.projectile
  return voices and voices[role] or DamageTypes.cue(
    projectile.packet and projectile.packet.damageType,
    role
  ),
    voices ~= nil
end
P.sections.fields = true
function P.field(g, hazard)
  local fields = P.of(Pools.get(g, hazard.owner)).fields
  return fields and (fields[hazard.art] or fields[hazard.kind or 'pool'])
end
return P

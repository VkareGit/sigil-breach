-- The playable characters. An actor names its character; its body, movement
-- and limits are read from here, so nothing assumes the one knight.
local Character = require('src.content.defs.character')
local Registry = require('src.core.registry')
local Tuning = require('src.content.tuning')
local registry = Registry:new('characters')
local C = { default = 'knight' }
local entries = registry.entries
function C.define(def)
  local built = Character.define(def)
  registry:register(built.id, built)
  return built
end
function C.unregister(id)
  return registry:unregister(id)
end
function C.get(id)
  return registry:get(id)
end
function C.has(id)
  return registry:has(id)
end
-- The character of an actor; a hand-made record is the default one.
function C.of(actor)
  local id = actor.character or C.default
  return entries[id] or error('unknown character: ' .. tostring(id))
end
-- What the session's first actor is when nothing else is said.
function C.standard()
  return entries[C.default]
end
-- The health, ward and dodges a new actor starts with, unless it was given
-- its own. A prefab hook (session/components.lua) and the save's migration.
function C.born(actor)
  local def = C.of(actor)
  local body = def.body
  actor.character = def.id
  actor.maxHp = actor.maxHp or body.hp
  actor.hp = actor.hp or actor.maxHp
  actor.maxArmor = actor.maxArmor or body.armor
  actor.armor = actor.armor or actor.maxArmor
  actor.dash = actor.dash or body.dashCharges
  return actor
end
-- The most health an actor can have (a hand-made record: its character's).
function C.maxHp(actor)
  return actor.maxHp or C.of(actor).body.hp
end
-- The share of health an actor has left.
function C.share(actor)
  return actor.hp / C.maxHp(actor)
end
-- Below the share every wounded look of the interface starts from.
function C.low(actor)
  return C.share(actor) < Tuning.lowHealth
end
C.define(require('src.content.knight'))
return C

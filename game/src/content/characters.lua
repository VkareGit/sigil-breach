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
-- The health, ward and stamina a new actor starts with, unless it was given
-- its own. A prefab hook (session/components.lua) and the save's migration.
function C.born(actor)
  local def = C.of(actor)
  local body = def.body
  actor.character = def.id
  actor.maxHp = actor.maxHp or body.hp
  actor.hp = actor.hp or actor.maxHp
  actor.maxArmor = actor.maxArmor or body.armor
  actor.armor = actor.armor or actor.maxArmor
  if def.resources and not actor.resources then
    actor.resources = {}
    for id, resource in pairs(def.resources) do
      actor.resources[id] = resource.start
    end
  end
  return actor
end
-- Every resource back at its full measure.
function C.rest(actor)
  for id, resource in pairs(C.of(actor).resources or {}) do
    if actor.resources then
      actor.resources[id] = resource.max
    end
  end
end
-- The most health an actor can have (a hand-made record: its character's).
function C.maxHp(actor)
  return actor.maxHp or C.of(actor).body.hp
end
-- The share of health an actor has left.
function C.share(actor)
  return actor.hp / C.maxHp(actor)
end
-- The most ward an actor can hold: his vows' in the chapel, the field's cap on the proving ground.
function C.maxWard(actor)
  return actor.maxArmor or C.of(actor).body.armor
end
function C.wardShare(actor)
  return math.min(1, actor.armor / C.maxWard(actor))
end
-- A share as the whole percent the status bar shows: full is 100, a scratch below it 99,
-- anything alive at least 1, nothing 0 (never -0, which the painted numbers cannot write).
function C.percent(share)
  return share > 0 and math.ceil(share * 100 - 1e-9) or 0
end
-- Below the share every wounded look of the interface starts from.
function C.low(actor)
  return C.share(actor) < Tuning.lowHealth
end
C.define(require('src.content.knight'))
return C

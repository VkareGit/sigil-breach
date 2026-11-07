-- A playable character: its body under the shared rules, how it moves, what it
-- starts with and how it is shown. Everything a knight used to take from
-- constants comes from here, so a second character is one definition.
local Schema = require('src.core.schema')
local DefsKnight = require('src.content.defs.knight')
local Reaction = require('src.content.defs.reaction')
local ContentResources = require('src.content.resources')
local Character = {}
local function speed(desc)
  return { type = 'number', required = true, min = 0, desc = desc }
end
Character.movement = Schema:new('movement', {
  moveSpeed = speed('running speed (m/s)'),
  groundAccel = speed('acceleration on the ground (m/s^2)'),
  groundBrake = speed('braking on the ground (m/s^2)'),
  airAccel = speed('steering in the air (m/s^2)'),
  airSpeed = speed('speed steered to in the air (m/s)'),
  airMomentumCap = speed('momentum kept in the air (m/s)'),
  jumpSpeed = speed('take-off speed (m/s)'),
  slideSpeed = speed('speed of a slide (m/s)'),
  slideTime = speed('length of a slide (s)'),
  slideCooldown = speed('between slides (s)'),
  dashSpeed = speed('speed of a dodge (m/s)'),
  dashTime = speed('length of a dodge (s)'),
})
Character.kit = Schema:new('kit', {
  weapons = { type = 'table', desc = 'weapon ids; none: the default loadout' },
  abilities = { type = 'table', desc = 'ability ids; none: the default loadout' },
})
Character.presentation = Schema:new('presentation', {
  portrait = { type = 'string', desc = 'portrait of the HUD' },
  voice = { type = 'string', desc = 'voice of its sounds' },
})
Character.resource = Schema:new('resource of a character', {
  max = { type = 'number', required = true, min = 0 },
  start = { type = 'number', required = true, min = 0 },
  regen = { type = 'number', default = 0, min = 0, desc = 'per second' },
  pause = { type = 'number', default = 0, min = 0, desc = 'no regen this long after a spend (s)' },
})
Character.schema = Schema:new('character', {
  id = { type = 'string', required = true },
  name = { type = 'string', desc = 'text key of its name' },
  faction = { type = 'string', desc = "its side; none: 'knight' (content/factions.lua)" },
  body = { type = 'table', required = true, desc = 'content/defs/knight.lua: schema' },
  movement = { type = 'table', required = true, schema = Character.movement },
  kit = { type = 'table', schema = Character.kit },
  presentation = { type = 'table', schema = Character.presentation },
  reactions = Reaction.field,
  resources = { type = 'table', desc = 'resource -> { max, start, regen }' },
})
function Character.define(def)
  local where = 'character ' .. tostring(def.id)
  local built = Schema.copy(def)
  built.body = DefsKnight.schema:build(def.body, where .. '.body')
  built = Character.schema:build(built, where)
  for id, resource in pairs(built.resources or {}) do
    assert(ContentResources:has(id), where .. '.resources: unknown resource ' .. tostring(id))
    built.resources[id] = Character.resource:build(resource, where .. '.resources.' .. id)
  end
  built.kit = built.kit or {}
  built.presentation = built.presentation or {}
  return built
end
return Character

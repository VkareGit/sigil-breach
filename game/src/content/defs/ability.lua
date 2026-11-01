-- Ability: the TYPE OBJECT of equipment the knight uses (the powder charge;
-- never magic, the knight is a man). It wraps an action (content/defs/action.lua: the
-- delivery kind, its payload and timing, the same format as demon attacks)
-- with what the knight carries of it: uses at most and at the start, and
-- the notice when none is left. The live record (uses left, ready time) is
-- player.abilityState[id] (content/abilities.lua: newState).
local EquipmentArt = require('src.content.equipment_art')
local Schema = require('src.core.schema')
local Id = require('src.core.id')
local Action = require('src.content.defs.action')
local Text = require('src.content.text')
local Resources = require('src.content.resources')
local Ability = {}
Ability.pulses = Schema:new('pulses', {
  every = { type = 'number', required = true, min = 1e-3, desc = 'between pulses (s)' },
  time = { type = 'number', min = 0, desc = 'how long a channel lasts (s)' },
})
Ability.schema = Schema:new('ability', {
  id = { type = 'string', required = true },
  name = { type = 'string', required = true, desc = 'text key' },
  tag = { type = 'string', required = true, desc = 'text key: its word on the HUD key (Q CHARGE)' },
  hands = { type = 'string', desc = 'equipment hands sequence (content/equipment_art.lua)' },
  action = { type = 'table', required = true, desc = 'Action.build(...): delivery and payload' },
  capacity = { type = 'number', required = true, min = 1, desc = 'uses carried at most' },
  start = { type = 'number', required = true, min = 0, desc = 'uses a fresh knight carries' },
  empty = { type = 'string', required = true, desc = 'text key: notice when no use is left' },
  cost = {
    type = 'table',
    default = { uses = 1 },
    desc = "what one release spends: 'uses' or a resource (content/resources.lua)",
  },
  posture = { type = 'string', desc = 'condition the knight stands in through the windup' },
  fragile = { type = 'boolean', desc = 'a blow on the knight stops it' },
  channel = { type = 'table', schema = Ability.pulses, desc = 'it goes on pulsing after release' },
  toggle = { type = 'table', schema = Ability.pulses, desc = 'it pulses until cast again' },
})
function Ability.define(def)
  local path = 'ability ' .. tostring(def.id)
  local built = Ability.schema:build(def, path)
  Id.check(built.id, path .. '.id')
  assert(
    not built.hands or EquipmentArt.entries[built.hands],
    path .. '.hands: unknown equipment hands sequence ' .. tostring(built.hands)
  )
  assert(built.capacity % 1 == 0, path .. '.capacity: expected an integer')
  assert(built.start % 1 == 0, path .. '.start: expected an integer')
  assert(built.start <= built.capacity, path .. '.start: exceeds capacity')
  -- Its words are text keys (content/text.lua, plan v10 V6).
  for _, field in ipairs({ 'name', 'tag', 'empty' }) do
    assert(Text.has(built[field]), path .. '.' .. field .. ': unknown text key ' .. built[field])
  end
  built.action = Action.build(built.action, path .. '.action')
  for id, amount in pairs(built.cost) do
    assert(id == 'uses' or Resources:has(id), path .. '.cost: unknown resource ' .. tostring(id))
    assert(type(amount) == 'number' and amount >= 0, path .. '.cost.' .. id)
  end
  assert(not (built.channel and built.toggle), path .. ': a channel or a toggle, not both')
  assert(not built.channel or built.channel.time, path .. '.channel.time: required')
  return built
end
return Ability

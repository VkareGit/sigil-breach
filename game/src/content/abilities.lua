-- The knight's abilities by id (0.24 F4): an action in the same format as the
-- demons' attacks (content/defs/action.lua) plus what the knight carries of
-- it (content/defs/ability.lua). The knight casts the abilities of his
-- loadout (player.abilities, slot order; Q is slot 1); each has a live
-- record player.abilityState[id] = { uses, readyAt }. New equipment (never
-- magic: the knight is a man) is a new entry with a delivery kind; its
-- behaviour is the kind's
-- (combat/abilities.lua: throw, bolt).
local Registry = require('src.core.registry')
local Action = require('src.content.defs.action')
local Ability = require('src.content.defs.ability')
local Abilities = Registry:new('abilities')
-- Powder charge (Q): a thrown fire charge. Fire meets no armour rating, so it
-- answers iron; fire demons resist it. The throw was tuned under a private
-- gravity of 12 and is rescaled to the world's (combat/explosives.lua).
Abilities:register(
  'powder',
  Ability.define({
    id = 'powder',
    name = 'POWDER CHARGE',
    tag = 'CHARGE',
    capacity = 3,
    start = 2,
    empty = 'No charges. Restock at the Ember.',
    action = Action.build(Action.throw({
      id = 'powder',
      range = 8,
      windup = 0,
      cooldown = 0.6,
      speed = 8,
      lift = 2.2,
      fuse = 1,
      radius = 4,
      blast = {
        base = 180,
        impact = 150,
        damageType = 'fire',
        penetration = 0.25,
        falloffStart = 0.8,
        falloffEnd = 4,
      },
      selfBlast = { base = 45, impact = 150, falloffStart = 0.8, falloffEnd = 4 },
    })),
  })
)
-- How long the notice of an empty ability stays (s).
Abilities.noticeTime = 1.7
-- The abilities a new knight carries (slot order).
Abilities.defaultLoadout = { 'powder' }
-- Register an ability definition (equipment, a mod, a test).
function Abilities.define(def)
  local built = Ability.define(def)
  Abilities:register(built.id, built)
  return built
end
-- A fresh live record: the starting uses, ready at once.
function Abilities.newState(def)
  return { uses = def.start, readyAt = 0 }
end
-- The live records of a loadout.
function Abilities.kit(loadout)
  local kit = {}
  for _, id in ipairs(loadout) do
    kit[id] = Abilities.newState(Abilities:get(id))
  end
  return kit
end
-- Give equipment by definition id, without changing the knight's prefab or
-- caster. Already equipped equipment keeps its slot and remaining uses.
function Abilities.give(g, id)
  local def = Abilities:get(id)
  local p = g.player
  for slot, equipped in ipairs(p.abilities) do
    if equipped == id then
      return slot
    end
  end
  local slot = #p.abilities + 1
  p.abilities[slot] = id
  p.abilityState[id] = Abilities.newState(def)
  return slot
end
-- The ability in a slot of the knight's loadout and its live record.
function Abilities.slot(g, slot)
  local p = g.player
  local id = p.abilities and p.abilities[slot or 1]
  return id and Abilities:find(id), id and p.abilityState[id]
end
-- Every ability back at rest (a new life, a reset): ready at once.
function Abilities.rest(g)
  for _, state in pairs(g.player.abilityState or {}) do
    state.readyAt = 0
  end
end
-- What a checkpoint keeps: uses by id and the equipped ids in slot order.
function Abilities.inventory(g)
  local uses, loadout = {}, {}
  for slot, id in ipairs(g.player.abilities) do
    loadout[slot] = id
    uses[id] = g.player.abilityState[id].uses
  end
  return uses, loadout
end
-- Back from a checkpoint: reconstruct its slots and records, so equipment
-- absent from the default loadout still returns. Old in-memory checkpoints
-- without a slot list keep the receiving knight's loadout.
function Abilities.restore(g, uses, loadout)
  local p = g.player
  local slots, states = {}, {}
  for slot, id in ipairs(loadout or p.abilities) do
    local def = Abilities:get(id)
    assert(not states[id], 'duplicate equipped ability: ' .. id)
    local state = Abilities.newState(def)
    if uses and uses[id] ~= nil then
      state.uses = uses[id]
    end
    slots[slot], states[id] = id, state
  end
  p.abilities, p.abilityState = slots, states
end
-- Every ability's uses (refill: to capacity; empty: 0).
function Abilities.fill(g, empty)
  for _, id in ipairs(g.player.abilities) do
    g.player.abilityState[id].uses = empty and 0 or Abilities:get(id).capacity
  end
end
return Abilities

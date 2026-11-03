-- The supplies every mode lays out (health, ammunition) and how the knight
-- takes them. What [E] does and says is each mode's own.
local Abilities = require('src.content.abilities')
local Characters = require('src.content.characters')
local Archetypes = require('src.content.enemies')
local Spawn = require('src.session.spawn')
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local World = require('src.world.arena')
local Tuning = require('src.content.tuning')
local Rules = require('src.combat.rules')
local Weapons = require('src.content.weapons')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Text = require('src.content.text')
local Modes = require('src.session.modes')
local Interactions = {}

local distance = MathX.distance
-- The weapon an ammunition pickup is for: its weapon id, or its loadout slot
-- (the first by default). Nothing when the knight does not carry that weapon
-- (an empty slot, a gun not in the arsenal): the pickup stays on the floor.
local function ammoFor(player, pickup)
  local id = pickup.weapon or player.loadout[pickup.slot or 1]
  local state = id and player.arsenal[id]
  if state then
    return Weapons.get(id), state
  end
end

-- Supplies (0.24, Strategy): each pickup kind says whether the knight needs
-- it and what taking it gives. A new kind of supply is a new entry.
--   wanted(player, pickup)  true when the pickup would give something
--   take(player, pickup)    applies it; returns the notice text and how much it gave
-- Every supply names its amount where it is laid (map, mode or drop data). What a knight
-- could not take stays on the floor, a smaller pack (0.42, the owner: nothing is wasted).
Interactions.supplies = {
  health = {
    wanted = function(player)
      return player.hp < Characters.maxHp(player)
    end,
    take = function(player, pickup)
      local before = player.hp
      player.hp = math.min(Characters.maxHp(player), player.hp + pickup.amount)
      local gained = math.floor(player.hp - before + 0.5)
      return Text.get('pickup_health', { amount = gained }), gained
    end,
  },
  -- Ammunition for one weapon (pickup.weapon, else pickup.slot, else the first).
  ammo = {
    wanted = function(player, pickup)
      local def, state = ammoFor(player, pickup)
      return state ~= nil and Weapons.room(def, state) > 0
    end,
    take = function(player, pickup)
      local def, state = ammoFor(player, pickup)
      local gained = Weapons.refill(def, state, pickup.amount)
      return Text.get('pickup_rounds', { amount = gained }), gained
    end,
  },
  -- A draught for the flask (0.42): one more use, never beyond what it holds.
  flask = {
    wanted = function(player)
      local state = player.abilityState and player.abilityState.flask
      return state ~= nil and state.uses < Abilities.capacity('flask', state)
    end,
    take = function(player, pickup)
      local state = player.abilityState.flask
      local before = state.uses
      state.uses = math.min(Abilities.capacity('flask', state), before + pickup.amount)
      local gained = state.uses - before
      return Text.get('pickup_flask', { amount = gained }), gained
    end,
  },
  -- A relic (0.43, owner D8): an engraving or a copy of a sigil found in the chapel, never sold
  -- at a fire. What it gives is the mode's (run/pilgrimage.lua: takeRelic).
  relic = {
    wanted = function(_, pickup, g)
      return g ~= nil and Modes.act(g, 'relicWanted', pickup) == true
    end,
    take = function(_, pickup, g)
      return Modes.act(g, 'takeRelic', pickup), pickup.amount
    end,
  },
}
-- A guardian is never fought with empty hands: a knight out of rounds finds
-- some where it can reach them, one bundle at a time.
local function mercy(g, player)
  if Weapons.left(g, player) > 0 then
    return
  end
  local guardian = false
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    guardian = guardian or (e.hp > 0 and Archetypes.of(e).guardian)
  end
  for _, pickup in ipairs(Pools.of(g, 'pickups')) do
    guardian = guardian and pickup.kind ~= 'ammo'
  end
  if not guardian then
    return
  end
  for _, offset in ipairs(Tuning.mercy.offsets) do
    local x, z = player.x + offset[1], player.z + offset[2]
    if not World.solid(g.world, x, z, Tuning.reach.supply) then
      Spawn.make(g, 'pickup', {
        x = x,
        z = z,
        level = player.level,
        kind = 'ammo',
        amount = Tuning.mercy.rounds,
      })
      return
    end
  end
end
function Interactions.collectSupplies(g)
  local player = Roles.controlled(g)
  mercy(g, player)
  local pickups = Pools.of(g, 'pickups')
  for i = #pickups, 1, -1 do
    local pickup = pickups[i]
    local supply = Interactions.supplies[pickup.kind]
    if
      supply
      and supply.wanted(player, pickup, g)
      and distance(player, pickup) < Tuning.reach.supply
      and World.visible(
        g.world,
        player.x,
        player.z,
        pickup.x,
        pickup.z,
        nil,
        nil,
        player.level,
        pickup.level
      )
    then
      local text, gained = supply.take(player, pickup, g)
      Signal(g, 'PickupTaken', { pickup = pickup, text = text })
      local rest = pickup.amount - (gained or pickup.amount)
      if rest >= 1 then
        pickup.amount = rest
      else
        Pools.removeAt(g, 'pickups', i)
      end
    end
  end
end
return Interactions

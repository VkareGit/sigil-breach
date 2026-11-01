-- The supplies every mode lays out (health, ammunition) and how the knight
-- takes them. What [E] does and says is each mode's own (the classic arena:
-- run/classic.lua, plan v11 E2; the proving ground, the expedition).
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
-- it and what taking it gives. A new kind of supply is a new entry; kinds
-- owned by a mode (the expedition's souls) are collected by that mode.
--   wanted(player, pickup)  true when the pickup would give something
--   take(player, pickup)    applies it and returns the notice text
-- Every supply names its amount where it is laid (map, mode or drop data).
Interactions.supplies = {
  health = {
    wanted = function(player)
      return player.hp < require('src.content.characters').maxHp(player)
    end,
    take = function(player, pickup)
      local before = player.hp
      player.hp =
        math.min(require('src.content.characters').maxHp(player), player.hp + pickup.amount)
      return Text.get('pickup_health', { amount = math.floor(player.hp - before + 0.5) })
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
      return Text.get('pickup_rounds', { amount = Weapons.refill(def, state, pickup.amount) })
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
      and supply.wanted(player, pickup)
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
      Signal(g, 'PickupTaken', { pickup = pickup, text = supply.take(player, pickup) })
      Pools.removeAt(g, 'pickups', i)
    end
  end
end
return Interactions

-- The original three-seal trial's world triggers and their prompts (the
-- classic mode's interact and context: run/modes.lua), and the supplies
-- every mode lays out. What [E] does and says in another mode is that
-- mode's own (the proving ground, the expedition).
local Signal = require('src.session.signal')
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local World = require('src.world.arena')
local Presentation = require('src.session.presentation')
local Tuning = require('src.content.tuning')
local Rules = require('src.combat.rules')
local Weapons = require('src.content.weapons')
local Classic = require('src.content.classic')
local Interactions = {}

local distance = MathX.distance
-- The main weapon (first of the loadout): where the trial's rounds go.
local function mainWeapon(player)
  local id = player.loadout[1]
  return Weapons.get(id), player.arsenal[id]
end
-- The weapon an ammunition pickup is for: its weapon id, or its loadout slot
-- (the first by default).
local function ammoFor(player, pickup)
  local id = pickup.weapon or player.loadout[pickup.slot or 1]
  return Weapons.get(id), player.arsenal[id]
end

local function nearSecret(g)
  local anchor = g.world.anchors and g.world.anchors.secret
  return anchor and not g.secretFound and distance(g.player, anchor) < Classic.reach.secret
end

local function breakSeal(g, seal, index)
  local player, K = g.player, Classic.seal
  seal.active = true
  g.seals = g.seals + 1
  Presentation.cue(g, 'seal')
  g.view.surge = K.surge
  g:notify('SEAL ' .. seal.name .. ' BROKEN  /  ' .. g.seals .. ' of ' .. #K.ambush, 4)
  g:burst(seal.x, K.burstHeight, seal.z, seal.color, K.burst, K.burstSpeed)
  local ambush = K.ambush[index] or K.ambush[#K.ambush]
  for i, position in ipairs(ambush.spots) do
    local kind = i == 1 and ambush.leader or K.thrall
    local enemy = g:spawn(kind, position[1], position[2])
    enemy.awake, enemy.memory = true, K.memory
    enemy.lastX, enemy.lastZ, enemy.spawnAge = player.x, player.z, 0
  end
  local _, main = mainWeapon(player)
  main.reserve = math.min(Classic.maxRounds, main.reserve + Tuning.sealAmmo)
  player.armor = math.min(Classic.maxWard, player.armor + K.ward)
end

local function finishClassic(g)
  g.state = 'won'
  local rank = Classic.rank
  g.rank = g.elapsed < rank.S.time and g.damageTaken < rank.S.damage and 'S'
    or (g.elapsed < rank.A.time and 'A' or 'B')
  local previous = tonumber((love.filesystem.read('best-score-v03.txt'))) or 0
  g.bestScore = math.max(previous, g.score)
  if not g.testing then
    love.filesystem.write('best-score-v03.txt', tostring(g.bestScore))
  end
  Presentation.capture(g, false)
  Presentation.cue(g, 'seal')
end

-- [E] in the classic trial: the secret, a seal, the way out after the guardian.
function Interactions.classicInteract(g)
  local player = g.player
  if nearSecret(g) then
    g.secretFound = true
    local secret = Classic.secret
    player.armor = math.min(Classic.maxWard, player.armor + secret.ward)
    local _, main = mainWeapon(player)
    main.reserve = math.min(Classic.maxRounds, main.reserve + secret.rounds)
    g.score = g.score + secret.score
    g:notify(
      'SECRET: THE TITHE  /  +' .. secret.ward .. ' ward  +' .. secret.rounds .. ' rounds',
      4
    )
    Presentation.cue(g, 'seal')
    return true
  end
  for i, seal in ipairs(g.world.seals) do
    if not seal.active and distance(player, seal) < Classic.reach.seal then
      breakSeal(g, seal, i)
      return true
    end
  end
  if g.bossDead and distance(player, g.world.portal) < Classic.reach.portal then
    finishClassic(g)
    return true
  end
  return false
end

-- The classic trial's prompt where the knight stands.
function Interactions.classicContext(g)
  if nearSecret(g) then
    return '[E]  SEARCH THE CRACKED RELIQUARY'
  end
  for _, seal in ipairs(g.world.seals) do
    if not seal.active and distance(g.player, seal) < Classic.reach.seal then
      return '[E]  BREAK THE SEAL  /  ' .. seal.name
    end
  end
  if g.bossDead and distance(g.player, g.world.portal) < Classic.reach.portal then
    return '[E]  END THE LIMBO TRIAL'
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
      return player.hp < Rules.playerBody().hp
    end,
    take = function(player, pickup)
      local before = player.hp
      player.hp = math.min(Rules.playerBody().hp, player.hp + pickup.amount)
      return '+' .. math.floor(player.hp - before + 0.5) .. ' HEALTH'
    end,
  },
  -- Ammunition for one weapon (pickup.weapon, else pickup.slot, else the first).
  ammo = {
    wanted = function(player, pickup)
      local def, state = ammoFor(player, pickup)
      return state.reserve < def.maxReserve
    end,
    take = function(player, pickup)
      local def, state = ammoFor(player, pickup)
      local before = state.reserve
      state.reserve = math.min(def.maxReserve, before + pickup.amount)
      return '+' .. (state.reserve - before) .. ' ROUNDS'
    end,
  },
}
function Interactions.collectSupplies(g)
  local player = g.player
  for i = #g.pickups, 1, -1 do
    local pickup = g.pickups[i]
    local supply = Interactions.supplies[pickup.kind]
    if
      supply
      and supply.wanted(player, pickup)
      and distance(player, pickup) < Tuning.reach.supply
      and World.visible(g.world, player.x, player.z, pickup.x, pickup.z)
    then
      Signal(g, 'PickupTaken', { pickup = pickup, text = supply.take(player, pickup) })
      table.remove(g.pickups, i)
    end
  end
end
-- A demon fell in the classic arena (run/modes.lua: reward): supplies every
-- few kills, and the Margrave's fall opens the way out.
function Interactions.classicReward(g, event)
  local enemy, K = event.enemy, Tuning.rewards
  if g.kills % K.ammoEvery == 0 then
    Spawn.make(g, 'pickup', { x = enemy.x, z = enemy.z, kind = 'ammo', amount = Tuning.killAmmo })
  end
  if g.kills % K.healthEvery == 0 then
    Spawn.make(
      g,
      'pickup',
      { x = enemy.x + K.dropSpacing, z = enemy.z, kind = 'health', amount = Tuning.healthPickup }
    )
  end
  if (require('src.content.enemies').of(enemy) or {}).guardian then
    g.bossDead = true
    event.guardianFell = true
  end
end
function Interactions.advanceClassic(g)
  if g.seals ~= #Classic.seal.ambush or g.bossSpawned then
    return
  end
  for _, enemy in ipairs(g.enemies) do
    if enemy.hp > 0 then
      return
    end
  end
  g.bossSpawned = true
  local guardian = Classic.guardian
  local anchor = assert(g.world.anchors.boss, 'classic mode requires a boss anchor')
  g:spawn(guardian.kind, anchor.x, anchor.z)
  g:notify('MARGRAVE OF ASH  /  Guardian of the first circle', 5)
  Presentation.cue(g, 'pulse')
  local player = g.player
  player.hp = math.min(Rules.playerBody().hp, player.hp + guardian.health)
  local mainDef, main = mainWeapon(player)
  main.reserve = math.min(mainDef.maxReserve, main.reserve + guardian.rounds)
  player.armor = math.min(Classic.maxWard, player.armor + guardian.ward)
end

return Interactions

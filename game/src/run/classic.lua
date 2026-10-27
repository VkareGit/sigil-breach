-- The classic arena (plan v11 E2: the mode's own logic, out of the session's
-- interactions): the three seals, the hidden sigil, the guardian and the way
-- out. Its private record is g.modeData (rank, best score); the seals and
-- the secret are the world's (world/arena.lua), the guardian the
-- encounter's (session/encounter.lua). The supplies every mode lays out stay
-- in session/interactions.lua.
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local World = require('src.world.arena')
local Presentation = require('src.session.presentation')
local Tuning = require('src.content.tuning')
local Rules = require('src.combat.rules')
local Weapons = require('src.content.weapons')
local Classic = require('src.content.classic')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Text = require('src.content.text')
local Encounter = require('src.session.encounter')
local Stats = require('src.session.stats')
local Mode = {}

local distance = MathX.distance
-- The main weapon (first of the loadout): where the trial's rounds go.
local function mainWeapon(player)
  local id = player.loadout[1]
  return Weapons.get(id), player.arsenal[id]
end
-- The mode's record: its rank and best score, once it is won.
function Mode.init(g)
  g.modeData = { rank = nil, bestScore = nil }
end
local function record(g)
  g.modeData = g.modeData or {}
  return g.modeData
end

local function nearSecret(g)
  local anchor = g.world.anchors and g.world.anchors.secret
  return anchor
    and not g.world.secretFound
    and distance(Roles.controlled(g), anchor) < Classic.reach.secret
end

local function breakSeal(g, seal, index)
  local player, K = Roles.controlled(g), Classic.seal
  seal.active = true
  Presentation.cue(g, 'seal')
  g.view.surge = K.surge
  g:notify(
    Text.get(
      'classic_seal_broken',
      { name = Text.get(seal.name), count = World.activeSeals(g.world), total = #K.ambush }
    ),
    4
  )
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

local function finish(g)
  g.state = 'won'
  local rank, data = Classic.rank, record(g)
  data.rank = g.elapsed < rank.S.time and Stats.total(g, 'damageTaken') < rank.S.damage and 'S'
    or (g.elapsed < rank.A.time and 'A' or 'B')
  local previous = tonumber((love.filesystem.read('best-score-v03.txt'))) or 0
  data.bestScore = math.max(previous, Stats.total(g, 'score'))
  if not g.testing then
    love.filesystem.write('best-score-v03.txt', tostring(data.bestScore))
  end
  Presentation.capture(g, false)
  Presentation.cue(g, 'seal')
end

-- [E] in the classic trial: the secret, a seal, the way out after the guardian.
function Mode.interact(g)
  local player = Roles.controlled(g)
  if nearSecret(g) then
    g.world.secretFound = true
    local secret = Classic.secret
    player.armor = math.min(Classic.maxWard, player.armor + secret.ward)
    local _, main = mainWeapon(player)
    main.reserve = math.min(Classic.maxRounds, main.reserve + secret.rounds)
    local stats = Stats.controlled(g)
    stats.score = stats.score + secret.score
    g:notify(Text.get('classic_secret', { ward = secret.ward, rounds = secret.rounds }), 4)
    Presentation.cue(g, 'seal')
    return true
  end
  for i, seal in ipairs(g.world.seals) do
    if not seal.active and distance(player, seal) < Classic.reach.seal then
      breakSeal(g, seal, i)
      return true
    end
  end
  if Encounter.guardianDead(g) and distance(player, g.world.portal) < Classic.reach.portal then
    finish(g)
    return true
  end
  return false
end

-- The classic trial's prompt where the knight stands.
function Mode.context(g)
  if nearSecret(g) then
    return Text.get('classic_search')
  end
  for _, seal in ipairs(g.world.seals) do
    if not seal.active and distance(Roles.controlled(g), seal) < Classic.reach.seal then
      return Text.get('classic_break', { name = Text.get(seal.name) })
    end
  end
  if
    Encounter.guardianDead(g)
    and distance(Roles.controlled(g), g.world.portal) < Classic.reach.portal
  then
    return Text.get('classic_end')
  end
end

-- A demon fell in the classic arena (run/modes.lua: reward): supplies every
-- few kills, and the Margrave's fall opens the way out.
function Mode.reward(g, event)
  local enemy, K = event.enemy, Tuning.rewards
  local kills = Stats.total(g, 'kills')
  if kills % K.ammoEvery == 0 then
    Spawn.make(
      g,
      'pickup',
      { x = enemy.x, z = enemy.z, level = enemy.level, kind = 'ammo', amount = Tuning.killAmmo }
    )
  end
  if kills % K.healthEvery == 0 then
    Spawn.make(g, 'pickup', {
      x = enemy.x + K.dropSpacing,
      z = enemy.z,
      level = enemy.level,
      kind = 'health',
      amount = Tuning.healthPickup,
    })
  end
  if (require('src.content.enemies').of(enemy) or {}).guardian then
    Encounter.guardianFell(g)
    event.guardianFell = true
  end
end
-- Every step: once the three seals are broken and their defenders down, the
-- guardian comes.
function Mode.advance(g)
  if World.activeSeals(g.world) ~= #Classic.seal.ambush or Encounter.guardianSpawned(g) then
    return
  end
  for _, enemy in ipairs(Pools.of(g, 'enemies')) do
    if enemy.hp > 0 then
      return
    end
  end
  Encounter.guardianArrived(g)
  local guardian = Classic.guardian
  local anchor = assert(g.world.anchors.boss, 'classic mode requires a boss anchor')
  g:spawn(guardian.kind, anchor.x, anchor.z)
  g:notify(Text.get('classic_guardian'), 5)
  Presentation.cue(g, 'pulse')
  local player = Roles.controlled(g)
  player.hp = math.min(Rules.playerBody().hp, player.hp + guardian.health)
  local mainDef, main = mainWeapon(player)
  main.reserve = math.min(mainDef.maxReserve, main.reserve + guardian.rounds)
  player.armor = math.min(Classic.maxWard, player.armor + guardian.ward)
end
-- What its ending screen shows (ui/screens/ending.lua asks Queries.result).
function Mode.result(g, out)
  local data = g.modeData or {}
  out.rank, out.bestScore = data.rank, data.bestScore
  out.seals = World.activeSeals(g.world)
  return out
end
return Mode

local Spawn = require('src.session.spawn')
local Presentation = require('src.session.presentation')
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local F = require('src.player.feel')
local Save = require('src.storage.run_save')
local E = require('src.run.economy')
local Waves = require('src.content.waves')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local T = require('src.content.tuning')
local Encounter = require('src.session.encounter')
local Sanctuary = require('src.session.sanctuary')
local K = require('src.content.expedition')
local R = { shrine = Sanctuary.shrine, totalWaves = K.totalWaves }
local guardianWave = K.totalWaves + 1
local Spawner = require('src.run.spawner')
local Pools = require('src.session.world')
local Navigation = require('src.world.navigation')
local Roles = require('src.core.roles')
local portals = Spawner.portals
R.portals = portals
local distance = MathX.distance
-- Only an expedition session saves, loads and progresses as one (a session
-- of another mode — the proving ground, a hub — may share its record g.run
-- for its shop, never its save or its waves). A hand-made record names no mode.
local function expedition(g)
  return not g.mode or g.mode == 'expedition'
end
local function inventory(g)
  local p = Roles.controlled(g)
  local loadout, weapons = Weapons.inventory(g)
  local abilities, abilityLoadout = Abilities.inventory(g)
  return {
    armor = p.armor,
    essence = 0,
    weapon = g.weapon,
    loadout = loadout,
    weapons = weapons,
    abilities = abilities,
    abilityLoadout = abilityLoadout,
  }
end
-- Development builds briefly saved echoes in an expanded layout. Keep their
-- value and death rules, but put unreachable positions on the current test field.
local function restoreEcho(g, echo)
  if not echo then
    return nil, false
  end
  local x, z = echo.x, echo.z
  local relocated = W.solid(g.world, x, z, K.echo.clearance)
    or not Navigation.distance(g.world, x, z, g.world.spawn.x, g.world.spawn.z)
  if relocated then
    x, z = K.echo.fallback.x, K.echo.fallback.z
  end
  return { amount = echo.amount, x = x, z = z, wave = echo.wave }, not not relocated
end
local function restore(g, v)
  local p = Roles.controlled(g)
  p.hp = require('src.content.enemies').player.body.hp
  p.armor = v.armor
  Weapons.restore(g, v.loadout, v.weapons)
  p.souls = 0
  g.weapon = v.weapon
  Abilities.restore(g, v.abilities, v.abilityLoadout)
  local spawn = g.world.spawn
  p.x, p.z, p.yaw, p.pitch = spawn.x, spawn.z, spawn.yaw, 0
  p.jump, p.jumpV, p.dash, p.dashTimer, p.invuln = 0, 0, T.knight.dashCharges, 0, 0
  local shrine = Sanctuary.at(g)
  p.yaw = math.atan2(shrine.x - p.x, shrine.z - p.z)
  p.heat, p.overheat, p.heatDelay = nil, nil, nil
  Abilities.rest(g)
  Pools.clear(g, 'charges')
  local motion = g.view.motion
  F.init(g)
  g.view.motion = motion
  g.cooldown, g.reload, g.view.muzzle, g.view.hurt, g.view.shake, g.view.surge = 0, 0, 0, 0, 0, 0
  g.reloadWeapon = nil
  g.view.presentationPrevious = nil
  g.nextAttack = 0
  g.view.hitmarker = 0
  g.combo = 0
  g.comboTimer = 0
  g.zoneTimer = 0
end
R.clearWorld = Encounter.clearWorld
function R.init(g)
  R.clearWorld(g)
  -- Give the sanctuary its own silhouette and light, not an overlapping ordinary torch.
  for i = #g.world.lamps, 1, -1 do
    if distance(g.world.lamps[i], Sanctuary.at(g)) < K.emberClearance then
      table.remove(g.world.lamps, i)
    end
  end
  g.run = {
    phase = 'preparing',
    wave = 1,
    wallet = K.wallet,
    glyph = 'none',
    owned = {},
    claimed = {},
    deaths = 0,
    fragment = false,
  }
  Roles.controlled(g).souls = 0
  g.run.checkpoint = inventory(g)
end
function R.snapshot(g)
  if not expedition(g) then
    return nil, 'Only an expedition is saved as one.'
  end
  local r = g.run
  return {
    mode = g.mode,
    phase = r.phase,
    wave = r.wave,
    wallet = r.wallet,
    glyph = r.glyph,
    owned = r.owned,
    claimed = r.claimed,
    checkpoint = r.checkpoint,
    inventory = inventory(g),
    echo = r.echo,
    elapsed = g.elapsed,
    kills = g.kills,
    damage = g.damageTaken,
    deaths = r.deaths,
    secret = g.secretFound,
    secretOpen = r.archivedSecretOpen,
    score = g.score,
    fragment = r.fragment,
  }
end
function R.save(g)
  if not expedition(g) then
    return false, 'Only an expedition is saved as one.'
  end
  if g.testing then
    return true
  end
  local r = g.run
  if r.phase ~= 'preparing' and r.phase ~= 'defeated' and r.phase ~= 'complete' then
    return false
  end
  local ok, reason = Save.write(R.snapshot(g))
  g.saveWarning = not ok and reason or nil
  return ok
end
function R.load(g, data)
  if not expedition(g) then
    return false, 'Only an expedition session loads an expedition.'
  end
  R.clearWorld(g)
  local echo, relocated = restoreEcho(g, data.echo)
  g.run = {
    phase = data.phase,
    wave = data.wave,
    wallet = data.wallet,
    glyph = data.glyph,
    owned = data.owned,
    claimed = data.claimed,
    checkpoint = data.checkpoint,
    echo = echo,
    deaths = data.deaths,
    fragment = data.fragment,
    archivedSecretOpen = data.secretOpen,
  }
  restore(g, data.phase == 'defeated' and data.checkpoint or data.inventory)
  g.elapsed, g.kills, g.damageTaken, g.secretFound, g.score =
    data.elapsed, data.kills, data.damage, data.secret, data.score
  g.state = data.phase == 'complete' and 'won' or (data.phase == 'defeated' and 'dead' or 'playing')
  if g.state == 'dead' then
    Roles.controlled(g).hp = 0
  end
  if g.state == 'won' then
    g.bossDead = true
    g.bossSpawned = true
  end
  g.seals = math.min(3, data.wave - 1)
  for i, s in ipairs(g.world.seals) do
    s.active = i <= g.seals
  end
  Presentation.capture(g, g.state == 'playing')
  g:notify(
    relocated and 'Echo moved to the proving field. All souls kept.'
      or 'Expedition resumed. Souls and purchases kept.',
    3
  )
end
function R.start(g)
  g.state = 'playing'
  Presentation.capture(g, true)
  local shrine = Sanctuary.at(g)
  Roles.controlled(g).yaw =
    math.atan2(shrine.x - Roles.controlled(g).x, shrine.z - Roles.controlled(g).z)
  g:notify('LIMBO / 4 waves and a guardian. [E] Merchant at the Ember. [ENTER] Ready.', 6)
  R.save(g)
end
function R.ready(g)
  local r = g.run
  if
    not r
    or r.phase ~= 'preparing'
    or (g.state ~= 'playing' and g.state ~= 'shop')
    or g.map
    or g.help
  then
    return false
  end
  -- Commit the full entry state before starting. Reload is settled at the shrine.
  require('src.combat.reload').cancel(g)
  Weapons.close(g)
  g.reload = 0
  g.cooldown = 0
  r.checkpoint = inventory(g)
  R.save(g)
  r.phase = 'countdown'
  r.countdown = T.waveCountdown
  r.pending = {}
  r.queueIndex = 1
  r.spawnTimer = 0
  r.lastGate = 0
  r.phaseTime = 0
  r.waveKills = 0
  r.soulGather = 0
  g.bossDead = false
  g.bossSpawned = false
  Encounter.clearStage(g)
  -- Supplies have a fixed wave budget; an old wave cannot leave free crates behind.
  if r.wave <= K.totalWaves then
    Pools.clear(g, 'pickups')
    for _, s in ipairs(K.supplies) do
      Spawn.make(g, 'pickup', { kind = s.kind, amount = s.amount, x = s.x, z = s.z })
    end
  end
  g.state = 'playing'
  g.fireBuffer = 0
  Presentation.capture(g, true)
  g:notify(Waves[r.wave].tip, 5)
  return true
end
R.openShop = Sanctuary.openShop
function R.closeShop(g)
  if g.state ~= 'shop' then
    return false
  end
  g.state = 'playing'
  Presentation.capture(g, true)
  return true
end
-- A purchase at the Ember (any mode with a wallet: run/economy.lua) and its
-- notice; the expedition also saves it (R.buy).
function R.trade(g, id)
  local ok, reason = E.buy(g, id)
  if ok then
    Presentation.cue(g, 'pickup', 0.35)
    g.shopMessage = 'Done. ' .. g.run.wallet .. ' souls left.'
  else
    g.shopMessage = reason
  end
  return ok
end
function R.buy(g, id)
  local ok = R.trade(g, id)
  if ok then
    R.save(g)
  end
  return ok
end
function R.lose(g)
  local r = g.run
  if r.phase == 'defeated' then
    return
  end
  r.deaths = r.deaths + 1
  r.lost = r.wallet
  r.echo = r.wallet > 0
      and { amount = r.wallet, x = Roles.controlled(g).x, z = Roles.controlled(g).z, wave = r.wave }
    or nil
  r.wallet = 0
  r.phase = 'defeated'
  g.state = 'dead'
  Encounter.clearThreats(g)
  r.pending = {}
  R.save(g)
end
function R.retry(g)
  local r = g.run
  if not r or r.phase ~= 'defeated' then
    return false
  end
  R.clearWorld(g)
  restore(g, r.checkpoint)
  r.phase = 'preparing'
  g.state = 'playing'
  g.map = false
  g.help = false
  g.shopMessage = nil
  g.view.feedbackTimer = 0
  Presentation.capture(g, true)
  g:notify(
    'Retry '
      .. (r.wave == guardianWave and 'the guardian fight' or ('wave ' .. r.wave))
      .. '. Recover the echo during the fight.',
    5
  )
  R.save(g)
  return true
end
function R.onKill(g, e, source)
  local r = g.run
  r.waveKills = (r.waveKills or 0) + 1
  if e.rewardId and not r.claimed[e.rewardId] then
    Spawn.make(g, 'pickup', {
      kind = 'soul',
      x = e.x,
      z = e.z,
      level = e.level,
      amount = e.rewardSouls,
      rewardId = e.rewardId,
    })
  end
  if (require('src.content.enemies').of(e) or {}).guardian then
    g.bossDead = true
  end
end
function R.collectSoul(g, a)
  if not expedition(g) then
    return false
  end
  local r = g.run
  if not r.claimed[a.rewardId] then
    r.claimed[a.rewardId] = true
    r.wallet = r.wallet + a.amount
    r.soulGather = (r.soulGather or 0) + a.amount
    g.view.feedback = '+' .. a.amount .. ' SOULS'
    g.view.feedbackTimer = K.souls.notice
    Presentation.cue(g, 'pickup', 0.18)
  end
end
function R.remaining(g)
  local r = g.run
  if not r then
    return 0
  end
  if r.phase ~= 'wave' and r.phase ~= 'countdown' then
    return 0
  end
  local alive = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      alive = alive + 1
    end
  end
  return alive + #(r.pending or {}) + math.max(0, #Waves[r.wave].queue - (r.queueIndex or 1) + 1)
end
-- What the expedition answers for its session (run/modes.lua handlers; the
-- proving ground shares the record g.run and answers some of these alike).
-- The prompt where the knight stands: the Ember before a wave, the echo.
function R.context(g)
  local r = g.run
  if r.phase == 'preparing' and Sanctuary.near(g) then
    return '[E]  EMBER / REST AND TRADE'
  end
  if r.echo and distance(Roles.controlled(g), r.echo) < K.echo.prompt then
    return (r.phase == 'wave' or r.wave > r.echo.wave) and 'APPROACH / RECOVER LOST SOULS'
      or 'THE ECHO WAITS / BEGIN THE WAVE'
  end
  return nil
end
-- The wave tier a new demon gets: the wave it belongs to.
function R.tier(g)
  return g.run and g.run.wave
end
-- The fight is on only in a wave (the policy 'phased': session/capabilities).
function R.waveActive(g)
  return g.run ~= nil and g.run.phase == 'wave'
end
-- What the status bar shows of the run: the engraved glyph, the purse, the
-- echo to reclaim, the wave and whether a fight is on (target bar). One
-- report reused every frame (read at once by the HUD, never kept).
local report = {}
function R.hud(g)
  local r = g.run
  report.glyph, report.wallet, report.echo = r.glyph, r.wallet, r.echo
  report.progress = r.wave == guardianWave and 'BOSS' or ('WAVE ' .. r.wave .. '/' .. K.totalWaves)
  report.fighting = r.phase == 'wave'
  return report
end
function R.finishWave(g)
  if not expedition(g) then
    return false
  end
  local r = g.run
  if r.phase ~= 'wave' then
    return false
  end
  for _, a in ipairs(Pools.of(g, 'pickups')) do
    if a.kind == 'soul' then
      R.collectSoul(g, a)
    end
  end
  Pools.clear(g, 'pickups')
  Encounter.clearThreats(g)
  r.pending = {}
  g.threat = 0
  -- An echo not reached during combat remains reachable in the quiet aftermath.
  r.wallet = r.wallet + (r.wave == guardianWave and K.guardianReward or K.waveReward)
  Roles.controlled(g).hp = require('src.content.enemies').player.body.hp
  Roles.controlled(g).dash = T.knight.dashCharges
  require('src.combat.reload').cancel(g)
  g.reload = 0
  g.cooldown = 0
  Weapons.close(g)
  Weapons.loadAll(g)
  g.comboTimer = 0
  g.view.feedbackTimer = 0
  if r.wave == guardianWave then
    -- The victory screen closes exploration; return any remaining echo first.
    if r.echo then
      r.wallet = r.wallet + r.echo.amount
      r.echo = nil
    end
    r.phase = 'complete'
    r.fragment = true
    g.bossDead = true
    g.state = 'won'
    Presentation.capture(g, false)
    Presentation.cue(g, 'seal')
  else
    r.wave = r.wave + 1
    r.phase = 'preparing'
    g.seals = math.min(3, r.wave - 1)
    for i, s in ipairs(g.world.seals) do
      s.active = i <= g.seals
    end
    g:notify('WAVE CLEANSED / +' .. K.waveReward .. ' souls. Rest: health restored.', 5)
    Presentation.cue(g, 'seal')
  end
  r.checkpoint = inventory(g)
  R.save(g)
  Signal(g, 'WaveCleared', { wave = r.wave, final = r.phase == 'complete' })
  return true
end
function R.update(g, dt)
  if not expedition(g) then
    return
  end
  local r, p = g.run, Roles.controlled(g)
  if r.phase == 'countdown' then
    r.countdown = math.max(0, r.countdown - dt)
    if r.countdown == 0 then
      r.phase = 'wave'
      r.phaseTime = 0
      Presentation.cue(g, 'seal', 0.5)
    end
  end
  if r.phase == 'wave' then
    local _, exhausted = Spawner.step(g, dt)
    if exhausted then
      R.finishWave(g)
      return
    end
  end
  -- Souls are physical drops; nearby ones drift toward you without crossing walls.
  local pickups = Pools.of(g, 'pickups')
  for i = #pickups, 1, -1 do
    local a = pickups[i]
    if a.kind == 'soul' then
      local d = distance(p, a)
      if d < K.souls.reach and W.visible(g.world, p.x, p.z, a.x, a.z) then
        if d < K.souls.take then
          R.collectSoul(g, a)
          Pools.removeAt(g, 'pickups', i)
        else
          local travel = math.min(d, dt * K.souls.drift)
          a.x = a.x + (p.x - a.x) / d * travel
          a.z = a.z + (p.z - a.z) / d * travel
        end
      end
    end
  end
  if
    r.echo
    and (r.phase == 'wave' or (r.phase == 'preparing' and r.wave > r.echo.wave))
    and distance(p, r.echo) < K.echo.reach
    and W.visible(g.world, p.x, p.z, r.echo.x, r.echo.z)
  then
    local amount = r.echo.amount
    r.wallet = r.wallet + amount
    r.echo = nil
    g:notify('RECOVERED ' .. amount .. ' SOULS', 3)
    Presentation.cue(g, 'seal', 0.6)
    if r.phase == 'preparing' then
      R.save(g)
    end
  end
end
return R

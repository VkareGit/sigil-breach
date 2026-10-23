-- An isolated live sandbox. It uses the normal Descent combat definitions,
-- but never owns a saved expedition or advances its waves.
local MathX = require('src.core.mathx')
local Presentation = require('src.session.presentation')
local Signal = require('src.session.signal')
local F = { limit = 20 }
local W = require('src.world.arena')
local Feel = require('src.player.feel')
local Encounter = require('src.session.encounter')
local Sanctuary = require('src.session.sanctuary')
local Definitions = require('src.content.enemy_catalog')
local Spawner = require('src.run.spawner')
local Telemetry = require('src.combat.telemetry')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Shop = require('src.content.shop')
F.catalog = {
  -- Every creature whose definition lists it here, in its order
  -- (catalog.field: content/defs/creature.lua). The gallery uses the same.
  enemies = {},
  -- 0.22 stations: everything as it is now, measured in place.
  stations = {
    { id = 'range', name = 'RANGE' },
    { id = 'physics', name = 'PHYSICS' },
    { id = 'waves', name = 'WAVE TRIAL' },
  },
  seals = {
    { id = 'asmoday', name = 'ASMODAY' },
    { id = 'stolas', name = 'STOLAS' },
    {
      id = 'buer',
      name = 'BUER',
    },
  },
}
for _, def in ipairs(require('src.content.enemies').listed('field')) do
  F.catalog.enemies[#F.catalog.enemies + 1] = { id = def.id, name = Definitions[def.id].name }
end
-- The weapons the knight of this session carries, as catalogue entries
-- { id = slot, name } (the catalogue follows the loadout, never a count).
function F.weapons(g)
  local list = {}
  for slot, id in ipairs(g.player.loadout) do
    list[slot] = { id = slot, name = Weapons.get(id).name }
  end
  return list
end
local function tell(g, message)
  g.testField.message = message
  g:notify(message, 3)
end
local distance = MathX.distance
function F.new(Game)
  local g = Game.new('descent')
  g.mode = 'field'
  g.testField = {
    invincible = true,
    frozen = false,
    selected = 'imp',
    poseIndex = 1,
    returnLabel = 'MAIN MENU',
  }
  F.reset(g)
  return g
end
function F.refill(g)
  if not g.testField then
    return false
  end
  require('src.combat.reload').cancel(g)
  local p = g.player
  -- Health of the knight's body, the ward's cap, every dodge charge.
  p.hp, p.armor, p.souls = require('src.content.enemies').player.body.hp, Shop.maxWard, 0
  p.dash = require('src.content.tuning').knight.dashCharges
  Abilities.fill(g)
  -- Every weapon full, its reserve at its cap, its action at rest.
  for _, id in ipairs(p.loadout) do
    local def, state = Weapons.get(id), p.arsenal[id]
    state.mag, state.reserve = def.capacity, def.maxReserve
  end
  Weapons.rest(g)
  g.charges = {}
  p.heat, p.overheat, p.heatDelay, p.invuln = nil, nil, nil, 0
  g.reload, g.cooldown, g.fireBuffer = 0, 0, 0
  Abilities.rest(g)
  tell(g, 'Health, ward, ammo, charges and dodge restored.')
  return true
end
function F.reset(g)
  if not g.testField then
    return false
  end
  Encounter.clearWorld(g)
  -- A fresh field measures anew (skirmish, stations, real-play reports).
  Telemetry.reset(g)
  local motion = g.view.motion
  Feel.init(g)
  g.view.motion = motion
  g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27.5, math.pi, 0
  g.player.jump, g.player.jumpV, g.player.dashTimer = 0, 0, 0
  g.run = {
    phase = 'wave',
    wave = 1,
    wallet = 1000,
    glyph = 'none',
    owned = {},
    claimed = {},
    deaths = 0,
    fragment = false,
    pending = {},
  }
  g.seals, g.kills, g.shots, g.hits, g.score, g.damageTaken, g.elapsed = 0, 0, 0, 0, 0, 0, 0
  g.bossSpawned, g.bossDead, g.secretFound, g.map, g.help = false, false, false, false, false
  for _, seal in ipairs(g.world.seals) do
    seal.active = false
  end
  g.weapon = 1
  g.cooldown, g.view.muzzle, g.view.hurt, g.view.shake, g.view.surge, g.view.hitmarker =
    0, 0, 0, 0, 0, 0
  g.view.feedbackTimer, g.comboTimer, g.zoneTimer, g.nextAttack = 0, 0, 0, 0
  g.view.presentationPrevious = nil
  g.availableSave = nil
  g.saveWarning = nil
  g.shopMessage = nil
  g.testField.poseIndex = 1
  g.testField.skirmish = false
  g.testField.station, g.testField.posts, g.testField.labels, g.testField.trial = nil, nil, nil, nil
  g.state = 'field_catalog'
  F.refill(g)
  tell(g, 'Clean field. Choose a demon or a trial tool.')
  Presentation.capture(g, false)
  return true
end
function F.open(g)
  if not g.testField then
    return false
  end
  g.testField.returnState = g.state == 'dead' and 'dead' or 'playing'
  g.state = 'field_catalog'
  g.help = false
  g.map = false
  g.fireBuffer = 0
  g.view.presentationPrevious = nil
  Presentation.capture(g, false)
  return true
end
function F.skirmish(g)
  if not g.testField then
    return false
  end
  F.reset(g)
  g.testField.skirmish = true
  g.testField.invincible = false
  g.testField.frozen = false
  g.player.armor = 40
  for _, id in ipairs(g.player.loadout) do
    g.player.arsenal[id].reserve = Weapons.get(id).startReserve
  end
  F.spawn(g, 'imp', 1)
  F.spawn(g, 'imp', 1)
  F.spawn(g, 'stolas', 1)
  F.close(g)
  tell(g, 'Skirmish / 3 opponents. F2: tools. ESC: pause.')
  return true
end
function F.close(g)
  if not g.testField then
    return false
  end
  g.state = g.player.hp <= 0 and 'dead' or 'playing'
  g.run.phase = 'wave'
  g.help = false
  g.map = false
  g.fireBuffer = 0
  g.view.presentationPrevious = nil
  Presentation.capture(g, g.state == 'playing')
  return true
end
function F.toggleGod(g)
  if not g.testField then
    return false
  end
  g.testField.invincible = not g.testField.invincible
  tell(g, g.testField.invincible and 'God mode on.' or 'God mode off. Damage is real.')
  return g.testField.invincible
end
function F.toggleFreeze(g)
  if not g.testField then
    return false
  end
  g.testField.frozen = not g.testField.frozen
  for _, e in ipairs(g.enemies) do
    e.previewFrame = nil
  end
  tell(
    g,
    g.testField.frozen and 'AI, attacks, projectiles and hazards frozen.'
      or 'AI and projectiles live. Manual pose preview off.'
  )
  return g.testField.frozen
end
-- A catalogue demon set on the knight: awake, remembering where he stands,
-- facing him, its first blow a moment off.
local function engage(g, e, kind)
  local p = g.player
  e.fieldKind = kind
  e.awake = true
  e.memory = 60
  e.lastX = p.x
  e.lastZ = p.z
  e.facing = math.atan2(p.x - e.x, p.z - e.z)
  e.attack = 1.2
end
-- Where count demons of kind may stand (free, in sight, 3 m or more from
-- the knight, apart from the living and from open gates), or nil and why.
-- Gates still opening count toward the limit of live demons.
local function place(g, kind, count)
  if not g.testField or not Definitions[kind] then
    return nil, 'Unknown trial type.'
  end
  local allowed = false
  for _, e in ipairs(F.catalog.enemies) do
    if e.id == kind then
      allowed = true
    end
  end
  if not allowed or (count ~= 1 and count ~= 3) then
    return nil, 'Choose one demon or a group of three.'
  end
  local alive = #g.run.pending
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      alive = alive + 1
    end
  end
  if alive + count > F.limit then
    tell(g, 'Limit of 20 live demons. Reset the field or defeat some targets.')
    return nil, g.testField.message
  end
  local p = g.player
  local radius = require('src.content.enemies').get(kind).appearance.fieldRing
  local spots = {}
  local function legal(x, z)
    local candidate = { x = x, z = z }
    if
      W.solid(g.world, x, z, radius)
      or distance(p, candidate) < 3
      or not W.visible(g.world, p.x, p.z, x, z)
    then
      return false
    end
    for _, e in ipairs(g.enemies) do
      if e.hp > 0 and distance(e, candidate) < 1.8 then
        return false
      end
    end
    for _, list in ipairs({ g.run.pending, spots }) do
      for _, s in ipairs(list) do
        if distance(s, candidate) < 1.8 then
          return false
        end
      end
    end
    return true
  end
  for _, d in ipairs({ 6, 9, 12, 4 }) do
    for _, offset in ipairs({ 0, -2.1, 2.1, -4.2, 4.2 }) do
      local x = p.x + math.sin(p.yaw) * d + math.cos(p.yaw) * offset
      local z = p.z + math.cos(p.yaw) * d - math.sin(p.yaw) * offset
      if #spots < count and legal(x, z) then
        spots[#spots + 1] = { x = x, z = z }
      end
    end
  end
  if #spots < count then
    local candidates = {}
    for z = 2, g.world.size - 1 do
      for x = 2, g.world.size - 1 do
        local d = distance(p, { x = x, z = z })
        if d >= 3 and d < 16 and legal(x, z) then
          candidates[#candidates + 1] = { x = x, z = z, d = d }
        end
      end
    end
    table.sort(candidates, function(a, b)
      return a.d < b.d
    end)
    for _, s in ipairs(candidates) do
      if #spots < count and legal(s.x, s.z) then
        spots[#spots + 1] = s
      end
    end
  end
  if #spots < count then
    tell(g, 'No free visible space. Move to the nave or reset the field.')
    return nil, g.testField.message
  end
  -- Remove old bodies only when adding a new batch, keeping death inspection intact.
  for i = #g.enemies, 1, -1 do
    if g.enemies[i].hp <= 0 then
      table.remove(g.enemies, i)
    end
  end
  g.testField.selected = kind
  g.testField.poseIndex = 1
  return spots
end
local function targets(kind, count)
  return Definitions[kind].name .. ' / ' .. count .. ' target' .. (count == 1 and '' or 's')
end
-- Demons of kind standing at once (pose preview, tools, tests): no portal,
-- no arrival (spawnAge 1). Returns the created demons, or nil and why.
function F.spawn(g, kind, count)
  local spots, why = place(g, kind, count)
  if not spots then
    return nil, why
  end
  local created = {}
  for _, s in ipairs(spots) do
    local e = g:spawn(kind, s.x, s.z)
    engage(g, e, kind)
    e.spawnAge = 1
    created[#created + 1] = e
  end
  F.update(g, 0)
  tell(g, targets(kind, count) .. ' on the field.')
  return created
end
-- The catalogue's summons (F2) come through portals: each opens a gate at
-- its place and the demon steps out when it has glowed (Spawner.gate; the
-- arrivals run in stations()). Returns the gates, or nil and why.
function F.summon(g, kind, count)
  local spots, why = place(g, kind, count)
  if not spots then
    return nil, why
  end
  local gates = {}
  for _, s in ipairs(spots) do
    local gate = Spawner.gate(kind, s.x, s.z)
    gate.fieldKind = kind
    g.run.pending[#g.run.pending + 1] = gate
    gates[#gates + 1] = gate
    Signal(g, 'PortalOpened', { gate = gate })
  end
  tell(
    g,
    targets(kind, count) .. ' summoned through ' .. (count == 1 and 'a portal.' or 'portals.')
  )
  return gates
end
-- What a demon stepping out of a gate here is given: a catalogue summons
-- is set on the knight, a wave trial's demon gets the wave's welcome.
local function arrive(g, e, gate)
  if gate.fieldKind then
    engage(g, e, gate.fieldKind)
  else
    Spawner.welcome(g, e, gate)
  end
end
function F.pose(g, delta)
  if not g.testField then
    return false
  end
  local t = g.testField
  local kind = t.selected
  local targets = {}
  for _, e in ipairs(g.enemies) do
    if e.fieldKind == kind then
      targets[#targets + 1] = e
    end
  end
  if #targets == 0 then
    targets = F.spawn(g, kind, 1)
    if not targets then
      return false
    end
  end
  local frames = require('src.enemies.animation').frameCount(kind)
  t.poseIndex = ((t.poseIndex - 1 + (delta or 1)) % frames) + 1
  t.frozen = true
  for _, e in ipairs(targets) do
    e.previewFrame = t.poseIndex
  end
  tell(
    g,
    'Pose preview ' .. t.poseIndex .. ' / ' .. frames .. '. Turn AI on to return to animation.'
  )
  return true
end
function F.visitSeal(g, name)
  if not g.testField then
    return false
  end
  for _, s in ipairs(g.world.seals) do
    if s.name:lower() == tostring(name):lower() then
      local function clear(x, z)
        if W.solid(g.world, x, z, 0.28) or not W.visible(g.world, x, z, s.x, s.z) then
          return false
        end
        for _, e in ipairs(g.enemies) do
          if e.hp > 0 and distance(e, { x = x, z = z }) < 2.2 then
            return false
          end
        end
        return true
      end
      local x, z
      for _, radius in ipairs({ 3, 4.5, 6 }) do
        for i = 0, 15 do
          local a = i * math.pi / 8
          local tx, tz = s.x + math.sin(a) * radius, s.z + math.cos(a) * radius
          if not x and clear(tx, tz) then
            x, z = tx, tz
          end
        end
      end
      if not x then
        tell(g, 'The seal is blocked by targets. Reset the field.')
        return false
      end
      local p = g.player
      p.x, p.z = x, z
      p.yaw = math.atan2(s.x - x, s.z - z)
      p.pitch = 0.08
      p.vx, p.vz, p.jump, p.jumpV, p.crouch = 0, 0, 0, 0, 0
      p.dashTimer, p.slideTimer, p.jumpBuffer = 0, 0, 0
      g.view.presentationPrevious = nil
      tell(g, 'Seal ' .. s.name .. ' / Goetia, 1904. [F2] Trial catalogue.')
      return true
    end
  end
  return false
end
function F.shop(g)
  if not g.testField then
    return false
  end
  local p = g.player
  p.x, p.z = 16, 27.5
  local shrine = Sanctuary.at(g)
  p.yaw = math.atan2(shrine.x - p.x, shrine.z - p.z)
  p.pitch = 0
  p.vx, p.vz = 0, 0
  g.run.wallet = 1000
  g.run.phase = 'preparing'
  g.state = 'playing'
  g.map = false
  g.help = false
  g.shopMessage = 'PROVING GROUND / 1000 trial souls. Purchases never change the expedition.'
  return Sanctuary.openShop(g)
end
-- What the proving ground answers for its session (run/modes.lua handlers;
-- the gallery's pads answer first there: world/gallery.lua).
-- [E] away from a pad: the Ember's trial shop.
function F.interact(g)
  if Sanctuary.near(g) then
    return F.shop(g)
  end
  return false
end
-- The prompt away from a pad: the selected demon and its pose mode.
function F.context(g)
  local field, manual = g.testField, false
  for _, enemy in ipairs(g.enemies) do
    if enemy.fieldKind == field.selected and enemy.previewFrame then
      manual = true
    end
  end
  return '[F2] '
    .. Definitions[field.selected].name
    .. ' / '
    .. (manual and ('POSE ' .. field.poseIndex) or 'AUTO ANIMATION')
end
-- A new demon's tier: the TIER dial, else the wave of the shared record.
function F.tier(g)
  return (g.testField and g.testField.tier) or (g.run and g.run.wave)
end
-- Time can stop and the knight can be unhurt here (policy freezable,
-- invincible); the fight is on in the record's wave phase, as in a run.
function F.frozen(g)
  return g.testField ~= nil and g.testField.frozen == true
end
function F.invincible(g)
  return g.testField and g.testField.invincible
end
function F.waveActive(g)
  return g.run ~= nil and g.run.phase == 'wave'
end
-- The status bar: the trial purse and glyph, never an echo, 'PROVING'.
-- One report reused every frame (read at once by the HUD, never kept).
local report = {}
function F.hud(g)
  local r = g.run
  report.glyph, report.wallet, report.echo = r.glyph, r.wallet, nil
  report.progress, report.fighting = 'PROVING', r.phase == 'wave'
  return report
end
-- STATIONS (0.22). Training dummies are real demons of the chosen tier that
-- neither move nor attack (AI 'dummy'), heal fully between shots and stand
-- up again 1.5 s after a lethal blow, so every number on screen is real.
local function post(g, kind, x, z, label)
  local posts = g.testField.posts or {}
  g.testField.posts = posts
  local entry = { kind = kind, x = x, z = z, label = label }
  posts[#posts + 1] = entry
  return entry
end
local function raise(g, entry)
  local e = g:spawn(entry.kind, entry.x, entry.z)
  e.fieldKind, e.dummy, e.spawnAge = entry.kind, true, 1
  e.facing = math.atan2(g.player.x - e.x, g.player.z - e.z)
  e.displayName = entry.label
  entry.enemy, entry.down = e, nil
  return e
end
local function label(g, x, z, text, y)
  local labels = g.testField.labels or {}
  g.testField.labels = labels
  labels[#labels + 1] = { x = x, y = y or 0.35, z = z, text = text }
end
local function station(g, name)
  F.reset(g)
  g.testField.station = name
  g.testField.invincible = true
  g.testField.frozen = false
end
-- Shooting range: dummies at 4/8/12/16/20 m along the nave, staggered so no
-- body hides another; read damage falloff, spread, zones and guard at range.
function F.range(g)
  if not g.testField then
    return false
  end
  station(g, 'range')
  local p = g.player
  p.x, p.z, p.yaw, p.pitch = 16, 27.5, math.pi, 0
  local lanes = { { 4, -1.7 }, { 8, 2.1 }, { 12, -2.4 }, { 16, 2.4 }, { 20, 0 } }
  for _, lane in ipairs(lanes) do
    local d, dx = lane[1], lane[2]
    local x, z = p.x + dx, p.z - math.sqrt(d * d - dx * dx)
    raise(g, post(g, 'imp', x, z, 'Range ' .. d .. ' m'))
    label(g, x, z, d .. ' m')
  end
  F.close(g)
  tell(g, 'Range / dummies at 4-20 m heal between shots. Hitboxes: F2.')
  return true
end
-- Physics: a domino row straight ahead, a wall-slam dummy by the east wall
-- and one live thrall to trip with a leg shot during its lunge.
function F.physics(g)
  if not g.testField then
    return false
  end
  station(g, 'physics')
  local p = g.player
  p.x, p.z, p.yaw, p.pitch = 16, 24.5, math.pi, 0
  for i = 1, 3 do
    raise(g, post(g, 'imp', 16, 21.4 - (i - 1) * 0.8, 'Domino ' .. i))
  end
  label(g, 16, 21.4, 'DOMINO: shoot the first')
  raise(g, post(g, 'imp', 22.6, 27, 'Wall slam'))
  label(g, 22.6, 27, 'WALL SLAM: shotgun from 2 m')
  local live = F.spawn(g, 'imp', 1)
  if live and live[1] then
    label(g, live[1].x, live[1].z, 'TRIP: legs during its lunge', 2.1)
  end
  F.close(g)
  tell(g, 'Physics / domino, wall slam, trip. God mode on.')
  return true
end
-- Wave trial: the real spawner (portals, packs, flanks) on a wave chosen by
-- the TIER dial (5 = the Margrave), with real damage; reports time and harm.
function F.waves(g)
  if not g.testField then
    return false
  end
  station(g, 'waves')
  g.testField.invincible = false
  local tier = g.testField.tier or 1
  local r = g.run
  r.wave = math.min(5, tier)
  r.queueIndex, r.pending, r.spawnTimer, r.phaseTime, r.lastGate = 1, {}, 0, 0, nil
  g.testField.trial = { started = g.elapsed, damage = g.damageTaken, wave = r.wave }
  -- Each trial is measured on its own (combat/telemetry.lua) and starts with
  -- a calm pacing director.
  Telemetry.reset(g)
  g.intensity = 0
  g.player.armor = 40
  F.close(g)
  tell(g, 'Wave trial ' .. r.wave .. ' / real damage. F2: abort.')
  return true
end
-- Keep stations alive: heal dummies, raise fallen ones, run the wave trial.
local function stations(g, dt)
  local t = g.testField
  for _, entry in ipairs(t.posts or {}) do
    local e = entry.enemy
    if e and e.hp > 0 then
      e.hp = e.maxHp
    elseif e then
      entry.down = (entry.down or 0) + dt
      if entry.down >= 1.5 then
        raise(g, entry)
      end
    end
  end
  local trial = t.trial
  if not (trial and g.run.phase == 'wave') then
    -- The catalogue's portals open outside a wave trial too.
    Spawner.arrivals(g, dt, arrive)
  end
  if trial and g.run.phase == 'wave' then
    local _, done = Spawner.step(g, dt, arrive)
    if done then
      t.trial = nil
      local m = Telemetry.get(g)
      local summary = string.format(
        'Wave trial %d cleared / %.1f s / damage taken %.0f / control %.0f %% / kill %.1f s.',
        trial.wave,
        g.elapsed - trial.started,
        g.damageTaken - trial.damage,
        100 * Telemetry.uptime(g),
        m.ttkCount > 0 and m.ttkSum / m.ttkCount or 0
      )
      tell(g, summary)
      -- The measurements go to the playtest report (app/session_report.lua).
      Signal(g, 'WaveCleared', { wave = trial.wave, final = false, trial = true })
    end
  end
end
function F.update(g, dt)
  if g.testField and dt and dt > 0 then
    stations(g, dt)
  end
  local bosses = 0
  for _, e in ipairs(g.enemies) do
    if e.boss and e.hp > 0 then
      bosses = bosses + 1
    end
  end
  g.bossSpawned = bosses == 1
  g.bossDead = false
end
function F.action(g, id)
  if not g.testField then
    return false
  end
  if id == 'field_close' then
    F.close(g)
  elseif id == 'field_open' then
    F.open(g)
  elseif id == 'field_archive' then
    g.state = 'field_archive'
    g.help = false
    g.map = false
    g.view.presentationPrevious = nil
    Presentation.capture(g, false)
  elseif id:match('^archive_') then
    return require('src.content.occult_catalog').action(g, id)
  elseif id == 'field_station_range' then
    F.range(g)
  elseif id == 'field_station_physics' then
    F.physics(g)
  elseif id == 'field_station_waves' then
    F.waves(g)
  elseif id == 'field_reset' then
    F.reset(g)
  elseif id == 'field_skirmish' then
    F.skirmish(g)
  elseif id == 'field_refill' then
    F.refill(g)
  elseif id == 'field_god' then
    F.toggleGod(g)
  elseif id == 'field_freeze' then
    F.toggleFreeze(g)
  elseif id == 'field_tier' then
    -- Wave tier of the next demons: speed, damage, health, aggression, lead.
    g.testField.tier = (g.testField.tier or 1) % 5 + 1
    tell(
      g,
      'Tier ' .. g.testField.tier .. ' / new demons fight like wave ' .. g.testField.tier .. '.'
    )
  elseif id == 'field_hitboxes' then
    g.testField.hitboxes = not g.testField.hitboxes
    tell(
      g,
      g.testField.hitboxes and 'Hitboxes on / shot surface, body ring, attack contact.'
        or 'Hitboxes off.'
    )
  elseif id == 'field_pose_prev' or id == 'field_pose_next' then
    if F.pose(g, id == 'field_pose_prev' and -1 or 1) then
      F.close(g)
    end
  elseif id == 'field_shop' then
    F.shop(g)
  elseif id == 'field_low' then
    g.player.hp, g.player.armor, g.player.souls = 25, 0, 0
    Abilities.fill(g, true)
    for _, state in pairs(g.player.arsenal) do
      state.mag, state.reserve = 0, 0
    end
    tell(g, 'Low resources / HUD preview.')
    F.close(g)
  elseif id:match('^field_select_') then
    local key = id:sub(14)
    if not Definitions[key] then
      return false
    end
    g.testField.selected = key
    g.testField.poseIndex = 1
  elseif id:match('^field_spawn_') then
    local kind, n = id:match('^field_spawn_(%a+)_(%d)$')
    if F.summon(g, kind, tonumber(n)) then
      F.close(g)
    end
  elseif id:match('^field_weapon_') then
    local slot = tonumber(id:sub(14))
    local valid = false
    for _, weapon in ipairs(F.weapons(g)) do
      if weapon.id == slot then
        valid = true
      end
    end
    if not valid then
      return false
    end
    g:switchWeapon(slot)
    F.close(g)
  elseif id:match('^field_seal_') then
    if F.visitSeal(g, id:sub(12)) then
      F.close(g)
    end
  else
    return false
  end
  return true
end
return F

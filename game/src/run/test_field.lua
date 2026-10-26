-- An isolated live sandbox. It uses the normal Descent combat definitions,
-- but never owns a saved expedition or advances its waves.
local Presentation = require('src.session.presentation')
local K = require('src.content.field')
local Text = require('src.content.text')
local F = { limit = K.limit }
local Feel = require('src.player.feel')
local Encounter = require('src.session.encounter')
local Sanctuary = require('src.session.sanctuary')
local Archetypes = require('src.content.enemies')
local Actions = require('src.run.field.actions')
local Placement = require('src.run.field.placement')
local Trials = require('src.run.field.trials')
local Visits = require('src.run.field.visits')
local Telemetry = require('src.combat.telemetry')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Shop = require('src.content.shop')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
F.catalog = require('src.run.field.catalog')
-- The weapons the knight of this session carries, as catalogue entries
-- { id = slot, name = text key } (the catalogue follows the loadout, never
-- a count).
function F.weapons(g)
  local list = {}
  for slot, id in ipairs(Roles.controlled(g).loadout) do
    list[slot] = { id = slot, name = Weapons.get(id).name }
  end
  return list
end
-- The field's message (its screens show it) and a notice: text key and its
-- parameters (content/text.lua).
local function tell(g, key, parameters)
  local message = Text.get(key, parameters)
  g.testField.message = message
  g:notify(message, 3)
end
F.tell = tell
function F.new(Game, mapId)
  return Game.new('field', mapId)
end
function F.init(g)
  g.testField = {
    invincible = true,
    frozen = false,
    selected = 'imp',
    poseIndex = 1,
  }
  g.view.fieldReturnLabel = 'return_menu'
  F.reset(g)
end
function F.refill(g)
  if not g.testField then
    return false
  end
  require('src.combat.reload').cancel(g)
  local p = Roles.controlled(g)
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
  Pools.clear(g, 'charges')
  p.heat, p.overheat, p.heatDelay, p.invuln = nil, nil, nil, 0
  g.reload, g.cooldown, g.fireBuffer = 0, 0, 0
  Abilities.rest(g)
  tell(g, 'field_refilled')
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
  Roles.controlled(g).x, Roles.controlled(g).z, Roles.controlled(g).yaw, Roles.controlled(g).pitch =
    K.start.x, K.start.z, math.pi, 0
  Roles.controlled(g).jump, Roles.controlled(g).jumpV, Roles.controlled(g).dashTimer = 0, 0, 0
  g.run = {
    phase = 'wave',
    wave = 1,
    wallet = K.wallet,
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
  tell(g, 'field_clean')
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
  Roles.controlled(g).armor = K.armor
  for _, id in ipairs(Roles.controlled(g).loadout) do
    Roles.controlled(g).arsenal[id].reserve = Weapons.get(id).startReserve
  end
  F.spawn(g, 'imp', 1)
  F.spawn(g, 'imp', 1)
  F.spawn(g, 'stolas', 1)
  F.close(g)
  tell(g, 'field_skirmish')
  return true
end
function F.close(g)
  if not g.testField then
    return false
  end
  g.state = Roles.controlled(g).hp <= 0 and 'dead' or 'playing'
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
  tell(g, g.testField.invincible and 'field_god_on' or 'field_god_off')
  return g.testField.invincible
end
function F.toggleFreeze(g)
  if not g.testField then
    return false
  end
  g.testField.frozen = not g.testField.frozen
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    e.previewFrame = nil
  end
  tell(g, g.testField.frozen and 'field_frozen' or 'field_live')
  return g.testField.frozen
end
-- Targets (run/field/placement.lua), the seal and shop visits
-- (run/field/visits.lua) and the stations (run/field/trials.lua).
function F.spawn(g, kind, count)
  return Placement.spawn(F, g, kind, count)
end
function F.summon(g, kind, count)
  return Placement.summon(F, g, kind, count)
end
function F.pose(g, delta)
  return Placement.pose(F, g, delta)
end
function F.visitSeal(g, id)
  return Visits.seal(F, g, id)
end
function F.shop(g)
  return Visits.shop(F, g)
end
function F.range(g)
  return Trials.range(F, g)
end
function F.physics(g)
  return Trials.physics(F, g)
end
function F.waves(g)
  return Trials.waves(F, g)
end -- What the proving ground answers for its session (run/modes.lua handlers;
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
  for _, enemy in ipairs(Pools.of(g, 'enemies')) do
    if enemy.fieldKind == field.selected and enemy.previewFrame then
      manual = true
    end
  end
  return Text.get('field_context', {
    name = Text.get(Archetypes.get(field.selected).name),
    mode = manual and Text.get('field_context_pose', { pose = field.poseIndex })
      or Text.get('field_context_auto'),
  })
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
  report.progress, report.fighting = Text.get('field_progress'), r.phase == 'wave'
  return report
end
function F.update(g, dt)
  if g.testField and dt and dt > 0 then
    Trials.tick(F, g, dt)
  end
  local bosses = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.boss and e.hp > 0 then
      bosses = bosses + 1
    end
  end
  g.bossSpawned = bosses == 1
  g.bossDead = false
end
function F.action(g, id)
  return Actions.dispatch(g, id, F)
end
return F

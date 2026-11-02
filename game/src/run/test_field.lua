-- An isolated live sandbox on the normal combat definitions. It saves nothing.
local Destruction = require('src.combat.destruction')
local Reload = require('src.combat.reload')
local Characters = require('src.content.characters')
local Presentation = require('src.session.presentation')
local K = require('src.content.field')
local Text = require('src.content.text')
local F = { limit = K.limit }
local Feel = require('src.player.feel')
local Encounter = require('src.session.encounter')
local Sanctuary = require('src.session.sanctuary')
local Archetypes = require('src.content.enemies')
local Actions = require('src.run.field.actions')
local Access = require('src.run.field.access')
local Placement = require('src.run.field.placement')
local Trials = require('src.run.field.trials')
local Chambers = require('src.run.field.chambers')
local Stations = require('src.run.field.station_layout')
local ActorReset = require('src.run.actor_reset')
local TrialReset = require('src.run.field.reset')
local Visits = require('src.run.field.visits')
local Telemetry = require('src.combat.telemetry')
local Observation = require('src.combat.observation')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Shop = require('src.content.shop')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Stats = require('src.session.stats')
local World = require('src.world.arena')
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
function F.new(Game, mapId, options)
  return Game.new('field', mapId, options)
end
function F.init(g, options)
  Chambers.validate(g)
  -- Legacy maps retain their historical tools; authored stations are checked.
  if Chambers.layout(g) and Chambers.layout(g).stations then
    Stations.validate(g)
  end
  g.testField = {
    invincible = true,
    frozen = false,
    selected = K.dummy,
    poseIndex = 1,
    features = Access.copy(options),
    -- Effort is paid here unless a frozen reference asks for the old rules.
    attrition = not (options and options.attrition == false),
  }
  if g.testField.attrition then
    Abilities.give(g, 'flask', Roles.controlled(g))
  end
  g.view.fieldReturnLabel = 'return_menu'
  F.reset(g)
end
function F.allows(g, feature)
  return Access.allows(g.testField, feature)
end
-- The journal reconstructs this session's policy, not today's release default.
function F.options(g)
  local attrition = not g.testField.attrition and false or nil
  if g.testField.features then
    return { features = Access.copy(g.testField), attrition = attrition }
  end
  return attrition == false and { attrition = false } or nil
end
function F.attrition(g)
  return g.testField ~= nil and g.testField.attrition == true
end
function F.refill(g)
  if not g.testField then
    return false
  end
  Reload.cancel(g)
  local p = Roles.controlled(g)
  -- Health of the knight's body, the ward's cap, every dodge charge.
  p.hp, p.armor, p.souls = Characters.maxHp(p), Shop.maxWard, 0
  p.dash = Characters.of(p).body.dashCharges
  Characters.rest(p)
  Abilities.fill(g, nil, Roles.controlled(g))
  -- Every weapon full, its reserve at its cap, its action at rest.
  Weapons.fill(g, p)
  Weapons.rest(g)
  Pools.clear(g, 'charges')
  p.invuln = 0
  p.reload, p.cooldown, p.fireBuffer = 0, 0, 0
  Abilities.rest(g, Roles.controlled(g))
  tell(g, 'field_refilled')
  return true
end
function F.reset(g)
  if not g.testField then
    return false
  end
  Encounter.clearWorld(g)
  ActorReset.actor(g, Roles.controlled(g))
  TrialReset.session(g)
  -- A reset ends every observation of the field before it (plan v11 E4).
  Observation.invalidate(g)
  -- A fresh field measures anew (skirmish, stations, real-play reports).
  Telemetry.reset(g)
  local motion = g.view.motion
  Feel.init(g)
  g.view.motion = motion
  local start = Stations.get(g).start
  Roles.controlled(g).x, Roles.controlled(g).z, Roles.controlled(g).yaw, Roles.controlled(g).pitch =
    start.x, start.z, math.pi, 0
  g.run = {
    wallet = K.wallet,
    glyph = 'none',
    owned = {},
    claimed = {},
    deaths = 0,
    fragment = false,
    pending = {},
  }
  Stats.reset(g)
  g.elapsed = 0
  Roles.controlled(g).shots, Roles.controlled(g).hits = 0, 0
  g.map, g.help = false, false
  Encounter.setGuardian(g, false, false)
  Destruction.reset(g.world)
  World.breakSeals(g.world, 0)
  Roles.controlled(g).weapon = 1
  Roles.controlled(g).cooldown, g.view.muzzle, g.view.hurt, g.view.shake, g.view.surge, g.view.hitmarker =
    0, 0, 0, 0, 0, 0
  g.view.feedbackTimer, g.zoneTimer, g.nextAttack = 0, 0, 0
  g.view.presentationPrevious = nil
  g.saveWarning = nil
  g.shopMessage = nil
  g.testField.poseIndex = 1
  g.testField.skirmish = false
  g.testField.roomTrial = nil
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
  Roles.controlled(g).fireBuffer = 0
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
  Weapons.restock(g, Roles.controlled(g))
  for _, kind in ipairs(K.skirmish) do
    F.spawn(g, kind, 1)
  end
  F.close(g)
  tell(g, 'field_skirmish')
  return true
end
function F.close(g)
  if not g.testField then
    return false
  end
  g.state = Roles.controlled(g).hp <= 0 and 'dead' or 'playing'
  g.help = false
  g.map = false
  Roles.controlled(g).fireBuffer = 0
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
  local allowed, reason = Placement.request(F, g, kind, count)
  if not allowed then
    return nil, reason
  end
  local trial = Chambers.forCreature(g, kind)
  if trial then
    return Chambers.start(F, g, trial, count)
  end
  -- Newly registered content without an authored chamber still has a clean
  -- free trial; adding a creature does not require editing this dispatcher.
  if Chambers.layout(g) then
    F.reset(g)
  end
  return Placement.summon(F, g, kind, count)
end
function F.chamber(g, id, count)
  return Chambers.start(F, g, id, count)
end
function F.retry(g)
  local trial = g.testField and g.testField.roomTrial
  return trial and Chambers.start(F, g, trial.id, trial.count) or F.reset(g)
end
function F.pose(g, delta)
  return Placement.pose(F, g, delta)
end
function F.visitSeal(g, id)
  return Visits.seal(F, g, id)
end
function F.shop(g)
  if not F.allows(g, 'trade') then
    return false
  end
  return Visits.shop(F, g)
end
function F.range(g)
  return Trials.range(F, g)
end
function F.physics(g)
  return Trials.physics(F, g)
end
-- [E] away from a pad: the Ember's trial shop.
function F.interact(g)
  if F.allows(g, 'trade') and Sanctuary.near(g) then
    return F.shop(g)
  end
  return false
end
-- The prompt away from a pad: the selected demon and its pose mode.
function F.context(g)
  local trialContext = Chambers.context(g)
  if trialContext then
    return trialContext
  end
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
-- Time can stop and the knight can be unhurt here (policy freezable, invincible).
function F.frozen(g)
  return g.testField ~= nil and g.testField.frozen == true
end
function F.invincible(g)
  return g.testField and g.testField.invincible
end
-- The status bar: the trial purse and glyph, never an echo, 'PROVING'.
-- One report reused every frame (read at once by the HUD, never kept).
local report = {}
function F.hud(g)
  local r = g.run
  report.glyph, report.wallet, report.echo = r.glyph, r.wallet, nil
  report.progress = Text.get('field_progress')
  return report
end
function F.update(g, dt)
  if g.testField and dt and dt > 0 then
    Trials.tick(F, g, dt)
    Chambers.update(g)
  end
  local bosses = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.boss and e.hp > 0 then
      bosses = bosses + 1
    end
  end
  Encounter.setGuardian(g, bosses == 1, false)
end
function F.action(g, id)
  return Actions.dispatch(g, id, F)
end
return F

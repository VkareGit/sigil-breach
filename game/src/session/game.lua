-- Session facade used by the application, combat systems and QA. Construction
-- and player commands live here; simulation, consequences and world triggers
-- have separate owners. Public methods keep one stable entry point.
local Entities = require('src.session.entities')
local Capabilities = require('src.session.capabilities')
local Execution = require('src.combat.execution')
local Resources = require('src.combat.resources')
local World = require('src.world.arena')
local Maps = require('src.content.maps.index')
local Presentation = require('src.session.presentation')
local Feel = require('src.player.feel')
local Combat = require('src.combat.combat')
local Tuning = require('src.content.tuning')
local AI = require('src.enemies.ai')
local Reload = require('src.combat.reload')
local Modes = require('src.run.modes')
local Signal = require('src.session.signal')
local Archetypes = require('src.content.enemies')
local Rules = require('src.combat.rules')
local Weapons = require('src.content.weapons')
local State = require('src.session.state')
local Outcomes = require('src.session.damage_outcomes')
local Simulation = require('src.session.simulation')
local Fields = require('src.session.fields')
local ContentContracts = require('src.session.content_contracts')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Bodies = require('src.combat.bodies')
local Text = require('src.content.text')
local Context = require('src.session.context')
local Game = {}
Game.__index = Game
-- Presentation state lives in g.view (session/fields.lua): reading or writing
-- one of its fields on the session itself is a mistake, reported at once.
-- A field that moved off the session (plan v11) names its new place.
setmetatable(Game, {
  __index = function(_, key)
    if Fields.viewOwner(key) then
      error('session.' .. key .. ' is presentation state: use session.view.' .. key, 2)
    end
    if Fields.retired[key] then
      error('session.' .. key .. ' moved to ' .. Fields.retired[key], 2)
    end
  end,
})
function Game.__newindex(session, key, value)
  if Fields.viewOwner(key) then
    error('session.' .. key .. ' is presentation state: use session.view.' .. key, 2)
  end
  if Fields.retired[key] then
    error('session.' .. key .. ' moved to ' .. Fields.retired[key], 2)
  end
  rawset(session, key, value)
end

-- Optional constructor data belongs to the mode; its init copies persistent
-- options into its record, so snapshots/replays retain the selected policy.
function Game.new(mode, mapId, options)
  local id, kind = Modes.resolve(mode)
  ContentContracts.validate()
  local descriptor = kind.session
  local data = Maps:get(mapId or descriptor.map)
  for _, part in ipairs(descriptor.requires or {}) do
    assert(data[part], 'mode ' .. id .. ' needs a map with ' .. part .. ': ' .. data.id)
  end
  local g = setmetatable(State.new(descriptor.world, mapId or descriptor.map), Game)
  Feel.init(g)
  if descriptor.prepare then
    descriptor.prepare(g)
  end
  g.mode = id
  if kind.init then
    kind.init(g, options)
  end
  return g
end

function Game:notify(text, duration)
  self.view.message, self.view.messageTimer = text, duration or 3
end

function Game:start()
  local mode = Modes.of(self)
  local result = mode.start(self)
  Signal(self, 'ModeStarted', { mode = mode })
  return result
end

-- One cell of the world becomes another tile (a door): a command, so a journal
-- replays it and a save keeps it.
function Game:setCell(x, z, tile)
  World.setCell(self.world, x, z, tile)
  return true
end

function Game:spawn(kind, x, z)
  local archetype = Archetypes.get(kind)
  assert(archetype and archetype.body, 'unknown archetype: ' .. tostring(kind))
  self.nextId = self.nextId + 1
  -- Factory: the 'creature' prefab declares every field with its default
  -- (session/components.lua); only what depends on this demon is given here.
  local enemy = self.ecs:create('creature', {
    kind = archetype.kind,
    x = x,
    z = z,
    id = self.nextId,
    -- The circle's guardian arrives knowing where the knight is.
    awake = archetype.guardian,
    -- Arrival time, for the time-to-kill measurement (combat/telemetry.lua).
    bornAt = self.elapsed or 0,
  }, false)
  Rules.equip(enemy, archetype)
  -- Tier: the mode's (the expedition's wave, the proving ground's dial).
  local tier = Modes.act(self, 'tier') or self.tier or 1
  Rules.applyTier(enemy, tier)
  enemy.variant = archetype.variant
  AI.init(enemy)
  return Pools.add(self, 'enemies', enemy)
end

-- The commands below act for one actor (plan v11 E3b): who is a knight's id,
-- or nil for the controlled one. An id that names no knight is refused, a
-- dead actor's command does nothing; what is seen and heard (the view, the
-- cues) answers the controlled knight's commands only.
local function commander(self, who)
  local actor = Bodies.actor(self, who)
  if not actor or (actor.hp or 1) <= 0 then
    return nil
  end
  return actor, actor == Roles.controlled(self)
end

function Game:reloadGun(who)
  local actor, presented = commander(self, who)
  if not actor or Reload.left(self, actor) > 0 or not Weapons.inHand(self, nil, actor) then
    return false
  end
  if Reload.start(self, false, actor) then
    return true
  end
  local mag, reserve = Weapons.meter(self, nil, actor)
  if mag == 0 and reserve == 0 then
    actor.cooldown = 0.20
    if presented then
      self:notify(Text.get('no_ammo'), 2)
      Presentation.cue(self, 'empty')
    end
  end
  return false
end

function Game:switchWeapon(which, who)
  if type(which) ~= 'number' then
    return false
  end
  local actor, presented = commander(self, who)
  if not actor then
    return false
  end
  local def, state = Weapons.inHand(self, which, actor)
  if not def or actor.weapon == which then
    return false
  end
  Reload.cancel(self, actor)
  actor.weapon = which
  actor.cooldown = math.max(0.20, (state.readyAt or 0) - self.elapsed)
  local view = Context.view(self, actor)
  if view then
    view.swapAge, view.shotAge, view.interruptedClose = 0, 10, nil
  end
  -- An action left open finishes its reload when the weapon is back in hand.
  if state.open then
    Reload.start(self, false, actor)
  end
  return true
end

-- Turn the view (the mouse, app/input.lua): yaw and pitch change in radians.
-- The pitch stays within the camera's limit (content/tuning.lua: camera).
-- A command like any other, so a journal replays the aim exactly.
function Game:look(dYaw, dPitch, who)
  local p = commander(self, who)
  if not p then
    return false
  end
  local limit = Tuning.camera.pitchLimit
  p.yaw = p.yaw + (dYaw or 0)
  p.pitch = math.max(-limit, math.min(limit, p.pitch + (dPitch or 0)))
end

function Game:dash(dx, dz, who)
  local player, presented = commander(self, who)
  if
    not player
    or self.state ~= 'playing'
    or self.map
    or self.help
    or player.dash < 1
    or player.dashTimer > 0
    or (Capabilities.attrition(self) and not Resources.ready(player, 'stamina'))
  then
    return false
  end
  player.slideTimer = 0
  player.perfectUsed = false
  -- The afterimage: a blow that would have met the knight where he stood
  -- is dodged perfectly (combat/dodge.lua: afterimage).
  player.dodgeFromX, player.dodgeFromZ = player.x, player.z
  player.dash = player.dash - 1
  player.dashTimer = Rules.movement(player).dashTime
  local body = Rules.playerBody(player)
  if Capabilities.attrition(self) then
    Resources.exert(player, 'stamina', body.rollStamina)
    player.invuln = math.max(player.invuln, body.rollIframes)
    player.cooldown = math.max(player.cooldown, body.rollLock)
  else
    player.invuln = math.max(player.invuln, body.dashIframes)
  end
  local length = math.sqrt(dx * dx + dz * dz)
  if length < 0.1 then
    dx, dz = math.sin(player.yaw), math.cos(player.yaw)
  else
    dx, dz = dx / length, dz / length
  end
  player.dashX, player.dashZ = dx, dz
  -- Its flash and the flecks it throws: feedback/movement_marks.lua.
  if Context.view(self, player) then
    Presentation.call(Context.of(self, player), 'motion.dash', dx, dz)
  end
  if presented then
    Presentation.cue(self, 'dash')
  end
  return true
end
-- Actors joining, leaving and taking control (plan v11 E3, journal v5): each
-- a command, so a journal records it and its replay builds the same pool.
-- record: a knight as a member of the pools section (session/world.lua:
-- memberRecord). False and the reason when it does not join.
function Game:actorJoin(record)
  local knight, reason = Pools.knightFromRecord(self, record)
  if not knight then
    return false, reason
  end
  Pools.add(self, 'knights', knight)
  return true
end
-- A knight leaves the pool (never the controlled one). His missiles,
-- charges and effects stay in the world with his id as their owner.
function Game:actorLeave(id)
  local knight = Bodies.actor(self, id)
  if not knight or knight == Roles.controlled(self) then
    return false
  end
  Context.unwatch(self, knight.id)
  Pools.remove(self, 'knights', knight)
  require('src.combat.observation').invalidateActor(self, knight)
  return true
end
-- Control passes to the knight id: the one losing it lets go of the trigger.
function Game:actorControl(id)
  local knight = Bodies.actor(self, id)
  local previous = Roles.controlled(self)
  if not knight or knight == previous or (knight.hp or 1) <= 0 then
    return false
  end
  require('src.player.intent').clear(self, previous)
  Roles.control(self, knight)
  Context.controlChanged(self, previous, knight)
  -- Both knights' observations end; the others' stay (plan v11 E4).
  local Observation = require('src.combat.observation')
  Observation.invalidateActor(self, previous)
  Observation.invalidateActor(self, knight)
  self.view.presentationPrevious = nil
  return true
end

-- A command whose meaning is the mode's (run/modes.lua: ready, retry,
-- closeShop, buy, catalog...): the application issues it through the session,
-- so a journal records and replays it like any other command.
function Game:act(name, ...)
  -- A command renews the session's views (run/queries.lua, plan v11 E2).
  require('src.run.queries').command(self)
  return Modes.act(self, name, ...)
end

-- These functions receive the session as their first argument, so they can be
-- exposed directly as methods without duplicate forwarding implementations.
Game.shoot = Combat.shoot
-- Cast the ability in a slot (Q casts slot 1): combat/abilities.lua.
Game.cast = require('src.combat.abilities').cast
-- A burst of particles (presentation; nothing without one).
function Game:burst(...)
  return Presentation.call(self, 'burst', ...)
end
Game.damageEnemy = Outcomes.enemy
Game.damagePlayer = Outcomes.player
Game.damageBody = Outcomes.body
Game.recordPlayerDamage = Outcomes.recordPlayerDamage
-- [E] and its prompt mean what the mode says (run/modes.lua: interact, context).
function Game:interact()
  if self.state ~= 'playing' then
    return
  end
  return Execution.perform(self) or Entities.interact(self) or Modes.act(self, 'interact')
end
function Game:context()
  return Execution.prompt(self) or Entities.prompt(self) or Modes.act(self, 'context') or nil
end
Game.update = Simulation.update
Game.simulate = Simulation.step

return Game

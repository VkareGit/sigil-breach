-- Session facade used by the application, combat systems and QA. Construction
-- and player commands live here; simulation, consequences and world triggers
-- have separate owners. Public methods keep one stable entry point.
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
local Classic = require('src.content.classic')
local Fields = require('src.session.fields')
local Game = {}
Game.__index = Game
-- Presentation state lives in g.view (session/fields.lua): reading or writing
-- one of its fields on the session itself is a mistake, reported at once.
setmetatable(Game, {
  __index = function(_, key)
    if Fields.viewOwner(key) then
      error('session.' .. key .. ' is presentation state: use session.view.' .. key, 2)
    end
  end,
})
function Game.__newindex(session, key, value)
  if Fields.viewOwner(key) then
    error('session.' .. key .. ' is presentation state: use session.view.' .. key, 2)
  end
  rawset(session, key, value)
end

function Game.new(mode, mapId)
  local g = setmetatable(State.new(mode, mapId), Game)
  Feel.init(g)
  -- Keep the classic fixture construction before Descent initialization:
  -- archetype initialization consumes seeded randomness used by replays/QA.
  -- The classic trial's garrison and supplies belong to its own map.
  g.pickups = {}
  if g.world.mapId == Classic.map then
    for _, entry in ipairs(Classic.garrison) do
      g:spawn(entry[1], entry[2], entry[3])
    end
    for i, supply in ipairs(Classic.supplies) do
      g.pickups[i] = { x = supply.x, z = supply.z, kind = supply.kind, amount = supply.amount }
    end
  end
  -- The session names its mode (run/modes.lua); its policy and progression follow.
  g.mode = Modes.forSession[mode] or 'classic'
  local kind = Modes:get(g.mode)
  if kind.init then
    kind.init(g)
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
  self.enemies[#self.enemies + 1] = enemy
  return enemy
end

function Game:reloadGun()
  if self.reload > 0 or not Weapons.inHand(self) then
    return false
  end
  if Reload.start(self, false) then
    return true
  end
  local mag, reserve = Weapons.ammo(self)
  if mag == 0 and reserve == 0 then
    self.cooldown = 0.20
    self:notify('No ammo / switch weapons or restock at the Ember.', 2)
    Presentation.cue(self, 'empty')
  end
  return false
end

function Game:switchWeapon(which)
  if type(which) ~= 'number' then
    return false
  end
  local def, state = Weapons.inHand(self, which)
  if not def or self.weapon == which then
    return false
  end
  Reload.cancel(self)
  self.weapon, self.view.swapAge = which, 0
  self.cooldown = math.max(0.20, (state.readyAt or 0) - self.elapsed)
  self.view.shotAge = 10
  -- An action left open finishes its reload when the weapon is back in hand.
  if state.open then
    Reload.start(self, false)
  end
  return true
end

-- Turn the view (the mouse, app/input.lua): yaw and pitch change in radians.
-- The pitch stays within the camera's limit (content/tuning.lua: camera).
-- A command like any other, so a journal replays the aim exactly.
function Game:look(dYaw, dPitch)
  local p, limit = self.player, Tuning.camera.pitchLimit
  p.yaw = p.yaw + (dYaw or 0)
  p.pitch = math.max(-limit, math.min(limit, p.pitch + (dPitch or 0)))
end

function Game:dash(dx, dz)
  local player = self.player
  if
    self.state ~= 'playing'
    or self.map
    or self.help
    or player.dash < 1
    or player.dashTimer > 0
  then
    return false
  end
  player.slideTimer = 0
  player.perfectUsed = false
  -- The afterimage: a blow that would have met the knight where he stood
  -- is dodged perfectly (combat/dodge.lua: afterimage).
  player.dodgeFromX, player.dodgeFromZ = player.x, player.z
  player.dash = player.dash - 1
  player.dashTimer = Tuning.dashTime
  player.invuln = math.max(player.invuln, Rules.playerBody().dashIframes)
  local length = math.sqrt(dx * dx + dz * dz)
  if length < 0.1 then
    dx, dz = math.sin(player.yaw), math.cos(player.yaw)
  else
    dx, dz = dx / length, dz / length
  end
  player.dashX, player.dashZ = dx, dz
  -- Its flash and the flecks it throws: feedback/movement_marks.lua.
  Presentation.call(self, 'motion.dash', dx, dz)
  Presentation.cue(self, 'dash')
  return true
end

-- A command whose meaning is the mode's (run/modes.lua: ready, retry,
-- closeShop, buy, catalog...): the application issues it through the session,
-- so a journal records and replays it like any other command.
function Game:act(name, ...)
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
Game.recordPlayerDamage = Outcomes.recordPlayerDamage
-- [E] and its prompt mean what the mode says (run/modes.lua: interact, context).
function Game:interact()
  if self.state ~= 'playing' then
    return
  end
  return Modes.act(self, 'interact')
end
function Game:context()
  return Modes.act(self, 'context') or nil
end
Game.update = Simulation.update
Game.simulate = Simulation.step

return Game

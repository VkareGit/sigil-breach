-- Game modes (State + Strategy): what a session is for and how it moves on.
-- A mode names its progression (called once per simulation step, after the
-- fight). A new mode (the future base / hub) is a new entry; the session
-- asks Modes.of(g) instead of comparing flags in many places.
--   id            registry name
--   init(g)       optional: prepare a new session of this mode
--   construction(g) optional: copied constructor options for journal replay;
--                   init(g, options) owns their validation and persistent state
--   start(g)      leave the menu and begin
--   progress(g, dt)
--   prepared      its painted world loads before it is shown
--   policy        what it allows the simulation (session/capabilities.lua:
--                 freezable, invincible, attrition)
-- What the player's commands and the fight's consequences mean in this mode
-- (plan v5 G2; each optional, a mode without one ignores it; Modes.act):
--   ready(g)            the player is ready (ENTER)
--   retry(g)            again after a death
--   closeShop(g)        leave the Ember's trade
--   buy(g, offerId)     a purchase at the Ember
--   lose(g)             the knight died
--   reward(g, event)    a demon died (EnemyKilled): what the mode gives
--   remaining(g)        demons still to defeat (HUD)
--   catalog(g, id)      a proving-ground catalogue action (targets, stations,
--                       reset, tier, poses...); true when the id was one
-- What the session asks its mode instead of reading the mode's record
-- (g.run, g.testField) itself (each optional):
--   interact(g)         [E] while playing (Game:interact); true when it acted
--   context(g)          the prompt where the knight stands, or nil
--   frozen(g)           a 'freezable' mode: whether time is stopped now
--   invincible(g)       an 'invincible' mode: whether the knight is unhurt now
--   hud(g)              the status bar's data { glyph, wallet, echo,
--                       progress }
--   runView(g), fieldView(g)  read-only views of its run and its proving
--                       ground for the screens (run/mode_views.lua)
--   posed(g)            its targets hold their catalogue pose
-- Its private state (plan v11 E2): one record, the session field named by
-- record ('run' for the chapel, 'testField' for the proving ground,
-- 'modeData', the default, for every other mode). The same hooks keep any
-- of them (each optional): reset(g) back to the start, snapshot(g) the
-- data of its checkpoint, load(g, data) and save(g); a file of its own is a
-- section it declares (storage/save.lua: Save.declare). World and encounter
-- state is not a mode's: the seals are the world's
-- (world/arena.lua), the guardian the encounter's (session/encounter.lua).
-- The application issues the player's ones through the session (Game:act),
-- so the command journal records them.
-- Every session names its mode (g.mode: Game.new, the proving ground). The modes themselves
-- register from run/modes.lua; the session knows only this registry.
local Registry = require('src.core.registry')
local Capabilities = require('src.session.capabilities')
local Maps = require('src.content.maps.index')
local Modes = Registry:new('modes', function(mode, id)
  assert(type(mode.progress) == 'function', 'mode ' .. id .. ' needs progress(g, dt)')
  assert(type(mode.start) == 'function', 'mode ' .. id .. ' needs start(g)')
  assert(type(mode.session) == 'table', 'mode ' .. id .. ' needs a session descriptor')
  Maps:get(mode.session.map)
  assert(
    mode.session.prepare == nil or type(mode.session.prepare) == 'function',
    'mode ' .. id .. ' needs a prepare function'
  )
  assert(
    mode.init == nil or type(mode.init) == 'function',
    'mode ' .. id .. ' needs an init function'
  )
  assert(mode.record == nil or type(mode.record) == 'string', 'mode ' .. id .. ': record is a name')
  assert(
    mode.construction == nil or type(mode.construction) == 'function',
    'mode ' .. id .. ' needs construction(g) for constructor options'
  )
  Capabilities.define(id, mode.policy or {}, mode)
end)
-- The mode a new session is built for (Game.new(kind)): an unknown id is an error.
function Modes.resolve(id)
  id = id or Modes.default
  return id, Modes:get(id)
end
function Modes:unregister(id)
  local removed = Registry.unregister(self, id)
  if removed then
    Capabilities.undefine(id)
  end
  return removed
end
-- The mode of a session.
function Modes.of(g)
  return g.mode and Modes:get(g.mode)
end
-- The private record of the session's mode (Modes contract: record).
function Modes.record(g)
  local mode = Modes.of(g)
  return mode and g[mode.record or 'modeData']
end
-- What a command or a consequence means in the session's mode: the mode's
-- handler name(g, ...), or false when the mode has none.
function Modes.act(g, name, ...)
  local mode = Modes.of(g)
  local handler = mode and mode[name]
  if handler then
    return handler(g, ...)
  end
  return false
end
return Modes

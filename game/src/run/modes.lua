-- Game modes (State + Strategy): what a session is for and how it moves on.
-- A mode names its progression (called once per simulation step, after the
-- fight). A new mode (the future base / hub) is a new entry; the session
-- asks Modes.of(g) instead of comparing flags in many places.
--   id            registry name
--   test(g)       true when the session is in this mode (checked in order)
--   init(g)       optional: prepare a new session of this mode
--   construction(g) optional: copied constructor options for journal replay;
--                   init(g, options) owns their validation and persistent state
--   start(g)      leave the menu and begin
--   progress(g, dt)
--   policy        what it allows the simulation (session/capabilities.lua:
--                 phased, freezable, invincible)
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
--   tier(g)             the tier of a demon spawned now (else g.tier or 1)
--   waveActive(g)       a 'phased' mode: whether its fight is on now
--   frozen(g)           a 'freezable' mode: whether time is stopped now
--   invincible(g)       an 'invincible' mode: whether the knight is unhurt now
--   hud(g)              the status bar's data { glyph, wallet, echo,
--                       progress, fighting }; a mode with none draws the
--                       classic arena's HUD (ui/screens/hud.lua)
--   runView(g), fieldView(g)  read-only views of its run and its proving
--                       ground for the screens (run/mode_views.lua)
--   posed(g)            its targets hold their catalogue pose
--   result(g, out)      what its ending shows (the classic arena's rank)
-- Its private state (plan v11 E2): one record, the session field named by
-- record ('run' for the expedition, 'testField' for the proving ground,
-- 'modeData', the default, for every other mode). The same hooks keep any
-- of them (each optional): reset(g) back to the start, snapshot(g) the
-- data of its checkpoint, load(g, data) and save(g); a file of its own is a
-- section it declares (storage/save.lua: Save.declare). World and encounter
-- state is not a mode's: the seals and the secret are the world's
-- (world/arena.lua), the guardian the encounter's (session/encounter.lua).
-- The application issues the player's ones through the session (Game:act),
-- so the command journal records them.
-- Every session names its mode (g.mode: Game.new, the proving ground); the
-- tests only recognise a hand-made record that names none.
local Runs = require('src.content.runs')
local Registry = require('src.core.registry')
local Presentation = require('src.session.presentation')
local Capabilities = require('src.session.capabilities')
local Descent = require('src.run.descent')
local ClassicMode = require('src.run.classic')
local Encounter = require('src.session.encounter')
local Maps = require('src.content.maps.index')
local Classic = require('src.content.classic')
local Id = require('src.core.id')
local Views = require('src.run.mode_views')
local Pools = require('src.session.world')
local Spawn = require('src.session.spawn')
local Text = require('src.content.text')
-- Every mode opens on the first map of the expedition unless it is told another.
local firstMap = Runs.stage({}).map
local function field()
  return require('src.run.test_field')
end
local Modes = Registry:new('modes', function(mode, id)
  assert(type(mode.progress) == 'function', 'mode ' .. id .. ' needs progress(g, dt)')
  assert(type(mode.start) == 'function', 'mode ' .. id .. ' needs start(g)')
  assert(type(mode.session) == 'table', 'mode ' .. id .. ' needs a session descriptor')
  Id.check(mode.session.world, 'mode ' .. id .. '.session.world')
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
-- The original sessions seeded the classic fixture before initialization.
-- Keep that RNG history explicitly for those sessions; a new mode does not
-- inherit another mode's actors merely by using the same map.
local function prepareClassic(g)
  if g.world.mapId ~= Classic.map then
    return
  end
  for _, entry in ipairs(Classic.garrison) do
    g:spawn(entry[1], entry[2], entry[3])
  end
  for _, supply in ipairs(Classic.supplies) do
    Spawn.make(
      g,
      'pickup',
      { x = supply.x, z = supply.z, kind = supply.kind, amount = supply.amount }
    )
  end
end
-- The proving ground (skirmish and stations). Required lazily: the proving
-- ground uses the expedition's definitions and must not load in a cycle.
Modes:register('field', {
  session = { world = 'descent', map = firstMap, prepare = prepareClassic },
  record = 'testField',
  init = function(g, options)
    field().init(g, options)
  end,
  construction = function(g)
    return field().options(g)
  end,
  reset = function(g)
    return field().reset(g)
  end,
  visit = function(g, previous)
    -- Text keys (content/text.lua).
    g.view.fieldReturnLabel = previous.state == 'menu' and 'return_menu'
      or (previous.state == 'settings' and 'return_settings' or 'return_expedition')
  end,
  worldView = function(g, out)
    return Views.fieldWorld(g, g.run, out, g.testField)
  end,
  tools = function(g, out)
    return Views.fieldTools(g, g.testField, out)
  end,
  objective = Views.fieldObjective,
  runView = function(g, out)
    return Views.run(g, g.run, out)
  end,
  fieldView = function(g, out)
    return Views.field(g, g.testField, out)
  end,
  weaponModifier = function(g)
    return g.run.glyphs or g.run.glyph
  end,
  canTrade = function(g)
    return field().allows(g, 'trade') and g.run.phase == 'preparing'
  end,
  policy = { phased = true, freezable = true, invincible = true, attrition = true },
  attrition = function(g)
    return field().attrition(g)
  end,
  -- Its targets hold the catalogue pose they were given.
  posed = function()
    return true
  end,
  test = function(g)
    return g.testField ~= nil
  end,
  -- The proving ground keeps an expedition record for its shop and waves,
  -- but never its progression: ready, retry and the shop lead back to the field.
  start = function(g)
    return field().close(g)
  end,
  progress = function(g, dt)
    field().update(g, dt)
  end,
  ready = function(g)
    return field().close(g)
  end,
  retry = function(g)
    return field().retry(g)
  end,
  closeShop = function(g)
    return g.state == 'shop' and field().close(g)
  end,
  -- Trial souls: the purchase without the expedition's save.
  buy = function(g, offer)
    return field().allows(g, 'trade') and Descent.trade(g, offer) or false
  end,
  catalog = function(g, id)
    return field().action(g, id)
  end,
  lose = function(g)
    require('src.run.field.chambers').failed(g)
    Encounter.clearThreats(g)
    return false
  end,
  remaining = function(g)
    local alive = 0
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      if e.hp > 0 then
        alive = alive + 1
      end
    end
    return alive
  end,
  -- A gallery pad answers first, then the field (its shop, its prompt).
  interact = function(g)
    if require('src.world.gallery').interact(g) then
      return true
    end
    return field().interact(g)
  end,
  context = function(g)
    return require('src.world.gallery').context(g) or field().context(g)
  end,
  tier = function(g)
    return field().tier(g)
  end,
  waveActive = function(g)
    return field().waveActive(g)
  end,
  frozen = function(g)
    return field().frozen(g)
  end,
  invincible = function(g)
    return field().invincible(g)
  end,
  hud = function(g)
    return field().hud(g)
  end,
})
-- The expedition: waves, shrine, shop and saves.
Modes:register('expedition', {
  session = {
    world = 'descent',
    map = firstMap,
    prepare = prepareClassic,
    requires = { 'ember', 'gates' },
  },
  record = 'run',
  worldView = function(g, out)
    return Views.expeditionWorld(g, g.run, out)
  end,
  objective = function(g)
    return Views.expeditionObjective(g, g.run)
  end,
  runView = function(g, out)
    return Views.run(g, g.run, out)
  end,
  weaponModifier = function(g)
    return g.run.glyphs or g.run.glyph
  end,
  canTrade = function(g)
    return g.run.phase == 'preparing'
  end,
  snapshot = Descent.snapshot,
  load = Descent.load,
  save = Descent.save,
  newRequiresConfirmation = function(g, id)
    return (g.availableSave and g.availableSave.phase ~= 'complete')
      or (id == 'restart' and g.run.phase ~= 'complete')
  end,
  policy = { phased = true },
  test = function(g)
    return g.run ~= nil
  end,
  init = function(g)
    Descent.init(g)
  end,
  start = function(g)
    return Descent.start(g)
  end,
  progress = function(g, dt)
    Descent.update(g, dt)
  end,
  ready = Descent.ready,
  retry = Descent.retry,
  closeShop = Descent.closeShop,
  buy = Descent.buy,
  lose = Descent.lose,
  reward = function(g, event)
    Descent.onKill(g, event.enemy, event.source, event.owner)
  end,
  remaining = Descent.remaining,
  interact = Descent.openShop,
  context = Descent.context,
  tier = Descent.tier,
  waveActive = Descent.waveActive,
  hud = Descent.hud,
})
-- The classic arena (regression coverage): seals, then the Margrave.
Modes:register('classic', {
  session = {
    world = 'classic',
    map = firstMap,
    prepare = prepareClassic,
    requires = { 'portal' },
  },
  record = 'modeData',
  init = ClassicMode.init,
  reset = ClassicMode.init,
  worldView = Views.classicWorld,
  objective = Views.classicObjective,
  result = ClassicMode.result,
  test = function()
    return true
  end,
  start = function(g)
    g.state = 'playing'
    g:notify(Text.get('classic_start'), 4)
    Presentation.capture(g, true)
  end,
  progress = ClassicMode.advance,
  reward = ClassicMode.reward,
  interact = ClassicMode.interact,
  context = ClassicMode.context,
})
-- A session that names no mode (a hand-made record) is the first whose
-- test holds (session/capabilities.lua asks).
Capabilities.recognise = function(g)
  for id, mode in Modes:each() do
    if mode.test and mode.test(g) then
      return id
    end
  end
end
-- The mode a new session is built for (Game.new(kind)).
Modes.aliases = { descent = 'expedition' }
-- Construction and replay accept the registered id. Only historic public
-- names are aliases; an unknown id never silently becomes the classic game.
function Modes.resolve(id)
  id = id or 'classic'
  id = Modes.aliases[id] or id
  return id, Modes:get(id)
end
function Modes:unregister(id)
  local removed = Registry.unregister(self, id)
  if removed then
    Capabilities.undefine(id)
  end
  return removed
end
-- The mode of a session: the one it names (g.mode, how new modes are
-- entered), else the first whose test holds, in registration order (the
-- original three recognise their own flags; classic is the catch-all).
function Modes.of(g)
  if g.mode then
    return Modes:get(g.mode)
  end
  for _, mode in Modes:each() do
    if mode.test and mode.test(g) then
      return mode
    end
  end
end
-- The private record of the session's mode (Modes contract: record).
function Modes.record(g)
  local mode = Modes.of(g)
  return mode and g[mode.record or 'modeData']
end
-- What a command or a consequence means in the session's mode: the mode's
-- handler name(g, ...), or false when the mode has none.
function Modes.act(g, name, ...)
  local handler = Modes.of(g)[name]
  if handler then
    return handler(g, ...)
  end
  return false
end
return Modes

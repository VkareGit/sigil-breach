-- Game modes (State + Strategy): what a session is for and how it moves on.
-- A mode names its progression (called once per simulation step, after the
-- fight). A new mode (the future base / hub) is a new entry; the session
-- asks Modes.of(g) instead of comparing flags in many places.
--   id            registry name
--   test(g)       true when the session is in this mode (checked in order)
--   init(g)       optional: prepare a new session of this mode
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
-- The application issues the player's ones through the session (Game:act),
-- so the command journal records them.
-- Every session names its mode (g.mode: Game.new, the proving ground); the
-- tests only recognise a hand-made record that names none.
local Registry = require('src.core.registry')
local Presentation = require('src.session.presentation')
local Capabilities = require('src.session.capabilities')
local Descent = require('src.run.descent')
local Interactions = require('src.session.interactions')
local Encounter = require('src.session.encounter')
local function field()
  return require('src.run.test_field')
end
local Modes = Registry:new('modes', function(mode, id)
  assert(type(mode.progress) == 'function', 'mode ' .. id .. ' needs progress(g, dt)')
  assert(type(mode.start) == 'function', 'mode ' .. id .. ' needs start(g)')
  Capabilities.define(id, mode.policy or {}, mode)
end)
-- The proving ground (skirmish and stations). Required lazily: the proving
-- ground uses the expedition's definitions and must not load in a cycle.
Modes:register('field', {
  policy = { phased = true, freezable = true, invincible = true },
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
    return field().reset(g)
  end,
  closeShop = function(g)
    return g.state == 'shop' and field().close(g)
  end,
  -- Trial souls: the purchase without the expedition's save.
  buy = Descent.trade,
  catalog = function(g, id)
    return field().action(g, id)
  end,
  lose = function(g)
    Encounter.clearThreats(g)
    return false
  end,
  remaining = function(g)
    local alive = 0
    for _, e in ipairs(g.enemies) do
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
    Descent.onKill(g, event.enemy, event.source)
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
  test = function()
    return true
  end,
  start = function(g)
    g.state = 'playing'
    g:notify('Three courts. Three seals. One way out.', 4)
    Presentation.capture(g, true)
  end,
  progress = function(g)
    Interactions.advanceClassic(g)
  end,
  reward = Interactions.classicReward,
  interact = Interactions.classicInteract,
  context = Interactions.classicContext,
})
-- The mode a new session is built for (Game.new(kind)).
Modes.forSession = { descent = 'expedition', classic = 'classic' }
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

-- The bench for working on a blow, on the proving ground only:
--   F3 next blow of the selected demon   F4 strike it now
--   F5 read the creature files again     F6 time 1, 1/2, 1/4, stopped
--   F7 one step of a stopped time
-- Time is the application's: the simulation still advances by whole steps, so a
-- slowed fight is the same fight.
local Archetypes = require('src.content.enemies')
local Bench = require('src.content.field').bench
local Definitions = require('src.session.definitions')
local Pools = require('src.session.world')
local Queries = require('src.session.queries')
local Text = require('src.content.text')
local fixedStep = require('src.core.rate').step
local Tools = {}
local SCALES = Bench.times
local STEP_TICKS = Bench.stepTicks
-- Every creature read again from its file. Its table stays the same one, so the
-- bodies standing here take the new blows; a broken file changes nothing.
function Tools.reloadCreatures(game)
  local fresh = {}
  for _, id in ipairs(Archetypes.creatures) do
    local name = table.concat({ 'src', 'content', 'creatures', id }, '.')
    local before = package.loaded[name]
    package.loaded[name] = nil
    local ok, def = pcall(require, name)
    if not ok then
      package.loaded[name] = before
      return false, tostring(def)
    end
    fresh[id] = def
  end
  for id, def in pairs(fresh) do
    local held = Archetypes[id]
    for key in pairs(held) do
      held[key] = nil
    end
    for key, value in pairs(def) do
      held[key] = value
    end
  end
  for _, e in ipairs(Pools.of(game, 'enemies')) do
    if e.ai ~= 'windup' and e.ai ~= 'strike' then
      e.attackSpec = nil
    end
  end
  -- A deliberate change: what is sealed from now on is the new data.
  Definitions.seal()
  return true
end
local handlers = {}
function handlers.f3(_, game)
  game:act('catalog', 'field_blow_next')
end
function handlers.f4(_, game)
  game:act('catalog', 'field_blow_go')
end
function handlers.f5(_, game)
  local ok, reason = Tools.reloadCreatures(game)
  game:notify(
    ok and Text.get('field_reloaded') or Text.get('field_reload_failed', { reason = reason }),
    4
  )
end
function handlers.f6(app, game)
  app.timeIndex = (app.timeIndex or 1) % #SCALES + 1
  app.timeScale = SCALES[app.timeIndex]
  game:notify(Text.get('field_time', { scale = app.timeScale }), 3)
end
function handlers.f7(app)
  if app.timeScale == 0 then
    app.accumulator = (app.accumulator or 0) + fixedStep * STEP_TICKS
  end
end
function Tools.key(app, key)
  local game = app.game
  local handler = handlers[key]
  if not handler or not game or not Queries.field(game) or game.state ~= 'playing' then
    return false
  end
  handler(app, game)
  return true
end
-- What a frame adds to the clock of the fixed steps.
function Tools.time(app, dt)
  local game = app.game
  if app.timeScale and game and Queries.field(game) then
    return dt * app.timeScale
  end
  return dt
end
return Tools

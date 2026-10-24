-- A new mode is constructed, visited, snapshotted and replayed by the same
-- production paths. The fixture has no expedition or proving-ground record.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(Game)
  local Modes = require('src.run.modes')
  local Queries = require('src.run.queries')
  local Navigation = require('src.app.navigation')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local Journal = require('src.session.journal')
  local Actions = require('src.run.field.actions')
  local Field = require('src.run.test_field')
  local Stations = require('src.run.field.stations')
  local UI = require('src.ui.interface')
  local lines = {}
  local check = Fixtures.checker(lines, 'mode lifecycle: ', 'mode lifecycle: ')
  local fixtureId = 'foundation_probe'
  local function definition()
    return {
      session = { world = fixtureId, map = require('src.content.maps.index').default },
      init = function(g)
        assert(g.run == nil and g.testField == nil and #g.enemies == 0)
        g.modeData = { steps = 0 }
      end,
      start = function(g)
        g.state = 'playing'
      end,
      progress = function(g)
        g.modeData.steps = g.modeData.steps + 1
      end,
      objective = function()
        return 'Fixture objective'
      end,
      worldView = function()
        return { gates = {}, classicSecret = false, paintedPickups = true }
      end,
      snapshot = function(g)
        return { steps = g.modeData.steps }
      end,
      load = function(g, saved)
        g.modeData = { steps = saved.steps }
        return true
      end,
    }
  end
  local oldFocus = UI.focus
  local ok, problem = xpcall(function()
    check(
      'unknown mode is rejected instead of silently becoming classic',
      not pcall(Game.new, 'missing_mode')
    )
    local invalid = definition()
    invalid.session.map = 'missing_map'
    check(
      'invalid constructor map is rejected atomically',
      not pcall(Modes.register, Modes, fixtureId, invalid) and not Modes:has(fixtureId)
    )
    invalid = definition()
    invalid.policy = { phased = true }
    check(
      'a phased mode needs its phase query',
      not pcall(Modes.register, Modes, fixtureId, invalid) and not Modes:has(fixtureId)
    )
    Modes:register(fixtureId, definition())
    local fresh = Game.new(fixtureId)
    check(
      'new mode constructs its own state without classic actors or foreign records',
      fresh.mode == fixtureId
        and fresh.modeData.steps == 0
        and fresh.run == nil
        and fresh.testField == nil
        and #fresh.enemies == 0
    )
    check(
      'legacy descent alias keeps its canonical expedition identity',
      Game.new('descent').mode == 'expedition'
    )
    check(
      'a mode provides presentation without exposing a run record',
      Queries.objective(fresh) == 'Fixture objective'
        and Queries.world(fresh).paintedPickups
        and Queries.tools(fresh) == nil
    )
    fresh.testing = true
    local journal = Journal.record(fresh)
    fresh:start()
    for _ = 1, 12 do
      fresh:update(1 / 120, {})
    end
    Journal.stop(fresh)
    local encoded = Journal.encode(journal)
    local decoded = Journal.decode(encoded)
    local replay = Journal.session(Game, decoded)
    replay.testing = true
    Journal.replay(replay, decoded)
    check(
      'new-mode journal reconstructs and replays through its registry descriptor',
      fresh.modeData.steps > 0
        and not Integrity.difference(Integrity.capture(fresh), Integrity.capture(replay))
    )
    local saved = Modes.act(fresh, 'snapshot')
    fresh.modeData.steps = 0
    check(
      'own checkpoint handlers preserve a mode without expedition state',
      Modes.act(fresh, 'load', saved) and fresh.modeData.steps == saved.steps
    )
    local snapshot = Snapshot.capture(fresh)
    fresh.modeData.steps = 999
    Snapshot.restore(fresh, snapshot)
    check('whole-session memento includes the new mode record', fresh.modeData.steps == saved.steps)

    local resets = 0
    local base = Game.new('classic')
    local app = {
      game = base,
      input = {
        reset = function()
          resets = resets + 1
        end,
      },
      adopt = function(self, game)
        self.game = game
      end,
    }
    local visited = Navigation.enter(app, fixtureId)
    visited:start()
    visited.modeData.steps = 41
    local nested = Navigation.enter(app, 'field')
    check(
      'a nested visit retains two isolated complete sessions',
      app.game == nested
        and Navigation.previous(app) == visited
        and visited ~= base
        and nested.run ~= visited.run
    )
    check(
      'return label is presentation rather than recorded mode data',
      nested.view.fieldReturnLabel == 'BACK TO EXPEDITION' and nested.testField.returnLabel == nil
    )
    check(
      'first return restores the same paused instance and its own state',
      Navigation.back(app)
        and app.game == visited
        and visited.state == 'paused'
        and visited.modeData.steps == 41
    )
    check(
      'second return restores the original instance and empties the stack',
      Navigation.back(app)
        and app.game == base
        and Navigation.previous(app) == nil
        and not Navigation.back(app)
    )
    local before = app.game
    check(
      'invalid navigation target cannot consume a return destination',
      not pcall(Navigation.enter, app, 'missing_mode')
        and app.game == before
        and Navigation.previous(app) == nil
    )
    check('every successful transition resets pending input', resets == 4)

    local field = Game.new('field')
    Modes.act(field, 'visit', { state = 'settings' })
    field.testing = true
    local fieldJournal = Journal.record(field)
    field:act('catalog', 'field_tier')
    Journal.stop(field)
    local reconstructed = Journal.session(Game, fieldJournal)
    reconstructed.testing = true
    Journal.replay(reconstructed, fieldJournal)
    check(
      'a field visited from settings replays without its cosmetic return label',
      not Integrity.difference(Integrity.capture(field), Integrity.capture(reconstructed))
    )
    check(
      'malformed or unknown catalogue references are refused',
      not field:act('catalog', 'field_spawn_missing_1')
        and not field:act('catalog', 'field_spawn_imp_2')
        and not field:act('catalog', 'field_weapon_0')
        and not field:act('catalog', 'field_select_missing')
    )
    check(
      'invalid registered field tool is rejected',
      not pcall(Actions.fixed.register, Actions.fixed, 'field_probe', {})
    )
    Actions.fixed:register('field_probe', {
      run = function(g)
        g.testField.probeUsed = true
        return true
      end,
    })
    check(
      'a registered tool reaches the existing field dispatcher without editing Field',
      field:act('catalog', 'field_probe') and field.testField.probeUsed == true
    )
    Stations:register('fixture_station', {
      name = 'FIXTURE STATION',
      run = function(g)
        g.testField.station = 'fixture_station'
        return true
      end,
    })
    local listed = false
    for _, station in ipairs(Field.catalog.stations) do
      listed = listed or station.id == 'fixture_station'
    end
    check(
      'one new station entry reaches both catalogue and dispatch',
      listed
        and field:act('catalog', 'field_station_fixture_station')
        and field.testField.station == 'fixture_station'
    )
    check(
      'unknown station cannot enter inspection',
      not field:act('catalog', 'field_station_missing')
    )
    local source = Game.new('field')
    check(
      'catalogue summons still open real gates before spawning',
      source:act('catalog', 'field_spawn_imp_1')
        and #source.run.pending == 1
        and #source.enemies == 0
    )
    Field.update(source, require('src.content.waves').portal.glow / 2)
    check('portal is still empty halfway through its authored glow', #source.enemies == 0)
    Field.update(source, require('src.content.waves').portal.glow)
    check(
      'the target arrives after the portal glow',
      #source.run.pending == 0 and #source.enemies == 1
    )
    source:act('catalog', 'field_spawn_stolas_1')
    Field.reset(source)
    check(
      'field reset clears active targets and pending arrivals together',
      #source.run.pending == 0
        and #source.enemies == 0
        and #source.hazards == 0
        and #source.bullets == 0
        and #source.charges == 0
    )
  end, debug.traceback)
  Actions.fixed:unregister('field_probe')
  Stations:unregister('fixture_station')
  Modes:unregister(fixtureId)
  UI.focus = oldFocus
  assert(ok, problem)
  return lines
end
return Tests

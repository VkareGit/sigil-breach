-- Public scope is instance data, not a deleted executor or a hidden button.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(Game)
  local Field = require('src.run.test_field')
  local Modes = require('src.run.modes')
  local Navigation = require('src.app.navigation')
  local Commands = require('src.app.commands')
  local Release = require('src.app.release')
  local Integrity = require('src.session.integrity')
  local Journal = require('src.session.journal')
  local Snapshot = require('src.session.snapshot')
  local Queries = require('src.run.queries')
  local UI = require('src.ui.interface')
  local lines = {}
  local check = Fixtures.checker(lines, 'field access: ', 'field access: ')
  local function fresh()
    local g = Game.new('field', nil, Release.sessionOptions.field)
    g.testing = true
    return g
  end
  local g = fresh()
  check('an empty field reports no targets from the dormant wave queue', Queries.remaining(g) == 0)
  local target = g:spawn('imp', 16, 22)
  check('the public target count follows live bodies', Queries.remaining(g) == 1)
  target.hp = 0
  check('a fallen body is no longer a live target', Queries.remaining(g) == 0)
  Field.reset(g)
  local initial = Integrity.capture(g)
  check(
    'blocked catalogue commands are rejected without changing the session',
    not g:act('catalog', 'field_shop') and not Integrity.difference(initial, Integrity.capture(g))
  )
  check(
    'owner APIs refuse unavailable tools too',
    not Field.shop(g) and not Integrity.difference(initial, Integrity.capture(g))
  )
  local offered = {}
  for _, button in ipairs(UI.controls(g, {})) do
    offered[button.id] = true
  end
  check(
    'actual public controls agree with execution and retain other tools',
    not offered.field_shop
      and offered.field_station_range
      and offered.field_station_physics
      and offered.field_refill
      and offered.field_spawn_boss_1
  )
  local p = g.player
  local shrine = require('src.session.sanctuary').at(g)
  Field.close(g)
  p.x, p.z = shrine.x, shrine.z
  local before = Integrity.capture(g)
  check(
    'the Ember interaction does not enter trade',
    not Field.interact(g) and not Integrity.difference(before, Integrity.capture(g))
  )
  g:act('ready')
  check(
    'ready remains free combat without queueing a wave',
    g.state == 'playing' and not g.testField.trial and #g.enemies == 0 and #g.run.pending == 0
  )
  -- An accidental shop state must not bypass the mode's trade policy.
  g.state = 'shop'
  p.arsenal.exorcist.reserve = 71
  before = Integrity.capture(g)
  check(
    'buy and canTrade remain denied even in a stray shop state',
    not Modes.act(g, 'canTrade')
      and not g:act('buy', 'ammo')
      and not Integrity.difference(before, Integrity.capture(g))
  )
  g:act('catalog', 'field_reset')
  check(
    'full reset retains public availability',
    not Field.allows(g, 'trade') and g.state == 'field_catalog'
  )
  local options = { features = { trade = false } }
  local owned = Game.new('field', nil, options)
  options.features.trade = true
  check(
    'constructor options are copied rather than aliased',
    not Field.allows(owned, 'trade') and owned.testField.features ~= options.features
  )
  check(
    'invalid feature values fail at construction',
    not pcall(Game.new, 'field', nil, { features = { trade = 'false' } })
  )
  check(
    'misspelled release feature fails instead of silently enabling a tool',
    not pcall(Game.new, 'field', nil, { features = { trades = false } })
  )
  local stations = require('src.run.field.stations')
  check(
    'misspelled station requirement fails at registration',
    not pcall(stations.register, stations, 'invalid_requirement', {
        name = 'station_range',
        feature = 'wave',
        run = function()
          return true
        end,
      }) and not stations:has('invalid_requirement')
  )
  local snapshot = Snapshot.capture(g)
  g.testField.features = nil
  Snapshot.restore(g, snapshot)
  check('snapshot preserves the instance policy', not Field.allows(g, 'trade'))
  g = fresh()
  local journal = Journal.record(g)
  g:act('catalog', 'field_shop')
  g:act('catalog', 'field_reset')
  g:act('catalog', 'field_station_range')
  g:update(1 / 120, {})
  Journal.stop(g)
  local decoded = Journal.decode(Journal.encode(journal))
  local replay = Journal.session(Game, decoded)
  replay.testing = true
  Journal.replay(replay, decoded)
  check(
    'serialized journal reconstructs restrictions and replays the range exactly',
    not Field.allows(replay, 'trade')
      and replay.testField.station == 'range'
      and not Integrity.difference(Integrity.capture(g), Integrity.capture(replay))
  )
  local legacy = Game.new('field')
  legacy.testing = true
  check(
    'library-only field still exercises its real trade',
    Field.shop(legacy) and legacy.state == 'shop'
  )
  local old = Game.new('field')
  old.testing = true
  local oldJournal = Journal.record(old)
  old:act('catalog', 'field_shop')
  Journal.stop(old)
  local oldReplay = Journal.session(Game, oldJournal)
  oldReplay.testing = true
  Journal.replay(oldReplay, oldJournal)
  check(
    'old journals without options retain their unrestricted semantics',
    oldJournal.header.options == nil
      and oldReplay.state == 'shop'
      and not Integrity.difference(Integrity.capture(old), Integrity.capture(oldReplay))
  )
  -- The same generic navigation applies release options before adopt/record.
  local focus, relative = UI.focus, love.mouse.getRelativeMode()
  local menu = Game.new('floor')
  local app = {
    game = menu,
    sessionOptions = Release.sessionOptions,
    settings = {},
    input = { reset = function() end },
    adopt = function(self, session)
      self.game = session
    end,
    saveSettings = function() end,
  }
  local ok, problem = xpcall(function()
    local public = Navigation.enter(app, 'field')
    check(
      'navigation configures the field before making it active',
      not Field.allows(public, 'trade') and Queries.field(public).features.trade == false
    )
    Commands.dispatch(app, 'field_shop')
    check(
      'application commands cannot reopen unavailable catalogue tools',
      app.game == public and public.state == 'field_catalog' and not public.testField.trial
    )
    Commands.dispatch(app, 'new_confirm')
    check(
      'stale confirmation stays in the allowed mode instead of constructing an expedition',
      app.game.mode == 'field' and not Field.allows(app.game, 'trade')
    )
    app.game = menu
    Commands.dispatch(app, 'new_confirm')
    Commands.dispatch(app, 'restart')
    check(
      'stale run commands cannot activate the menu backdrop expedition',
      app.game == menu and menu.state == 'menu'
    )
  end, debug.traceback)
  UI.focus = focus
  love.mouse.setRelativeMode(relative)
  assert(ok, problem)
  return lines
end
return Tests

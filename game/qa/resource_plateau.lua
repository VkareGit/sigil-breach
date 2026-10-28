-- Repeated native renderer ownership through actual world and HUD draws.
-- Counts are structural assertions; Lua memory is reported, not an FPS proxy.
local Plateau = {}
function Plateau.run(Game, renderer, initial, settings, output)
  local Tooling = require('qa.tooling')
  local Renderer = require('src.render.renderer')
  local Gallery = require('src.render.gallery')
  local UI = require('src.ui.interface')
  local Application = require('src.app.application')
  local Navigation = require('src.app.navigation')
  local Context = require('src.session.context')
  local Journal = require('src.session.journal')
  local Pools = require('src.session.world')
  local Tree = require('src.core.data_tree')
  local Queries = require('src.run.queries')
  local lg = love.graphics
  local cycles = tonumber(os.getenv('SIGIL_RESOURCE_CYCLES') or '8')
  assert(
    cycles and cycles % 1 == 0 and cycles >= 3 and cycles <= 32,
    'resource cycles must be an integer from 3 to 32'
  )
  local lines = Tooling.header('REAL RENDERER RESOURCE PLATEAU', false)
  local function snapshot(label)
    collectgarbage('collect')
    collectgarbage('collect')
    local stats = lg.getStats()
    stats.heap = collectgarbage('count')
    lines[#lines + 1] = string.format(
      '%s images=%d canvases=%d texture_MiB=%.3f lua_KiB=%.3f',
      label,
      stats.images,
      stats.canvases,
      stats.texturememory / 1048576,
      stats.heap
    )
    return stats
  end
  local w, h = lg.getDimensions()
  renderer:draw(initial, w, h)
  UI.draw(initial, w, h, settings)
  lg.present()
  snapshot('application_before')
  local baseline, fresh
  local heaps = {}
  local ownership = setmetatable({}, { __mode = 'k' })
  -- A live owner keeps its cached borrowed table, even through collection.
  -- Keeping that borrowed table afterwards must not keep the owner alive.
  local function queryOwnership()
    local owner = Game.new('expedition')
    owner.testing = true
    local borrowed = setmetatable({ Queries.run(owner) }, { __mode = 'v' })
    collectgarbage('collect')
    collectgarbage('collect')
    assert(
      borrowed[1] and Queries.valid(owner, borrowed[1]),
      'live query owner lost its cached view'
    )
    ownership[owner] = 'query ownership regression session'
    return borrowed[1]
  end
  jit.off(queryOwnership, true)
  local retainedBorrow = queryOwnership()
  local function draw(game)
    fresh:draw(game, w, h)
    UI.draw(game, w, h, settings)
    lg.present()
  end
  local function cycleWork(cycle)
    local retained = setmetatable({}, { __mode = 'k' })
    local app = Application.new()
    app.settings = settings
    app.qa.isolated, app.qa.capture = true, true
    local menu = Game.new('expedition')
    menu.testing = true
    fresh = Renderer.new()
    app.renderer = fresh
    while Gallery.pending(fresh) > 0 do
      Gallery.preloadStep(fresh)
    end
    app:adopt(menu)
    draw(menu)
    app:action('field_start')
    local function prepare()
      require('qa.tooling').advanceUntil('resource cycle preparation', function()
        return not app.loading
      end, function(dt)
        app:draw()
        app:update(dt)
      end, 1 / 60, 10)
    end
    prepare()
    local game = app.game
    game.testing = true
    assert(game.mode == 'field' and Navigation.previous(app) == menu, 'field navigation lost menu')
    local journal = Journal.record(game)
    game:act('catalog', 'field_close')
    local knight = Tree.decode(Pools.memberRecord(game.player))
    knight.id = 'resource_observer'
    assert(game:actorJoin(Pools.memberRecord(knight)))
    local actor = Pools.get(game, knight.id)
    assert(Context.watch(game, actor.id), 'resource cycle did not allocate actor view')
    retained[Context.watched(game)[actor.id]] = 'private actor view'
    game:shoot(nil, actor.id)
    game:update(1 / 120, {})
    draw(game)
    draw(Context.of(game, actor))
    Context.unwatch(game, actor.id)
    assert(next(Context.watched(game)) == nil, 'unwatch retained private actor state')
    assert(game:actorLeave(actor.id))
    Journal.stop(game)
    local replay = Journal.session(Game, journal)
    replay.testing = true
    Journal.replay(replay, journal)
    app:adopt(replay)
    prepare()
    draw(replay)
    -- The expedition remains closed in the player menu. Exercise its real
    -- navigation/session lifecycle through the registered mode API, not a
    -- new public menu command or a hand-built fake scene.
    local expedition = Navigation.enter(app, 'expedition')
    expedition.testing = true
    expedition:start()
    expedition:update(1 / 120, {})
    assert(expedition.mode == 'expedition' and expedition.state == 'playing')
    draw(expedition)
    assert(Navigation.back(app) and app.game == replay)
    assert(Navigation.back(app) and app.game == menu and not app.navigation)
    draw(menu)
    snapshot('cycle_' .. cycle .. '_menu_after_field_expedition_replay')
    local mesh = fresh.worldMesh
    fresh:release()
    assert(
      menu.world and not pcall(mesh.getVertexCount, mesh),
      'living menu retained released mesh'
    )
    for _, scope in ipairs({ fresh.resources, fresh.targets, fresh.native }) do
      assert(
        scope.closed and next(scope.held) == nil and next(scope.owned) == nil,
        'released renderer retained a resource scope entry'
      )
    end
    retained[menu], retained[game], retained[replay], retained[expedition] =
      'menu session', 'recorded field session', 'replayed field session', 'expedition session'
    retained[journal], retained[app] = 'stopped journal', 'temporary application'
    -- The caller collects only after this stack (including the journal and
    -- navigation references) has gone, then checks structural reachability.
    fresh = nil
    return retained
  end
  local ok, problem = xpcall(function()
    for cycle = 1, cycles do
      local retained = cycleWork(cycle)
      local after = snapshot('cycle_' .. cycle .. '_released')
      local retainedNames = {}
      for _, name in pairs(retained) do
        retainedNames[#retainedNames + 1] = name
      end
      table.sort(retainedNames)
      for object, name in pairs(retained) do
        ownership[object] = 'cycle_' .. cycle .. ': ' .. name
      end
      lines[#lines + 1] = 'cycle_'
        .. cycle
        .. '_retained_before_JIT_eviction: '
        .. (#retainedNames > 0 and table.concat(retainedNames, ', ') or 'none')
      heaps[#heaps + 1] = after.heap
      baseline = baseline or after
      assert(
        after.images <= baseline.images
          and after.canvases <= baseline.canvases
          and after.texturememory <= baseline.texturememory,
        'native images/canvases/textures grew after renderer release'
      )
    end
  end, debug.traceback)
  if fresh then
    fresh:release()
  end
  assert(ok, problem)
  local function owners()
    local names = {}
    for _, name in pairs(ownership) do
      names[#names + 1] = name
    end
    table.sort(names)
    return names
  end
  local beforeEviction = owners()
  snapshot('all_cycles_before_JIT_eviction')
  lines[#lines + 1] = 'Retained ownership entries before JIT eviction: '
    .. #beforeEviction
    .. ' ('
    .. table.concat(beforeEviction, ', ')
    .. ')'
  -- LuaJIT traces can retain closed command closures. Measure every normal
  -- cycle first; evict compiled code once solely to audit application roots.
  -- A registry/reference cycle survives this eviction and still fails below.
  jit.flush()
  snapshot('ownership_after_single_JIT_eviction')
  local afterEviction = owners()
  lines[#lines + 1] = 'Retained ownership entries after JIT eviction: ' .. #afterEviction
  assert(
    #afterEviction == 0,
    'application retained ownership after JIT eviction: ' .. table.concat(afterEviction, ', ')
  )
  assert(type(retainedBorrow) == 'table', 'query regression did not retain its borrowed table')
  local low, high = math.huge, -math.huge
  for i = math.max(1, #heaps - 2), #heaps do
    low, high = math.min(low, heaps[i]), math.max(high, heaps[i])
  end
  lines[#lines + 1] = string.format(
    'Last 3 released cycles: Lua spread %.3f KiB; native resource counts/texture bytes did not grow beyond the first released warm cycle.',
    high - low
  )
  lines[#lines + 1] =
    'Each cycle drew menu, field, a second actor view, replay and expedition through actual navigation, then returned to menu. Native/heap measurements above use normal JIT behavior throughout all cycles. A single final JIT eviction distinguishes compiled-closure retention from application ownership; no cycle sessions, journals, applications or private views remain afterwards. The query regression keeps a borrowed view alive while its owner is collected. The original application renderer, UI and global weapon presentation remain live intentionally. Lua heap is reported without an arbitrary pass threshold.'
  Tooling.write(output, 'resource-plateau.txt', lines, false)
  for _, line in ipairs(lines) do
    print(line)
  end
end
return Plateau

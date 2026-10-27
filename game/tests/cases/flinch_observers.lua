-- The painted spring belongs to the striker's basis, not the active view.
-- A source change is a presentation discontinuity, never a backwards lean
-- caused by interpolating scalar values expressed in opposite bases.
local Fixtures = require('tests.support.fixtures')
local Context = require('src.session.context')
local Pools = require('src.session.world')
local Flinch = require('src.enemies.flinch')
local Pose = require('src.enemies.pose')
local P = require('src.render.presentation')
local Integrity = require('src.session.integrity')
local Tests = {}
local near = Fixtures.within(1e-10)

local function arena(G)
  local g = G.new('classic')
  g.testing = true
  g:start()
  Pools.clear(g, 'enemies')
  Pools.clear(g, 'pickups')
  local a = g.player
  a.x, a.z, a.yaw = 16, 25, math.pi
  local kit = { 'exorcist', 'judge' }
  local b = g.ecs:create('knight', {
    id = 'flinch_observer_b',
    x = 16,
    z = 15,
    yaw = 0,
    hp = 100,
    loadout = kit,
    arsenal = require('src.content.weapons').arsenal(kit),
    weapon = 1,
    abilities = { 'powder' },
    abilityState = require('src.content.abilities').kit({ 'powder' }),
  }, false)
  assert(g:actorJoin(Pools.memberRecord(b)))
  b = Pools.get(g, b.id)
  Context.watch(g, b.id)
  local e = g:spawn('imp', 16, 20)
  e.dummy, e.spawnAge, e.ai, e.walkSpeed = true, 1, 'idle', 0
  return g, a, b, e
end

local function lean(g, e, observer)
  return Pose.sample(g, e, nil, observer).lean
end

function Tests.pose(G, check)
  local g, a, b, e = arena(G)
  Flinch.begin(g, e, a)
  e.flinchLean, e.flinchLeanV = 0.1, 0.2
  local before = Integrity.capture(g)
  check(
    'opposite observers see opposite sides of one painted spring',
    near(lean(g, e, a), 0.1) and near(lean(g, e, b), -0.1)
  )
  check(
    'pose queries leave the scalar, velocity and source unchanged',
    not Integrity.difference(before, Integrity.capture(g))
  )

  P.capture(g)
  Flinch.begin(g, e, b)
  check(
    'a new opposite source rebases both displacement and velocity',
    near(e.flinchLean, -0.1) and near(e.flinchLeanV, -0.2)
  )
  before = Integrity.capture(g)
  for _, t in ipairs({ 0, 0.5, 1 }) do
    local va, vb = P.sample(g, t), P.sample(Context.of(g, b), t)
    check(
      'source change never inverts the sampled lean at alpha ' .. t,
      near(lean(va, va.enemies[1], Context.viewer(va)), 0.1)
        and near(lean(vb, vb.enemies[1], Context.viewer(vb)), -0.1)
    )
  end
  check(
    'sampling two observers changes no simulation field',
    not Integrity.difference(before, Integrity.capture(g))
  )

  -- The original one-observer convention follows the same body. Refreshing
  -- its contact position must not become a new basis or disable smoothing.
  e.flinchLean, e.flinchLeanV = 0.1, 0.2
  P.capture(g)
  b.x = b.x + 1
  Flinch.begin(g, e, b)
  check(
    'a moving existing source keeps the exact scalar and velocity',
    e.flinchLean == 0.1 and e.flinchLeanV == 0.2
  )
  e.flinchLean = 0.2
  for _, t in ipairs({ 0, 0.5, 1 }) do
    local view = P.sample(Context.of(g, b), t)
    check(
      'same-source interpolation keeps the original convention at alpha ' .. t,
      near(lean(view, view.enemies[1], Context.viewer(view)), 0.1 + 0.1 * t)
    )
  end

  -- Anonymous impacts retain a concrete origin too. Their basis changes
  -- when that origin moves, even though both source ids are nil.
  Flinch.begin(g, e, { x = 16, z = 25 })
  e.flinchLean, e.flinchLeanV = 0.1, 0.2
  P.capture(g)
  Flinch.begin(g, e, { x = 16, z = 15 })
  for _, t in ipairs({ 0, 0.5, 1 }) do
    local view = P.sample(g, t)
    check(
      'anonymous contact change never inverts the lean at alpha ' .. t,
      near(lean(view, view.enemies[1], Context.viewer(view)), 0.1)
    )
  end

  -- Death uses the killing blow's saved side in the same source basis;
  -- querying another observer must not rewrite the corpse response.
  Flinch.begin(g, e, a)
  e.hp, e.deathTime = 0, 0.1
  e.deathResponse = { strength = 0.5, side = 1 }
  before = Integrity.capture(g)
  local fromA = lean(g, e, a)
  local opposite = { x = 16, z = 15 }
  check(
    'the corpse collapse projects its saved side for opposite observers',
    fromA < 0 and near(lean(g, e, opposite), -fromA)
  )
  check(
    'corpse presentation cannot change its death response',
    not Integrity.difference(before, Integrity.capture(g))
  )
end

-- This path runs with the suite's real GPU renderer, not a draw stub. The
-- headless probe exercises pose/sampling separately; it never claims a draw.
function Tests.draw(G, renderer, check)
  local g, a, b, e = arena(G)
  Flinch.begin(g, e, a)
  e.flinchLean, e.flinchLeanV = 0.1, 0.2
  P.capture(g)
  Flinch.begin(g, e, b)
  local before = Integrity.capture(g)
  local lg = love.graphics
  local canvas = lg.newCanvas(1280, 720)
  local ownPresent, present = rawget(renderer, 'present'), renderer.present
  renderer.present = function(self, shown, w, h)
    lg.setCanvas(canvas)
    lg.origin()
    lg.clear(0, 0, 0, 1)
    return present(self, shown, w, h)
  end
  lg.push('all')
  local ok, problem = xpcall(function()
    for _, t in ipairs({ 0, 0.5, 1 }) do
      for _, observer in ipairs({ a, b, b, a }) do
        renderer:draw(P.sample(Context.of(g, observer), t), 1280, 720)
      end
    end
  end, debug.traceback)
  lg.pop()
  renderer.present = ownPresent
  canvas:release()
  assert(ok, problem)
  check(
    'drawing both observers in both orders leaves the entire simulation unchanged',
    not Integrity.difference(before, Integrity.capture(g))
  )
end

function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'flinch-observers: ', 'flinch-observers: ')
  Tests.pose(G, check)
  Tests.draw(G, renderer, check)
  return lines
end
return Tests

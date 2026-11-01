-- Plan v5 G2: the engine ready for more maps and modes. A map whose floor
-- stands higher fights exactly like Limbo shifted up; distance fields are
-- shared and identical; the modes answer the player's commands; the keys of
-- play are data; the collector settles at transitions.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'engine: ', 'engine: ')
  local within = Fixtures.within(1e-9)
  local Maps = require('src.content.maps.index')
  local World = require('src.world.arena')
  local B = require('src.combat.ballistics')
  local Tuning = require('src.content.tuning')
  local Modes = require('src.run.modes')
  local Field = require('src.run.test_field')

  -- A copy of Limbo with its floor 0.6 m higher.
  local raised = {}
  for k, v in pairs(Maps:get('floor')) do
    raised[k] = v
  end
  raised.id, raised.floor = 'raised_floor', 0.6
  Maps:register('raised_floor', raised)
  local ok, err = pcall(function()
    local function arena(mapId)
      local g = G.new('floor', mapId)
      g.testing = true
      g:start()
      g.enemies, g.bullets, g.hazards, g.pickups = {}, {}, {}, {}
      g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 25, math.pi, 0
      return g
    end
    local flat, high = arena('floor'), arena('raised_floor')
    local _, flatEye = B.origin(flat)
    local _, highEye = B.origin(high)
    check('the eye stands on the ground of its map', within(highEye - flatEye, 0.6))
    local down = B.world(high.world, 16, highEye, 25, 0, -1, 0, 10)
    check(
      'a shot straight down meets the raised floor',
      within(down, highEye - 0.6 - Tuning.floorSurface)
    )
    -- The same volley at the same demon on both floors.
    local results = {}
    for i, g in ipairs({ flat, high }) do
      local e = g:spawn('imp', 16, 20)
      e.hp, e.maxHp, e.spawnAge = 10000, 10000, 1
      g.player.pitch = -0.05
      g.player.weapon = 2
      g:shoot()
      results[i] = { hp = e.hp, part = g.view.shotReport and g.view.shotReport.rays[1].part }
    end
    check(
      'a shot meets the same part and deals the same wound on a raised floor',
      results[1].part ~= nil
        and results[1].part == results[2].part
        and results[1].hp == results[2].hp
    )
    -- A powder charge thrown flat comes to rest on its own floor.
    local rest = {}
    for i, g in ipairs({ flat, high }) do
      g.enemies = {}
      g.player.pitch = -0.3
      g:cast(1)
      local charge = g.charges[1]
      for _ = 1, 110 do
        g:update(1 / 120, {})
      end
      rest[i] = charge.y
    end
    check('a thrown charge rests on the raised floor', within(rest[2] - rest[1], 0.6, 1e-6))
  end)
  Maps:unregister('raised_floor')
  assert(ok, err)

  -- Distance fields: one shared field per goal while the map is unchanged.
  local w = World.new('floor')
  local a = World.flow(w, 16, 25)
  local b = World.flow(w, 16.2, 24.9)
  local same = a == b
  World.rebuild(w)
  local c = World.flow(w, 16, 25)
  local equal = c ~= a
  for id, d in pairs(a) do
    equal = equal and c[id] == d
  end
  for id in pairs(c) do
    equal = equal and a[id] ~= nil
  end
  check('a distance field is shared within a goal cell and rebuilt with the map', same and equal)

  -- The modes answer the commands; a mode without an answer refuses.
  local field = Field.new(G)
  field.testing = true
  Field.close(field)
  field:spawn('imp', 16, 20)
  local classic = Fixtures.arena(G)
  check(
    'the proving ground counts its demons and the plain room has no retry',
    Modes.act(field, 'remaining') == 1 and Modes.act(classic, 'retry') == false
  )

  -- Keys of play are data; ability slots have keys of their own.
  local Bindings = require('src.app.bindings')
  check(
    'every ability slot has a key and Q casts the first',
    Bindings.abilities[1] == 'q' and #Bindings.abilities >= 2
  )

  -- The collector settles and keeps its pacing.
  require('src.app.application').settle()
  local pause = collectgarbage('setpause', Tuning.collector.pause)
  check('a transition settles the collector at its pacing', pause == Tuning.collector.pause)
  return lines
end
return Tests

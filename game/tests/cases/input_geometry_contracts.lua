-- Review regressions: time slicing preserves every actor's intent; prepared
-- geometry belongs to its caller; teleport invalidates only the moved actor.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
local function join(g, id, x, z)
  local Pools = require('src.session.world')
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local kit = { 'exorcist', 'judge' }
  local k = g.ecs:create('knight', {
    id = id,
    x = x,
    z = z,
    yaw = math.pi,
    hp = 100,
    loadout = kit,
    arsenal = Weapons.arsenal(kit),
    weapon = 1,
    abilities = { 'powder' },
    abilityState = Abilities.kit({ 'powder' }),
  }, false)
  assert(g:actorJoin(Pools.memberRecord(k)))
  return Pools.get(g, id)
end
local function arena(G, mode)
  local Pools = require('src.session.world')
  local g = G.new(mode or 'floor')
  g.ephemeral = true
  g:start()
  Pools.clear(g, 'enemies')
  Pools.clear(g, 'pickups')
  g.player.x, g.player.z, g.player.yaw = 16, 25, math.pi
  return g
end
function Tests.input(G, check)
  local Simulation = require('src.session.simulation')
  local Serialize = require('src.core.serialize')
  local Journal = require('src.session.journal')
  local Integrity = require('src.session.integrity')
  local Pools = require('src.session.world')
  local sample = {
    dash = true,
    forward = 0.3,
    custom = 'preserved',
    actors = {
      other = { forward = 1, slide = true, dash = true, custom = 'actor preserved' },
    },
  }
  local original, steps = Serialize.encode(sample), {}
  Simulation.update({
    simulate = function(_, dt, input)
      steps[#steps + 1] = { dt = dt, input = input }
    end,
  }, 1 / 30, sample)
  local same = #steps == 4 and steps[1].input == sample
  for i = 2, #steps do
    local input = steps[i].input
    local other = input.actors and input.actors.other
    same = same
      and not input.dash
      and input.forward == sample.forward
      and input.custom == sample.custom
      and other
      and other.forward == 1
      and other.custom == sample.actors.other.custom
      and not other.dash
      and not other.slide
  end
  check('substeps keep all held fields and consume every actor edge only once', same)
  check(
    'substeps never mutate the caller input or nested actor records',
    Serialize.encode(sample) == original
  )

  local function moving()
    local g = arena(G)
    join(g, 'other', 20, 25)
    return g
  end
  for _, edge in ipairs({ 'none', 'dash', 'slide' }) do
    for _, who in ipairs({ 'controlled', 'other' }) do
      local coarse, fine = moving(), moving()
      local input = { forward = 0.4, actors = { other = { forward = 0.7 } } }
      if edge ~= 'none' then
        local own = who == 'other' and input.actors.other or input
        own[edge] = true
      end
      local log = Journal.record(coarse)
      coarse:update(1 / 30, input)
      Journal.stop(coarse)
      fine:update(1 / 120, input)
      for _ = 2, 4 do
        fine:update(1 / 120, { forward = 0.4, actors = { other = { forward = 0.7 } } })
      end
      local equal = true
      for _, id in ipairs({ 'knight1', 'other' }) do
        local a, b = Pools.get(coarse, id), Pools.get(fine, id)
        for _, key in ipairs({ 'x', 'z', 'vx', 'vz', 'dash', 'dashTimer', 'slideTimer' }) do
          equal = equal and math.abs((a[key] or 0) - (b[key] or 0)) < 1e-9
        end
      end
      check('coarse and fine movement agree: ' .. who .. ' ' .. edge, equal)
      local replay = moving()
      Journal.replay(replay, Journal.decode(Journal.encode(log)))
      check(
        'coarse actor input replays exactly: ' .. who .. ' ' .. edge,
        not Integrity.difference(Integrity.capture(coarse), Integrity.capture(replay))
      )
    end
  end
end
function Tests.geometry(G, check)
  local A = require('src.content.enemies')
  local Creature = require('src.content.defs.creature')
  local profiles = require('src.enemies.hit_volumes').profiles
  local B = require('src.combat.ballistics')
  local O = require('src.combat.observation')
  local id = 'contract_volume'
  profiles[id] = {
    shapes = { { id = 'torso', zone = 'torso', x = 0.75, bottom = 0.2, top = 0.8, radius = 0.1 } },
  }
  A[id] = Creature.define({
    extends = A.imp,
    id = id,
    kind = 'imp',
    variant = id,
    appearance = { hit = 'volumes', anatomy = id },
  })
  local ok, reason = xpcall(function()
    local g = arena(G)
    local e = g:spawn(id, 16, 20)
    e.dummy, e.spawnAge = true, 1
    local a, b = g.player, join(g, 'other', 16, 10)
    local first = B.prepare(g, a, {})
    local original, shape = first[1].volumes, first[1].volumes[1]
    local x, z = shape.x, shape.z
    local second = B.prepare(g, b, {})
    check(
      'two prepared observers own separate volume arrays and shapes',
      original ~= second[1].volumes
        and shape ~= second[1].volumes[1]
        and shape.x == x
        and shape.z == z
        and second[1].volumes[1].x ~= x
    )
    local saved = O.capture(g, g, a)
    B.prepare(g, b, second)
    local savedX = saved.bodies[1].volumes[1].x
    B.prepare(g, a, first)
    check(
      'preparing again reuses the caller volumes without changing other observers',
      first[1].volumes == original
        and first[1].volumes[1] == shape
        and saved.bodies[1].volumes[1].x == savedX
    )
    local usual = B.prepare(g, a)
    local usualVolumes, usualShape = usual[1].volumes, usual[1].volumes[1]
    B.prepare(g, a)
    check(
      'the usual shot scratch reuses volume arrays and shapes',
      usual[1].volumes == usualVolumes and usual[1].volumes[1] == usualShape
    )
    local fixed = {
      {
        id = 'test-body',
        zone = 'torso',
        material = 'flesh',
        x = 16,
        z = 20,
        radius = 0.5,
        bottom = 0,
        top = 2,
      },
    }
    local d, zone, receipt = B.body(g, e, 16.6, 2.15, 18, 0, 0, 1, 4, fixed, nil, 0.2)
    local expected = 2 - math.sqrt((0.5 + math.sqrt(0.2 ^ 2 - 0.15 ^ 2)) ^ 2 - 0.6 ^ 2)
    check(
      'finite projectile reaches explicit volume at rounded rim',
      d
        and math.abs(d - expected) < 2e-7
        and zone == 'torso'
        and receipt.shapeId == 'test-body'
        and receipt.normal[2] > 0.7
    )
    check(
      'same zero-radius ray misses explicit volume',
      not B.body(g, e, 16.6, 2.15, 18, 0, 0, 1, 4, fixed)
    )
    check(
      'explicit volume rejects inflated square corner',
      not B.body(g, e, 16.65, 2.15, 18, 0, 0, 1, 4, fixed, nil, 0.2)
    )
    check(
      'finite volume sweep respects remaining range',
      not B.body(g, e, 16.6, 2.15, 18, 0, 0, 1, 1, fixed, nil, 0.2)
    )
  end, debug.traceback)
  A[id], profiles[id] = nil, nil
  assert(ok, reason)
end
function Tests.teleport(G, check)
  local O = require('src.combat.observation')
  local Intent = require('src.player.intent')
  local Weapons = require('src.content.weapons')
  for _, destination in ipairs({ 'seal', 'shop' }) do
    local g = arena(G, 'field')
    -- Neither destination is the current place; the other knight stays still.
    g.player.x, g.player.z = 16, 20
    local other = join(g, 'other', 20, 25)
    local seen = O.capture(g, g, g.player)
    local foreign = O.capture(g, g, other)
    local command = O.command(seen, g, g.player)
    Intent.queue(g, 'fire', command)
    Intent.queue(g, 'jump')
    local x, z = g.player.x, g.player.z
    local id = destination == 'seal' and ('field_seal_' .. g.world.seals[1].id) or 'field_shop'
    assert(g:act('catalog', id))
    if destination == 'shop' then
      assert(g:act('closeShop'))
    end
    check(
      destination .. ' teleport invalidates only the moved actor observation',
      (g.player.x ~= x or g.player.z ~= z)
        and not O.valid(g, seen, g.player)
        and O.valid(g, foreign, other)
    )
    check(
      destination .. ' teleport drops buffered fire and jump',
      g.player.fireBuffer == 0 and g.player.fireCommand == nil and g.player.jumpBuffer == 0
    )
    local ammo = Weapons.state(g).mag
    check(
      destination .. ' rejects a pre-teleport shot without spending ammunition',
      g:shoot(command) == false and Weapons.state(g).mag == ammo
    )
    check(
      destination .. ' accepts a fresh observation after arrival',
      g:shoot(O.command(O.capture(g, g, g.player), g, g.player)) == true
    )
  end
  local g = arena(G, 'field')
  local seen = O.capture(g, g, g.player)
  g:act('catalog', 'field_seal_missing')
  check('a refused teleport keeps the current observation valid', O.valid(g, seen, g.player))
end
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'input geometry: ', 'input geometry: ')
  Tests.input(G, check)
  Tests.geometry(G, check)
  Tests.teleport(G, check)
  return lines
end
return Tests

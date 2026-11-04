-- Integration proofs of finite attacks: the rendered body need not be a
-- point, a footprint cannot reach every floor, and a delay has an instant.
local Fixtures = require('tests.support.fixtures')
local Spawn = require('src.session.spawn')
local Pools = require('src.session.world')
local Schema = require('src.core.schema')
local Action = require('src.content.defs.action')
local Volumes = require('src.content.defs.area')
local Area = require('src.combat.area_contact')
local Ground = require('src.physics.ground')
local Projectiles = require('src.combat.projectiles')
local Hazards = require('src.enemies.hazards')
local Ranged = require('src.enemies.ranged_kinds')
local Explosives = require('src.combat.explosives')
local Tests = {}
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'attack volume: ', 'attack volume: ')
  local near = Fixtures.within(1e-6)
  local function fresh()
    local g = Fixtures.arena(Game)
    local w = { size = 20, map = {} }
    for z = 1, 20 do
      w.map[z] = {}
      for x = 1, 20 do
        w.map[z][x] = 0
      end
    end
    g.world = w
    local p = g.player
    p.x, p.z, p.hp, p.armor, p.invuln = 10, 10, 100, 0, 0
    return g, p
  end
  -- High small bolts can be ducked. Low bolts and large spheres really do
  -- intersect the same crouched body: no secret immunity for sliding.
  for _, rate in ipairs({ 60, 120, 240 }) do
    for _, case in ipairs({
      { 'low sliding', 1.15, 0.12, 0.43, true },
      { 'high sliding', 1.6, 0.12, 0.43, false },
      { 'high standing', 1.6, 0.12, 0, true },
      { 'large sliding', 1.6, 0.26, 0.43, true },
    }) do
      local g, p = fresh()
      p.crouch = case[4]
      Spawn.make(g, 'projectile', {
        x = 10,
        y = case[2],
        z = 8,
        vx = 0,
        vy = 0,
        vz = 12,
        radius = case[3],
        life = 1,
        packet = { base = 5, impact = 0 },
      })
      for _ = 1, rate / 2 do
        Projectiles.update(g, 1 / rate, p)
      end
      check(case[1] .. ' at ' .. rate .. ' Hz', (p.hp < 100) == case[5])
    end
  end
  local g, p = fresh()
  local e = g:spawn('stolas', 10, 5)
  e.aimX, e.aimZ, e.leapY = 10, 10, 0.4
  local bolt = Action.build({
    id = 'high-test',
    kind = 'bolt',
    range = 10,
    windup = 1,
    speed = 5,
    height = 2.2,
    aimHeight = 1.9,
    radius = 0.18,
    packet = { base = 5, impact = 0 },
  })
  Ranged.bolt.execute(g, e, bolt, 0)
  local b = Pools.of(g, 'projectiles')[1]
  check(
    'airborne muzzle and authored aim height determine the real flight',
    near(b.y, 2.6) and near(b.y + b.vy * ((10 - b.z) / b.vz), 1.9) and b.radius == 0.18
  )
  local Art = require('src.render.hazard_art')
  local Pass = require('src.render.passes.projectiles')
  local paint, size, foot = Art.upright
  Art.upright = function(_, _, y, _, _, scale)
    size, foot = scale, y
  end
  local ok, problem = pcall(Pass.draw, {}, g)
  Art.upright = paint
  assert(ok, problem)
  check(
    'painted projectile core contains the custom physical diameter',
    near(size * require('src.content.art.rites').projectiles.default.core, 0.36)
      and near(foot + size * 0.5, b.y)
  )
  for _, jump in ipairs({ 0.41, 0.43 }) do
    g, p = fresh()
    p.jump = jump
    Hazards.add(g, 10, 10, 0, 1, 0.1, { packet = { base = 5, impact = 0 } })
    Hazards.update(g, 0.01, p)
    check('floor pool height at jump ' .. jump, (p.hp < 100) == (jump < 0.42))
  end
  -- A delayed strike samples the player when the mark expires, not the end
  -- of the step. Same straight trajectory, three update sizes.
  for _, rate in ipairs({ 20, 60, 120 }) do
    for _, leaving in ipairs({ true, false }) do
      g, p = fresh()
      local owner = g:spawn('furfur', 3, 3)
      local h = Spawn.make(g, 'hazard', {
        x = 10,
        z = 10,
        owner = owner.id,
        kind = 'lightning',
        radius = 0.5,
        volume = Schema.copy(Volumes.defaults.lightning),
        delay = 0.02,
        life = 0.2,
        packet = { base = 5, impact = 0 },
      })
      local time = 0
      for _ = 1, math.ceil(0.05 * rate) do
        local previous =
          { x = leaving and 10 + 20 * time or 11.2 - 20 * time, z = 10, jump = 0, crouch = 0 }
        time = time + 1 / rate
        p.x = leaving and 10 + 20 * time or 11.2 - 20 * time
        Hazards.update(g, 1 / rate, previous)
      end
      check(
        'delayed lightning samples its deadline at ' .. rate .. ' Hz / ' .. tostring(leaving),
        h.struck and (p.hp < 100) == leaving
      )
    end
  end
  -- A rising cylinder ends at a solid deck, even when the victim is at the
  -- same x/z. Without the deck, standing inside that band is a real hit.
  g, p = fresh()
  local source = { x = 10, z = 10, radius = 1 }
  local volume = Volumes.defaults.lightning
  p.jump = 3
  check('lightning cannot reach an arbitrarily high target', not Area.test(g, source, volume, p))
  p.jump = 0
  p.crouch = 0.43
  check('ducking does not avoid a column reaching the ground', Area.test(g, source, volume, p))
  g.world.elevations = {}
  g.world.decks = { [10] = { [10] = { { 2, 2.2 } } } }
  p.level = 2.2
  check('a deck blocks the ground column from the room below', not Area.test(g, source, volume, p))
  source.level, p.level = 2.2, 0
  check(
    'a column on the upper floor does not hit through its floor',
    not Area.test(g, source, volume, p)
  )
  source.level, p.level = nil, nil
  g.world.decks = nil
  p.x, p.crouch = 12, 0
  source.radius = 3
  g.world.map[10][11] = 1
  check(
    'stone blocks a landing shock as well as a pool',
    not Area.test(g, source, Volumes.defaults.landing, p)
  )
  -- A jump off a ledge remains in world height while the ground changes.
  g, p = fresh()
  g.world.elevations = { [10] = { [10] = 1 } }
  local before = { x = 10, z = 10, jump = 0, crouch = 0 }
  p.x, p.jump = 12, 0
  local midpoint = Area.sample(g, p, before, 0.5)
  check(
    'pulse interpolation follows world height across floor steps',
    near(Ground.of(g.world, midpoint) + midpoint.jump, 0.5)
  )
  p.x, p.z = 10.1, 10
  check(
    'a pool still reaches feet on its own raised floor',
    Area.test(g, { x = 10, z = 10, radius = 1 }, Volumes.defaults.pool, p)
  )
  -- Designer extension: different finite band, same executor and payload.
  local authored = Schema.copy(require('src.content.enemies').buer.attacks[1])
  authored.pool.volume = { bottom = 1.5, top = 2, sample = 'body', includeRadius = true }
  local custom = Action.build(authored)
  g, p = fresh()
  source = { x = 10, z = 10, radius = 1 }
  check('a raised custom band meets the standing body', Area.test(g, source, custom.pool.volume, p))
  p.crouch = 0.43
  check(
    'the same custom band clears a crouched body',
    not Area.test(g, source, custom.pool.volume, p)
  )
  for _, bad in ipairs({
    { bottom = 2, top = 1, sample = 'body', includeRadius = true },
    { bottom = 0, top = math.huge, sample = 'body', includeRadius = true },
    { bottom = 0, top = 1, sample = 'bodi', includeRadius = true },
  }) do
    authored.pool.volume = bad
    check(
      'invalid finite volume is rejected: ' .. tostring(bad.top) .. '/' .. bad.sample,
      not pcall(Action.build, authored)
    )
  end
  g, p = fresh()
  e = g:spawn('buer', 3, 3)
  e.aimX, e.aimZ = 10, 10
  Ranged.pool.execute(g, e, custom, 0)
  local h = Pools.of(g, 'hazards')[1]
  check('spawned pool retains its real caster even without periodic effects', h.owner == e.id)
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local state, captured = Integrity.capture(g), Snapshot.capture(g)
  h.volume.top = 99
  Snapshot.restore(g, captured)
  check(
    'snapshot owns and restores a hazard volume',
    not Integrity.difference(state, Integrity.capture(g))
      and Pools.of(g, 'hazards')[1].volume.top == 2
  )
  -- Every actor supplies its own pose; controlling a crouched knight cannot
  -- make another standing knight immune to a raised band.
  g, p = fresh()
  p.crouch = 0.43
  local other = g.ecs:create('knight', { x = 10.1, z = 10, hp = 100, armor = 0, invuln = 0 })
  Hazards.add(
    g,
    10,
    10,
    0,
    1,
    0.1,
    { volume = custom.pool.volume, packet = { base = 5, impact = 0 } }
  )
  Hazards.update(g, 0.01, p)
  check('a raised band samples each knight independently', p.hp == 100 and other.hp < 100)
  -- Existing charge uses a spherical 3D pressure sample, never a 2D disc.
  g, p = fresh()
  p.jump = 6
  Explosives.explode(g, {
    action = require('src.content.abilities'):get('powder').action,
    x = 10,
    y = 0.2,
    z = 10,
    owner = p.id,
  })
  check('an explosion below a sufficiently high jump misses', p.hp == 100)
  g, p = fresh()
  g.world.elevations = {}
  g.world.decks = { [10] = { [10] = { { 2, 2.2 } } } }
  p.level = 2.2
  Explosives.explode(g, {
    action = require('src.content.abilities'):get('powder').action,
    x = 10,
    y = 0.2,
    z = 10,
    owner = p.id,
  })
  check('an explosion cannot damage the knight through a solid deck', p.hp == 100)
  return lines
end
return Tests

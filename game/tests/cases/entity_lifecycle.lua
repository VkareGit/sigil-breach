-- Plan v10 V1: entities with a lifecycle. Pools change through the world,
-- creatures are found by id, corpses that are done leave the step for the
-- remains, knights are a pool, and content definitions stay sealed.
local Fixtures = require('tests.support.fixtures')
local Pools = require('src.session.world')
local World = require('src.world.arena')
local Snapshot = require('src.session.snapshot')
local Definitions = require('src.session.definitions')
local Tests = {}
local function ids(list)
  local out = {}
  for i, e in ipairs(list) do
    out[i] = e.id
  end
  return table.concat(out, ',')
end
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'entity lifecycle: ', 'entity lifecycle: ')

  -- Ids, membership and the index.
  local g = Fixtures.arena(Game)
  local made = {}
  for i = 1, 6 do
    made[i] = g:spawn('imp', 10 + i, 20)
  end
  check('a spawned creature is found by its id', Pools.get(g, made[3].id) == made[3])
  check(
    'an id already in the world is refused without changing the pool',
    not pcall(Pools.add, g, 'enemies', { id = made[2].id }) and #Pools.of(g, 'enemies') == 6
  )
  local list = Pools.of(g, 'enemies')
  for i = #list, 1, -1 do
    if i % 2 == 0 then
      Pools.removeAt(g, 'enemies', i)
    end
  end
  check(
    'removal while iterating backwards keeps the others in order',
    ids(Pools.of(g, 'enemies')) == ids({ made[1], made[3], made[5] })
      and Pools.get(g, made[2].id) == nil
      and Pools.get(g, made[5].id) == made[5]
  )
  local removed = Pools.keep(g, 'enemies', function(e)
    return e ~= made[3]
  end)
  check(
    'keep compacts stably and forgets the removed id',
    removed == 1
      and ids(Pools.of(g, 'enemies')) == ids({ made[1], made[5] })
      and Pools.get(g, made[3].id) == nil
  )
  g.enemies = {}
  check('an array replaced outside the world reindexes on lookup', Pools.get(g, made[1].id) == nil)

  -- Knights are a pool; g.player is the controlled one.
  check(
    'the controlled knight is the first of the knights pool and found by id',
    Pools.of(g, 'knights')[1] == g.player
      and Pools.get(g, g.player.id) == g.player
      and g.ecs:query('knight')[1] == g.player
  )

  -- 300 deaths in one encounter: the living pool holds the living only.
  local field = Fixtures.arena(Game)
  local dead = 0
  for z = 11, 23 do
    for x = 4, 28 do
      if dead < 300 and not World.solid(field.world, x, z, 0.5) then
        local body = field:spawn('imp', x, z)
        field:damageEnemy(body, body.hp + 1, 'weapon')
        dead = dead + 1
      end
    end
  end
  local guard = field:spawn('imp', 16, 6)
  guard.awake = false
  local K = require('src.content.combat_defaults').corpse
  local steps = math.ceil((K.visible + 1) * 120)
  for _ = 1, steps do
    field:update(1 / 120, {})
  end
  local enemies, remains = Pools.of(field, 'enemies'), Pools.of(field, 'remains')
  local alive = 0
  for _, e in ipairs(enemies) do
    alive = alive + (e.hp > 0 and 1 or 0)
  end
  check(
    '300 corpses at rest leave the living pool for the remains',
    dead == 300 and #remains == 300 and #enemies == alive and alive == 1
  )
  check(
    'retired corpses stay found by id and in id order',
    Pools.get(field, remains[1].id) == remains[1] and remains[1].id < remains[300].id
  )
  local before = remains[1].x
  for _ = 1, 120 do
    field:update(1 / 120, {})
  end
  check('a retired corpse is no longer stepped', remains[1].x == before)

  -- A snapshot carries the remains and the index follows the restored copy.
  local memento = Snapshot.capture(field)
  Snapshot.restore(field, memento)
  local restored = Pools.of(field, 'remains')
  check(
    'a restored session finds its restored remains by id',
    #restored == 300
      and restored[1] ~= remains[1]
      and Pools.get(field, restored[1].id) == restored[1]
  )

  -- The presented sample reads its own interpolated arrays.
  local Presentation = require('src.render.presentation')
  local shown = Fixtures.arena(Game)
  local body = shown:spawn('imp', 16, 20)
  body.awake = false
  Presentation.capture(shown)
  body.x = body.x + 1
  local sample = Presentation.sample(shown, 0.5)
  local view = Pools.of(sample, 'enemies')[1]
  check(
    'the presentation sample interpolates instead of reading the live pool',
    view ~= body and math.abs(view.x - (body.x - 0.5)) < 1e-9
  )

  -- Sealed definitions: a changed field is reported, a registry may grow.
  Definitions.seal()
  local weapon = require('src.content.weapons').get('exorcist')
  local capacity = weapon.ammo.capacity
  weapon.ammo.capacity = capacity + 1
  local changes = Definitions.changes()
  weapon.ammo.capacity = capacity
  check(
    'a changed definition field is reported with its path',
    #changes == 1 and changes[1]:find('capacity', 1, true) ~= nil
  )
  local Maps = require('src.content.maps.index')
  local fixture = require('qa.data.crowd_map')
  local registered = not Maps:find(fixture.id)
  if registered then
    Maps:register(fixture.id, fixture)
  end
  local grown = #Definitions.changes()
  if registered then
    Maps:unregister(fixture.id)
  end
  check(
    'registering and unregistering content is not a change of a definition',
    grown == 0 and #Definitions.changes() == 0
  )
  Definitions.seal()
  return lines
end
return Tests

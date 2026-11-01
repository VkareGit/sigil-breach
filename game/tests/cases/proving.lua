-- The game's own map, as it is played. Most suites stand in the plain test room, so what only
-- the chapel has is proved here: its data fits its walls, a knight can walk the whole way,
-- and the field works on the same map a player sees.
local Bot = require('qa.souls_bot')
local Copy = require('src.core.schema').copy
local Encounter = require('src.session.encounter')
local F = require('tests.support.fixtures')
local Field = require('src.run.test_field')
local K = require('src.content.pilgrimage')
local Maps = require('src.content.maps.index')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local Shop = require('src.content.shop')
local World = require('src.world.arena')
local T = {}
local TICK = 1 / 120
local function emptied(Game)
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  Encounter.clearStage(g)
  return g
end
-- The knight walks to a spot the way a player would, through the map's own walls.
local function walk(g, x, z, seconds)
  local knight = Bot.walker(Bot.careless)
  for _ = 1, seconds * 120 do
    if math.abs(g.player.x - x) + math.abs(g.player.z - z) < 1 then
      return true
    end
    g:update(TICK, knight(g, {}, x, z))
  end
  return false
end
local function data(check)
  for id, area in K.areas:each() do
    local problems = P.problems(area)
    check('area ' .. id .. ' fits its map: ' .. table.concat(problems, '; '), #problems == 0)
  end
  local function broken(change)
    local area = Copy(K.start())
    change(area)
    return P.problems(area)[1] or ''
  end
  check(
    'a post in a wall is found',
    broken(function(a)
      a.garrison[1].x, a.garrison[1].z = 0.5, 0.5
    end):find('stands in a wall', 1, true)
  )
  check(
    'a creature that does not exist is found',
    broken(function(a)
      a.garrison[1].creature = 'nobody'
    end):find('names no creature', 1, true)
  )
  check(
    'a patrol through a wall is found',
    broken(function(a)
      a.garrison[1].patrol = { { x = 0.5, z = 0.5 } }
    end):find('patrol 1', 1, true)
  )
  check(
    'a fire nobody can wake at is found',
    broken(function(a)
      a.fires[2].x, a.fires[2].z = 0.5, 0.5
    end):find('fire ' .. K.start().fires[2].id, 1, true)
  )
  check(
    'a map that does not exist is found',
    broken(function(a)
      a.map = 'nowhere'
    end):find('no map', 1, true)
  )
  local claims = pcall(K.areas.register, K.areas, 'twin', {
    id = 'twin',
    map = 'proving',
    first = K.start().first,
    fires = K.start().fires,
    garrison = {},
  })
  check('a fire id used twice is refused', not claims)
end
local function journey(check, Game)
  local g = emptied(Game)
  local way = K.start()
  for _, fire in ipairs(way.fires) do
    if fire.id ~= way.first then
      check('the way leads to fire ' .. fire.id, walk(g, fire.x, fire.z + 1, 120))
      check('and it is that fire', P.fireHere(g) == fire)
      g:interact()
      check('it lights', g.run.lit[fire.id] and g.state == 'shop')
      g:act('closeShop')
      Encounter.clearStage(g)
    end
  end
  for _, door in ipairs(way.doors) do
    g.player.x, g.player.z = way.fires[1].x, way.fires[1].z - K.wake
    check('the way leads to door ' .. door.id, walk(g, door.side.x, door.side.z, 120))
    g.player.x, g.player.z = door.side.x, door.side.z
    g:interact()
    check('it opens', g.run.opened[door.id])
    g:interact()
    check('and leads through', g.player.x == door.back.x and g.player.z == door.back.z)
    check('where a knight can stand', not World.solid(g.world, g.player.x, g.player.z, K.clearance))
    g:update(TICK, { forward = 1 })
    check('and move', g.player.z ~= door.back.z or g.player.x ~= door.back.x)
    g.player.x, g.player.z = door.back.x, door.back.z
    g:interact()
    check('and back', g.player.x == door.side.x and g.player.z == door.side.z)
  end
  P.forget()
end
local function posts(check, Game)
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  local way = K.start()
  check('every post is filled', #Pools.of(g, 'enemies') == #way.garrison)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    check(e.post .. ' stands free', not World.solid(g.world, e.x, e.z, e.radius or K.clearance))
  end
  P.forget()
end
local function trade(check, Game)
  local g = emptied(Game)
  g.run.wallet = Shop.maxWallet
  g:interact()
  check('a fire on the real map trades', g.state == 'shop')
  local sold = 0
  for _, offer in ipairs(Shop.offers) do
    if g:act('buy', offer.id) then
      sold = sold + 1
    end
  end
  check('something can be bought after a rest', sold > 0)
  P.forget()
end
local function field(check, Game)
  local g = Field.new(Game, 'proving')
  g:start()
  check('the field opens on the real map', g.world.mapId == 'proving')
  local function settled(title)
    for _ = 1, 240 do
      g:update(TICK, {})
    end
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      if e.hp > 0 and World.solid(g.world, e.x, e.z, 0) then
        check(title .. ': a body stands in a wall', false)
      end
    end
    check(title .. ' runs on the real map', true)
  end
  for _, chamber in ipairs(Maps:get('proving').proving.chambers) do
    Field.reset(g)
    Field.chamber(g, chamber.id, 1)
    settled('chamber ' .. chamber.id)
  end
  Field.reset(g)
  Field.skirmish(g)
  settled('the skirmish')
  Field.reset(g)
  Field.range(g)
  settled('the range')
  Field.reset(g)
  Field.physics(g)
  settled('the physics station')
end
-- What a long session leaves behind stays bounded.
local function limits(check, Game)
  local g = Field.new(Game, 'proving')
  for _ = 1, Pools.remainsKept + 5 do
    Pools.retire(g, g:spawn('imp', 24, 30))
  end
  check('the dead are kept to a limit', #Pools.of(g, 'remains') == Pools.remainsKept)
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'proving: ', 'proving: ')
  limits(check, Game)
  data(check)
  posts(check, Game)
  journey(check, Game)
  trade(check, Game)
  field(check, Game)
  return lines
end
return T

-- Things break by real shots and blasts, ruin changes the world for everything
-- in it, and a reset or a load gives exactly the same world back.
local F = require('tests.support.fixtures')
local Destruction = require('src.combat.destruction')
local Kinds = require('src.content.breakables')
local Ruin = require('src.content.maps.breakables')
local Release = require('src.app.release')
local Ground = require('src.physics.ground')
local Collision = require('src.physics.collision')
local Ballistics = require('src.combat.ballistics')
local Save = require('src.storage.session_save')
local World = require('src.world.arena')
local Navigation = require('src.world.navigation')
local T = {}
local function session(Game)
  local g = Game.new('field', 'proving', Release.sessionOptions.field)
  g.ephemeral, g.state, g.elapsed = true, 'playing', 70
  g.enemies = {}
  return g
end
local function find(g, id)
  for _, def in ipairs(Destruction.list(g.world)) do
    if def.id == id then
      return def
    end
  end
end
-- Aim at a point and pull the trigger through the real weapon path.
local function shoot(g, x, z, tx, ty, tz)
  local p = g.player
  p.x, p.z = x, z
  local dx, dz = tx - x, tz - z
  p.yaw = math.atan2(dx, dz)
  local _, eye = Ballistics.origin(g)
  p.pitch = math.atan2(ty - eye, math.sqrt(dx * dx + dz * dz))
  p.cooldown, p.reload = 0, 0
  require('src.content.weapons').state(g).mag = 2
  return g:shoot()
end
local function snapshot(w)
  local parts = {}
  for z = 1, #w.map do
    parts[#parts + 1] = table.concat(w.map[z])
    for x = 1, #w.map[z] do
      parts[#parts + 1] = Ground.cell(w, x, z)
      parts[#parts + 1] = Ground.decks(w, x, z) and 1 or 0
      parts[#parts + 1] = Collision.top(w.map[z][x], w, x, z)
    end
  end
  return table.concat(parts, ',')
end
local function reachable(w, x0, z0)
  local step = w.stepHeight
  local seen, open = { [z0 * 100 + x0] = true }, { { x0, z0 } }
  while #open > 0 do
    local c = table.remove(open)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local x, z = c[1] + d[1], c[2] + d[2]
      local key = z * 100 + x
      local row = w.map[z]
      if row and row[x] == 0 and not seen[key] then
        if Ground.cell(w, x, z) - Ground.cell(w, c[1], c[2]) <= step + 1e-8 then
          seen[key] = true
          open[#open + 1] = { x, z }
        end
      end
    end
  end
  return function(x, z)
    return seen[z * 100 + x] == true
  end
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'destruction: ', 'destruction: ')
  local g = session(Game)
  local before = snapshot(g.world)
  check('the map places breakables', #Destruction.list(g.world) > 60)
  -- A pier takes real shots and falls.
  local pier = find(g, 'ash-pier-3')
  check('the pier stands where the map has it', g.world.map[pier.cell[2]][pier.cell[1]] == 2)
  local hit = Ballistics.world(g.world, 8, 1.15, 20, -1, 0, 0, 12)
  check('a shot stops at the drawn radius of the pier', math.abs(hit - (3 - 0.62)) < 0.01)
  local high = Ballistics.world(g.world, 8, 7, 20, -1, 0, 0, 12)
  check('and at its drawn height', math.abs(high - (3 - 0.62)) < 0.01)
  local fired = 0
  while not Destruction.broken(g.world, pier.id) and fired < 40 do
    if shoot(g, 8, 20.2, 5, 2, 20) then
      fired = fired + 1
    end
    g:update(1 / 120, {})
  end
  print('MEASURE shots to fell a pier at 3 m: ' .. fired)
  check('a pier falls to a handful of shots ' .. fired, fired >= 2 and fired <= 6)
  local w = g.world
  check('its cell opens', w.map[20][5] == 0)
  check('the rubble rises', Ground.cell(w, 5, 20) > 0)
  check('the aisle behind it closes', Ground.cell(w, 4, 20) > w.stepHeight)
  local hole = pier.hole
  local roof = Ground.decks(w, math.floor(hole.x + 0.5), 20)
  check('the roof it carried is gone', roof == nil)
  check('sky reaches the hole', Ground.ceiling(w, hole.x, 20, 2) == nil)
  check(
    'the outer wall has fallen to its tear',
    pier.tear and Collision.top(1, w, 2, 20) < 7 and Collision.top(1, w, 1, 20) < 7
  )
  local up = Ballistics.world(w, 8, 1.15, 16, -1, 0, 0, 12)
  check('other walls stand', Collision.top(1, w, 2, 12) == 17.5 and up > 0)
  check('banners on it fall with it', Destruction.broken(w, 'ash-banner-3'))
  local keys = 0
  for _ in pairs(w.destruction) do
    keys = keys + 1
  end
  check('the fall reached only what it should ' .. keys, keys < 12)
  -- Save and load the ruin.
  local text = Save.encode(g)
  local values = assert(Save.decode(text))
  local other = session(Game)
  Save.restore(other, values)
  check('a load rebuilds the same ruin', snapshot(other.world) == snapshot(w))
  check('a load keeps what broke', Destruction.broken(other.world, pier.id))
  check('a save of a ruin restores over a ruin', pcall(Save.restore, g, values))
  check('and stays the same', snapshot(g.world) == snapshot(other.world))
  -- Reset gives the map back.
  Destruction.reset(g.world)
  check('a reset gives back the exact world', snapshot(g.world) == before)
  -- Walls protect, bodies crush.
  g = session(Game)
  local urn = find(g, 'ash-urn-1')
  local spare = find(g, 'ash-urn-2')
  shoot(g, urn.from[1] + 3, urn.from[3], urn.from[1], 0.4, urn.from[3])
  check('one shot breaks an urn', Destruction.broken(g.world, urn.id))
  check('and only that urn', not Destruction.broken(g.world, spare.id))
  g.player.x, g.player.z = spare.from[1], spare.from[3]
  g:update(1 / 120, {})
  check('walking through an urn breaks it', Destruction.broken(g.world, spare.id))
  local bench = find(g, 'nave-bench-1')
  g = session(Game)
  shoot(g, 18.6, 13, 21, 0.6, 13)
  check('a wall protects what stands behind it', not Destruction.broken(g.world, bench.id))
  g = session(Game)
  shoot(g, 13, 18, 15, 5, 13.7)
  check('a shot brings a banner down', Destruction.broken(g.world, 'ash-banner-2'))
  g = session(Game)
  local seat = find(g, 'nave-bench-3')
  shoot(g, 24, 20.5, seat.from[1], 0.6, 20.5)
  check('a shot breaks a bench', Destruction.broken(g.world, seat.id))
  local chain = find(g, 'ash-chain-1')
  g = session(Game)
  shoot(g, chain.to[1] + 1, chain.to[3] + 3, chain.to[1], 3, chain.to[3] + 1)
  check('a chain takes a blow', g.world.destruction ~= nil)
  -- Demons feel it; bodies are not left inside what rose.
  g = session(Game)
  local e = g:spawn('imp', 6.2, 20)
  e.hp, e.maxHp = 1000, 1000
  local inside = g:spawn('imp', 4, 20)
  inside.hp, inside.maxHp = 1000, 1000
  g.player.x, g.player.z = 4.5, 21.6
  pier = find(g, 'ash-pier-3')
  Destruction.blast(g, {
    x = 5.6,
    y = 1,
    z = 20,
    owner = g.player.id,
    action = { radius = 4, blast = { base = 100000 } },
  })
  check('a charge at its foot brings a pier down', Destruction.broken(g.world, pier.id))
  check('the fall crushes a demon beside it', e.hp <= 1000 - Kinds.pier.crush.damage + 1)
  for _ = 1, 240 do
    g:update(1 / 120, { strafe = 1 })
  end
  check('a body under the rubble can still move', g.state == 'playing')
  -- Routes follow the ruin, whatever falls.
  g = session(Game)
  local field = Navigation
  check('routes know a geometry revision', field ~= nil and g.world.geometryRevision ~= nil)
  local revision = g.world.geometryRevision
  local view = g.world.viewRevision
  for _, def in ipairs(Destruction.list(g.world)) do
    if Kinds[def.kind].collapses then
      Destruction.blast(g, {
        x = def.cell[1],
        y = 1,
        z = def.cell[2] + 0.7,
        owner = g.player.id,
        action = { radius = 4, blast = { base = 100000 } },
      })
    end
  end
  check('a fall renews routes', g.world.geometryRevision > revision)
  check('a fall does not rebuild the drawn world', g.world.viewRevision == view)
  local walk = reachable(g.world, 24, 36)
  check('with every pier down the first hall stays reachable', walk(10, 20))
  check('and its altar', walk(10, 7))
  check('and the second hall', walk(38, 20))
  check('and its altar too', walk(38, 7))
  check('and the sanctuary', walk(24, 4))
  -- Shapes are pure and one for the fall and the art.
  local tear = { z = 20, half = 3.45, low = 5.4, high = 10.9, seed = 1 }
  check('a tear ends at its edge', Ruin.tearHeight(tear, 24) == math.huge)
  check('a tear is lowest at its middle', Ruin.tearHeight(tear, 20) < Ruin.tearHeight(tear, 23))
  -- A map without breakables pays nothing and rejects nothing.
  local classic = Game.new('floor')
  classic.ephemeral = true
  check('a map without breakables has none', #Destruction.list(classic.world) == 0)
  Destruction.step(classic)
  check('world rebuild still bumps the drawn world', World.rebuild(classic.world) ~= nil)
  return lines
end
return T

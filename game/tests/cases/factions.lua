-- Plan v10 V2: sides, targets and one damage path. Every trial here is made
-- of data only (a faction on a body, a side in the registry, a second
-- knight in the pool); no game code knows any of them.
local Fixtures = require('tests.support.fixtures')
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Target = require('src.enemies.target')
local Factions = require('src.content.factions')
local Hazards = require('src.enemies.hazards')
local Pose = require('src.enemies.pose')
local Tests = {}
-- Simulate up to seconds, or until done() holds.
local function steps(g, seconds, done)
  for _ = 1, math.ceil(seconds * 120) do
    g:update(1 / 120, {})
    if g.state ~= 'playing' or (done and done()) then
      return
    end
  end
end
local function ready(e)
  e.awake, e.attack, e.spawnAge = true, 0, 1
  return e
end
local function knight(g, id, x, z)
  local k = g.ecs:create('knight', { id = id, x = x, z = z, hp = 100, yaw = 0 })
  return k
end
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'factions: ', 'factions: ')

  -- Default relations keep 0.32: demons fight the knight, not each other.
  local g = Fixtures.arena(Game)
  local demon = ready(g:spawn('imp', 16, 21))
  local other = ready(g:spawn('imp', 18, 21))
  check(
    'a demon fights the knight by default, never another demon',
    Target.of(g, demon) == g.player and not Bodies.hostile(g, demon, other)
  )
  Hazards.add(g, other.x, other.z, 0, 1.2, 1, { packet = { base = 9, impact = 0 } })
  local before = other.hp
  g:update(1 / 120, {})
  check("a demons' pool does not hurt a demon standing in it", other.hp == before)

  -- An ally: an ordinary imp on the knight's side, by one field.
  g = Fixtures.arena(Game)
  local ally = ready(g:spawn('imp', 16, 17.5))
  ally.faction = 'knight'
  demon = ready(g:spawn('imp', 16, 16))
  check(
    'a demon chooses the nearer hostile body: the ally, not the far knight',
    Target.choose(g, demon) == ally and Target.of(g, ally) == demon
  )
  -- Each way on its own: the body attacked stands still (a training dummy).
  ally.dummy = true
  local knightHp, allyHp = g.player.hp, ally.hp
  steps(g, 4)
  check(
    "a demon's blows reach the ally through the one damage path; the knight is untouched",
    ally.hp < allyHp and g.player.hp == knightHp
  )
  g = Fixtures.arena(Game)
  ally = ready(g:spawn('imp', 16, 17.5))
  ally.faction = 'knight'
  demon = g:spawn('imp', 16, 16)
  demon.dummy = true
  local demonHp = demon.hp
  steps(g, 4)
  check("the ally's blows reach a demon", demon.hp < demonHp and g.player.hp == knightHp)
  g = Fixtures.arena(Game)
  ally = g:spawn('imp', 16, 18)
  ally.faction, ally.dummy = 'knight', true
  allyHp = ally.hp
  Hazards.add(g, ally.x, ally.z, 0, 1.2, 1, { packet = { base = 9, impact = 0 }, side = 'demons' })
  g:update(1 / 120, {})
  check("a demons' pool hurts an ally standing in it", ally.hp < allyHp)

  -- A rogue: a side of its own, hostile to demons and knights alike.
  local registered = not Factions:find('fixture_rogue')
  if registered then
    Factions:register('fixture_rogue', { hostile = { demons = true, knight = true } })
  end
  g = Fixtures.arena(Game)
  local rogue = ready(g:spawn('imp', 16, 16))
  rogue.faction = 'fixture_rogue'
  demon = g:spawn('imp', 16, 14.5)
  demon.dummy = true
  demonHp = demon.hp
  check('a rogue demon targets the nearer demon', Target.of(g, rogue) == demon)
  steps(g, 3)
  check('a rogue demon hurts another demon', demon.hp < demonHp)
  if registered then
    Factions:unregister('fixture_rogue')
  end

  -- A turret: a missile thrower that does not walk, on the knight's side.
  g = Fixtures.arena(Game)
  local turret = ready(g:spawn('stolas', 16, 22))
  turret.faction, turret.speed = 'knight', 0
  local x, z = turret.x, turret.z
  demon = g:spawn('imp', 16, 15)
  demon.dummy = true
  demonHp, knightHp = demon.hp, g.player.hp
  steps(g, 5)
  check(
    'a turret holds its place and its missiles hurt demons, never the knight',
    math.abs(turret.x - x) < 0.5
      and math.abs(turret.z - z) < 0.5
      and demon.hp < demonHp
      and g.player.hp == knightHp
  )

  -- Two knights: demons choose between them; the other knight is hit and
  -- falls without ending the fight.
  g = Fixtures.arena(Game)
  local second = knight(g, 'knight2', 16, 16)
  local events = { hit = 0, fell = 0 }
  g.bus:on('sim', 'KnightHit', function()
    events.hit = events.hit + 1
  end)
  g.bus:on('sim', 'KnightFell', function()
    events.fell = events.fell + 1
  end)
  demon = ready(g:spawn('imp', 16, 14.5))
  check(
    'the second knight is a pool member found by id and the nearer target',
    Pools.get(g, 'knight2') == second and Target.of(g, demon) == second
  )
  knightHp = g.player.hp
  -- No ward: the first blow that lands decides.
  second.hp, second.armor = 20, 0
  steps(g, 6, function()
    return events.fell > 0
  end)
  check(
    'the second knight is hit and falls; the controlled one and the fight go on',
    events.hit > 0
      and events.fell == 1
      and second.hp == 0
      and g.state == 'playing'
      and g.player.hp == knightHp
  )
  check(
    'after the second knight fell the demon fights the controlled one',
    Target.of(g, demon) == g.player
  )

  -- A perfect dodge belongs to the knight who dodged.
  g = Fixtures.arena(Game)
  second = knight(g, 'knight2', 16, 16)
  demon = ready(g:spawn('imp', 16, 14.5))
  second.invuln, second.dashTimer = 0.2, 0.2
  g:damageBody(second, 10, demon.x, demon.z, { base = 10, impact = 30 }, demon)
  check(
    "a blow during the second knight's dodge is his perfect dodge",
    second.perfectUsed == true and not g.player.perfectUsed and second.hp == 100
  )

  -- Poses are seen from an explicit observer (plan v11 E4): the billboard
  -- turns to it; a camera's viewer on the session is never asked.
  second.x, second.z = 19, 15
  local view = setmetatable({ viewer = second }, { __index = g })
  local own, seen = Pose.sample(view, demon), Pose.sample(g, demon, nil, second)
  check(
    'an explicit observer sees the pose turned to itself; the camera is not asked',
    math.abs(seen.yaw - math.atan2(second.x - demon.x, second.z - demon.z)) < 1e-9
      and math.abs(own.yaw - math.atan2(g.player.x - demon.x, g.player.z - demon.z)) < 1e-9
      and math.abs(seen.yaw - own.yaw) > 1e-3
  )

  -- A side must exist before a creature names it.
  check(
    'a creature naming an unknown side is refused',
    not pcall(require('src.content.defs.creature').define, {
      extends = require('src.content.enemies').get('imp'),
      id = 'fixture_sideless',
      faction = 'fixture_nobody',
    })
  )
  return lines
end
return Tests

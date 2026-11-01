-- Death presentation must describe one resolved kill without changing its
-- damage, momentum, rewards, aim or the RNG stream used by combat and AI.
local Fixtures = require('tests.support.fixtures')
local Tests = {}

function Tests.run(Game)
  -- Rules proven on the encounters they were tuned for (tests/support/v033_encounters.lua).
  Game = require('tests.support.v033_encounters').game(Game)
  local Death = require('src.feedback.death_response')
  local Anim = require('src.enemies.animation')
  local Body = require('src.enemies.body')
  local Audio = require('src.audio.audio')
  local Effects = require('src.feedback.effects')
  local Archetypes = require('src.content.enemies')
  local lines = {}
  local check = Fixtures.checker(lines, 'death response: ', 'death response: ')
  local near = Fixtures.within(1e-8)
  local function fresh(kind)
    local g = Game.new('classic')
    g.testing, g.state, g.enemies, g.pickups = true, 'playing', {}, {}
    g.player.x, g.player.z = 16, 25
    local e = g:spawn(kind or 'imp', 16, 15)
    return g, e
  end
  local muted = Audio.muted
  Audio.muted = true

  local g, e = fresh()
  g:damageEnemy(e, 10, 'weapon')
  check('a survivable wound cannot start the death response', e.hp > 0 and not e.deathResponse)
  g:damageEnemy(e, e.maxHp, 'weapon')
  local score, kills, hp, yaw =
    require('src.session.stats').total(g, 'score'),
    require('src.session.stats').total(g, 'kills'),
    e.hp,
    g.player.yaw
  local contacted = Death.contact(g, e, 90, true, { e.x, 1.1, e.z }, { dx = 0, dz = -1 })
  check(
    'a resolved lethal hit starts one local contact response',
    contacted and e.deathResponse.contacted
  )
  check(
    'kill feedback cannot change rewards, health or aim',
    require('src.session.stats').total(g, 'score') == score
      and require('src.session.stats').total(g, 'kills') == kills
      and e.hp == hp
      and g.player.yaw == yaw
  )
  local count = #g.view.particles
  check(
    'contact particles are small enough to leave the painted death readable',
    count >= 3 and count <= 8
  )
  check(
    'the same resolved contact cannot emit twice',
    not Death.contact(g, e, 90, true, { e.x, 1.1, e.z }) and #g.view.particles == count
  )
  local directed = true
  for _, particle in ipairs(g.view.particles) do
    directed = directed and particle.vz < 0 and particle.material == 'blood'
  end
  check('lethal clots follow projectile travel through the wound', directed)

  g, e = fresh()
  e.hp = 1
  g:damageEnemy(e, 101, 'weapon')
  check('overkill remains visible when the enemy had one HP', e.deathResponse.strength > 0.70)
  local rng = love.math.getRandomState()
  Death.contact(g, e, 80, true, { e.x, 1.1, e.z }, { dx = 0, dz = -1 })
  Death.land(g, e, 2, 0.2)
  check(
    'new pigment responses do not consume gameplay randomness',
    love.math.getRandomState() == rng
  )

  e.fallY, e.fallVY, e.deathTime = 0.10, 0.4, 0
  local first = Anim.pose(g, e)
  e.deathTime = 0.14
  local second, height = Anim.pose(g, e)
  check(
    'the airborne silhouette advances instead of hovering in a frozen frame',
    first == 14 and second == 15 and height == e.fallY
  )
  e.fallY, e.fallVY, e.fallLanded, e.deathTime = 0, 0, 0.16, 0.30
  check('ground contact does not restart the death clock', Anim.pose(g, e) == 16)
  e.deathTime = 0.5
  check(
    'a thrown body reaches the final corpse on the original collapse clock',
    Anim.pose(g, e) == 18
  )

  local settled = true
  for _, kind in ipairs({ 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }) do
    local scene, enemy = fresh(kind)
    enemy.hp, enemy.deathTime = 0, 20
    local frame, hover, lean, sx, sy = Anim.pose(scene, enemy)
    local expected = (kind == 'buer' or kind == 'boss') and 12 or 18
    settled = settled and frame == expected and hover == 0 and lean == 0 and sx == 1 and sy == 1
  end
  check('all six creatures retain a motionless final authored corpse', settled)

  g, e = fresh()
  g:damageEnemy(e, e.maxHp, 'weapon')
  local step = 1 / 120
  for _ = 1, 26 do
    Body.fall(g, e, step)
    e.deathTime = e.deathTime + step
  end
  check(
    'a grounded body does not thud before its painted floor contact',
    not e.deathResponse.landedAt
  )
  Body.fall(g, e, step)
  e.deathTime = e.deathTime + step
  check(
    'a grounded collapse has one delayed contact beat',
    near(e.deathResponse.landedAt, 0.22) and e.deathResponse.contacts == 1
  )
  check(
    'floor response stays local and does not cover the enemy silhouette',
    #g.view.effects == 2 and g.view.effects[1].y <= 0.1 and g.view.effects[1].size < 0.6
  )
  local effects, decals = #g.view.effects, #g.view.decals
  Death.land(g, e, 8, 0.3)
  check(
    'a second landing or rebound cannot duplicate the impact',
    #g.view.effects == effects and #g.view.decals == decals and e.deathResponse.contacts == 1
  )
  check('a stationary collapse reuses the existing blood footprint', #g.view.decals == 1)

  local function thrown(dt)
    local scene, enemy = fresh()
    scene:damageEnemy(enemy, enemy.maxHp, 'weapon')
    enemy.pushX, enemy.pushZ, enemy.fallY, enemy.fallVY = 0, -7, 0, 1.5
    for _ = 1, math.floor(1 / dt + 0.5) do
      Body.fall(scene, enemy, dt)
      enemy.deathTime = enemy.deathTime + dt
    end
    return scene, enemy
  end
  local slow, a = thrown(1 / 30)
  local fast, b = thrown(1 / 120)
  check(
    'the physical fall still has frame-independent travel and contact time',
    near(a.z, b.z, 1e-6) and near(a.fallLanded, b.fallLanded)
  )
  check(
    'airborne landing follows calculated gravity, not an animation timer',
    near(a.fallLanded, 3 / Archetypes.defaults.fall.gravity)
  )
  check(
    'a thrown body leaves its landing mark at the travelled position',
    #slow.view.decals == 2
      and slow.view.decals[2].z < slow.view.decals[1].z - 0.25
      and near(slow.view.decals[2].z, a.deathResponse.landingZ)
  )
  check(
    'first impact is emitted once at both simulation rates',
    a.deathResponse.contacts == 1
      and b.deathResponse.contacts == 1
      and #slow.view.effects == 2
      and #fast.view.effects == 2
  )

  g, e = fresh()
  e.hp = 0
  Death.begin(e, 85, 0, 'weapon')
  e.deathTime = 0
  check(
    'the lethal silhouette retains its lighting during the first beat',
    near(Death.shade(e), 1) and Death.pain(e) > 0
  )
  e.deathTime = 0.3
  check(
    'death settles smoothly into floor shadow without a white flash',
    Death.shade(e) < 1 and Death.shade(e) > 0.72 and Death.pain(e) == 0
  )
  e.deathTime = 5
  check(
    'an old corpse has no residual hit flash or extra light',
    near(Death.shade(e), 0.72, 1e-6) and Death.pain(e) == 0
  )

  local weak, light = fresh()
  light.hp = 0
  Death.land(weak, light, 1, 0.2)
  local heavy, giant = fresh('boss')
  giant.hp = 0
  Death.land(heavy, giant, 3, 0.2)
  check(
    'greater contact energy yields a larger bounded pigment impact',
    heavy.view.effects[1].size > weak.view.effects[1].size and heavy.view.effects[1].size <= 0.66
  )
  Effects.update(heavy, 0.3)
  check(
    'ground pigment expires quickly while the corpse remains',
    #heavy.view.effects == 0 and giant.hp == 0
  )

  Audio.muted = muted
  return lines
end

return Tests

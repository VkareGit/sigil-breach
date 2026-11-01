-- Plan v13 O1-O3: the world stands at its posts, a rest raises it, a death leaves the
-- souls behind, a second death loses them, guardians stay down and the save holds it.
local F = require('tests.support.fixtures')
local K = require('src.content.pilgrimage')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local T = {}
local function session(Game)
  local g = Game.new('pilgrimage')
  g.testing = true
  g:act('start')
  g.state = 'playing'
  return g
end
local function byPost(g, post)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.post == post then
      return e
    end
  end
end
local function run(g, seconds)
  for _ = 1, math.floor(seconds * 120) do
    g:update(1 / 120, {})
  end
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'pilgrimage: ', 'pilgrimage: ')
  P.forget()
  local g = session(Game)
  local p = g.player
  check('the knight wakes at the first fire', P.fireHere(g) ~= nil and P.fireHere(g).id == K.first)
  check('every post and guardian stands', #Pools.of(g, 'enemies') == #K.garrison + #K.guardians)
  check('nobody knows he is here', byPost(g, 'nave_1').awake == false)
  check('no waves, effort is paid', require('src.session.capabilities').attrition(g))
  check('the flask is carried', p.abilityState.flask.uses == 3)
  -- A rest raises the common creatures, heals, refills.
  local victim = byPost(g, 'nave_1')
  g:damageEnemy(victim, victim.hp + 1, 'weapon', nil, p.id)
  check('a kill pays souls', g.run.wallet > 0)
  check('the post is empty', victim.hp <= 0)
  local second = byPost(g, 'nave_2')
  g:damageEnemy(second, second.hp + 1, 'weapon', nil, p.id)
  p.hp, p.abilityState.flask.uses = 20, 0
  local wallet = g.run.wallet
  check('[E] rests at a fire', g:interact() and g.state == 'shop')
  check('it heals', p.hp == 100)
  check('it fills the flask', p.abilityState.flask.uses == 3)
  check('it raises the fallen', byPost(g, 'nave_1').hp > 0)
  check('souls stay', g.run.wallet == wallet)
  check('the fire trades', g:act('buy', 'ammo') ~= nil)
  wallet = g.run.wallet
  g:act('closeShop')
  check('the menu closes', g.state == 'playing')
  -- A body follows, gives up, and goes home.
  local e = byPost(g, 'nave_5')
  e.x, e.z = 24, 39
  e.awake, e.memory, e.visible = true, 1, false
  p.x, p.z = 24, 36
  e.dummy = nil
  run(g, 0.2)
  check('too far from its post it gives up', e.awake == false)
  -- Death: the souls stay.
  p.x, p.z = 24, 30
  p.armor = 0
  g:damagePlayer(500)
  check('he falls', g.state == 'dead')
  check('the souls lie where he fell', g.run.echo and g.run.echo.amount == wallet)
  check('and his purse is empty', g.run.wallet == 0)
  check('he wakes at his fire', g:act('retry') and g.state == 'playing')
  check('at the fire', P.fireHere(g) ~= nil)
  local post = byPost(g, 'nave_1')
  g:damageEnemy(post, post.hp + 1, 'weapon', nil, p.id)
  p.x, p.z = 24, 31
  p.armor = 0
  g:damagePlayer(500)
  check('a second death loses them', g.run.echo.amount < wallet and g.run.echo.z == 31)
  g:act('retry')
  p.x, p.z = g.run.echo.x, g.run.echo.z
  run(g, 0.02)
  check('what lies there is taken back', g.run.echo == nil and g.run.wallet > 0)
  -- A guardian shuts its hall and stays down.
  local boss = byPost(g, 'margrave')
  p.x, p.z = 24, 28
  run(g, 0.05)
  check('a guardian does not notice from outside', not boss.awake and g.run.arena == nil)
  p.x, p.z = 10, 25
  run(g, 0.02)
  check('a guardian opens its fight', g.run.arena == 'margrave')
  p.x = 19
  run(g, 0.02)
  check('it turns', boss.awake)
  check('and shuts its hall', p.x <= 17)
  check('the fire there is not lit', P.fireHere(g) == nil)
  g:damageEnemy(boss, boss.hp + 1, 'weapon', nil, p.id)
  check('it falls for good', g.run.felled.margrave and g.run.arena == nil)
  p.x, p.z = 10, 21
  check('a new fire stands', P.fireHere(g) ~= nil and P.fireHere(g).id == 'west')
  g:interact()
  check('and it does not come back', byPost(g, 'margrave') == nil)
  check('travel leaves its menu', g:act('ready') and g.state == 'playing')
  check('and leads to a lit fire', P.fireHere(g).id ~= 'west')
  -- The door behind the guardian is a wall until it is opened from its side.
  local World = require('src.world.arena')
  check('a door is a wall', World.solid(g.world, 14, 6, 0.3))
  p.x, p.z = 14.5, 4.5
  g:interact()
  check('barred from the far side', World.solid(g.world, 14, 6, 0.3))
  p.x, p.z = 13.5, 7
  g:interact()
  check('it opens from its own', not World.solid(g.world, 14, 6, 0.3))
  -- The save holds the way.
  local saved = session(Game)
  check('a new session wakes at the last fire', saved.run.fire ~= K.first or saved.run.lit.west)
  check('it remembers the fallen', saved.run.felled.margrave)
  check('and does not raise them', byPost(saved, 'margrave') == nil)
  check('an open door stays open', not World.solid(saved.world, 14, 6, 0.3))
  check('the other is still shut', World.solid(saved.world, 34, 6, 0.3))
  local Destruction = require('src.combat.destruction')
  check('a rest settles the ruin', Destruction.settle ~= nil)
  -- The last guardian ends the way.
  local storm = byPost(saved, 'furfur')
  saved:damageEnemy(storm, storm.hp + 1, 'weapon', nil, saved.player.id)
  check('the last guardian ends it', saved.state == 'won')
  P.forget()
  return lines
end
return T

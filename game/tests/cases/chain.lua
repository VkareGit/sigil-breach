-- A chain of kills: one weapon's, ended by a blow or by time, with an edge on that weapon alone.
local Chain = require('src.combat.chain')
local Combat = require('src.combat.combat')
local F = require('tests.support.fixtures')
local K = require('src.content.chain')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local Weapons = require('src.content.weapons')
local T = {}
local TICK = 1 / 120
local function fresh(Game)
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  Weapons.restore(g, { 'exorcist', 'judge' }, nil, g.player)
  g.player.weapon = 1
  return g, g.player
end
-- A kill by a weapon's rounds: the one in hand unless another is named.
local function kill(g, p, weapon)
  local e = g:spawn('imp', p.x + 8, p.z)
  g:damageEnemy(e, e.hp + 1, 'weapon', nil, p.id, weapon or Weapons.idAt(g, nil, p))
end
-- Only a weapon's rounds make a chain, and they make it for their weapon, whatever is in hand.
local function origins(check, Game)
  local g, p = fresh(Game)
  g:switchWeapon(2)
  local Abilities = require('src.content.abilities')
  local action = Abilities:get('powder').action
  for i = 1, 3 do
    local e = g:spawn('imp', p.x + (i - 2) * 0.6, p.z - 6)
    e.hp = 1
  end
  local struck = require('src.combat.explosives').strike(
    g,
    { x = p.x, y = 1, z = p.z - 6, owner = p.id },
    action.radius,
    action.blast,
    'charge'
  )
  check('a charge kills three', struck.kills == 3 and p.shots == 0)
  check('and makes no chain', p.chainCount == nil and Chain.step(p) == nil)
  g, p = fresh(Game)
  kill(g, p)
  kill(g, p)
  local e = g:spawn('imp', p.x, p.z - 1.5)
  e.stun, e.hp = 2, 1
  require('src.combat.rules').addCondition(e, 'exposed', 2)
  p.yaw = math.pi
  check('an execution kills', require('src.combat.execution').perform(g) and e.hp <= 0)
  check('and neither grows nor ends the chain', p.chainCount == 2 and Chain.step(p) ~= nil)
  local exorcist = p.chainWeapon
  g:switchWeapon(2)
  kill(g, p, exorcist)
  check(
    'rounds still in flight count for their weapon',
    p.chainCount == 3 and p.chainWeapon == exorcist
  )
  local bare = Weapons.attack(g, nil, nil, p)
  check(
    'the edge stays on it',
    Chain.edge(p, 'judge', bare) == bare and Chain.edge(p, exorcist, bare) ~= bare
  )
end
local function run(g, seconds)
  for _ = 1, math.ceil(seconds * 120) do
    g:update(TICK, {})
  end
end
-- PLAN Z13: the medal of a kill reads the knight as he was at the kill, not as the
-- presentation finds him after it: a break kill's own heal, a step back.
local function atTheKill(check, Game)
  local Characters = require('src.content.characters')
  local g = F.arena(Game)
  local p = g.player
  local most = Characters.maxHp(p)
  p.hp = most * K.lastRites - 5
  local broken = g:spawn('imp', p.x + 5, p.z)
  broken.stun = 0.2
  g:damageEnemy(broken, broken.hp + 500, 'weapon', nil, p.id)
  check('a break kill heals him above his last rites', p.hp > most * K.lastRites)
  g:update(TICK, {})
  check('and he has them, as he was when it fell', g.view.medal == 'last_rites')
  g = F.arena(Game)
  p = g.player
  local close = g:spawn('imp', p.x + K.pointBlank * 0.6, p.z)
  g:damageEnemy(close, close.hp + 500, 'weapon', nil, p.id)
  p.x = p.x - K.pointBlank * 2
  g:update(TICK, {})
  check(
    'a kill at point blank is told so, though he stepped back after it',
    g.view.medal == 'point_blank'
  )
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'chain: ', 'chain: ')
  atTheKill(check, Game)
  local g, p = fresh(Game)
  kill(g, p)
  check('one kill is no chain', Chain.step(p) == nil)
  kill(g, p)
  check('two are a diptych', Chain.step(p).id == 'diptych')
  g:update(TICK, {})
  check('and it is told', g.view.medal == 'diptych')
  local bare = Weapons.attack(g, nil, nil, p)
  check('a diptych gives no edge', Chain.edge(p, p.chainWeapon, bare) == bare)
  kill(g, p)
  check('three are a triptych', Chain.step(p).id == 'triptych')
  local edged = Chain.edge(p, p.chainWeapon, bare)
  check('its rounds pierce', edged.penetration == bare.penetration + 0.25)
  check('the weapon itself is not changed', bare.penetration < edged.penetration)
  check('another weapon has no edge', Chain.edge(p, 'judge', bare) == bare)
  kill(g, p)
  check('four break guards', Chain.edge(p, p.chainWeapon, bare).impact == bare.impact * 1.25)
  p.hp = 50
  kill(g, p)
  check('five mend a little', Chain.step(p).id == 'polyptych' and p.hp == 58)
  kill(g, p)
  check('each kill past it too', p.hp == 66)
  run(g, K.window + 0.1)
  check('time ends a chain', Chain.step(p) == nil)
  check('and with it the edge', Chain.edge(p, p.chainWeapon, bare) == bare)
  g, p = fresh(Game)
  kill(g, p)
  kill(g, p)
  g:damagePlayer(5)
  check('a blow ends a chain', Chain.step(p) == nil)
  g, p = fresh(Game)
  kill(g, p)
  kill(g, p)
  g:switchWeapon(2)
  kill(g, p)
  check('another weapon begins its own', p.chainCount == 1 and p.chainWeapon == 'judge')
  g, p = fresh(Game)
  kill(g, p)
  kill(g, p)
  kill(g, p)
  local e = Pools.of(g, 'enemies')[1]
  e.x, e.z = p.x, p.z + 3
  p.yaw, p.pitch = 0, 0
  check('the edge reaches a real shot', Combat ~= nil and g:shoot(nil))
  g, p = fresh(Game)
  g.player.x, g.player.z = 24, 9
  kill(g, p)
  kill(g, p)
  p.x, p.z = 24, 9
  g:interact()
  check('a rest ends a chain', Chain.step(p) == nil)
  origins(check, Game)
  P.forget()
  return lines
end
return T

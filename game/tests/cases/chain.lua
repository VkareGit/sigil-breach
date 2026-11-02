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
  return g, g.player
end
local function kill(g, p)
  local e = g:spawn('imp', p.x + 8, p.z)
  g:damageEnemy(e, e.hp + 1, 'weapon', nil, p.id)
end
local function run(g, seconds)
  for _ = 1, math.ceil(seconds * 120) do
    g:update(TICK, {})
  end
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'chain: ', 'chain: ')
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
  P.forget()
  return lines
end
return T

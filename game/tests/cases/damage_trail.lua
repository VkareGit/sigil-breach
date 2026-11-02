-- The damage trail on a target's bar: kept by the view, fed by that view's own blows, aged by
-- the session's clocks. Looking away, another body and another session change nothing of it.
local Encounter = require('src.session.encounter')
local F = require('tests.support.fixtures')
local K = require('src.content.tuning').clocks
local P = require('src.run.pilgrimage')
local T = {}
local function fresh(Game)
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  Encounter.clearStage(g)
  return g, g.player
end
local function run(g, seconds)
  for _ = 1, math.ceil(seconds * 120) do
    g:update(1 / 120, {})
  end
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'damage trail: ', 'damage trail: ')
  local g, p = fresh(Game)
  local weapon = p.loadout[1]
  local a = g:spawn('imp', p.x + 6, p.z - 6)
  local whole = a.hp
  g:damageEnemy(a, 30, 'weapon', nil, p.id, weapon)
  local trail = g.view.damageTrail
  check(
    'the first blow is summed with no target followed before',
    trail and trail.id == a.id and trail.sum == 30
  )
  g:damageEnemy(a, 20, 'weapon', nil, p.id, weapon)
  check('blows add up', g.view.damageTrail.sum == 50)
  check('the pale share starts where the bar was', g.view.damageTrail.shown == whole)
  p.yaw = p.yaw + math.pi
  run(g, K.trailHold + 0.1)
  check('time passes while he looks away', g.view.damageTrail.sum == 0)
  check('and the pale share falls', g.view.damageTrail.shown < whole)
  local b = g:spawn('imp', p.x - 6, p.z - 6)
  g:damageEnemy(b, 10, 'weapon', nil, p.id, weapon)
  check(
    'another body begins its own',
    g.view.damageTrail.id == b.id and g.view.damageTrail.sum == 10
  )
  local other = fresh(Game)
  check('another session keeps its own', other.view.damageTrail == nil)
  check('and leaves this one alone', g.view.damageTrail.sum == 10)
  P.forget()
  return lines
end
return T

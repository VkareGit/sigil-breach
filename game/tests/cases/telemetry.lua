-- Measurement contracts through actual damage and event paths; never tune rewards.
local Fixtures = require('tests.support.fixtures')
local Telemetry = require('src.combat.telemetry')
local Rules = require('src.combat.rules')
local Tests = {}
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'telemetry: ', 'telemetry: ')
  local g = Fixtures.arena(Game)
  Telemetry.reset(g)
  local e = g:spawn('imp', 16, 20)
  e.spawnAge = 1
  g.elapsed = 2
  Telemetry.aware(g, e)
  g.elapsed = 4
  g:damageEnemy(e, 1, 'weapon')
  Telemetry.tick(g, 0.25)
  e.stun, e.knockedDown = 0.3, true
  Telemetry.tick(g, 0.25)
  g.elapsed = 5
  g:damageEnemy(e, e.hp + 1, 'weapon')
  local t = Telemetry.get(g)
  check(
    'first hit and first awareness have distinct kill clocks',
    t.firstHitKillSum == 1 and t.awareKillSum == 3 and t.ttkSum == 5
  )
  check(
    'one kill and one timing sample are counted',
    t.kills == 1 and t.firstHitKillCount == 1 and t.awareKillCount == 1
  )
  check(
    'full health records unused healing, not fictitious HP gain',
    t.healingPotential > 0 and t.healed == 0 and t.healingWasted == t.healingPotential
  )
  check('full health feedback promises no healing', g.view.feedback == 'BREAK KILL  /  HEALTH FULL')
  check(
    'control category totals partition the legacy controlled time',
    math.abs(t.controlTime - t.knockdownTime - t.exposedTime - t.staggerTime - t.flinchTime) < 1e-9
  )
  check('knockdown cause counted without changing healing condition', t.breakKnockdown == 1)
  local mark = Telemetry.copy(g)
  local second = g:spawn('imp', 16, 20)
  g.player.hp = require('src.content.characters').standard().body.hp - 2
  second.stun = 0.1
  g:damageEnemy(second, second.hp + 1, 'weapon')
  local delta = Telemetry.since(g, mark)
  check(
    'partial healing splits potential into gained and unused',
    delta.healed == 2
      and delta.healingWasted > 0
      and math.abs(delta.healingPotential - delta.healed - delta.healingWasted) < 1e-9
  )
  check(
    'partial healing feedback shows the recovered HP',
    g.view.feedback == 'BREAK KILL  /  +2 HEALTH'
  )
  check(
    'one-shot kills contribute zero first-hit duration',
    delta.firstHitKillCount == 1 and delta.firstHitKillSum == 0
  )
  check(
    'reports name potential, actual and wasted healing',
    table.concat(Telemetry.lines(g), '\n'):find('Healing potential', 1, true) ~= nil
  )
  local full = g:spawn('imp', 16, 20)
  g.player.hp, full.stun = 50, 0.1
  g:damageEnemy(full, full.hp + 1, 'weapon')
  check(
    'full reward feedback matches the health delta',
    g.player.hp == 59 and g.view.feedback == 'BREAK KILL  /  +9 HEALTH'
  )
  Telemetry.reset(g)
  check(
    'reset clears body observations and counters',
    next(g.telemetryBodies) == nil and Telemetry.get(g).kills == 0
  )
  -- One decision (combat/rules/balance.lua: offBalance) travels with the kill:
  -- the reward and the measurement read the same causes.
  local events = {}
  g.bus:on('sim', 'EnemyKilled', function(event)
    events[#events + 1] = event
  end)
  local thrall = g:spawn('imp', 16, 20)
  thrall.spawnAge = 1
  -- A Judge round on a thrall: a broken guard and a major wound at once.
  require('src.combat.combat').react(g, thrall, 60, true, { 16, 1, 20 }, nil, 60)
  g:damageEnemy(thrall, thrall.hp + 1, 'weapon')
  local both = events[#events]
  check(
    'a blow that breaks the guard and wounds names both causes',
    both.offBalance and both.causes.guard and both.causes.wound and not both.causes.micro
  )
  local margrave = g:spawn('boss', 16, 18)
  -- Cause attribution at the final death, not exhaustion of its first stock.
  margrave.phaseIndex = #(require('src.content.enemies').boss.phases or { 1 })
  margrave.spawnAge = 1
  Rules.stunBriefly(margrave, 0.035, 'micro')
  g:damageEnemy(margrave, margrave.hp + 1, 'weapon')
  local micro = events[#events]
  check(
    "a boss's micro-stun is its own cause, not a broken guard",
    micro.offBalance and micro.causes.micro and not micro.causes.guard and not micro.causes.trip
  )
  local walker = g:spawn('imp', 18, 20)
  walker.spawnAge = 1
  g:damageEnemy(walker, walker.hp + 1, 'weapon')
  check(
    'an unbroken kill is no break kill and carries no cause',
    events[#events].offBalance == false
      and not events[#events].causes.guard
      and not events[#events].causes.wound
  )
  local t2 = Telemetry.get(g)
  check(
    'telemetry counts the causes it is given (no second interpretation)',
    t2.breakGuard == 1 and t2.breakWound == 1 and t2.breakMicro == 1 and t2.breakOther == 0
  )
  check('a killed body releases its measurement record', next(g.telemetryBodies) == nil)
  local leaving = g:spawn('imp', 15, 20)
  leaving.spawnAge = 1
  Telemetry.tick(g, 0.1)
  local tracked = g.telemetryBodies[leaving.id] ~= nil
  for i = #g.enemies, 1, -1 do
    if g.enemies[i] == leaving then
      table.remove(g.enemies, i)
    end
  end
  Telemetry.tick(g, 0.1)
  check(
    'a body removed alive releases its record at the next step',
    tracked and g.telemetryBodies[leaving.id] == nil
  )
  return lines
end
return Tests

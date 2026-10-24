-- A new clock source and diagnostic painter do not alter creature animation,
-- hit geometry or combat state. Production phase regressions live in animation.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local Phase = require('src.enemies.action_phase')
  local Animation = require('src.enemies.animation')
  local Debug = require('src.render.attack_debug')
  local Schema = require('src.core.schema')
  local Integrity = require('src.session.integrity')
  local lines = {}
  local check = Fixtures.checker(lines, 'action presentation: ', 'action presentation: ')
  local id = 'trial_phase'
  local ok, problem = xpcall(function()
    local g = Fixtures.arena(G)
    local e = g:spawn('imp', 16, 21)
    e.attackSpec = Schema.copy(e.archetype.attacks[1])
    e.attackSpec.kind, e.attackSpec.id, e.attackKind = id, id, id
    e.attackSpec.duration, e.ai, e.phase = 0.8, 'strike', 0.4
    local calls = 0
    Phase.register(id, function(_, spec)
      calls = calls + 1
      return spec.duration * 2
    end)
    local before = Integrity.capture(g)
    check(
      'new kind supplies a duration without modifying creature animation',
      Animation.actionPhase(e) == 0.25 and calls == 1
    )
    check(
      'duration sampling cannot write combat state',
      not Integrity.difference(before, Integrity.capture(g))
    )
    e.windupDuration, e.windup = 0.6, 0.3
    check('windup still follows its own authoritative countdown', Phase.sample(e, 'windup') == 0.5)
    e.recover = 0.4
    check(
      'recovery uses actual remaining time independently of strike duration',
      Phase.sample(e, 'recover') == 0.5
    )
    local watched = Integrity.capture(g)
    local drawn, painterCalls = nil, 0
    Debug.register(id, function(_, game, actor, spec, colors)
      painterCalls = painterCalls + 1
      drawn = { game = game, actor = actor, spec = spec, color = colors.attack }
    end)
    local colors = { attack = { 1, 0, 0 } }
    Debug.draw({}, g, e, colors)
    check(
      'new diagnostic receives the same live action and no duplicated clock',
      painterCalls == 1
        and drawn.game == g
        and drawn.actor == e
        and drawn.spec == e.attackSpec
        and drawn.color == colors.attack
    )
    check(
      'sampling and diagnostics leave combat state unchanged',
      not Integrity.difference(watched, Integrity.capture(g))
    )
    e.ai = 'move'
    Debug.draw({}, g, e, colors)
    check('inactive action cannot paint an active attack diagnostic', painterCalls == 1)
    check('non-action state has no visual action phase', Phase.sample(e) == 0)
    check(
      'invalid duration provider is rejected before it can be used',
      not pcall(Phase.register, 'trial_bad_phase', {})
    )
    check(
      'invalid diagnostic provider is rejected before it can be used',
      not pcall(Debug.register, 'trial_bad_phase', {})
    )
  end, debug.traceback)
  Phase.unregister(id)
  Debug.unregister(id)
  Phase.unregister('trial_bad_phase')
  Debug.unregister('trial_bad_phase')
  assert(ok, problem)
  return lines
end
return Tests

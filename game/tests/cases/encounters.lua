local Fixtures = require('tests.support.fixtures')
local A = require('src.content.enemies')
local Creature = require('src.content.defs.creature')
local Schema = require('src.core.schema')
local Actions = require('src.enemies.actions')
local Selection = require('src.enemies.attack_selection')
local Rules = require('src.combat.rules')
local Snapshot = require('src.session.snapshot')
local Integrity = require('src.session.integrity')
local Stats = require('src.session.stats')
local Tests = {}
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'encounter: ', 'encounter: ')
  local near = Fixtures.within(1e-7)
  local function fresh(kind)
    local g = Fixtures.arena(Game)
    local e = g:spawn(kind or 'furfur', 16, 19)
    e.awake, e.visible, e.spawnAge, e.target = true, true, 2, g.player.id
    return g, e
  end
  local g, e = fresh()
  check(
    'close range chooses a claw, middle a charge, far a marked strike',
    Actions.choose(e, 1.5, 0).id == 'melee'
      and Actions.choose(e, 6, 0).id == 'charge'
      and Actions.choose(e, 10, 0).id == 'lightning'
  )
  local first = Actions.choose(e, 6, 0)
  Selection.committed(e, first)
  check(
    'same distance offers a different attack after commitment',
    Actions.choose(e, 6, 0).id == 'lightning'
  )
  e.restUntil = { charge = 9, lightning = 9 }
  check('cooldowns are hard limits, not preferences or a fallback', Actions.choose(e, 6, 8) == nil)
  check('exact cooldown boundary permits choice', Actions.choose(e, 6, 9) ~= nil)
  local gated = Schema.copy(A.furfur)
  gated.tactics.moves[2].fromTier = 2
  e.archetype = Creature.define(gated)
  e.restUntil, e.lastAttack = nil, nil
  check('tier-gated move cannot be chosen early', Actions.choose(e, 6, 10).id ~= 'charge')
  e.tier = 2
  check('tier unlock uses the same chooser and executor', Actions.choose(e, 6, 10).id == 'charge')
  e.archetype, e.tier = A.furfur, 1
  check('no long-range melee fallback outside its authored band', Actions.choose(e, 30, 10) == nil)
  local frozen = Integrity.capture(g)
  for _ = 1, 20 do
    Actions.choose(e, 6, 10)
  end
  check(
    'selection is read-only, including RNG',
    not Integrity.difference(frozen, Integrity.capture(g))
  )
  -- Preserve the ordered policy for a creature without tactics.
  local _, imp = fresh('imp')
  check(
    'legacy choice still respects separated claw/leap bands',
    Actions.choose(imp, 1, 0).id == 'claw'
      and not Actions.choose(imp, 3, 0)
      and Actions.choose(imp, 5, 0).id == 'leap'
  )
  for _, kind in ipairs({ 'boss', 'furfur' }) do
    g, e = fresh(kind)
    local identity, hp = e.id, e.maxHp
    local killed, phases, lost = 0, 0, 0
    g.bus:on('sim', 'EnemyKilled', function(ev)
      if ev.enemy == e then
        killed = killed + 1
      end
    end)
    g.bus:on('sim', 'EnemyPhaseChanged', function(ev)
      if ev.enemy == e then
        phases = phases + 1
      end
    end)
    g.bus:on('sim', 'BodyHit', function(ev)
      if ev.enemy == e then
        lost = lost + ev.health
      end
    end)
    local kills = Stats.total(g, 'kills')
    e.conditions.exposed, e.poise = 3, 10
    e.restUntil = { charge = 12 }
    e.pushX = 0.8
    local notice, noticeTimer = g.view.message, g.view.messageTimer
    g:damageEnemy(e, hp + 10000, 'weapon', nil, g.player.id)
    check(
      kind .. ' phase transition adds no HUD announcement',
      g.view.message == notice and g.view.messageTimer == noticeTimer
    )
    check(
      kind .. ' refills once, same body, no death event or counted kill',
      e.id == identity
        and e.phaseIndex == 2
        and e.hp == math.floor(hp * A.of(e).phases[2].refill + 0.5)
        and killed == 0
        and phases == 1
        and Stats.total(g, 'kills') == kills
        and not e.killCounted
    )
    check(kind .. ' excess damage discarded; health feedback counts only real loss', lost == hp)
    check(
      kind .. ' transition cannot unlock the exit or create a corpse',
      not require('src.session.encounter').guardianDead(g)
        and e.deathTime == 0
        and not e.deathResponse
    )
    check(
      kind .. ' transition preserves conditions, guard, cooldown and impulse',
      e.conditions.exposed == 3
        and e.poise == 10
        and e.restUntil.charge == 12
        and near(e.pushX, 0.8)
    )
    check(
      kind .. ' has a recovery window and stays in fury after refill',
      e.ai == 'recover' and e.recover == A.of(e).phases[2].recovery and A.furious(e)
    )
    local again = e.hp
    g:damageEnemy(e, 1, 'weapon')
    check(kind .. ' is damageable during transition (no hidden shield)', e.hp == again - 1)
    g:damageEnemy(e, 10000, 'weapon', nil, g.player.id)
    g:damageEnemy(e, 10000, 'weapon', nil, g.player.id)
    check(
      kind .. ' final death and statistics occur exactly once',
      e.hp == 0 and killed == 1 and phases == 1 and Stats.total(g, 'kills') == kills + 1
    )
  end
  g, e = fresh()
  Rules.applyTier(e, 3)
  local hp = e.maxHp
  g:damageEnemy(e, hp, 'effect')
  check(
    'new stock uses tiered spawn HP, not base definition HP',
    e.hp == math.floor(hp * 0.5 + 0.5)
  )
  local attack = A.furfur.attacks[3]
  e.recover, e.attack, e.hitPause, e.stun = 0, 0, 0, 0
  Actions.begin(g, e, 6, attack)
  check('higher phase/tier preserves full telegraph', e.windupDuration >= attack.windup)
  Actions.execute(g, e)
  e.ai, e.phase = 'strike', attack.duration + 0.01
  Actions.strike(g, e, 0.01)
  check(
    'phase pressure scales cooldown only, not punishable recovery',
    near(e.attack, attack.cooldown / Selection.pace(e)) and e.recover == attack.recover
  )
  -- Transition cancels an unreleased mark, but not existing projectiles.
  g, e = fresh()
  Actions.begin(g, e, 6, A.furfur.attacks[3])
  local pending = e.pendingHazard
  g.bullets[1] = { owner = e.id, life = 2 }
  g:damageEnemy(e, e.hp, 'weapon')
  check(
    'unreleased strike cancelled at phase boundary',
    pending.cancelled and not e.pendingHazard and e.ai == 'recover'
  )
  check(
    'released work retains owner and lifetime',
    g.bullets[1].owner == e.id and g.bullets[1].life == 2
  )
  -- Snapshot/save retain phase and selection history, and never duplicate a reward.
  g, e = fresh()
  Selection.committed(e, A.furfur.attacks[2])
  g:damageEnemy(e, e.hp, 'weapon')
  local captured, snapshot = Integrity.capture(g), Snapshot.capture(g)
  g:damageEnemy(e, e.hp, 'weapon')
  Snapshot.restore(g, snapshot)
  check(
    'snapshot restores full encounter state after a death',
    not Integrity.difference(captured, Integrity.capture(g))
  )
  local Save = require('src.storage.session_save')
  local encoded = Save.encode(g)
  local restored = Fixtures.arena(Game)
  assert(Save.load(restored, encoded))
  local loaded = restored.enemies[1]
  check(
    'disk save retains phase, stock basis and attack history',
    loaded.phaseIndex == 2
      and loaded.phaseBaseHp == 1400
      and loaded.hp == 700
      and loaded.lastAttack == 'charge'
      and loaded.attackRepeats == 1
  )
  -- Validate data additions before combat, never silently degrade a typo.
  local function rejected(change)
    local def = Schema.copy(A.furfur)
    change(def)
    return not pcall(Creature.define, def)
  end
  check(
    'unknown policy fails at load',
    rejected(function(d)
      d.tactics.policy = 'contex'
    end)
  )
  check(
    'unknown attack fails at load',
    rejected(function(d)
      d.phases[2].tactics.moves[1].attack = 'nope'
    end)
  )
  check(
    'duplicate phase fails at load',
    rejected(function(d)
      d.phases[2].id = d.phases[1].id
    end)
  )
  check(
    'zero stock fails at load',
    rejected(function(d)
      d.phases[2].refill = 0
    end)
  )
  check(
    'empty tactics fails at load',
    rejected(function(d)
      d.tactics.moves = {}
    end)
  )
  check(
    'impossible range fails at load',
    rejected(function(d)
      d.tactics.moves[1].min = 50
    end)
  )
  check(
    'sparse phase list fails at load',
    rejected(function(d)
      d.phases[4] = d.phases[2]
    end)
  )
  -- No new AI required for a phase at half health without a refill.
  local custom = Schema.copy(A.furfur)
  custom.phases[2].at, custom.phases[2].refill = 0.5, nil
  custom = Creature.define(custom)
  g, e = fresh()
  Rules.equip(e, custom)
  g:damageEnemy(e, 700, 'weapon')
  check(
    'authored half-health phase preserves health and maximum',
    e.phaseIndex == 2 and e.hp == 700 and e.maxHp == 1400
  )
  -- Effect pulses use actual health removed, not before-after HP across a refill.
  local Effects = require('src.combat.effects')
  local Effect = require('src.content.defs.effect')
  local dot = Effect.schema:fill({
    id = 'phase_test_burn',
    kind = 'periodic',
    duration = 2,
    interval = 0.1,
    packet = { base = 30, impact = 0, damageType = 'physical' },
    cancelOnSourceDeath = true,
  })
  g, e = fresh()
  e.hp = 1
  local pulse
  g.bus:on('sim', 'EffectPulse', function(ev)
    if ev.target == e then
      pulse = ev
    end
  end)
  Effects.apply(g, e, { dot }, g.player)
  g.elapsed = g.elapsed + 0.1
  Effects.update(g, 0.1)
  check(
    'periodic damage crosses phase with a positive exact health receipt',
    e.phaseIndex == 2 and pulse and pulse.health == 1 and e.effectState ~= nil
  )
  Effects.apply(g, g.player, { dot }, e)
  g.elapsed = g.elapsed + 0.1
  Effects.update(g, 0.1)
  check(
    'source-bound effect remains while its caster enters next phase',
    g.player.effectState ~= nil
  )
  g:damageEnemy(e, 10000, 'weapon')
  g.elapsed = g.elapsed + 0.1
  Effects.update(g, 0.1)
  check('source-bound effect cancels only on final death', g.player.effectState == nil)
  -- Real shots recorded across both stocks, not a journal of manual HP edits.
  local function replayScene()
    local scene, boss = fresh('boss')
    boss.x, boss.z, boss.hp, boss.maxHp, boss.dummy = 16, 22, 1, 10, true
    boss.phaseBaseHp = 10 -- tiny authored test stock; real weapon damage
    scene.player.pitch = 0.04
    return scene, boss
  end
  local Journal = require('src.session.journal')
  local recorded, boss = replayScene()
  local journal = Journal.record(recorded)
  recorded:shoot()
  local secondStock = boss.phaseIndex == 2 and boss.hp > 0
  for _ = 1, 180 do
    recorded:update(1 / 120, {})
  end
  recorded:shoot()
  Journal.stop(recorded)
  check(
    'actual volley exhausts one stock without spilling into the next',
    secondStock and boss.hp == 0
  )
  local replayed = replayScene()
  Journal.replay(replayed, Journal.decode(Journal.encode(journal)))
  check(
    'serialized commands replay phase and final death bit for bit',
    not Integrity.difference(Integrity.capture(recorded), Integrity.capture(replayed))
  )
  -- Public reset abandons the encounter, and a new spawn starts phase one.
  local field = Game.new('field', nil, require('src.app.release').sessionOptions.field)
  field.testing = true
  local old = field:spawn('boss', 16, 22)
  field:damageEnemy(old, old.hp, 'weapon')
  require('src.run.test_field').reset(field)
  local new = field:spawn('boss', 16, 22)
  check(
    'field reset cannot carry phases or histories into the next trial',
    new.id ~= old.id and new.phaseIndex == nil and new.lastAttack == nil and new.hp == new.maxHp
  )
  return lines
end
return Tests

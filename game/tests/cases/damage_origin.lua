-- Audit closure: source identity is separate from a contact's label and from
-- the controlled view. These tests exercise real damage/actor/replay paths.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local Pools = require('src.session.world')
  local Effects = require('src.combat.effects')
  local Effect = require('src.content.defs.effect')
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local Stats = require('src.session.stats')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local Journal = require('src.session.journal')
  local Encounter = require('src.session.encounter')
  local Explosives = require('src.combat.explosives')
  local lines = {}
  local check = Fixtures.checker(lines, 'damage origin: ', 'damage origin: ')
  local function fresh()
    local g = G.new('classic')
    g.testing = true
    g:start()
    Pools.clear(g, 'enemies')
    Pools.clear(g, 'pickups')
    g.player.x, g.player.z = 16, 30
    local loadout = { 'exorcist', 'judge' }
    local knight = g.ecs:create('knight', {
      id = 'origin_second',
      x = 16,
      z = 25,
      hp = 100,
      armor = 0,
      loadout = loadout,
      arsenal = Weapons.arsenal(loadout),
      weapon = 1,
      abilities = { 'powder' },
      abilityState = Abilities.kit({ 'powder' }),
    }, false)
    assert(g:actorJoin(Pools.memberRecord(knight)))
    local b = Pools.get(g, 'origin_second')
    local source, target = g:spawn('imp', 16, 21), g:spawn('imp', 17, 21)
    source.dummy, target.dummy = true, true
    target.hp, target.maxHp, target.armorRating = 500, 500, 0
    return g, b, source, target
  end
  local function packet(cancel)
    return {
      base = 1,
      impact = 0,
      push = 0,
      effects = {
        Effect.schema:fill({
          id = 'origin_burn',
          kind = 'periodic',
          duration = 0.6,
          interval = 0.2,
          cancelOnSourceDeath = cancel == true,
          packet = { base = 6, impact = 0, damageType = 'fire' },
        }),
      },
    }
  end
  local function pulse(g)
    g.elapsed = g.elapsed + 0.21
    Effects.update(g, 0.21)
  end
  local g, b, source, target = fresh()
  g:damageBody(target, packet(true), source.x, source.z, nil, source)
  local effect = target.effectState[1]
  check(
    'demon contact preserves its numeric owner and side',
    effect.sourceId == source.id and effect.sourceSide == 'demons'
  )
  local hp = target.hp
  source.hp = 0
  pulse(g)
  check(
    'owner-bound demon exposure ends before a pulse when the source dies',
    target.effectState == nil and target.hp == hp
  )

  g, b, source, target = fresh()
  g:damageBody(target, packet(false), source.x, source.z, nil, source)
  local killedOwner, pulseOwner, applied = false, false, 0
  g.bus:on('sim', 'EnemyKilled', function(event)
    killedOwner = event.owner
  end)
  g.bus:on('sim', 'EffectPulse', function(event)
    pulseOwner = event.owner
  end)
  g.bus:on('sim', 'EffectApplied', function()
    applied = applied + 1
  end)
  target.hp, source.hp = 4, 0
  pulse(g)
  check(
    'persistent exposure retains a dead demon as pulse and kill owner',
    target.hp == 0 and killedOwner == source.id and pulseOwner == source.id
  )
  check(
    'a pulse never recursively applies effects and the kill belongs to the world',
    applied == 0
      and target.effectState == nil
      and Stats.read(g, Stats.world).kills == 1
      and Stats.readControlled(g).kills == 0
  )

  g, b, source, target = fresh()
  g:damageBody(
    target,
    packet(true),
    source.x,
    source.z,
    nil,
    'projectile',
    { effectSource = { side = 'demons', id = source.id } }
  )
  check(
    'projectile/hazard contact context reaches a creature target',
    target.effectState[1].sourceId == source.id
  )

  g, b, source, target = fresh()
  g:damageBody(b, packet(true), source.x, source.z, nil, source)
  hp = b.hp
  source.hp = 0
  pulse(g)
  check(
    'demon exposure on another knight cancels against the same source',
    b.effectState == nil and b.hp == hp
  )

  g, b, source, target = fresh()
  g:damageEnemy(target, 1, 'weapon', packet(true), b.id)
  check(
    'a second knight owns the effect rather than the controlled knight',
    target.effectState[1].sourceId == b.id and target.effectState[1].sourceSide == 'knight'
  )
  local first = g.player
  assert(g:actorControl(b.id))
  first.hp = 0
  hp = target.hp
  pulse(g)
  check(
    'switching control and another knight dying do not cancel a living owner',
    target.effectState ~= nil and target.hp < hp
  )
  b.hp = 0
  hp = target.hp
  pulse(g)
  check('the actual knight dying cancels his effect', target.effectState == nil and target.hp == hp)

  g, b, source, target = fresh()
  g:damageEnemy(target, 1, 'unknown', packet(false), nil)
  check(
    'unknown provenance is explicit and not the controlled knight',
    target.effectState[1].sourceSide == 'world' and target.effectState[1].sourceId == nil
  )
  killedOwner = false
  g.bus:on('sim', 'EnemyKilled', function(event)
    killedOwner = event.owner
  end)
  target.hp = 4
  pulse(g)
  check(
    'an unknown periodic kill remains unowned',
    killedOwner == nil and Stats.read(g, Stats.world).kills == 1
  )

  local function withEffect()
    local scene, second, demon, victim = fresh()
    scene:damageBody(victim, packet(false), demon.x, demon.z, nil, demon)
    return scene, second, demon, victim
  end
  g, b, source, target = withEffect()
  local saved = Snapshot.capture(g)
  local log = Journal.record(g)
  for _ = 1, 80 do
    g:update(1 / 120, {})
  end
  Journal.stop(g)
  local expected = Integrity.capture(g)
  local replay = withEffect()
  local replayOK, replayError = pcall(Journal.replay, replay, Journal.decode(Journal.encode(log)))
  check(
    'periodic provenance and clocks replay bit for bit: '
      .. (replayOK and 'equal' or tostring(replayError)),
    replayOK and not Integrity.difference(expected, Integrity.capture(replay))
  )
  Snapshot.restore(g, saved)
  for _ = 1, 80 do
    g:update(1 / 120, {})
  end
  check(
    'mid-effect snapshot restores source identity and exact cadence',
    not Integrity.difference(expected, Integrity.capture(g))
  )

  g, b, source, target = fresh()
  Effects.apply(g, g.player, packet(false).effects, source)
  Effects.apply(g, b, packet(false).effects, source)
  Encounter.clearStage(g)
  check(
    'a wave boundary preserves the existing knight exposure policy for both actors',
    g.player.effectState ~= nil and b.effectState ~= nil
  )
  Encounter.clearWorld(g)
  check(
    'a full reset clears ongoing effects on every knight',
    g.player.effectState == nil and b.effectState == nil
  )

  g, b = fresh()
  Pools.clear(g, 'enemies')
  hp = b.hp
  Explosives.explode(
    g,
    { x = 16, z = 25, y = 1, owner = b.id, action = Abilities:get('powder').action }
  )
  check(
    'a second thrower is the self-damage report owner',
    b.hp < hp and g.explosionReport.selfDamage == hp - b.hp
  )
  g, b = fresh()
  Pools.clear(g, 'enemies')
  hp = b.hp
  Explosives.explode(
    g,
    { x = 16, z = 25, y = 1, owner = 'departed', action = Abilities:get('powder').action }
  )
  check(
    'an absent thrower is not replaced by another living knight',
    b.hp < hp and g.explosionReport.selfDamage == 0
  )

  local function reaction(controlSecond)
    local scene, striker, _, victim = fresh()
    scene.player.x, scene.player.z = 16, 15
    victim.x, victim.z = 16, 20
    if controlSecond then
      assert(scene:actorControl(striker.id))
    end
    require('src.combat.rules').react(
      scene,
      victim,
      20,
      false,
      { victim.x + 0.3, 1, victim.z },
      10,
      { origin = striker }
    )
    return victim
  end
  local fromA, fromB = reaction(false), reaction(true)
  check(
    'a real contact uses its striker irrespective of the active controller',
    fromA.flinchSide ~= 0
      and fromA.flinchSide == fromB.flinchSide
      and fromA.flinchLeanV == fromB.flinchLeanV
      and fromA.flinchOwner == 'origin_second'
  )

  -- A travelling bullet and its painted reaction use the same fallback eye.
  g, b, source, target = fresh()
  local profile = Weapons.get('judge')
  local shot = {
    profile = profile,
    attack = profile.attack,
    shooter = b,
    origin = { 16, 1, 25 },
    slot = 2,
    serial = 1,
    sequence = 1,
  }
  local bullet = {
    shot = shot,
    x = target.x + 0.2,
    y = 1,
    z = target.z,
    vx = 0,
    vy = 0,
    vz = -60,
    travelled = 4,
  }
  assert(g:actorLeave(b.id))
  b.x, b.z = 30, 30
  require('src.combat.combat').projectile(
    g,
    bullet,
    target,
    'torso',
    nil,
    require('src.combat.projectiles').observer(g, bullet)
  )
  check(
    'departed projectile owner leaves the same origin for geometry and reaction',
    target.flinchOwner == nil and target.flinchOriginX == 16 and target.flinchOriginZ == 25
  )
  return lines
end
return Tests

-- Diagnostics consume the contact already accepted by combat. Reading or
-- retaining this event must not alter a session, an attack or its definitions.
local Fixtures = require('tests.support.fixtures')
local Pools = require('src.session.world')
local Spawn = require('src.session.spawn')
local Ground = require('src.physics.ground')
local Projectiles = require('src.combat.projectiles')
local Melee = require('src.combat.melee')
local Contact = require('src.enemies.attack_contact')
local Hazards = require('src.enemies.hazards')
local Explosives = require('src.combat.explosives')
local Effects = require('src.combat.effects')
local Effect = require('src.content.defs.effect')
local Snapshot = require('src.session.snapshot')
local Integrity = require('src.session.integrity')
local Tests = {}

function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'contact receipt: ', 'contact receipt: ')
  local near = Fixtures.within(2e-7)
  local receipts = {}
  local function tree(value, seen)
    local kind = type(value)
    if kind == 'number' then
      return value == value and math.abs(value) ~= math.huge
    end
    if kind ~= 'table' then
      return kind == 'nil' or kind == 'string' or kind == 'boolean'
    end
    seen = seen or {}
    if seen[value] or getmetatable(value) then
      return false
    end
    seen[value] = true
    for key, field in pairs(value) do
      if type(key) ~= 'string' or not tree(field, seen) then
        return false
      end
    end
    return true
  end
  local function fresh()
    local g = Fixtures.arena(Game)
    g.player.armor, g.player.invuln = 0, 0
    local caught = {}
    for _, kind in ipairs({ 'PlayerHit', 'KnightHit' }) do
      g.bus:on('sim', kind, function(event)
        caught[#caught + 1] = { kind = kind, info = event.info }
        if event.info.contact then
          receipts[#receipts + 1] = event.info.contact
        end
      end)
    end
    return g, caught
  end
  local g, caught = fresh()
  local state = Snapshot.capture(g)
  g:damageBody(g.player, { base = 7, impact = 0 }, 16, 24, nil, 'self')
  local without = Integrity.capture(g)
  Snapshot.restore(g, state)
  local supplied = { kind = 'fixture', id = 'known', target = g.player.id }
  g:damageBody(g.player, { base = 7, impact = 0 }, 16, 24, nil, 'self', { contact = supplied })
  check(
    'event forwards the optional receipt without changing the canonical state',
    caught[2].info.contact == supplied and not Integrity.difference(without, Integrity.capture(g))
  )
  check(
    'player damage report does not store diagnostic geometry',
    g.playerDamageReport.contact == nil
  )

  g, caught = fresh()
  g.player.crouch = 0.43
  local source = g:spawn('imp', 18, 22)
  local b = Spawn.make(g, 'projectile', {
    x = 16,
    y = Ground.of(g.world, g.player) + 1.15,
    z = 24,
    vx = 0,
    vy = 0,
    vz = 30,
    radius = 0.26,
    life = 2,
    side = 'demons',
    owner = source.id,
    packet = { base = 7, impact = 0 },
  })
  Projectiles.update(g, 0.1, g.player)
  local c = caught[1] and caught[1].info.contact
  check(
    'projectile receipt names the selected missile, owner and knight',
    c
      and c.kind == 'projectile'
      and c.id == b.id
      and c.owner == source.id
      and c.target == g.player.id
  )
  check(
    'projectile receipt reports impact time and the crouched physical bounds',
    near(c.time, 0.52 / 30)
      and near(c.fraction, c.time / 0.1)
      and near(c.bounds.top, Ground.of(g.world, g.player) + 1.37)
  )
  check(
    'sphere centre and closest body point are distinguished',
    near(c.sphereCenter.z, 24.52) and near(c.point.z, 24.78) and c.radius == 0.26
  )
  b.x, source.x, g.player.x = 99, 98, 97
  check(
    'retained diagnostic geometry has no mutable body references',
    c.sphereCenter.x == 16 and c.bounds.x == 16 and c.point.x == 16
  )

  g, caught = fresh()
  g.player.crouch = 0.43
  Spawn.make(g, 'projectile', {
    x = 16.47,
    y = Ground.of(g.world, g.player) + 1.62,
    z = 24,
    vx = 0,
    vy = 0,
    vz = 30,
    radius = 0.26,
    life = 2,
    side = 'demons',
    packet = { base = 7, impact = 0 },
  })
  Projectiles.update(g, 0.1, g.player)
  check(
    'a rejected rounded-corner contact produces no damage receipt',
    #caught == 0 and g.player.hp == 100
  )

  g, caught = fresh()
  source = g:spawn('imp', 18, 22)
  local hit, fraction, geometry = Melee.contact(g, 16, 24, 16, 27, 1.15, 0.18, g.player, g.player)
  local attack = { id = 'receipt-claw', packet = { base = 7, impact = 0 } }
  Contact.hurt(g, source, attack, g.player, geometry)
  c = caught[1].info.contact
  check(
    'accepted melee geometry is forwarded rather than tested again',
    hit and c == geometry and c.kind == 'melee' and c.id == attack.id and c.owner == source.id
  )
  check(
    'melee closest point is on the swept target at the solved fraction',
    near(c.fraction, fraction) and near(c.point.z, 24.78) and near(c.sphereCenter.z, 24.6)
  )

  local Kinds = require('src.enemies.melee_kinds')
  local Rules = require('src.combat.rules')
  local Anchor = require('src.enemies.contact_anchor')
  local Schema = require('src.core.schema')
  g, caught = fresh()
  source = g:spawn('imp', 16, 22)
  attack = Schema.copy(Rules.archetype(source).attacks[1])
  attack.lungeSpeed = 0 -- isolate the authored hand sweep in this fixture
  source.ai, source.phase, source.spawnAge = 'strike', 0.08, 1
  source.attackSpec, source.attackKind = attack, attack.id
  source.lungeX, source.lungeZ = 0, 1
  local ax, ay, az = Anchor.point(g, source, source.phase, source.x, source.z, attack.contactAnchor)
  g.player.x, g.player.z, g.player.jump = ax, az + attack.contactReach[2], ay - 0.9
  Kinds.lunge.strike(g, source, attack, 0.01, {
    before = 0.07,
    oldX = source.x,
    oldZ = source.z,
    previous = g.player,
  })
  c = caught[1] and caught[1].info.contact
  check(
    'lunge delivery retains the accepted hand sweep and active-window time',
    c
      and c.id == attack.id
      and c.geometry == 'sphere-cylinder'
      and c.time >= 0
      and c.time <= 0.01
      and near(c.time, c.fraction * 0.01)
  )

  g, caught = fresh()
  source = g:spawn('furfur', 16, 22)
  attack = Rules.archetype(source).attacks[2]
  source.phase, source.chargeTime, source.lungeX, source.lungeZ = 0.2, 0.5, 0, 1
  Kinds.charge.strike(g, source, attack, 0.2, {
    before = 0,
    oldX = 16,
    oldZ = 22,
    previous = g.player,
  })
  c = caught[1] and caught[1].info.contact
  check(
    'charge delivery carries its contact time and the charge radius',
    c
      and c.id == attack.id
      and c.radius == attack.contactRadius
      and c.time >= 0
      and c.time <= 0.2
      and near(c.time, c.fraction * 0.2)
  )

  g, caught = fresh()
  source = g:spawn('imp', 16, 22)
  attack = Rules.archetype(source).attacks[2]
  source.leapY, source.leapVY, source.leapVX, source.leapVZ, source.leaping = 0.01, -5, 0, 0, true
  g.player.x, g.player.z = 16, 22
  Kinds.leap.strike(g, source, attack, 0.2, { previous = g.player })
  c = caught[1] and caught[1].info.contact
  check(
    'landing delivery reports its radial rule and solved landing time',
    c
      and c.id == attack.id
      and c.geometry == 'landing-radius'
      and c.time > 0
      and c.time < 0.2
      and near(c.time, c.fraction * 0.2)
  )

  g, caught = fresh()
  source = g:spawn('imp', 18, 22)
  Hazards.add(g, 16, 25, 0, 1, 1, { owner = source.id, packet = { base = 3, impact = 0 } })
  local h = Pools.of(g, 'hazards')[1]
  h.pulse = 0.05
  Hazards.update(g, 0.1, g.player)
  c = caught[1] and caught[1].info.contact
  check(
    'pool receipt uses the actual pulse time and feet sample',
    c
      and c.kind == 'hazard'
      and c.delivery == 'pool'
      and c.id == h.id
      and c.owner == source.id
      and near(c.time, 0.05)
      and near(c.fraction, 0.5)
      and near(c.samplePoint.y, Ground.of(g.world, g.player))
  )
  check(
    'pool does not invent a sphere collision surface',
    c.geometry == 'radial-feet' and c.point == nil
  )

  g, caught = fresh()
  source = g:spawn('furfur', 18, 22)
  h = Spawn.make(g, 'hazard', {
    x = 16,
    z = 25,
    kind = 'lightning',
    owner = source.id,
    side = 'demons',
    radius = 1,
    delay = 0,
    life = 1,
    packet = { base = 3, impact = 0 },
  })
  Hazards.update(g, 0.1, g.player)
  c = caught[1] and caught[1].info.contact
  check(
    'lightning explicitly reports its current vertical policy, without invented TOI',
    c
      and c.delivery == 'lightning'
      and c.geometry == 'radial-column'
      and c.bounds.heightPolicy == 'unbounded'
      and c.time == nil
      and c.samplePoint.y == nil
  )

  g, caught = fresh()
  b = Spawn.make(g, 'charge', {
    x = 16,
    y = Ground.of(g.world, g.player) + 1,
    z = 24,
    owner = g.player.id,
    vx = 0,
    vy = 0,
    vz = 0,
    fuse = 1,
  })
  Explosives.explode(g, b)
  c = caught[1] and caught[1].info.contact
  check(
    'explosion reports its resolved 3D anchor exposure and owner',
    c
      and c.kind == 'explosion'
      and c.id == b.id
      and c.owner == g.player.id
      and c.geometry == 'sphere-anchor'
      and c.distance > 1
      and c.point == nil
  )

  g, caught = fresh()
  source = g:spawn('imp', 18, 22)
  local definition = Effect.schema:fill({
    id = 'receipt-burn',
    kind = 'periodic',
    duration = 0.6,
    interval = 0.2,
    packet = { base = 3, impact = 0, damageType = 'fire' },
  })
  Effects.apply(g, g.player, { definition }, source)
  g.elapsed = g.elapsed + 0.21
  Effects.update(g, 0.21)
  c = caught[1] and caught[1].info.contact
  check(
    'periodic receipt identifies the exposure without inventing contact geometry',
    c
      and c.kind == 'periodic'
      and c.id == definition.id
      and c.owner == source.id
      and c.target == g.player.id
      and c.geometry == 'ongoing-exposure'
      and c.point == nil
      and c.radius == nil
      and c.time == nil
  )

  local Weapons, Abilities = require('src.content.weapons'), require('src.content.abilities')
  g, caught = fresh()
  local loadout = { 'exorcist', 'judge' }
  local second = g.ecs:create('knight', {
    id = 'receipt_second',
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
  assert(g:actorJoin(Pools.memberRecord(second)))
  second = Pools.get(g, 'receipt_second')
  supplied = { kind = 'fixture', id = 'second', target = second.id }
  g:damageBody(second, { base = 7, impact = 0 }, 16, 24, nil, 'self', { contact = supplied })
  check(
    'the same optional receipt reaches KnightHit for another actor',
    #caught == 1 and caught[1].kind == 'KnightHit' and caught[1].info.contact == supplied
  )
  local safe = true
  for _, receipt in ipairs(receipts) do
    safe = safe and tree(receipt)
  end
  check('all emitted contact receipts are finite pointer-free data trees', safe)
  return lines
end

return Tests

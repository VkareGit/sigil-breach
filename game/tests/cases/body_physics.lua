-- Physical invariants and attack lifecycle regressions. These do not depend
-- on a renderer, painted poses, test-arena decoration or random numbers.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local Physics = require('src.physics.body_physics')
  local Rules = require('src.combat.rules')
  local Body = require('src.enemies.body')
  local AI = require('src.enemies.ai')
  local Attacks = require('src.enemies.actions')
  local Hazards = require('src.enemies.hazards')
  local Archetypes = require('src.content.enemies')
  local near = Fixtures.within(1e-8)
  local function energy(x, z, m)
    return 0.5 * m * (x * x + z * z)
  end
  local function fresh()
    return Fixtures.arena(G)
  end
  local x, z, ox, oz, received, closing = Physics.contact(6, 0, 0, 0, 1, 1, 1, 0)
  check(
    'equal masses share a direct shove at 3 m/s',
    near(x, 3) and near(ox, 3) and z == 0 and oz == 0 and near(received, 3) and closing == 6
  )
  x, z, ox, oz = Physics.contact(6, 0, 0, 0, 1.4, 1, 1, 0)
  check(
    'a heavy body retains the correct common velocity after contact',
    near(x, 3.5) and near(ox, 3.5)
  )
  x, z, ox, oz = Physics.contact(6, 0, 0, 0, 1, 1.4, 1, 0)
  check(
    'a light body cannot manufacture momentum against a heavy body',
    near(x, 2.5) and near(ox, 2.5)
  )
  x, z, ox, oz, received, closing = Physics.contact(8, 5, 2, -3, 2, 3, 1, 0)
  check('a grazing contact preserves each body tangent', z == 5 and oz == -3)
  check(
    'contact uses relative closing speed, not donor world speed',
    near(closing, 6) and near(received, 2.4) and near(x, 4.4) and near(ox, 4.4)
  )
  x, z, ox, oz, received, closing = Physics.contact(2, 5, 8, -3, 2, 3, 1, 0)
  check(
    'bodies moving apart exchange no impulse',
    x == 2 and z == 5 and ox == 8 and oz == -3 and received == 0 and closing == 0
  )
  x, z, ox, oz, received = Physics.contact(8, 5, 2, -3, 2, 3, 0, 0)
  check(
    'coincident centers do not invent a collision direction',
    x == 8 and z == 5 and ox == 2 and oz == -3 and received == 0
  )
  x, z, ox, oz, received = Physics.contact(8, 5, 2, -3, 0, 3, 1, 0)
  check(
    'invalid mass cannot create non-finite velocities',
    x == 8 and z == 5 and ox == 2 and oz == -3 and received == 0
  )
  local momentum, passive, tangent, galilean = true, true, true, true
  for _, m1 in ipairs({ 0.25, 1, 1.4, 8.333333333 }) do
    for _, m2 in ipairs({ 0.25, 1, 1.4, 8.333333333 }) do
      for i = 0, 15 do
        local angle = i * math.pi / 8
        local nx, nz = math.cos(angle), math.sin(angle)
        local ax, az = 6 * nx + 2 * nz, 6 * nz - 2 * nx
        local bx, bz = -nx - 3 * nz, -nz + 3 * nx
        local vx, vz, wx, wz = Physics.contact(ax, az, bx, bz, m1, m2, nx, nz)
        momentum = momentum
          and near(m1 * vx + m2 * wx, m1 * ax + m2 * bx)
          and near(m1 * vz + m2 * wz, m1 * az + m2 * bz)
        passive = passive
          and energy(vx, vz, m1) + energy(wx, wz, m2)
            <= energy(ax, az, m1) + energy(bx, bz, m2) + 1e-8
        tangent = tangent
          and near(vx * nz - vz * nx, ax * nz - az * nx)
          and near(wx * nz - wz * nx, bx * nz - bz * nx)
        local a, b, c, d = Physics.contact(ax + 11, az - 7, bx + 11, bz - 7, m1, m2, nx, nz)
        galilean = galilean
          and near(a, vx + 11)
          and near(b, vz - 7)
          and near(c, wx + 11)
          and near(d, wz - 7)
      end
    end
  end
  check('256 mass and direction cases conserve both momentum components', momentum)
  check('256 mass and direction cases never gain kinetic energy', passive)
  check('256 mass and direction cases retain tangential motion', tangent)
  check('256 mass and direction cases are invariant under common world velocity', galilean)
  local decay, travel = Physics.drag(0, 0.5)
  check('zero drag has the constant velocity limit', decay == 1 and travel == 0.5)
  decay, travel = Physics.drag(14, 0.2)
  local step, part = Physics.drag(14, 0.1)
  check(
    'closed-form drag composes over time subdivisions',
    near(decay, step * step) and near(travel, part + step * part)
  )

  local g = fresh()
  local donor = g:spawn('armored', 14, 25)
  local receiver = g:spawn('imp', 14.5, 25)
  donor.pushX, donor.pushZ = 6, 2
  receiver.pushX, receiver.pushZ = 0, -1
  local hit = Rules.collide(g, donor, receiver)
  check(
    'world contact consumes the pure mass solution',
    hit
      and near(donor.pushX, 3.5)
      and near(receiver.pushX, 3.5)
      and donor.pushZ == 2
      and receiver.pushZ == -1
  )
  check(
    'contact guard uses the velocity delivered to the recipient',
    near(receiver.poise, 3.5 * Archetypes.defaults.collidePoise)
  )
  local saved = receiver.pushX
  check(
    'one contact cannot jolt a locked recipient again',
    not Rules.collide(g, donor, receiver) and receiver.pushX == saved and g.collisions == 1
  )
  receiver.collideLock = 0
  donor.pushX, donor.pushZ = 0, 6
  receiver.pushX, receiver.pushZ = 0, 0
  check(
    'fast tangential travel does not damage a neighbor guard',
    not Rules.collide(g, donor, receiver) and g.collisions == 1
  )
  receiver.pushX = 10
  donor.pushX = 6
  check(
    'a faster escaping recipient is not struck from behind',
    not Rules.collide(g, donor, receiver)
  )

  g = fresh()
  local e = g:spawn('imp', 23.25, 25)
  e.stun = 10
  local before = e.hp
  Rules.slam(g, e, 7)
  local first = e.hp
  for _ = 1, 48 do
    AI.update(g, 1 / 120, g.player)
  end
  check(
    'slam lock expires while a body is stationary',
    e.pushX == 0 and e.pushZ == 0 and e.slamLock == 0
  )
  Rules.slam(g, e, 7)
  check(
    'a second distinct wall impact is not swallowed by stale lock',
    near(before - first, 22.8) and near(first - e.hp, 22.8) and g.slams == 2
  )
  g = fresh()
  e = g:spawn('imp', 23.25, 25)
  e.pushX, e.pushZ = 7, 4
  Body.push(g, e, 1 / 120, 14)
  local decay = math.exp(-14 / 120)
  check(
    'a wall stops normal shove while retaining the sliding component',
    near(e.pushX, 0) and near(e.pushZ, 4 * decay) and near(e.hp, e.maxHp - 22.8)
  )

  g = fresh()
  e = g:spawn('stolas', 16, 20)
  local packet = Archetypes.stolas.attacks[1].packet
  Attacks.begin(g, e, 5)
  g.player.x = 18
  Attacks.execute(g, e)
  check(
    'a committed ranged attack retains its target when the player dodges',
    e.aimX == 16 and #g.bullets == 1 and near(g.bullets[1].vx, 0)
  )
  check(
    'attack execution forwards the original damage packet unchanged',
    g.bullets[1].packet == packet and g.bullets[1].owner == e.id
  )
  g = fresh()
  e = g:spawn('furfur', 16, 20)
  -- This is a delivery lifecycle check, not a particular tactical ranking.
  local lightning
  for _, attack in ipairs(Archetypes.furfur.attacks) do
    if attack.id == 'lightning' then
      lightning = attack
    end
  end
  Attacks.begin(g, e, 5, assert(lightning))
  local hazard = e.pendingHazard
  check(
    'lightning telegraph belongs to its committed caster',
    hazard and hazard.waitForCast and hazard.owner == e.id and near(hazard.delay, e.windup)
  )
  e.stun = 0.3
  e.windup = 0.4
  Hazards.update(g, 0.1, g.player)
  check(
    'a paused caster keeps damage waiting on its actual windup',
    #g.hazards == 1 and hazard.waitForCast and near(hazard.delay, 0.4) and g.player.hp == 100
  )
  e.hp = 0
  Hazards.update(g, 0.1, g.player)
  check(
    'a dead caster cannot leave an active delayed strike',
    #g.hazards == 0 and g.player.hp == 100
  )
  g = fresh()
  e = g:spawn('stolas', 16, 20)
  local pending = {
    kind = 'lightning',
    owner = e.id,
    x = 16,
    z = 25,
    radius = 1,
    delay = 0.2,
    life = 0.2,
    waitForCast = true,
  }
  e.pendingHazard = pending
  e.ai = 'windup'
  e.windup = 0.2
  g.hazards = { pending }
  Rules.interrupt(e)
  Hazards.update(g, 0.1, g.player)
  check(
    'interrupt immediately cancels owned telegraph without a rules-to-AI cycle',
    pending.cancelled and not e.pendingHazard and e.ai == 'hurt' and #g.hazards == 0
  )
  check(
    'legacy AI entry points remain compatible after the split',
    AI.interrupt == Rules.interrupt and AI.hazard == Hazards.add and AI.radius == Rules.radius
  )
end
return Tests

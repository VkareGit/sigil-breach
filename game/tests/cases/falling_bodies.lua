-- A killed body in the way (0.29): one rule for shots and the knight's
-- missiles (enemies/corpse.lua: shields). It shields while it falls — until
-- its painted collapse shows the last frame, has stopped leaning and lies on
-- the floor — takes no wound and gives no reward; then it lets them pass.
local Fixtures = require('tests.support.fixtures')
local B = require('src.combat.ballistics')
local Corpse = require('src.enemies.corpse')
local Defaults = require('src.content.combat_defaults').corpse
local Tests = {}
-- A thrall killed in front of a living one (its death clock at age, maybe
-- thrown up to height), and a ray through both paintings as drawn then.
local function line(G, age, height)
  local g = Fixtures.arena(G)
  g.state = 'playing'
  local front = g:spawn('imp', 16, 22)
  local rear = g:spawn('imp', 16, 20)
  front.spawnAge, rear.spawnAge = 1, 1
  front.hp, front.deathTime, front.fallY = 0, age or 0, height or 0
  local ox, oy, oz = B.origin(g)
  -- The highest such ray: through the bodies, clear of the floor.
  for i = 30, -30, -1 do
    local dx, dy, dz = B.direction(g.player.yaw, i / 100)
    if
      B.body(g, front, ox, oy, oz, dx, dy, dz, 20) and B.body(g, rear, ox, oy, oz, dx, dy, dz, 20)
    then
      return g, front, rear, { dx, dy, dz }, i / 100
    end
  end
  error('fixture: the two paintings must overlap on some ray')
end
local function trace(g, d)
  return B.traceVector(g, d[1], d[2], d[3], 20, B.prepare(g))
end
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'falling bodies: ', 'falling bodies: ')
  local extended = (Defaults.extended.last - Defaults.extended.first) * Defaults.extended.frame
  local compact = math.max(
    (Defaults.compact.last - Defaults.compact.first) * Defaults.compact.frame,
    Defaults.settle
  )
  -- The painted collapse of a thrall lasts longer than its lean (the old
  -- limit, corpse.settle 0.33 s): mid-fall it must still shield.
  local g, front, rear, ray, pitch = line(G, (Defaults.settle + extended) * 0.5)
  check(
    string.format(
      'a thrall still painted mid-fall (%.2f s of %.2f s) shields the body behind it',
      front.deathTime,
      extended
    ),
    trace(g, ray) == front
  )
  g, front, rear, ray = line(G, extended - 1e-6)
  local before = trace(g, ray)
  front.deathTime = extended
  local after = trace(g, ray)
  check(
    'the shield ends exactly when the collapse shows its last frame',
    before == front and after == rear
  )
  g, front, rear, ray = line(G, extended + 0.2, 0.3)
  check('a body thrown up is still falling while it is in the air', trace(g, ray) == front)
  local boss = g:spawn('boss', 10, 10)
  boss.hp, boss.deathTime = 0, compact - 1e-6
  local falling = Corpse.shields(boss)
  boss.deathTime = compact
  check(
    'a compact collapse (bosses) settles when its lean has settled too',
    falling and not Corpse.shields(boss)
  )
  -- A real shot at the falling body: the volley stops there and wounds no one.
  g, front, rear, ray, pitch = line(G, 0.1)
  local kills, report = 0
  g.bus:on('sim', 'EnemyKilled', function()
    kills = kills + 1
  end)
  g.bus:on('sim', 'VolleyResolved', function(event)
    report = event.report
  end)
  g.weapon, g.player.pitch, g.cooldown = 1, pitch, 0
  g:shoot()
  local shielded, unwounded = 0, true
  for _, ray in ipairs(report.rays) do
    shielded = shielded + (ray.target == front.id and ray.corpse and 1 or 0)
  end
  for _, contact in ipairs(report.contacts) do
    if contact.targetId == front.id then
      unwounded = unwounded and contact.damage == 0 and contact.kind == 'corpse'
    end
  end
  check(
    'pellets meeting a falling body stop there: no wound, no reward',
    shielded > 0 and unwounded and front.hp == 0 and kills == 0
  )
  -- The Judge's round passes bodies: through a falling one it goes on, with
  -- the same loss as through any body, and wounds the living one behind.
  g, front, rear, ray, pitch = line(G, 0.1)
  g.bus:on('sim', 'VolleyResolved', function(event)
    report = event.report
  end)
  g.weapon, g.player.pitch, g.cooldown = 2, pitch, 0
  local rearHp = rear.hp
  g:shoot()
  local through
  for _, contact in ipairs(report.contacts) do
    if contact.targetId == rear.id then
      through = contact
    end
  end
  check(
    "the Judge's round pierces a falling body and loses power on the way",
    through and through.retained < 1 and rear.hp < rearHp and front.hp == 0
  )
  -- A wall before the body wins, falling or not.
  g, front, rear, ray = line(G, 0.1)
  g.world.map[23][16] = 1
  local ox, oy, oz = B.origin(g)
  local target, distance = trace(g, ray)
  check(
    'a wall in front stops the shot before any falling body',
    target == nil and B.world(g.world, ox, oy, oz, ray[1], ray[2], ray[3], 20) == distance
  )
  -- The knight's missile follows the same rule.
  local Projectiles = require('src.combat.projectiles')
  local Spawn = require('src.session.spawn')
  local function missile(age)
    g, front, rear, ray = line(G, 0.05)
    front.deathTime = age
    ox, oy, oz = B.origin(g)
    rearHp = rear.hp
    Spawn.make(g, 'projectile', {
      x = ox,
      y = oy,
      z = oz,
      vx = ray[1] * 12,
      vy = ray[2] * 12,
      vz = ray[3] * 12,
      life = 2,
      side = 'knight',
      packet = { base = 30, impact = 10 },
      radius = 0.05,
    })
    for _ = 1, 120 do
      Projectiles.update(g, 1 / 120)
    end
    return rear.hp < rearHp, #g.bullets
  end
  local woundedEarly, leftEarly = missile(0.05)
  local woundedLate = missile(extended + 1)
  check(
    'a missile stops at a falling body and passes a settled one ('
      .. tostring(woundedEarly)
      .. ' '
      .. tostring(leftEarly)
      .. ' '
      .. tostring(woundedLate)
      .. ')',
    not woundedEarly and leftEarly == 0 and woundedLate
  )
  return lines
end
return Tests

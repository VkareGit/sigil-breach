-- Weight (src/feedback/weight.lua) and momentum against the world (src/combat/rules.lua):
-- what the rules decide must be what the player feels.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local Rules = require('src.combat.rules')
  local Weight = require('src.feedback.weight')
  local Weapons = require('src.content.weapons')
  local A = require('src.content.enemies')
  local AI = require('src.enemies.ai')
  local P = require('src.combat.projectiles')
  local near = Fixtures.within(1e-6)
  local function fresh()
    return Fixtures.arena(G)
  end
  -- Recoil is physics from data: momentum * power / mass.
  local sw, rw = Weapons.profile(1).weight, Weapons.profile(2).weight
  check(
    'recoil impulse is discharge momentum over weapon mass',
    near(sw.momentum / sw.mass, 24) and near(rw.momentum / rw.mass, 6)
  )
  local g = fresh()
  g.view.recoil, g.view.recoilV = 0, 0
  -- The impulse is given at the start of the shot's step and moved on by
  -- that step at once, so the frame of the flash shows it (PLAN E5).
  local spring = require('src.content.tuning').camera.recoilSpring
  local _, halfV = require('src.physics.kinematics').spring(
    0,
    12,
    0,
    spring[1],
    spring[2],
    require('src.core.rate').step
  )
  check(
    'one shotgun shell kicks half of a full volley',
    near(Weight.shot(g, Weapons.profile(1), 0.5), 12) and near(g.view.recoilV, halfV)
  )
  -- A heavier weapon trails the same turn further.
  local function trail(slot)
    local t = fresh()
    t.player.weapon = slot
    for _ = 1, 3 do
      t:update(1 / 120, {})
    end
    t.player.yaw = t.player.yaw + 0.12
    for _ = 1, 6 do
      t:update(1 / 120, {})
    end
    return math.abs(t.view.weaponAimX)
  end
  check('the heavy shotgun lags a turn more than the light revolver', trail(1) > trail(2) * 1.1)
  -- Being hit: the marker points at the source; a heavier blow knocks harder.
  local function struck(impact)
    local t = fresh()
    local p = t.player
    p.armor = 0
    t.view.weaponImpactVX = 0
    t.view.rollPunchV = 0
    t:damagePlayer(10, p.x - 3, p.z, { base = 10, impact = impact, damageType = 'fire' })
    return t
  end
  local light, heavy = struck(20), struck(120)
  local mark = heavy.view.hurtMarks and heavy.view.hurtMarks[1]
  check(
    'an incoming blow leaves a marker pointing at its source',
    mark ~= nil and near(mark.angle, math.atan2(-3, 0), 1e-6)
  )
  check(
    'the marker takes the colour of the damage type',
    mark and mark.color == Weight.typeColor('fire')
  )
  check(
    'a heavier blow knocks the weapon and the head harder',
    math.abs(heavy.view.weaponImpactVX) > math.abs(light.view.weaponImpactVX) * 1.8
      and math.abs(heavy.view.rollPunchV) > math.abs(light.view.rollPunchV) * 1.8
  )
  -- Facing -z the source at -x is on the player's right: the gun goes left.
  check(
    'a blow from the right knocks the weapon to the left',
    heavy.view.weaponImpactVX < 0
      and Weight.relative(heavy.player, heavy.player.x - 3, heavy.player.z) > 0
  )
  check(
    'breaking the player guard holds the world for a beat',
    heavy.impactSlow > 0 and light.impactSlow == 0
  )
  -- One way into a view impulse (PLAN E5): a profile in data is the whole
  -- answer to an event, by its strength, direction and distance.
  local Impulses = require('src.feedback.impulses')
  local made = {
    reach = 10,
    near = 2,
    far = 0.5,
    weaponImpactVX = { base = 10, gain = 20, side = 1 },
    shake = { base = 0.2 },
  }
  local function answer(distance, motion)
    local t = fresh()
    t.view.weaponImpactVX, t.view.shake, t.view.motion = 0, 0, motion
    Impulses.react(t.view, made, 1, 1, 0, distance)
    return t.view
  end
  local close, middle, beyond, still = answer(0), answer(6), answer(10), answer(0, false)
  check(
    'a profile made only of data answers by strength, direction and distance',
    near(close.weaponImpactVX, 30)
      and near(close.shake, 0.2)
      and near(middle.weaponImpactVX, 22.5)
      and near(middle.shake, 0.15)
      and beyond.weaponImpactVX == 0
      and beyond.shake == 0
  )
  check(
    'reduced motion removes the hands answer and keeps the frame shake',
    still.weaponImpactVX == 0 and near(still.shake, 0.2)
  )
  local piled = fresh()
  piled.view.weaponImpactVX = 0
  for _ = 1, 3 do
    Impulses.react(piled.view, 'blow', 1.6, -1, 0)
  end
  local limit = require('src.content.view_reactions').channels.weaponImpactVX.limits[2]
  check('many blows sum within one shared limit', near(piled.view.weaponImpactVX, limit))
  local kept = fresh()
  kept.view.killPunch = 0
  Impulses.react(kept.view, 'shotKill')
  Impulses.react(kept.view, 'heavyStagger')
  check(
    'a weaker answer never lowers a stronger one',
    near(
      kept.view.killPunch,
      require('src.content.view_reactions').profiles.shotKill.killPunch.base
    )
  )
  check(
    'an answer on an undeclared channel stops the game',
    not pcall(Impulses.react, fresh().view, { undeclared = { base = 1 } })
  )
  -- Near miss: heard and marked, never damaging.
  g = fresh()
  local p = g.player
  local hp = p.hp
  g.bullets = {
    {
      x = p.x - 1.5,
      y = 1.05,
      z = p.z + 0.8,
      vx = 6,
      vy = 0,
      vz = 0,
      life = 3,
      packet = { base = 14, impact = 40, damageType = 'astral' },
    },
  }
  for _ = 1, 240 do
    P.update(g, 1 / 120, p)
  end
  check(
    'a projectile passing close is a near miss with a marker',
    p.hp == hp and g.view.hurtMarks and #g.view.hurtMarks == 1 and g.view.hurtMarks[1].miss
  )
  g = fresh()
  p = g.player
  g.bullets = { { x = p.x - 1.5, y = 1.05, z = p.z + 3, vx = 6, vy = 0, vz = 0, life = 3 } }
  for _ = 1, 240 do
    P.update(g, 1 / 120, p)
  end
  check('a projectile far away is not a near miss', not g.view.hurtMarks or #g.view.hurtMarks == 0)
  -- Wall slam: find a wall east of the player row.
  g = fresh()
  local row = 25
  local wallX
  for x = 17, g.world.size do
    if g.world.map[row][x] == 1 then
      wallX = x
      break
    end
  end
  local function slam(speed, kind)
    local r = A[kind or 'imp'].body.radius
    local t = fresh()
    local e = t:spawn(kind or 'imp', wallX - 0.5 - r - 0.05, row)
    e.awake = true
    local hp0 = e.hp
    e.pushX, e.pushZ = speed, 0
    for _ = 1, 30 do
      AI.update(t, 1 / 120, t.player)
    end
    return e, hp0, t
  end
  local hard, hp0, sg = slam(7)
  -- 7 m/s is 3.8 m/s over the threshold: 3.8*6 = 22.8 harm, 3.8*16 guard.
  check(
    'a body thrown into a wall takes the excess speed as harm and stagger',
    near(hp0 - hard.hp, 22.8, 1e-3) and (hard.staggerLock or 0) > 0 and sg.slams == 1
  )
  local soft, hp1 = slam(2)
  check(
    'a gentle shove against a wall is not a slam',
    soft.hp == hp1 and (soft.staggerLock or 0) == 0
  )
  local boss, hp2 = slam(7, 'furfur')
  check('a boss shrugs off a wall slam', boss.hp == hp2)
  -- Body against body: momentum is shared by mass, the guard is jolted.
  g = fresh()
  local a, b = g:spawn('imp', 14, row), g:spawn('imp', 14.6, row)
  a.awake, b.awake = true, true
  a.pushX, a.pushZ = 6, 0
  b.pushX, b.pushZ = 0, 0
  AI.update(g, 1 / 120, g.player)
  check(
    'a thrown body hands momentum to the body it hits',
    (b.pushX or 0) > 1 and a.pushX < 6 and (b.poise or 0) > 0 and g.collisions == 1
  )
  -- The player obeys the slam rule too, and a wall never kills.
  g = fresh()
  p = g.player
  p.armor = 0
  p.x, p.z = wallX - 0.5 - 0.22 - 0.02, row
  p.pushX, p.pushZ = 6, 0
  for _ = 1, 6 do
    g:update(1 / 120, {})
  end
  check(
    'the player thrown into a wall is hurt and stopped',
    p.hp < 100 and near(p.pushX, 0) and g.lastSlam and g.lastSlam.player
  )
  g = fresh()
  p = g.player
  p.hp = 1
  p.armor = 0
  p.x, p.z = wallX - 0.5 - 0.22 - 0.02, row
  p.pushX, p.pushZ = 6, 0
  for _ = 1, 6 do
    g:update(1 / 120, {})
  end
  check('a wall slam never delivers the killing blow', p.hp > 0 and g.state == 'playing')
  -- Confirmation: a shot that breaks the guard says so.
  g = fresh()
  local target = g:spawn('buer', 16, 21)
  target.hp = 1000
  target.maxHp = 1000
  g.player.weapon = 1
  g:shoot()
  check(
    'a guard-breaking shot confirms the break (marker, number, flash)',
    g.view.breakConfirm > 0
      and target.breakFlash > 0
      and g.view.damageNumbers[#g.view.damageNumbers].broke
  )
  check(
    'the incoming projectile colours are one per damage type',
    Weight.typeColor('poison') ~= Weight.typeColor('astral')
      and Weight.typeColor(nil) == Weight.typeColor('physical')
  )
  check(
    'slam tuning lives in the world defaults',
    A.defaults.slamSpeed > 0 and A.defaults.collideSpeed > 0
  )
  -- Fair projectiles: the collision radius is the painted radius from data.
  local function pass(offset, radius)
    local t = fresh()
    local q = t.player
    q.armor = 0
    t.bullets = {
      {
        x = q.x - 3,
        y = 1.0,
        z = q.z + offset,
        vx = 6,
        vy = 0,
        vz = 0,
        life = 2,
        radius = radius,
        packet = {
          base = 10,
          impact = 0,
        },
      },
    }
    for _ = 1, 120 do
      P.update(t, 1 / 120, q)
    end
    return q.hp < 100
  end
  check(
    'a projectile hits exactly within body + its own radius',
    pass(0.22 + 0.12 - 0.02, 0.12)
      and not pass(0.22 + 0.12 + 0.02, 0.12)
      and pass(0.22 + 0.26 - 0.02, 0.26)
      and not pass(0.22 + 0.26 + 0.02, 0.26)
  )
  -- Round pillars: shots, bodies and sight agree with the painted shaft.
  local B = require('src.combat.ballistics')
  local Wd = require('src.world.arena')
  local Col = require('src.physics.collision')
  g = fresh()
  local _, _, grazeKind = B.world(g.world, 10, 1.3, 24.45, 1, 0, 0, 4)
  local _, _, coreKind = B.world(g.world, 10, 1.3, 25.2, 1, 0, 0, 4)
  check(
    'a shot past the square corner of a round pillar flies on, one into the shaft stops',
    grazeKind == 'range' and coreKind == 'wall'
  )
  check(
    'a body may stand where the square corner used to be',
    not Wd.solid(g.world, 12.55, 25.55, 0.22)
      and Wd.solid(g.world, 12.4, 25.4, 0.22)
      and B.pillarRadius == Col.pillarRadius
  )
  -- The Judge retains 62% through flesh. H5: a painted metal plate stops the
  -- round completely; armor still reduces damage to the owner of that plate.
  local Damage = require('src.combat.damage')
  local function line(first, second)
    local t = fresh()
    -- Keep the physical material under this penetration probe fixed.
    t.mode, t.testField = 'field', {}
    t.player.weapon = 2
    local a = t:spawn(first, 16, 21.5)
    local b = t:spawn(second or 'imp', 16, 19.5)
    a.hp, a.maxHp, b.hp, b.maxHp = 5000, 5000, 5000, 5000
    a.previewFrame, b.previewFrame = 1, 1
    t:shoot()
    return t, a, b
  end
  local lg, la, lb = line('imp')
  local ray = lg.view.shotReport.rays[1]
  local attack = Weapons.attack(lg, 2)
  local hit
  for _, h in ipairs(lg.view.shotReport.hitTargets) do
    if h.id == lb.id then
      hit = h
    end
  end
  check(
    'the Judge round passes through the first body into the second',
    lb.hp < 5000 and la.hp < 5000 and lg.view.shotReport.pierced == 1 and hit and hit.pierced
  )
  local alone = Damage.resolve(attack, lb, hit.distanceMin, 'torso')
  check('a pierced body takes 62 % of the round', near(5000 - lb.hp, alone * 0.62, 0.5))
  local ag, aa, ab = line('armored')
  check(
    'a metal plate takes the impact and stops the round before the second body',
    aa.hp < 5000 and ab.hp == 5000 and not ag.view.shotReport.pierced
  )
  local sg2 = fresh()
  sg2.player.weapon = 1
  local s1, s2 = sg2:spawn('imp', 16, 21.5), sg2:spawn('imp', 16, 19.5)
  s1.hp, s2.hp = 5000, 5000
  sg2:shoot()
  check(
    'shotgun pellets stop in the first body',
    not sg2.view.shotReport.pierced and sg2.view.shotReport.origin ~= nil
  )
  -- The fall of a killed body: a hard throw lifts it, it lands and collapses.
  local Anim = require('src.enemies.animation')
  g = fresh()
  local body = g:spawn('imp', 16, 21)
  body.hp = 1
  g.player.weapon = 1
  g:shoot()
  check('a point-blank kill lifts the body off its feet', body.hp <= 0 and (body.fallVY or 0) > 0)
  local airFrame = Anim.pose(g, body)
  for _ = 1, 10 do
    AI.update(g, 1 / 120, g.player)
  end
  check(
    'a body in flight holds its first falling frame and rises',
    Anim.pose(g, body) == airFrame and (body.fallY or 0) > 0
  )
  for _ = 1, 120 do
    AI.update(g, 1 / 120, g.player)
  end
  check(
    'the thrown body lands, collapses and comes to rest',
    body.fallLanded and body.fallY == 0 and Anim.pose(g, body) == 18 and math.abs(body.pushZ) < 0.01
  )
  local function fallTrace(dt)
    local t = fresh()
    local e = t:spawn('imp', 16, 15)
    e.hp = 0
    e.pushX, e.pushZ = 0, -7
    e.fallVY = 1.5
    e.fallY = 0
    for _ = 1, math.floor(1 / dt + 0.5) do
      AI.update(t, dt, t.player)
    end
    return e.z, e.fallLanded
  end
  local z1, l1 = fallTrace(1 / 120)
  local z2, l2 = fallTrace(1 / 30)
  check(
    'the fall is integrated in closed form (frame rate independent)',
    near(z1, z2, 1e-6) and near(l1, l2, 1e-9)
  )
  -- Flinch: heavier bodies give way less; the pain pose lasts the stagger.
  local function flinch(kind)
    local t = fresh()
    local e = t:spawn(kind, 16, 21)
    Rules.react(t, e, 60, true, { e.x + 0.2, 1.2, e.z }, 10)
    return e.flinch, math.abs(e.flinchLeanV)
  end
  local fi, vi = flinch('imp')
  local fa, va = flinch('armored')
  check('a heavier body flinches less from the same blow', fa < fi and va < vi)
  g = fresh()
  local s = g:spawn('buer', 16, 21)
  s.ai = 'hurt'
  s.phase = 0.4
  s.stun = 0.3
  check('the pain pose is held for the whole stagger', Anim.pose(g, s) == 9)
  local Geometry = require('src.enemies.geometry')
  if Geometry.layouts.imp then
    g = fresh()
    local h = g:spawn('imp', 16, 21)
    h.ai = 'idle'
    local Surface = require('src.enemies.surface')
    local function headX()
      return (Surface.locate(Surface.prepare(g, h), 'head'))
    end
    local rest = headX()
    h.flinchLean = 0.06
    local leaned = headX()
    check(
      'the painted head a shot meets follows the flinch lean of the body',
      math.abs(leaned - rest) > 0.02
    )
  end
  -- The hero's weapon: view punch and shove settle before the next shot.
  g = fresh()
  g.player.weapon = 2
  g:shoot()
  g:update(1 / 120, {})
  local rose = g.view.viewPunch > 0 and g.view.kickBack > 0
  for _ = 1, math.floor(Weapons.profile(2).cycle * 120) do
    g:update(1 / 120, {})
  end
  check(
    'the view punch rises and settles before the next revolver shot',
    rose and math.abs(g.view.viewPunch) < 0.0015 and math.abs(g.view.kickBack) < 0.05
  )
  g = fresh()
  g.player.weapon = 1
  g:shoot()
  for _ = 1, 4 do
    g:update(1 / 120, {})
  end
  local shotgunPunch = g.view.viewPunch
  g = fresh()
  g.player.weapon = 2
  g:shoot()
  for _ = 1, 4 do
    g:update(1 / 120, {})
  end
  check(
    'the heavy shotgun punches the view harder than the revolver',
    shotgunPunch > g.view.viewPunch * 1.3
  )
  g = fresh()
  g.view.motion = false
  g.player.weapon = 1
  g:shoot()
  g:update(1 / 120, {})
  check(
    'reduced motion setting disables view punch and shove',
    g.view.viewPunch == 0 and (g.view.kickBack or 0) == 0
  )
  -- Landing dips the view; low health is heard.
  g = fresh()
  p = g.player
  p.jump = 1.2
  p.jumpV = 0
  for _ = 1, 60 do
    g:update(1 / 120, {})
  end
  check('a landing dips the view', (g.view.viewPunchV or 0) ~= 0 or (g.view.viewPunch or 0) < 0)
  g = fresh()
  p = g.player
  p.hp = 12
  for _ = 1, 480 do
    g:update(1 / 120, {})
  end
  local fast = g.view.heartbeats or 0
  g = fresh()
  g.player.hp = 29
  for _ = 1, 480 do
    g:update(1 / 120, {})
  end
  check(
    'under 30 HP the heart is heard, faster as health fails',
    fast > (g.view.heartbeats or 0) and (g.view.heartbeats or 0) >= 2
  )
end
return Tests

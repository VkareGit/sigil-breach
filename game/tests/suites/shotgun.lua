local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, initial, renderer, getGame)
  -- Rules proven on the encounters they were tuned for (tests/support/v033_encounters.lua).
  G = require('tests.support.v033_encounters').game(G)
  local B = require('src.combat.ballistics')
  local C = require('src.combat.combat')
  local F = require('src.player.feel')
  local R = require('src.combat.reload')
  local T = require('src.content.tuning')
  local AI = require('src.enemies.ai')
  local Anim = require('src.enemies.animation')
  local V = require('src.render.weapon')
  local lines = {}
  local function check(name, value)
    lines[#lines + 1] = (value and 'PASS ' or 'FAIL ') .. name
    if not value then
      error('v05: ' .. name)
    end
  end
  local near = Fixtures.within(0.001)
  local g
  local function fresh()
    -- Isolate action serials, idle-pose phase/IDs, RNG and presentation too.
    -- Resetting only HP/ammo carried earlier fixture poses into later shots.
    g = G.new()
    g.testing = true
    g.state = 'playing'
    g.enemies = {}
    g.bullets = {}
    g.hazards = {}
    g.pickups = {}
    g.elapsed = 0
    g.nextAttack = 0
    g.map = false
    g.help = false
    g.player.cooldown = 0
    g.player.reload = 0
    g.player.weapon = 1
    require('src.session.stats').reset(g)
    g.player.shots = 0
    g.player.hits = 0
    require('src.world.arena').breakSeals(g.world, 0)
    require('src.session.encounter').setGuardian(g, false, false)
    g.player = require('tests.support.fixtures').actor({
      x = 16,
      z = 27,
      yaw = math.pi,
      pitch = 0,
      hp = 100,
      armor = 0,
      souls = 0,
      abilities = { 'powder' },
      abilityState = { powder = { uses = 2, readyAt = 0 } },
      loadout = { 'exorcist', 'judge' },
      arsenal = select(
        2,
        require('tests.support.fixtures').arsenal({ exorcist = { 2, 38 }, judge = { 6, 24 } })
      ),
      dash = 2,
      dashTimer = 0,
      jump = 0,
      jumpV = 0,
      invuln = 0,
    })
    F.init(g)
    g.player.arsenal.judge.readyAt = 0
    g.player.abilityState.powder.readyAt = 0
    g.charges = {}
  end
  local function step(t, input)
    for _ = 1, math.floor(t * 120 + 0.5) do
      g:update(1 / 120, input or {})
    end
  end
  fresh()
  -- Aim between the painted shoulders: 20 real contacts across two separate healthy bodies.
  -- The former 4 m fixture clipped empty silhouette edges and lost one pellet.
  g.player.pitch = 0.04
  local a = g:spawn('imp', 15.65, 23.5)
  local b = g:spawn('imp', 16.35, 23.5)
  g:shoot()
  check(
    'one aimed shotgun volley kills two healthy adjacent imps',
    a.hp <= 0 and b.hp <= 0 and g.view.shotReport.kills == 2
  )
  check(
    'multi-kill consumes only the two fired shells',
    g.player.arsenal.exorcist.mag == 0
      and g.player.arsenal.exorcist.reserve == 38
      and g.player.shots == 1
  )
  check(
    'each pellet has its own collision and damage accounting',
    #g.view.shotReport.rays == 20
      and g.view.shotReport.pelletsHit <= 20
      and g.view.shotReport.damage
        <= 12 * (20 + g.view.shotReport.headHits * (T.shotgunHeadMultiplier - 1)) + 0.001
  )
  check(
    'two-target volley gives explicit feedback',
    g.view.feedback:find('2 DEMONS', 1, true) and g.view.lastKill
  )
  fresh()
  -- At 7 m the spread spans three separated torsos (all 45 HP), not skull horns.
  g.player.pitch, g.player.yaw = -0.02, math.pi + 0.02
  for _, x in ipairs({ 15, 16, 17 }) do
    local e = g:spawn('imp', x, 20)
    e.hp = 45
  end
  g:shoot()
  check('wide spread can finish three wounded targets', g.view.shotReport.kills == 3)
  fresh()
  g.player.pitch = 0.04
  a = g:spawn('imp', 16, 25)
  b = g:spawn('imp', 16, 23)
  g:shoot()
  check(
    'front body blocks pellets even when this volley kills it',
    a.hp <= 0 and b.hp == b.maxHp and g.view.shotReport.targets == 1
  )
  local result = { a.hp, b.hp }
  fresh()
  g.player.pitch = 0.04
  a = g:spawn('imp', 16, 25)
  b = g:spawn('imp', 16, 23)
  -- Reverse the same identities/poses, not which body receives each idle ID.
  g.enemies = { b, a }
  g:shoot()
  check(
    'collision result is independent of enemy array order',
    near(a.hp, result[1]) and b.hp == result[2]
  )
  fresh()
  a = g:spawn('imp', 16, 25)
  b = g:spawn('imp', 16, 23)
  g:shoot()
  check(
    'pellets through real painted gaps can reach the rear body without penetration',
    b.hp < b.maxHp
      and g.view.shotReport.targets == 2
      and not require('src.content.weapons').attack(g, 1).pierce
  )
  fresh()
  g.player.pitch = 0.04
  a = g:spawn('imp', 15.65, 23.5)
  b = g:spawn('imp', 16.35, 23.5)
  b.hp = 1000
  g:shoot()
  check(
    'mixed kill and wound keeps gold kill confirmation',
    g.view.shotReport.kills == 1 and g.view.lastKill and g.view.lastDamage > 150
  )
  fresh()
  g.player.x = 13
  g.player.z = 25
  g.player.yaw = -math.pi / 2
  a = g:spawn('imp', 11, 25)
  g:shoot()
  check(
    'all shotgun pellets respect a blocking pillar',
    a.hp == a.maxHp and g.view.shotReport.targets == 0
  )
  fresh()
  a = g:spawn('imp', 18.3, 21)
  g:shoot()
  check('outside-cone enemy takes no area damage', a.hp == a.maxHp)
  fresh()
  g.player.pitch = -0.65
  a = g:spawn('imp', 16, 21)
  g:shoot()
  check('pellets hitting floor cannot continue through a target', a.hp == a.maxHp)
  local small, large = math.tan(T.pelletSpread) * 3, math.tan(T.pelletSpread) * 9
  check('spread footprint triples between 3 and 9 metres', near(large, small * 3))
  fresh()
  a = g:spawn('imp', 16, 24)
  -- A body volume as the explicit representation describes one (enemies/
  -- geometry.lua): the cylinder primitive itself, independent of any atlas.
  local head = { x = a.x, z = a.z, radius = 0.2, bottom = 1.55, top = 1.95 }
  local capDistance = B.cylinderShape(
    head,
    head.x,
    head.top + 1,
    head.z,
    0,
    -1,
    0,
    24,
    head.radius,
    head.bottom,
    head.top
  )
  check('analytic custom cylinder primitive accepts a descending cap entry', near(capDistance, 1))
  local e
  fresh()
  a = g:spawn('imp', 16, 26.999)
  e = B.trace(g, math.pi, 0, 24)
  check('a painted body one millimetre beyond the muzzle still receives the ray', e == a)
  local dd, n, kind = B.world(g.world, 13, 1.38, 25, -1, 0, 0, 24) -- 0.14: a round pillar stops shots at its painted radius, not its square cell.
  check(
    'grid traversal finds exact round pillar surface',
    near(dd, 1 - B.pillarRadius) and kind == 'wall' and near(n[1], 1)
  )
  dd, n, kind = B.world(g.world, 16, 1.38, 27, 0, -1, 0, 24)
  check('vertical ray hits floor without division errors', near(dd, 1.355) and kind == 'floor')
  fresh()
  g.player.arsenal.exorcist.mag = 1
  g.player.arsenal.exorcist.reserve = 0
  g.player.pitch = 0.06
  -- At 1.5 m all ten pellets land on flesh (120 total), not the horn/wing edge.
  a = g:spawn('imp', 16, 25.5)
  g:shoot()
  check(
    'single shell fires ten pellets at unchanged per-pellet damage',
    g.view.shotReport.pellets == 10
      and g.view.shotReport.damage <= 12 * (10 + g.view.shotReport.headHits * (T.shotgunHeadMultiplier - 1)) + 0.001
      and a.hp <= 0
  )
  check('single-shell recoil is scaled', g.view.shotPower == 0.5 and g.view.recoilV == 12)
  fresh()
  a = g:spawn('stolas', 16, 23)
  a.ai = 'windup'
  a.windup = 0.6
  a.windupDuration = 0.74
  a.aimX = 16
  a.aimZ = 27
  g:damageEnemy(a, 12)
  C.react(g, a, 12, true, { 16, 1.4, 23 })
  check(
    'one pellet does not cancel a committed spell',
    a.ai == 'windup' and a.stun == 0 and a.windup == 0.6
  )
  check('minor hit leaves current animation playing', Anim.pose(g, a) >= 7 and Anim.pose(g, a) <= 9)
  local weak = math.abs(a.pushZ)
  g:damageEnemy(a, 60)
  C.react(g, a, 60, true, { 16, 1.4, 23 })
  check(
    'solid blast interrupts and pushes harder',
    a.ai == 'hurt' and a.stun > 0 and math.abs(a.pushZ) > weak * 2
  )
  check(
    'target impact pause does not freeze the whole encounter',
    a.hitPause > 0 and g.impactSlow == 0
  )
  fresh()
  a = g:spawn('stolas', 16, 21)
  a.hp = 10000
  a.attack = 0
  g.player.weapon = 2
  g.player.hp = 10000
  for _ = 1, 480 do
    g.player.yaw = math.atan2(a.x - g.player.x, a.z - g.player.z)
    g:update(1 / 120, { shoot = true })
  end
  check('continuous revolver fire cannot permanently stun-lock a caster', a.attackCount > 0)
  fresh()
  a = g:spawn('imp', 16, 24)
  g:shoot()
  local z = a.z
  step(0.15)
  check('lethal blast carries corpse into its fall', a.z < z - 0.1)
  fresh()
  g:shoot()
  step(0.25)
  check(
    'shells do not eject before breech opens',
    #g.view.shells == 0 and not g.player.arsenal.exorcist.open
  )
  step(0.025)
  check(
    'opening ejects exactly the spent pair',
    #g.view.shells == 2 and g.player.arsenal.exorcist.open and g.player.arsenal.exorcist.spent == 0
  )
  step(0.31)
  check(
    'ammo is not credited before insertion',
    g.player.arsenal.exorcist.mag == 0 and g.player.arsenal.exorcist.reserve == 38
  )
  step(0.025)
  check(
    'insertion commits two shells once',
    g.player.arsenal.exorcist.mag == 2 and g.player.arsenal.exorcist.reserve == 36
  )
  check('gun cannot fire while loaded but open', not g:shoot())
  g:switchWeapon(2)
  g:switchWeapon(1)
  check(
    'returning to a loaded open gun resumes closing',
    g.player.reload > 0 and g.player.reloadOffset == 0.68
  )
  step(0.27)
  check('weapon swap cannot bypass original firing cadence', not g:shoot())
  step(0.08)
  check('closed gun fires after original cadence ends', g:shoot())
  fresh()
  g:shoot()
  step(0.35)
  g:switchWeapon(2)
  g:switchWeapon(1)
  step(0.45)
  check(
    'cancel and resume never duplicates ejected shells',
    #g.view.shells <= 2 and g.player.arsenal.exorcist.mag + g.player.arsenal.exorcist.reserve == 38
  )
  fresh()
  g.player.arsenal.exorcist.mag = 0
  g:reloadGun()
  step(0.12)
  check('manual loading of an empty gun invents no spent casings', #g.view.shells == 0)
  fresh()
  g.player.arsenal.exorcist.mag = 1
  g.player.arsenal.exorcist.reserve = 0
  g:shoot()
  g.player.arsenal.exorcist.reserve = 4
  step(1)
  g:reloadGun()
  step(0.12)
  check('one fired shell ejects exactly one casing', #g.view.shells == 1)
  fresh()
  g:shoot()
  step(0.4)
  local before = g.player.reload
  g:reloadGun()
  check('repeated reload input does not restart timeline', g.player.reload == before)
  fresh()
  g.player.arsenal.exorcist.mag = 0
  g:reloadGun()
  local Art = require('src.content.weapon_art')
  local entry = require('src.render.weapon_art').of(g)
  local first = V.frame(g)
  local noFlash = true
  local counts = {}
  for _ = 1, 110 do
    counts[V.frame(g)] = true
    noFlash = noFlash and V.muzzlePhase(g) == nil
    g:update(1 / 120, {})
  end
  for _, phase in ipairs(entry.phases.fire) do
    noFlash = noFlash and not counts[Art.frame(entry, phase.frame)]
  end
  check(
    'manual reload skips the muzzle flash',
    noFlash
      and counts[first]
      and counts[Art.variant(
        entry,
        Art.frame(entry, entry.open.primed),
        g.player.arsenal.exorcist.mag
      )]
  )
  fresh()
  a = g:spawn('stolas', 16, 24)
  a.ai = 'move'
  a.walkSpeed = 2
  a.facing = 0
  local frames = {}
  for i = 0, 60 do
    a.walk = i * 0.025
    g.time = i * 0.025
    frames[Anim.pose(g, a)] = true
  end
  local count = 0
  for _ in pairs(frames) do
    count = count + 1
  end
  check('Stolas uses six moving poses', count == 6)
  a.ai = 'windup'
  a.windupDuration = 0.74
  a.windup = 0.70
  local f1 = Anim.pose(g, a)
  a.windup = 0.35
  local f2 = Anim.pose(g, a)
  a.windup = 0.05
  local f3 = Anim.pose(g, a)
  check('Stolas builds a cast through three anticipation poses', f1 == 7 and f2 == 8 and f3 == 9)
  for _, sheet in ipairs({
    { 'stolas', require('src.content.enemy_art').entries.stolas.path },
    { 'exorcist', require('src.render.weapon_art').exorcist.path },
  }) do
    local data = love.image.newImageData(sheet[2])
    local _, _, _, alpha = data:getPixel(0, 0)
    check(sheet[1] .. ' sheet has actual alpha transparency', alpha < 0.05)
    data:release()
  end
  local balance = {
    'SIGIL 0.5 / measured shotgun balance',
    'Stationary centered aim; two full shells; original Limbo geometry.',
    'distance m | damage on one imp | pellets hit | pair kills / 2',
  }
  local damageAt = {}
  for _, distance in ipairs({ 2, 3, 4, 5, 6, 8, 10, 14, 18 }) do
    fresh()
    a = g:spawn('imp', 16, 27 - distance)
    a.hp = 1000
    g:shoot()
    local damage, pellets = 1000 - a.hp, g.view.shotReport.pelletsHit
    damageAt[distance] = damage
    fresh()
    g:spawn('imp', 15.54, 27 - distance)
    g:spawn('imp', 16.46, 27 - distance)
    g:shoot()
    balance[#balance + 1] = string.format(
      '%10.1f | %17.1f | %11d | %d',
      distance,
      damage,
      pellets,
      g.view.shotReport.kills
    )
  end
  check(
    'shotgun damage decreases meaningfully over distance',
    damageAt[3] > damageAt[6] and damageAt[6] > damageAt[10] and damageAt[10] > damageAt[18]
  )
  balance[#balance + 1] = ''
  balance[#balance + 1] =
    '20 pellets x 12 damage, spread +/-8.59 deg horizontal, +/-5.16 deg vertical envelope; actual pattern is flatter.'
  balance[#balance + 1] =
    'Falloff starts at 4 m, reaches 40% per-pellet damage at 18 m. Cycle 0.94 s.'
  balance[#balance + 1] =
    'Each target blocks the pellets it intercepts; no damage radius or automatic penetration.'
  local file = assert(io.open(require('qa.output').path('classic-balance.txt'), 'w'))
  file:write(table.concat(balance, '\n') .. '\n')
  file:close()
  print(table.concat(balance, '\n'))
  -- The old arena under the encounters it was tuned for; it leaves with the waves.
  local run = require('qa.scenarios.classic_playtest').run(G)
  check(
    'full Limbo can be completed with real combat and movement inputs',
    run.state == 'won' and run.seals == 3 and run.kills == 13
  )
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests

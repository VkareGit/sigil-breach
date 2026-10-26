local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, initial, renderer, getGame)
  local W = require('src.world.arena')
  local F = require('src.player.feel')
  local C = require('src.combat.combat')
  local V = require('src.render.weapon')
  local U = require('src.ui.interface')
  local A = require('src.audio.audio')
  local T = require('src.content.tuning')
  A.muted = true
  love.mouse.setRelativeMode(false)
  love.math.setRandomSeed(42)
  local lines = {}
  local function check(n, v)
    lines[#lines + 1] = (v and 'PASS ' or 'FAIL ') .. n
    if not v then
      error('Test failed: ' .. n)
    end
  end
  local near = Fixtures.within(0.001)
  local g = initial
  local function fresh()
    g.nextAttack = 0
    g.hazards = {}
    g.score = 0
    g.combo = 0
    g.comboTimer = 0
    g.view.feedbackTimer = 0
    g.damageTaken = 0
    g.world.secretFound = false
    g.help = false
    g.enemies = {}
    g.bullets = {}
    g.view.particles = {}
    g.pickups = {}
    g.state = 'playing'
    g.kills = 0
    g.map = false
    g.elapsed = 0
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
    g.player.weapon = 1
    g.player.cooldown, g.player.reload, g.player.shots, g.player.hits = 0, 0, 0, 0
    F.init(g)
    g.flowTimer = 0
    g.player.arsenal.judge.readyAt = 0
    g.player.abilityState.powder.readyAt = 0
    g.charges = {}
    for _, s in ipairs(g.world.seals) do
      s.active = false
    end
  end
  local function tick(seconds, input, hz)
    hz = hz or 120
    for i = 1, math.floor(seconds * hz + 0.5) do
      g:update(1 / hz, input or {})
    end
  end
  local field = W.flow(g.world, 16, 27)
  for _, s in ipairs(g.world.seals) do
    check(
      'path to ' .. s.name,
      field[math.floor(s.z + 0.5) * g.world.size + math.floor(s.x + 0.5)] ~= nil
    )
  end
  check('path to exit', field[3 * g.world.size + 16] ~= nil)
  local travel = {}
  for _, hz in ipairs({ 30, 60, 120 }) do
    fresh()
    tick(1, { forward = 1 }, hz)
    travel[#travel + 1] = 27 - g.player.z
  end
  check(
    'movement matches at 30 / 60 / 120 Hz',
    math.max(unpack(travel)) - math.min(unpack(travel)) < 0.08
  )
  check('run speed is responsive', travel[3] > 4.8 and travel[3] < 5.3)
  fresh()
  tick(1, { forward = 1, strafe = 1 })
  local diagonal = math.sqrt((g.player.x - 16) ^ 2 + (g.player.z - 27) ^ 2)
  check('diagonal speed normalized', near(diagonal, travel[3], 0.08))
  fresh()
  tick(0.5, { forward = 1 })
  local z = g.player.z
  tick(0.15)
  check('release brakes within 25 cm', z - g.player.z < 0.25 and g.player.vz == 0)
  fresh()
  tick(0.3, { forward = 1 })
  tick(0.2, { forward = -1 })
  check('direction reversal is immediate enough', g.player.vz > 4.9)
  fresh()
  g:dash(0, -1)
  tick(0.16)
  check('dash travels 2 to 2.7 metres', 27 - g.player.z > 2 and 27 - g.player.z < 2.7)
  check('dash consumes one charge', g.player.dash < 1.2)
  tick(1.4)
  check('dash refills', g.player.dash == 2)
  -- 0.14 open arena: the nave wall is the x=8 cell (face at 8.5).
  fresh()
  g.player.x = 9
  g.player.z = 28
  g:dash(-1, 0)
  tick(0.3)
  check(
    'dash cannot tunnel through wall',
    g.player.x > 8.7 and not W.solid(g.world, g.player.x, g.player.z, 0.21)
  )
  fresh()
  g.player.jumpBuffer = 0.12
  tick(0.20, { forward = 1 })
  check('jump buffer is honored', g.player.jump > 0.6)
  local airborneX = g.player.x
  local airborneVX = g.player.vx
  tick(0.15, { strafe = 1 })
  check(
    'air control follows integrated acceleration',
    math.abs((g.player.x - airborneX) - (airborneVX + g.player.vx) * 0.5 * 0.15) < 0.0001
      and g.player.x < airborneX - 0.19
  )
  tick(1)
  check('jump lands on floor', g.player.jump == 0)
  fresh()
  tick(1.3, { jump = true })
  check('holding jump supports repeated hops', g.player.jump > 0)
  fresh()
  local e = g:spawn('imp', 16, 24)
  check('shotgun fires on press', g:shoot())
  check('shot uses both barrels', g.player.arsenal.exorcist.mag == 0)
  check('close shotgun hit is lethal', e.hp <= 0)
  check(
    'hit feedback is immediate',
    g.view.hitmarker > 0 and g.view.recoilV > 0 and #g.view.traces > 0
  )
  check('shot immediately begins automatic cycle', g.player.reload > 0 and V.frame(g) == 2)
  local art = require('src.content.weapon_art')
  local entry = require('src.render.weapon_art').of(g)
  local observed, expected = {}, {}
  local function append(sequence, index)
    if sequence[#sequence] ~= index then
      sequence[#sequence + 1] = index
    end
  end
  -- A full reload must visit its authored phases in order. Partial-magazine
  -- leaf poses are covered separately; they cannot all appear in this cycle.
  for _, phase in ipairs(entry.phases.fire) do
    append(expected, art.variant(entry, art.frame(entry, phase.frame), 0))
  end
  local start = 0
  for _, phase in ipairs(entry.phases.reload) do
    if phase.finish > entry.automaticFireUntil then
      local index = art.frame(entry, phase.frame)
      local frame = entry.frames[index]
      -- Both shells load at reloadLoadTime; before it a 'loading' pose shows
      -- the pair pushed home but for those its hand still holds.
      local rounds = start >= T.reloadLoadTime and 2 or 0
      if start < T.reloadLoadTime and frame.roundsSource == 'loading' then
        rounds = math.max(0, 2 - frame.inHand)
      end
      append(expected, art.variant(entry, index, rounds))
    end
    start = phase.finish
  end
  append(expected, art.frame(entry, entry.ready))
  append(observed, V.frame(g))
  for i = 1, 120 do
    g:update(1 / 120, {})
    append(observed, V.frame(g))
  end
  local ordered = #observed == #expected
  for index, frame in ipairs(expected) do
    ordered = ordered and observed[index] == frame
  end
  check('automatic cycle reaches its authored phases and round variants in order', ordered)
  check(
    'automatic reload commits exactly two shells',
    g.player.arsenal.exorcist.mag == 2 and g.player.arsenal.exorcist.reserve == 36
  )
  check(
    'weapon is ready again in under one second',
    g.player.cooldown == 0 and g.player.reload == 0
  )
  fresh()
  g:shoot()
  tick(0.3, { forward = 1 })
  check('reload does not lock movement', g.player.z < 26)
  g:switchWeapon(2)
  check('switch cancels reload', g.player.reload == 0 and g.player.arsenal.exorcist.mag == 0)
  g:switchWeapon(1)
  g:reloadGun()
  tick(0.6)
  local total = g.player.arsenal.exorcist.mag + g.player.arsenal.exorcist.reserve
  g:switchWeapon(2)
  g:switchWeapon(1)
  tick(1)
  check(
    'cancel after insert cannot duplicate ammo',
    total == 38 and g.player.arsenal.exorcist.mag + g.player.arsenal.exorcist.reserve == 38
  )
  fresh()
  g:shoot()
  tick(T.shotgunCycle - 0.08)
  g.player.fireBuffer = 0.12
  tick(0.12)
  check('late trigger press is buffered into next shot', g.player.shots == 2)
  fresh()
  g.player.arsenal.exorcist.reserve = 0
  g.player.arsenal.exorcist.mag = 0
  g:shoot()
  check('empty shotgun never produces phantom hit', g.player.shots == 0)
  g:switchWeapon(2)
  tick(0.21)
  check(
    'revolver uses its own ammunition when shotgun is empty',
    g:shoot() and g.player.arsenal.judge.mag == 5
  )
  fresh()
  g.player.weapon = 2
  local front = g:spawn('imp', 16, 24)
  local back = g:spawn('imp', 16, 23)
  g:shoot()
  check(
    '0.14: the Judge round pierces the nearest enemy and loses power',
    front.hp < front.maxHp
      and back.hp < back.maxHp
      and back.maxHp - back.hp < front.maxHp - front.hp
  )
  fresh()
  g.player.weapon = 2
  g.player.x = 13
  g.player.z = 25
  g.player.yaw = -math.pi / 2
  e = g:spawn('imp', 11, 25)
  g:shoot()
  check('pillar blocks hitscan', e.hp == e.maxHp)
  fresh()
  g.player.pitch = 0.9
  e = g:spawn('imp', 16, 24)
  g:shoot()
  check('vertical aiming misses correctly', e.hp == e.maxHp)
  fresh()
  e = g:spawn('buer', 16, 24)
  e.hp = 1000
  g:shoot()
  local close = 1000 - e.hp
  fresh()
  e = g:spawn('buer', 16, 15)
  e.hp = 1000
  g:shoot()
  check('spread reduces distant shotgun damage', 1000 - e.hp < close * 0.7)
  fresh()
  e = g:spawn('buer', 16, 24)
  e.hp = 1000
  e.windup = 0.5
  g:shoot()
  check(
    'shotgun staggers and interrupts regular enemy',
    e.stun > 0 and e.windup == 0 and e.pushZ < 0
  )
  fresh()
  g.player.weapon = 2
  e = g:spawn('boss', 16, 22)
  e.windup = 0.5
  g:shoot()
  check('boss cannot be stunlocked by revolver', e.stun == 0 and e.windup == 0.5)
  fresh()
  g.player.hp = 60
  e = g:spawn('imp', 16, 24)
  g:shoot()
  check('close firearm kill has no supernatural healing', e.hp <= 0 and g.player.hp == 60)
  fresh()
  g.player.hp = 60
  e = g:spawn('imp', 16, 23)
  g:cast(1)
  check(
    'charge consumes one item without instant damage or healing',
    g.player.abilityState.powder.uses == 1
      and #g.charges == 1
      and e.hp == e.maxHp
      and g.player.hp == 60
  )
  fresh()
  g.player.armor = 40
  g:damagePlayer(20)
  check('armor splits damage', g.player.hp == 91 and g.player.armor == 29)
  g:damagePlayer(20)
  check('damage immunity prevents duplicate hit', g.player.hp == 91)
  fresh()
  g:dash(0, -1)
  g:damagePlayer(30)
  check('dash provides short immunity', g.player.hp == 100)
  fresh()
  e = g:spawn('imp', 16, 26.1)
  e.attack = 0
  e.awake = true
  tick(1 / 120)
  check('melee attack is telegraphed', e.windup > 0 and g.player.hp == 100)
  tick(0.7)
  check('melee attack connects', g.player.hp < 100)
  fresh()
  e = g:spawn('stolas', 16, 22)
  e.attack = 0
  e.awake = true
  tick(0.95)
  check('caster launches visible projectile', #g.bullets > 0)
  tick(1.5)
  check('projectile connects', g.player.hp < 100)
  fresh()
  e = g:spawn('imp', 11, 24)
  e.awake = true
  e.memory = 5
  e.lastX = 16
  e.lastZ = 27
  tick(3)
  check(
    'enemy can path around pillars',
    math.sqrt((e.x - 16) ^ 2 + (e.z - 27) ^ 2) < 3 and not W.solid(g.world, e.x, e.z, 0.19)
  )
  fresh()
  check('far interaction cannot break seal', not g:interact())
  for i, s in ipairs(g.world.seals) do
    g.player.x = s.x
    g.player.z = s.z + 1.5
    check('seal ' .. i .. ' activates', g:interact())
    local n = #g.enemies
    g:interact()
    check('seal ' .. i .. ' cannot duplicate wave', #g.enemies == n)
  end
  tick(1 / 120)
  check('boss waits for all defenders', not require('src.session.encounter').guardianSpawned(g))
  for _, en in ipairs(g.enemies) do
    g:damageEnemy(en, 10000)
  end
  tick(1 / 120)
  check(
    'boss appears after three clear courts',
    require('src.session.encounter').guardianSpawned(g) and #g.enemies == 10
  )
  local boss = g.enemies[#g.enemies]
  g.player.x, g.player.z = 16, 15
  g.player.hp = 100
  g.player.armor = 100
  g.player.yaw = math.pi
  g.player.pitch = 0.04
  g.player.weapon = 2
  for i = 1, 10000 do
    if boss.hp <= 0 or g.state == 'dead' then
      break
    end
    g.player.yaw = math.atan2(boss.x - g.player.x, boss.z - g.player.z)
    g:update(
      1 / 120,
      { shoot = true, strafe = math.sin(i / 75) > 0 and 1 or -1, dash = i % 180 == 0 }
    )
  end
  check('boss is beatable through real combat', boss.hp <= 0 and g.state == 'playing')
  check('boss death unlocks exit', require('src.session.encounter').guardianDead(g))
  g.player.x, g.player.z = 16, 4
  g:interact()
  check('exit reaches completion', g.state == 'won')
  fresh()
  g.player.hp = 1
  g:damagePlayer(30)
  check('death stops play', g.state == 'dead')
  -- Every stage of every reload mechanism has its own sound.
  local voiced = A.sources.shot and A.sources.revolver
  for _, mechanism in pairs(require('src.combat.reload').mechanisms) do
    for _, stage in ipairs({ 'open', 'load', 'close' }) do
      voiced = voiced and A.sources[mechanism.voices[stage]]
    end
  end
  check('mechanical sounds available', voiced)
  check('large font supports Polish', U.fonts[36]:hasGlyphs('ĄĆĘŁŃÓŚŹŻ'))
  -- The sheets drawn in play: a demon atlas and both weapon sheets.
  local WeaponArt = require('src.render.weapon_art')
  for _, sheet in ipairs({
    { 'imp', require('src.content.enemy_art').entries.imp.path },
    { 'exorcist', WeaponArt.exorcist.path },
    { 'judge', WeaponArt.judge.path },
  }) do
    local data = love.image.newImageData(sheet[2])
    local _, _, _, a = data:getPixel(20, 20)
    check(sheet[1] .. ' sheet has transparent background', a < 0.05)
    data:release()
  end
  love.keypressed('return', 'return')
  check('Enter starts new game', getGame().state == 'playing')
  love.keypressed('2', '2')
  check('number key switches weapon', getGame().player.weapon == 2)
  love.mousemoved(640, 360, 40, -30)
  check(
    'raw mouse input updates view',
    getGame().player.pitch > 0 and getGame().player.yaw > math.pi
  )
  love.keypressed('tab', 'tab')
  local elapsed = getGame().elapsed
  getGame():update(1 / 120, { shoot = true })
  check('map pauses gameplay', getGame().map and elapsed == getGame().elapsed)
  love.keypressed('escape', 'escape')
  love.keypressed('escape', 'escape')
  check('pause releases cursor', getGame().state == 'paused' and not love.mouse.getRelativeMode())
  love.keypressed('c', 'c')
  check('camera motion can be disabled', getGame().view.motion == false)
  love.keypressed('c', 'c')
  love.keypressed('return', 'return')
  check('resume restores gameplay', getGame().state == 'playing')
  love.focus(false)
  check('focus loss auto pauses', getGame().state == 'paused')
  love.keypressed('r', 'r')
  check(
    'restart clears run progress',
    getGame().kills == 0 and require('src.world.arena').activeSeals(getGame().world) == 0
  )
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests

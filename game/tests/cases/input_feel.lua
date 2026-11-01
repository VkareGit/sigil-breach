-- Input lifetime and physical presentation contracts. These tests use no GPU.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local Intent = require('src.player.intent')
  local Gait = require('src.player.movement_gait')
  local Weight = require('src.feedback.weight')
  local Motion = require('src.feedback.weapon_motion')
  local Feel = require('src.player.feel')
  local Weapons = require('src.content.weapons')
  local Audio = require('src.audio.audio')
  local near = Fixtures.within(1e-6)
  local function fresh()
    local g = G.new('floor')
    g.ephemeral = true
    g.state = 'playing'
    g.enemies = {}
    g.bullets = {}
    g.pickups = {}
    g.player.x, g.player.z, g.player.yaw = 16, 25, math.pi
    return g
  end
  local g = fresh()
  check(
    'intent queue rejects unknown actions without changing either buffer',
    not Intent.queue(g, 'reload') and g.player.fireBuffer == 0 and g.player.jumpBuffer == 0
  )
  Intent.queue(g, 'jump')
  g.player.jumpBuffer = 0.001
  check(
    'a grounded tap survives the final milliseconds of its input window',
    Intent.jump(g, 1 / 120, false, true) and g.player.jumpBuffer == 0
  )
  check('a consumed jump tap never repeats on its own', not Intent.jump(g, 1 / 120, false, true))
  check(
    'holding Space retains the existing repeat-on-landing behaviour',
    Intent.jump(g, 1 / 120, true, true) and Intent.jump(g, 1 / 120, true, true)
  )
  Intent.queue(g, 'jump')
  for _ = 1, 16 do
    Intent.jump(g, 1 / 120, false, false)
  end
  check(
    'an early airborne tap expires rather than jumping much later',
    not Intent.jump(g, 1 / 120, false, true)
  )
  Intent.queue(g, 'jump')
  for _ = 1, 10 do
    Intent.jump(g, 1 / 120, false, false)
  end
  check(
    'a short tap before landing remains available after the key is released',
    Intent.jump(g, 1 / 120, false, true)
  )
  local shots = 0
  g.shoot = function()
    shots = shots + 1
    return true
  end
  Intent.queue(g, 'fire')
  g.player.fireBuffer = 0.001
  check(
    'a fire tap remains valid through the final fractional simulation tick',
    Intent.fire(g, 1 / 120, false) and shots == 1 and g.player.fireBuffer == 0
  )
  check(
    'one consumed fire tap cannot discharge again',
    not Intent.fire(g, 1 / 120, false) and shots == 1
  )
  check(
    'holding fire keeps the existing repeat behaviour',
    Intent.fire(g, 1 / 120, true) and shots == 2
  )
  g.shoot = function()
    return false
  end
  Intent.queue(g, 'fire')
  for _ = 1, 16 do
    Intent.fire(g, 1 / 120, false)
  end
  check(
    'an unavailable weapon cannot retain a fire intention indefinitely',
    g.player.fireBuffer == 0
  )
  for _, state in ipairs({ 'paused', 'dead', 'field_catalog', 'shop' }) do
    g = fresh()
    Intent.queue(g, 'jump')
    Intent.queue(g, 'fire')
    g.state = state
    check(
      state .. ' rejects new gameplay intentions',
      not Intent.queue(g, 'jump') and not Intent.queue(g, 'fire')
    )
    Intent.fire(g, 1 / 120, true)
    check(
      state .. ' discards both pending gameplay intentions',
      g.player.fireBuffer == 0 and g.player.jumpBuffer == 0
    )
  end
  for _, overlay in ipairs({ 'map', 'help' }) do
    g = fresh()
    Intent.queue(g, 'jump')
    Intent.queue(g, 'fire')
    g[overlay] = true
    Intent.jump(g, 1 / 120, true, true)
    check(
      overlay .. ' overlay cancels pending taps rather than replaying them later',
      g.player.fireBuffer == 0 and g.player.jumpBuffer == 0
    )
  end
  g = fresh()
  Intent.queue(g, 'jump')
  Intent.queue(g, 'fire')
  for _, dt in ipairs({ 0, -1, 0 / 0, math.huge }) do
    Intent.jump(g, dt, true, true)
    Intent.fire(g, dt, true)
  end
  check(
    'invalid time cannot consume input or fire a weapon',
    g.player.shots == 0
      and g.player.fireBuffer == Intent.window
      and g.player.jumpBuffer == Intent.window
  )
  for _, rate in ipairs({ 30, 60, 144 }) do
    g = fresh()
    g.player.weapon = 2
    g.player.cooldown = 0.001
    Intent.queue(g, 'fire')
    g.player.fireBuffer = 0.001
    g:update(1 / rate, {})
    check(
      'real weapon consumes a buffered tap at cycle end at ' .. rate .. ' Hz',
      g.player.shots == 1 and g.player.arsenal.judge.mag == 5 and g.player.fireBuffer == 0
    )
    g = fresh()
    g.player.jump = 0.02
    g.player.jumpV = -1
    Intent.queue(g, 'jump')
    for _ = 1, math.ceil(0.1 * rate) do
      g:update(1 / rate, {})
    end
    check(
      'real landing consumes a released jump tap at ' .. rate .. ' Hz',
      g.player.jump > 0 and g.player.jumpV > 0 and g.player.jumpBuffer == 0
    )
    g = fresh()
    for _ = 1, rate * 2 do
      g:update(1 / rate, { jump = true })
    end
    check(
      'held jump still repeats without extra key events at ' .. rate .. ' Hz',
      g.view.movementImpactSerial >= 5 and g.player.jump > 0
    )
  end
  for _, blocked in ipairs({ 'paused', 'map', 'help' }) do
    g = fresh()
    Intent.queue(g, 'jump')
    Intent.queue(g, 'fire')
    if blocked == 'paused' then
      g.state = 'paused'
    else
      g[blocked] = true
    end
    g:update(1 / 60, {})
    g.state = 'playing'
    g.map = false
    g.help = false
    g:update(1 / 60, {})
    check(
      'actual ' .. blocked .. ' simulation discards pending taps before resuming',
      g.player.fireBuffer == 0
        and g.player.jumpBuffer == 0
        and g.player.shots == 0
        and g.player.jump == 0
    )
  end
  -- The hand plants and their audio share exactly one accumulated distance.
  local function gait(rate)
    local v = { view = {} }
    Gait.init(v)
    for _ = 1, rate * 2 do
      Gait.advance(v, 3 * Gait.stepDistance / rate, true)
    end
    return v
  end
  local reference = gait(120)
  for _, rate in ipairs({ 30, 60, 144 }) do
    local v = gait(rate)
    check(
      'planted phase and six footfalls match at ' .. rate .. ' Hz',
      near(v.view.gaitPhase, reference.view.gaitPhase) and v.view.gaitSteps == 6
    )
  end
  local v = { view = {} }
  Gait.init(v)
  local total = 6 * Gait.stepDistance
  for _, fraction in ipairs({ 0.001, 0.201, 0.003, 0.111, 0.002, 0.341, 0.341 }) do
    Gait.advance(v, total * fraction, true)
  end
  check(
    'unequal distance chunks preserve the full phase and every foot plant',
    near(v.view.gaitPhase, 6 * math.pi) and v.view.gaitSteps == 6
  )
  local before = v.view.gaitPhase
  Gait.advance(v, 10, false)
  Gait.advance(v, 0, true)
  Gait.advance(v, 0 / 0, true)
  Gait.advance(v, math.huge, true)
  check(
    'airborne stationary and invalid samples never invent footsteps',
    v.view.gaitPhase == before and v.view.gaitSteps == 6
  )
  Gait.advance(v, 0, true)
  Gait.advance(v, 0.00001, true)
  check(
    'resting exactly at a foot-plant boundary cannot duplicate its event',
    v.view.gaitSteps == 6
  )
  g = fresh()
  g.view.motion = false
  local plants = 0
  for _ = 1, 120 do
    plants = plants + (Motion.update(g, 1 / 120, Gait.stepDistance / 60, 0, 0) or 0)
  end
  check(
    'reduced motion keeps physical footsteps while clearing decorative hand motion',
    plants == 2 and g.view.weaponStride == 0 and g.view.weaponCarry == 0
  )
  g = fresh()
  g.player.yaw = 0
  for _ = 1, 30 do
    g:update(1 / 120, { strafe = 1 })
  end
  check('actual rightward movement leans the frame left', g.view.bank < -0.01 and g.player.vx > 0)
  -- A straight wall east of the fixture makes held strafe yield zero velocity.
  g = fresh()
  g.player.yaw = 0
  g.player.x = 16.28
  for z = 20, 29 do
    g.world.map[z][17] = 1
  end
  require('src.world.arena').rebuild(g.world)
  for _ = 1, 180 do
    g:update(1 / 120, { strafe = 1 })
  end
  check(
    'holding strafe into stone does not keep tilting a motionless view',
    math.abs(g.view.bank) < 1e-6 and math.abs(g.player.vx) < 1e-6 and g.view.gaitSteps == 0
  )
  g = fresh()
  g.view.gaitPhase = math.pi - 0.001
  g.player.dashTimer = 0.001
  g.player.dashX, g.player.dashZ = 0, -1
  g:update(1 / 120, { forward = 1 })
  check(
    'the final dash slice cannot masquerade as a planted walking step',
    g.player.dashTimer == 0 and g.view.gaitSteps == 0 and near(g.view.gaitPhase, math.pi - 0.001)
  )
  g = fresh()
  g.view.gaitPhase = math.pi - 0.001
  g.player.slideTimer = 0.001
  g.player.slideX, g.player.slideZ = 0, -1
  g:update(1 / 120, { forward = 1 })
  check(
    'the final slide slice cannot play a false standing footfall',
    g.player.slideTimer == 0 and g.view.gaitSteps == 0 and near(g.view.gaitPhase, math.pi - 0.001)
  )
  -- Preserve actual audio, including the user's chainmail layer, while counting
  -- events. One fixed-rate run contains no AI or pickups to contaminate it.
  local savedPlay = Audio.play
  local calls = 0
  Audio.play = function(name, ...)
    if name == 'step' then
      calls = calls + 1
    end
  end
  local ok, err = pcall(function()
    g = fresh()
    for _ = 1, 120 do
      g:update(1 / 120, { forward = 1 })
    end
    check(
      'each walking sound is emitted by the same planted phase as the hands',
      calls == g.view.gaitSteps and calls >= 3 and near(g.view.weaponStride, g.view.gaitPhase)
    )
    local was = calls
    g.player.jump = 4
    g.player.jumpV = 0
    for _ = 1, 20 do
      g:update(1 / 120, { forward = 1 })
    end
    check('air travel cannot play ground footfalls', calls == was)
  end)
  Audio.play = savedPlay
  if not ok then
    error(err)
  end
  -- Physical weapon/health rules are preserved when motion is switched off.
  g = fresh()
  Weight.shot(g, Weapons.profile(1), 1)
  Weight.update(g, 1 / 60)
  local recoil, hp, ammo = g.view.recoilV, g.player.hp, g.player.arsenal.exorcist.mag
  check(
    'the existing weight response rises before a motion setting change',
    g.view.viewPunch > 0 and g.view.kickBack > 0
  )
  g.view.motion = false
  Weight.update(g, 1 / 120)
  check(
    'disabling motion discards hidden view roll and weapon shove impulses',
    g.view.viewPunch == 0
      and g.view.viewPunchV == 0
      and g.view.rollPunch == 0
      and g.view.rollPunchV == 0
      and g.view.kickBack == 0
      and g.view.kickBackV == 0
  )
  g.view.motion = true
  Weight.update(g, 1 / 120)
  check(
    'reenabling motion cannot replay an old kick',
    g.view.viewPunch == 0
      and g.view.rollPunch == 0
      and g.view.kickBack == 0
      and recoil == g.view.recoilV
      and hp == g.player.hp
      and ammo == g.player.arsenal.exorcist.mag
  )
  g.view.hurtMarks = { { age = 0, life = 1 } }
  g.view.heartbeats = 12
  g.view.heartTimer = 0.4
  g.view.breakConfirm = 0.2
  g.view.rollSide = -1
  Feel.init(g)
  check(
    'field reset clears hurt markers heart clocks and body feedback together',
    #g.view.hurtMarks == 0
      and g.view.heartbeats == 0
      and g.view.heartTimer == 0
      and g.view.breakConfirm == 0
      and g.view.rollSide == 1
  )
  local function feedback(rate)
    local f = fresh()
    f.player.hp = 12
    Weight.shot(f, Weapons.profile(2), 1)
    for _ = 1, rate * 2 do
      Weight.update(f, 1 / rate)
    end
    return f
  end
  reference = feedback(120)
  for _, rate in ipairs({ 30, 60, 144 }) do
    local f = feedback(rate)
    check(
      'weight spring and heart cadence preserve elapsed time at ' .. rate .. ' Hz',
      near(f.view.viewPunch, reference.view.viewPunch)
        and near(f.view.kickBack, reference.view.kickBack)
        and f.view.heartbeats == reference.view.heartbeats
        and near(f.view.heartTimer, reference.view.heartTimer)
    )
  end
  g = fresh()
  Weight.shot(g, Weapons.profile(2), 1)
  g:update(0.05, {})
  g.state = 'paused'
  local punch, kick, phase = g.view.viewPunch, g.view.kickBack, g.view.gaitPhase
  g:update(0.2, { forward = 1, shoot = true, jump = true })
  check(
    'pause holds body response and footfall clocks without advancing play',
    g.view.viewPunch == punch and g.view.kickBack == kick and g.view.gaitPhase == phase
  )
  local timer = g.view.heartTimer
  for _, dt in ipairs({ 0, -1, 0 / 0, math.huge }) do
    Weight.update(g, dt)
  end
  check(
    'invalid time cannot poison the preserved weight response',
    g.view.viewPunch == punch and g.view.kickBack == kick and g.view.heartTimer == timer
  )
  -- OFF -> ON while paused must work without waiting for a simulation update.
  g = fresh()
  g.player.weapon = 2
  g:shoot()
  g:reloadGun()
  g:update(0.05, { forward = 1, jump = true })
  g.impactSlow = 0.06
  g.view.hitmarker = 0.1
  g.view.precisionHit = true
  g.view.breakConfirm = 0.12
  g.view.hurtMarks = { { age = 0.1, life = 1, angle = 0, harm = 0.2, severity = 0.3 } }
  g.view.heartTimer = 0.3
  require('src.render.presentation').capture(g)
  g.state = 'paused'
  local playerFields = {
    'x',
    'z',
    'vx',
    'vz',
    'jump',
    'jumpV',
    'crouch',
    'dash',
    'dashTimer',
    'hp',
    'armor',
    'yaw',
    'pitch',
  }
  local clockFields = {
    'elapsed',
    'time',
    'shotAge',
    'swapAge',
    'cooldown',
    'reload',
    'reloadDuration',
    'reloadOffset',
    'reloadStage',
    'reloadWeapon',
    'step',
    'gaitPhase',
    'gaitSteps',
    'stepSound',
    'impactSlow',
    'heartTimer',
    'hitmarker',
    'breakConfirm',
  }
  -- Rounds, reserves, actions and cadence of every weapon (the arsenal).
  local Serialize = require('src.core.serialize')
  local arsenalBefore = Serialize.encode(g.player.arsenal)
  local playerBefore, clocksBefore = {}, {}
  for _, key in ipairs(playerFields) do
    playerBefore[key] = g.player[key]
  end
  for _, key in ipairs(clockFields) do
    clocksBefore[key] = Fixtures.field(g, key)
  end
  local marks, contact, report = g.view.hurtMarks, g.view.movementContact, g.view.shotReport
  local B = require('src.combat.ballistics')
  local ox, oy, oz = B.origin(g)
  check(
    'pause-toggle fixture contains active recoil and a mechanical reload',
    g.view.recoil > 0
      and g.view.recoilV ~= 0
      and g.player.reload > 0
      and g.view.presentationPrevious ~= nil
  )
  g.view.motion = false
  Feel.clearMotion(g)
  g.view.motion = true
  local clear = true
  for _, key in ipairs({
    'recoil',
    'recoilV',
    'swayX',
    'swayY',
    'bank',
    'fovKick',
    'land',
    'landV',
    'bobWeight',
    'shake',
    'rollPunch',
    'rollPunchV',
    'viewPunch',
    'viewPunchV',
    'kickBack',
    'kickBackV',
    'weaponAimX',
    'weaponAimY',
    'weaponLagX',
    'weaponLagY',
    'weaponImpactX',
    'weaponImpactY',
    'weaponDip',
  }) do
    clear = clear and Fixtures.field(g, key) == 0
  end
  check(
    'paused motion toggle clears both classic recoil and new body feedback immediately',
    clear and g.view.presentationPrevious == nil
  )
  local preserved = true
  for _, key in ipairs(playerFields) do
    preserved = preserved and g.player[key] == playerBefore[key]
  end
  for _, key in ipairs(clockFields) do
    preserved = preserved and Fixtures.field(g, key) == clocksBefore[key]
  end
  preserved = preserved and Serialize.encode(g.player.arsenal) == arsenalBefore
  check(
    'motion reset preserves physical body ammunition weapon clocks and planted cadence',
    preserved
  )
  local ax, ay, az = B.origin(g)
  check(
    'motion reset preserves ballistic origin and combat receipts',
    near(ax, ox)
      and near(ay, oy)
      and near(az, oz)
      and g.view.hurtMarks == marks
      and g.view.movementContact == contact
      and g.view.shotReport == report
      and g.view.precisionHit
  )
  local V = require('src.render.weapon')
  local rx, ry, rr = V.pose(g)
  local tx, ty, tr, scale = V.transform(g, 800, 450)
  local illustration = require('src.render.weapon_art').of(g)
  local placement = illustration.placement or { 0, 0 }
  local sourceScale = 450 * illustration.screenScale / illustration.cellWidth
  check(
    'after paused toggle only the ongoing mechanical reload pose remains',
    near(tx, 400 + rx + placement[1] * sourceScale)
      and near(ty, 461 + ry + placement[2] * sourceScale)
      and near(tr, rr)
      and scale == 1
  )
  -- Root's view-punch transfer is a bounded hand offset, not a new firing axis.
  g = fresh()
  local bx, by, br, bs = V.transform(g, 800, 450)
  for _, amount in ipairs({ 0.05, 5, -0.05, -5 }) do
    g.view.viewPunch = amount
    local x, y, r, s = V.transform(g, 800, 450)
    check(
      'body punch ' .. amount .. ' remains a bounded vertical hand displacement',
      near(x, bx) and near(r, br) and near(s, bs) and near(y - by, amount > 0 and 4 or -4)
    )
  end
  g.view.motion = false
  local x, y, r, s = V.transform(g, 800, 450)
  check(
    'motion off suppresses transferred hand punch without altering the neutral pose',
    near(x, bx) and near(y, by) and near(r, br) and near(s, bs)
  )
end
return Tests

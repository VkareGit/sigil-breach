local Tests = {}
function Tests.run(G, initial, renderer, getGame)
  local F = require('src.player.feel')
  local T = require('src.content.tuning')
  local W = require('src.world.arena')
  local C = require('src.combat.combat')
  local P = require('src.render.presentation')
  local E = require('src.feedback.effects')
  local V = require('src.render.weapon')
  local Anim = require('src.enemies.animation')
  local lines = {}
  local function check(name, value)
    lines[#lines + 1] = (value and 'PASS ' or 'FAIL ') .. name
    if not value then
      error('v04: ' .. name)
    end
  end
  local g = G.new()
  g.testing = true
  local function reset()
    g.state = 'playing'
    g.enemies = {}
    g.bullets = {}
    g.pickups = {}
    g.hazards = {}
    require('src.world.arena').breakSeals(g.world, 0)
    require('src.session.encounter').setGuardian(g, false, false)
    g.map = false
    g.player.cooldown = 0
    g.player.reload = 0
    g.player.weapon = 1
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
  local function step(seconds, input)
    for i = 1, math.floor(seconds * 120 + 0.5) do
      g:update(1 / 120, input or {})
    end
  end
  reset()
  g:update(1 / 120, { slide = true })
  check('slide cannot start from a standstill', g.player.slideTimer == 0)
  reset()
  step(0.2, { forward = 1 })
  local z = g.player.z
  g:update(1 / 120, { forward = 1, slide = true })
  check(
    'running slide starts with a speed boost',
    g.player.slideTimer > 0 and math.abs(g.player.vz) > 8
  )
  check('slide grants no damage immunity', g.player.invuln == 0)
  step(0.15, { forward = 1 })
  check('slide lowers camera smoothly', g.player.crouch > 0.4)
  step(0.45, { forward = 1 })
  check(
    'slide ends without stopping movement',
    g.player.slideTimer == 0 and math.abs(g.player.vz) > 5
  )
  check('slide is brief and bounded in distance', z - g.player.z < 4.6 and z - g.player.z > 3.6)
  g:update(1 / 120, { forward = 1, slide = true })
  check('slide cooldown prevents repeated boosts', g.player.slideTimer == 0)
  step(0.4)
  check('standing height returns after slide', g.player.crouch == 0)
  reset()
  step(0.2, { forward = 1 })
  g:update(1 / 120, { slide = true })
  step(0.1)
  g:update(1 / 120, { jump = true, forward = 1 })
  -- 0.20: the slide's speed survives the jump (no one-tick cut to the air
  -- cap); it stays bounded by the slide speed and its excess decays.
  local jumpSpeed = math.abs(g.player.vz)
  check(
    'jump cancels slide and keeps bounded momentum',
    g.player.slideTimer == 0
      and g.player.jump > 0
      and jumpSpeed <= T.slideSpeed + 0.01
      and jumpSpeed > T.airMomentumCap
      and (g.player.airCap or 0) > T.airMomentumCap
  )
  step(0.2, { forward = 1 })
  check(
    'slide jump retains more speed than ordinary air run',
    math.abs(g.player.vz) > T.airSpeed + 0.3
  )
  step(1, { forward = 1, jump = true })
  check(
    'repeated jumps do not accumulate unlimited speed',
    math.sqrt(g.player.vx ^ 2 + g.player.vz ^ 2) <= T.airMomentumCap + 0.01
  )
  reset()
  step(0.2, { forward = 1 })
  g:update(1 / 120, { slide = true })
  g:dash(1, 0)
  check('dash overrides slide cleanly', g.player.slideTimer == 0 and g.player.dashTimer > 0)
  reset()
  g.player.x = 9
  g.player.z = 28
  g.player.yaw = -math.pi / 2
  g.player.vx = -5
  g:update(1 / 120, { slide = true })
  step(0.4)
  check(
    'slide cannot tunnel into cathedral wall',
    not W.solid(g.world, g.player.x, g.player.z, 0.21) and g.player.x > 8.7
  )
  reset()
  step(0.2, { forward = 1 })
  g:update(1 / 120, { slide = true })
  step(0.12, { forward = 1 })
  g.player.weapon = 2
  local target = g:spawn('imp', 16, g.player.z - 3)
  check('hitscan remains aligned while sliding', g:shoot() and target.hp < target.maxHp)
  local _, _, _, hitY = C.trace(g, g.player.yaw, 0, 1)
  check(
    'trace origin follows lowered eye height without cosmetic landing offset',
    math.abs(hitY - (1.38 + g.player.jump - g.player.crouch)) < 0.001
  )
  reset()
  g.player.crouch = 0.43
  g.bullets =
    { { x = 16, z = 27, y = 1.75, vx = 0, vy = 0, vz = 0, life = 1, color = { 1, 1, 1 } } }
  g:update(1 / 120, {})
  check('lower stance can pass below a high projectile', g.player.hp == 100)
  reset()
  g.player.crouch = 0.43
  g.bullets = { { x = 16, z = 27, y = 0.9, vx = 0, vy = 0, vz = 0, life = 1, color = { 1, 1, 1 } } }
  g:update(1 / 120, {})
  check('slide remains vulnerable to body-height projectiles', g.player.hp < 100)
  reset()
  P.capture(g)
  g.player.x = 18
  g.player.jump = 1
  g.player.yaw = 1.234
  g.player.pitch = 0.42
  local view = P.sample(g, 0.5)
  check(
    'render interpolation gives midpoint position',
    view.player.x == 17 and view.player.jump == 0.5
  )
  check(
    'raw mouse angles bypass interpolation',
    view.player.yaw == 1.234 and view.player.pitch == 0.42
  )
  check('render interpolation does not mutate simulation', g.player.x == 18 and g.player.jump == 1)
  check('interpolation clamps oversized blend factor', P.sample(g, 2).player.x == 18)
  g.map = true
  check('paused map uses exact current state', P.sample(g, 0.5) == g)
  reset()
  local en = g:spawn('imp', 16, 22)
  P.capture(g)
  en.x = 17
  en.walk = 1
  view = P.sample(g, 0.5)
  check(
    'enemy position and gait interpolate together',
    view.enemies[1].x == 16.5 and view.enemies[1].walk == 0.5
  )
  en.ai = 'strike'
  en.phase = 0
  check('state change never blends obsolete attack phase', P.sample(g, 0.5).enemies[1].phase == 0)
  reset()
  for i = 1, 80 do
    E.emit(g, 'stone', 16, 1, 24)
    E.stain(g, 16, 24, 0.5, 'imp')
  end
  check('impact and decal counts stay bounded', #g.view.effects == 48 and #g.view.decals == 40)
  E.update(g, 25)
  check('expired effects and stains are released', #g.view.effects == 0 and #g.view.decals == 0)
  for _, kind in ipairs({ 'stone', 'blood', 'smoke', 'arc' }) do
    E.emit(g, kind, 16, 1, 24)
    local fx = g.view.effects[#g.view.effects]
    local seen = {}
    for i = 0, 3 do
      fx.age = fx.duration * (i + 0.1) / 4
      seen[E.frame(fx)] = true
    end
    local n = 0
    for _ in pairs(seen) do
      n = n + 1
    end
    check(kind .. ' uses four temporal frames', n == 4)
  end
  reset()
  g:shoot()
  check(
    'shotgun produces a short muzzle smoke plume',
    #g.view.effects > 0 and g.view.effects[1].kind == 'smoke'
  )
  reset()
  en = g:spawn('imp', 16, 24)
  g:shoot()
  check(
    'lethal impact leaves a floor stain and blood effect',
    #g.view.decals == 1 and g.view.effects[#g.view.effects].kind == 'blood'
  )
  reset()
  g:shoot()
  local lastX, lastY, lastR = V.pose(g)
  local maxStep = 0
  for i = 1, 120 do
    g:update(1 / 120, {})
    local x, y, r = V.pose(g)
    maxStep = math.max(maxStep, math.abs(x - lastX), math.abs(y - lastY), math.abs(r - lastR) * 100)
    lastX, lastY, lastR = x, y, r
  end
  check('weapon reload transform has no sudden screen jump', maxStep < 3)
  check('reload returns weapon exactly to rest', lastX == 0 and lastY == 0 and lastR == 0)
  reset()
  g.player.weapon = 2
  g.time = 0
  local f = V.frame(g)
  g.time = 0.6
  check('idle revolver no longer flips between dissimilar poses', V.frame(g) == f)
  for _, kind in ipairs({ 'imp', 'stolas', 'buer', 'boss' }) do
    check(
      kind .. ' has measured grounding for every frame',
      #renderer.feet[kind] == Anim.frameCount(kind)
    )
    for _, offset in ipairs(renderer.feet[kind]) do
      assert(offset >= 0 and offset < 0.6, 'Invalid foot registration')
    end
  end
  local imp = love.image.newImageData(require('src.content.enemy_art').entries.imp.path)
  local w, h = imp:getDimensions()
  check('imp sheet has exact 6 by 4 square cells', w / 6 == h / 4)
  local _, _, _, alpha = imp:getPixel(0, 0)
  check('imp sheet has transparent background', alpha < 0.05)
  imp:release()
  local effects = love.image.newImageData(require('src.render.fresco_effects').effects.path)
  local _, _, _, a = effects:getPixel(0, 0)
  check('VFX sheet has actual alpha transparency', a < 0.05)
  effects:release()
  local distances = {}
  for _, hz in ipairs({ 30, 60, 120 }) do
    reset()
    g.player.vz = -5.25
    local origin = g.player.z
    g:update(1 / hz, { slide = true })
    for i = 2, math.floor(0.6 * hz) do
      g:update(1 / hz, {})
    end
    distances[#distances + 1] = origin - g.player.z
  end
  check(
    'slide travel is stable at 30 / 60 / 120 Hz',
    math.max(unpack(distances)) - math.min(unpack(distances)) < 0.12
  )
  local live = getGame()
  live.state = 'playing'
  live.map = false
  live.help = false
  live.player.vx, live.player.vz = 0, -5
  live.player.jump = 0
  live.player.dashTimer = 0
  live.player.slideTimer = 0
  live.player.slideCooldown = 0
  love.keypressed('lctrl')
  love.update(0.001)
  check('Ctrl remains buffered before a fixed simulation step', live.player.slideTimer == 0)
  love.update(1 / 120)
  check('Ctrl dispatch starts slide on next simulation step', live.player.slideTimer > 0)
  live.player.slideTimer = 0
  live.player.slideCooldown = 0
  live.player.vx, live.player.vz = 0, -5
  love.keypressed('lctrl')
  love.keypressed('escape')
  love.keypressed('escape')
  love.update(1 / 120)
  check('opening pause clears queued slide', live.player.slideTimer == 0)
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests

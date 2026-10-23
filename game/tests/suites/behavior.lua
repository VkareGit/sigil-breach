local Tests = {}
function Tests.run(G, initial, renderer, getGame)
  local AI = require('src.enemies.ai')
  local Anim = require('src.enemies.animation')
  local W = require('src.world.arena')
  local U = require('src.ui.interface')
  local A = require('src.audio.audio')
  local lines = {}
  local function check(n, v)
    lines[#lines + 1] = (v and 'PASS ' or 'FAIL ') .. n
    if not v then
      error('v03: ' .. n)
    end
  end
  local g = G.new()
  local function reset()
    g.enemies = {}
    g.hazards = {}
    g.bullets = {}
    g.nextAttack = 0
    g.state = 'playing'
    g.elapsed = 0
    g.player.arsenal.exorcist.readyAt = 0
    g.impactSlow = 0
    g.pickups = {}
    g.damageTaken = 0
    g.seals = 0
    g.bossSpawned = false
    g.bossDead = false
    g.secretFound = false
    g.score = 0
    g.combo = 0
    g.comboTimer = 0
    local p = g.player
    p.x, p.z = 16, 26
    p.yaw = math.pi
    p.pitch = 0
    p.hp = 100
    p.armor = 0
    p.invuln = 0
    p.vx, p.vz = 0, 0
    p.jump = 0
    p.dashTimer = 0
    p.arsenal.exorcist.mag = 2
    p.arsenal.exorcist.reserve = 38
    g.reload = 0
    g.cooldown = 0
  end
  local function step(seconds, input)
    for i = 1, math.floor(seconds * 120) do
      g:update(1 / 120, input or {})
    end
  end
  reset()
  local e = g:spawn('imp', 16, 24.2)
  e.attack = 0
  step(0.12)
  local ax, az = e.aimX, e.aimZ
  g.player.x = 18
  step(0.35)
  check('committed melee target stays frozen', e.aimX == ax and e.aimZ == az)
  step(0.6)
  check('sidestep dodges committed melee', g.player.hp == 100)
  reset()
  e = g:spawn('stolas', 16, 23)
  e.attack = 10
  local d0 = 3
  step(0.8)
  check(
    'caster retreats when crowded',
    math.sqrt((e.x - g.player.x) ^ 2 + (e.z - g.player.z) ^ 2) > d0 + 0.5
  )
  reset()
  e = g:spawn('stolas', 16, 19.5)
  e.attack = 10
  local x = e.x
  step(0.6)
  check('caster strafes at preferred distance', math.abs(e.x - x) > 0.2)
  reset()
  for i = 1, 6 do
    local en = g:spawn('stolas', 13 + i, 22)
    en.attack = 0
  end
  local max = 0
  for i = 1, 250 do
    g:update(1 / 120, {})
    local n = 0
    for _, en in ipairs(g.enemies) do
      if en.ai == 'windup' or en.ai == 'strike' then
        n = n + 1
      end
    end
    max = math.max(max, n)
  end
  check('attack budget limits overlapping telegraphs', max <= 2 and max > 0)
  reset()
  e = g:spawn('imp', 11, 24)
  AI.noise(g, 16, 26, 14)
  step(3)
  check(
    'heard target paths around pillar',
    math.sqrt((e.x - 16) ^ 2 + (e.z - 26) ^ 2) < 3 and not W.solid(g.world, e.x, e.z, 0.24)
  )
  reset()
  e = g:spawn('imp', 4, 16)
  AI.noise(g, 16, 26, 2)
  step(0.2)
  check('distant unseen enemy does not know player position', not e.awake)
  reset()
  e = g:spawn('buer', 16, 21)
  e.attack = 0
  step(1)
  check('Buer creates delayed area attack', #g.hazards == 1 and g.hazards[1].delay > 0)
  g.bullets = {}
  g.enemies = {}
  local hp = g.player.hp
  step(0.2)
  check('warning area does not deal early damage', g.player.hp == hp)
  step(0.7)
  check('active acid damages grounded player', g.player.hp < hp)
  reset()
  AI.hazard(g, 16, 26, 0.2, 1.3, 0.7)
  g.player.jump = 1.2
  AI.update(g, 0.3)
  check('jump clears acid', g.player.hp == 100)
  g.player.jump = 0
  AI.update(g, 1.1)
  check('hazard expires', #g.hazards == 0)
  reset()
  AI.hazard(g, 12, 25, 0.5, 1, 2)
  check('acid never spawns inside pillar', #g.hazards == 0)
  reset()
  local a = g:spawn('imp', 16, 22)
  local b = g:spawn('imp', 16, 22)
  a.attack = 10
  b.attack = 10
  step(0.2)
  check('identical spawns separate', math.abs(a.x - b.x) + math.abs(a.z - b.z) > 0.1)
  reset()
  e = g:spawn('imp', 16, 24)
  e.spawnAge = 0
  e.attack = 0
  step(0.45)
  check('summoning grace period prevents surprise attack', e.ai ~= 'strike' and g.player.hp == 100)
  reset()
  e = g:spawn('imp', 16, 24)
  e.attack = 0
  step(0.1)
  e.hp = 1000
  g:shoot()
  step(0.12)
  check('shotgun interrupts committed attack state', e.ai == 'hurt' and #g.bullets == 0)
  reset()
  e = g:spawn('imp', 16, 24)
  local frames = {}
  e.ai = 'move'
  e.walkSpeed = 2
  for i = 0, 39 do
    e.walk = i * 0.05
    frames[Anim.pose(g, e)] = true
  end
  local n = 0
  for _ in pairs(frames) do
    n = n + 1
  end
  check('locomotion uses six distinct poses', n == 6)
  e.ai = 'windup'
  e.windupDuration = 0.6
  e.windup = 0.5
  local f1 = Anim.pose(g, e)
  e.windup = 0.1
  local f2 = Anim.pose(g, e)
  e.ai = 'strike'
  local f3 = Anim.pose(g, e)
  check('anticipation and strike have distinct silhouettes', f1 == 7 and f2 == 9 and f3 == 10)
  e.ai = 'move'
  e.walkSpeed = 2
  e.facing = math.pi
  e.walk = 0
  check('enemy facing away shows back animation', Anim.pose(g, e) >= 19)
  e.hp = 0
  e.deathTime = 0.01
  local death1 = Anim.pose(g, e)
  e.deathTime = 0.18
  local death2 = Anim.pose(g, e)
  e.deathTime = 0.5
  check(
    'death progresses through collapse to persistent corpse',
    death1 == 14 and death2 == 15 and Anim.pose(g, e) == 18
  )
  reset()
  g.player.x, g.player.z = 4, 20.4
  check(
    'secret can be discovered in existing west court',
    g:interact() and g.secretFound and g.score == 500
  )
  g:interact()
  check('secret reward cannot be farmed', g.score == 500)
  reset()
  e = g:spawn('imp', 16, 24)
  g:damageEnemy(e, 1000)
  e = g:spawn('imp', 17, 24)
  g:damageEnemy(e, 1000)
  check('rapid kills reward a chain', g.combo == 2 and g.score == 225)
  g:damagePlayer(5, 17, 26)
  check('taking damage breaks chain and records direction', g.combo == 0 and g.view.damageDir > 1)
  local settings = { sensitivity = 1, fov = 100, music = 0.65, motion = true, hints = true }
  g.state = 'paused'
  check('mouse can adjust sensitivity', U.actionAt(g, settings, 870, 260) == 'sens_up')
  check('mouse can adjust field of view', U.actionAt(g, settings, 805, 310) == 'fov_down')
  check('mouse can toggle motion', U.actionAt(g, settings, 750, 412) == 'motion')
  U.focus = 1
  U.navigate(g, settings, 1)
  check('keyboard menu focus advances', U.selected(g, settings) == 'sens_down')
  g.help = true
  check(
    'help has a single obvious return action',
    #U.controls(g, settings) == 1 and U.controls(g, settings)[1].id == 'help_back'
  )
  g.help = false
  -- The painted atlases in play (content/enemy_art), not archived sheets:
  -- at their recorded source size and on a transparent ground.
  local Sources = require('src.content.art.sources')
  for _, kind in ipairs({ 'imp', 'stolas', 'buer', 'boss' }) do
    local path = require('src.content.enemy_art').entries[kind].path
    local data = love.image.newImageData(path)
    local w, h = data:getDimensions()
    local _, _, _, alpha = data:getPixel(w - 1, h - 1)
    check(
      kind .. ' painted atlas has its recorded size and a transparent ground',
      w == Sources[path][1] and h == Sources[path][2] and alpha < 0.05
    )
    data:release()
  end
  check(
    'positional warning sounds exist',
    A.sources.snarl and A.sources.owl and A.sources.growl and A.sources.cast
  )
  check(
    'adaptive score has its chant and its heartbeat',
    require('src.audio.soundscape').layers.chant and require('src.audio.soundscape').layers.heart
  )
  local lx, ly = U.toLogical(860, 360, 1720, 720)
  check('ultrawide input stays aligned to unstretched UI', lx == 640 and ly == 360)
  lx, ly = U.toLogical(512, 384, 1024, 768)
  check('4:3 input stays aligned to unstretched UI', lx == 640 and ly == 360)
  -- Exercise actual UI input dispatch, including a non-default focused action.
  love.keypressed('escape')
  love.keypressed('f1')
  check('F1 opens bestiary and pauses play', getGame().help and getGame().state == 'paused')
  love.keypressed('escape')
  check('closing help retains safe pause', not getGame().help and getGame().state == 'paused')
  local before = getGame().view.fov
  love.mousepressed(870 * love.graphics.getWidth() / 1280, 310 * love.graphics.getHeight() / 720, 1)
  check('click updates live camera FOV', getGame().view.fov == math.min(115, before + 5))
  love.mousepressed(805 * love.graphics.getWidth() / 1280, 310 * love.graphics.getHeight() / 720, 1)
  U.focus = 1
  love.keypressed('return')
  love.keypressed('tab')
  love.keypressed('f1')
  love.keypressed('escape')
  check(
    'help opened from map leaves a coherent paused state',
    not getGame().map and not getGame().help and getGame().state == 'paused'
  )
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests

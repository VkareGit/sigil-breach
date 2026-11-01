-- Actual combat calls plus independent contact/energy and recycling probes.
local Fixtures = require('tests.support.fixtures')
local T = {}
function T.run(G, check)
  local I = require('src.feedback.impact_response')
  local FX = require('src.feedback.effects')
  local Damage = require('src.combat.damage')
  local Weapons = require('src.content.weapons')
  local A = require('src.audio.audio')
  local muted = A.muted
  A.muted = true
  local near = Fixtures.within(1e-7)
  local function fresh(slot, wall)
    local g = G.new()
    g.ephemeral = true
    g.state = 'playing'
    g.enemies = {}
    g.pickups = {}
    g.view.particles = {}
    g.player.weapon = slot or 2
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 32, 32, 0, 0
    local w = { size = 70, map = {}, seals = {}, lamps = {}, decor = {} }
    for z = 1, 70 do
      w.map[z] = {}
      for x = 1, 70 do
        w.map[z][x] = (x == 1 or z == 1 or x == 70 or z == 70 or z == (wall or 60)) and 1 or 0
      end
    end
    -- Collision fixture only: the real G, shoot, damage, poise and FX paths run.
    g.world = w
    return g
  end
  local function effect(g, material)
    for _, e in ipairs(g.view.effects) do
      if e.material == material then
        return e
      end
    end
  end
  local function fire(slot, wall, yaw, pitch)
    local g = fresh(slot, wall)
    g.player.yaw = yaw or 0
    g.player.pitch = pitch or 0
    assert(g:shoot(), 'impact probe needs a real valid shot')
    return g
  end
  local close = fire(2, 35)
  local far = fire(2, 67)
  local a, b = close.view.shotReport.rays[1], far.view.shotReport.rays[1]
  local expected = 70 * (1 - (1 - 0.65) * (b.distance - 12) / (36 - 12))
  check(
    'near and far real revolver contacts retain the existing weapon falloff',
    a.kind == 'wall'
      and b.kind == 'wall'
      and near(a.response.energy, 70)
      and near(b.response.energy, expected)
  )
  check(
    'a distant wall impact has smaller paint and lower outward speed',
    b.response.size < a.response.size and b.response.normalSpeed < a.response.normalSpeed
  )
  local shotgunNear, shotgunFar = fire(1, 35), fire(1, 52)
  local nearPower, farPower = 0, 0
  for _, ray in ipairs(shotgunNear.view.shotReport.rays) do
    nearPower = nearPower + ray.response.energy
  end
  for _, ray in ipairs(shotgunFar.view.shotReport.rays) do
    farPower = farPower + ray.response.energy
  end
  check(
    'real shotgun pellets retain separate weaker contacts over distance',
    #shotgunNear.view.shotReport.rays == 20
      and #shotgunFar.view.shotReport.rays == 20
      and farPower < nearPower * 0.5
  )
  local plaster = effect(close, 'plaster')
  local floor = fire(2, 60, 0, -0.7)
  local floorEffect = effect(floor, 'stone')
  check(
    'walls shed ochre plaster and the floor sheds gray stone from the same painted atlas',
    plaster
      and floorEffect
      and plaster.kind == 'stone'
      and floorEffect.kind == 'stone'
      and plaster.tint ~= floorEffect.tint
      and floor.view.shotReport.rays[1].kind == 'floor'
  )
  local graze = fire(2, 35, math.asin(0.94))
  local c = graze.view.shotReport.rays[1].response
  check(
    'at the same retained energy a glancing shot has less normal energy than a square hit',
    near(c.energy, a.response.energy)
      and c.normalEnergy < a.response.normalEnergy * 0.15
      and c.tangentialEnergy > c.energy * 0.85
  )
  check(
    'glancing debris scrapes along the incoming direction while leaving the surface',
    c.tx > 0.99 and c.nz < -0.99 and c.tangentSpeed > 0 and c.normalSpeed < a.response.normalSpeed
  )
  local outward = true
  for _, g in ipairs({ close, far, floor, graze, shotgunNear, shotgunFar }) do
    for _, p in ipairs(g.view.particles) do
      local found = false
      for _, ray in ipairs(g.view.shotReport.rays) do
        local r = ray.response
        if
          near(p.x, ray.x + r.nx * r.offset, 1e-6)
          and near(p.y, ray.y + r.ny * r.offset, 1e-6)
          and near(p.z, ray.z + r.nz * r.offset, 1e-6)
        then
          found = true
          outward = outward and p.vx * r.nx + p.vy * r.ny + p.vz * r.nz > 0
        end
      end
      outward = outward and found
    end
  end
  check('every contact fragment starts outside its surface with an outward velocity', outward)
  check(
    'wall feedback starts in front of the visible niche fillet on its first frame',
    plaster.z < a.z - 0.0825 and plaster.age == 0
  )
  check(
    'environment feedback consumes ammunition once and cannot damage the player',
    close.player.arsenal.judge.mag == 5
      and close.player.shots == 1
      and close.player.hp == 100
      and close.view.shotReport.damage == 0
      and close.view.shotReport.headHits == 0
  )
  local function target(kind, hp, resistance)
    local g = fresh(2, 60)
    local e = g:spawn(kind, 32, 35)
    e.hp = hp or 1000
    e.maxHp = e.hp
    e.resistances = resistance and { physical = resistance } or {}
    local initial = e.hp
    assert(g:shoot())
    return g, e, initial
  end
  local bare, bareEnemy, bareHP = target('imp')
  local armored, armoredEnemy, armoredHP = target('armored')
  local bareBlood, armorBlood = effect(bare, 'blood'), effect(armored, 'blood')
  local metal = effect(armored, 'metal')
  check(
    'real armored body hit separates blood from absorbed iron impact',
    metal
      and armorBlood
      and bareBlood
      and not effect(bare, 'metal')
      and armorBlood.energy < bareBlood.energy
  )
  check(
    'blood magnitude follows actual lost HP rather than impulse',
    near(bareBlood.energy, bareHP - bareEnemy.hp)
      and near(armorBlood.energy, armoredHP - armoredEnemy.hp)
  )
  local detail = armored.view.shotReport.hitTargets[1]
  local ray = armored.view.shotReport.rays[1]
  local attack = Weapons.attack(armored, 2)
  local raw = Damage.resolve(attack, {}, ray.distance, ray.part)
  check(
    'metal contact accounts only for the independently computed armor loss',
    near(metal.energy, raw * (60 * (1 - 0.5)) / (100 + 60 * (1 - 0.5)))
      and near(metal.energy, detail.armorAbsorbed)
  )
  local resistant = target('imp', 1000, 0.5)
  check(
    'physical resistance without metal armor cannot create an iron clang',
    resistant.view.shotReport.blocked > 0
      and not effect(resistant, 'metal')
      and not effect(resistant, 'bone')
  )
  local dying = target('imp', 3)
  check(
    'overkill does not multiply the added blood plume beyond actual health loss',
    dying.view.shotReport.overkill > 0
      and near(effect(dying, 'blood').energy, 3)
      and effect(dying, 'blood').size < bareBlood.size
  )
  local profile = {
    base = 70,
    power = 1.2,
    zone = 0.9,
    upgrade = 1.1,
    penetration = 0.5,
    falloffStart = 12,
    falloffEnd = 36,
    minPower = 0.65,
  }
  check(
    'visual retained power preserves weapon power, zone and upgrade multipliers',
    near(I.retained(profile, 24), 70 * 1.2 * 0.9 * 1.1 * 0.825)
  )
  profile.penetration = 1
  check(
    'complete penetration cannot shed invented armor fragments',
    near(I.armorLoss(profile, { armorRating = 60 }, 24), 0)
  )
  local contact = {
    x = 2,
    y = 1,
    z = 3,
    dx = 0,
    dy = 0,
    dz = 1,
    normal = { 0, 0, -1 },
    distance = 4,
    kind = 'wall',
    seed = 17,
  }
  local g = {
    view = { effects = {}, decals = {}, particles = {} },
    stats = { knight = { kills = 0, score = 9, combo = 0, comboTimer = 0, damageTaken = 0 } },
    player = { hp = 84, shots = 12 },
  }
  local rng = love.math.getRandomState()
  local oldSurface, oldBody = I.surface, I.body
  for n = 1, 100 do
    I.surface(g, profile, contact, true)
  end
  check(
    'repeated impacts obey both the particle cap and the painted-effect cap',
    #g.view.particles <= 240 and #g.view.effects == 48
  )
  check(
    'visual variation does not consume the gameplay random stream',
    rng == love.math.getRandomState()
  )
  check(
    'calling visual contact responses cannot award points, shoot or remove health',
    g.player.shots == 12
      and require('src.session.stats').total(g, 'score') == 9
      and g.player.hp == 84
  )
  FX.update(g, 2)
  check(
    'all painted impact records expire into the bounded reusable pool',
    #g.view.effects == 0 and #g.view.effectPool <= 48 and #g.view.effectPool > 0
  )
  local recycled = FX.emit(g, 'smoke', 7, 8, 9, 0.30)
  check(
    'recycled smoke clears impact tint, material, energy and velocity',
    recycled.tint == nil
      and recycled.material == nil
      and recycled.energy == 0
      and recycled.incidence == 0
      and recycled.vx == 0
      and recycled.vy == 0
      and recycled.vz == 0
      and near(recycled.duration, 0.52)
  )
  local function drift(steps)
    local state = { view = { effects = {}, decals = {} } }
    local e = FX.emit(state, 'stone', 1, 2, 3, 0.4, { vx = 0.3, vy = 0.5, vz = -0.7, duration = 1 })
    for _, dt in ipairs(steps) do
      FX.update(state, dt)
    end
    return e
  end
  local one, many = drift({ 0.3 }), drift({ 0.1, 0.1, 0.1 })
  check(
    'painted impact drift is stable across simulation step partitions',
    near(one.x, many.x) and near(one.y, many.y) and near(one.z, many.z)
  )
  local phases = {}
  for i = 0, 3 do
    one.age = one.duration * (i + 0.1) / 4
    phases[FX.frame(one)] = true
  end
  local count = 0
  for _ in pairs(phases) do
    count = count + 1
  end
  check('material impacts still traverse all four authored animation frames', count == 4)
  -- Compare actual gameplay with and without this visual layer, not a formula
  -- copied from combat. Recoil, damage, timing, ammo, poise and shove must agree.
  local visual = fresh(1, 60)
  local ve = visual:spawn('armored', 32, 35)
  ve.hp = 1000
  ve.maxHp = 1000
  assert(visual:shoot())
  I.surface = function() end
  I.body = function() end
  local silent, se
  local ok, err = pcall(function()
    silent = fresh(1, 60)
    se = silent:spawn('armored', 32, 35)
    se.hp = 1000
    se.maxHp = 1000
    assert(silent:shoot())
  end)
  I.surface, I.body = oldSurface, oldBody
  assert(ok, err)
  check(
    'disabling all new impact art preserves damage, poise and shove',
    near(ve.hp, se.hp)
      and near(ve.poise, se.poise)
      and near(ve.pushX, se.pushX)
      and near(ve.pushZ, se.pushZ)
  )
  check(
    'disabling all new impact art preserves ammunition and weapon timing',
    visual.player.arsenal.exorcist.mag == silent.player.arsenal.exorcist.mag
      and visual.player.arsenal.exorcist.reserve == silent.player.arsenal.exorcist.reserve
      and near(visual.player.cooldown, silent.player.cooldown)
      and near(visual.player.reload, silent.player.reload)
      and near(visual.view.recoilV, silent.view.recoilV)
  )
  for _ = 1, 50 do
    close:update(1 / 120, {})
  end
  check(
    'real game particle physics removes every short contact fragment',
    #close.view.particles == 0
  )
  A.muted = muted
end
return T

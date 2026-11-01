-- Observable animation contracts: the picture follows physical action clocks,
-- and presentation cannot spend ammunition or advance the simulation.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local Anim = require('src.enemies.animation')
  local A = require('src.content.enemies')
  local Reload = require('src.combat.reload')
  local T = require('src.content.tuning')
  local V = require('src.render.weapon')
  local M = require('src.feedback.weapon_motion')
  local near = Fixtures.within(1e-7)
  local function fresh(slot)
    local g = G.new('floor')
    g.testing = true
    g.state = 'playing'
    g.run = nil
    g.enemies = {}
    g.bullets = {}
    g.hazards = {}
    g.pickups = {}
    g.player.weapon = slot or 1
    g.view.swapAge = 1
    g.view.shotAge = 10
    g.player.cooldown = 0
    return g
  end
  local g = fresh()
  local function enemy(kind, spec, state, phase)
    return {
      kind = kind,
      id = 1,
      hp = 100,
      x = 0,
      z = 0,
      walk = 0,
      walkSpeed = 0,
      ai = state,
      phase = phase or 0,
      attackSpec = spec,
      attackKind = spec.id,
      windup = spec.windup,
      windupDuration = spec.windup,
      recover = 0,
      stun = 0,
    }
  end
  local imp = enemy('imp', A.imp.attacks[1], 'strike', 0.115)
  check('imp strike retains its authored .23 second cycle', near(Anim.actionPhase(imp), 0.5))
  local furfur = enemy('furfur', A.furfur.attacks[1], 'strike', 0.14)
  local frame, _, lean = Anim.pose(g, furfur)
  check(
    'Furfur melee still has its early painted strike at .14 seconds',
    frame == 10 and near(Anim.actionPhase(furfur), 0.14 / 0.32) and lean > 0
  )
  furfur.phase = 0.17
  check(
    'Furfur changes strike pose at half of its own .32 second action',
    Anim.pose(g, furfur) == 11
  )
  furfur.phase = 0.26
  local _, _, tail = Anim.pose(g, furfur)
  check('Furfur melee visual follow-through remains active after .23 seconds', tail > 0)
  furfur = enemy('furfur', A.furfur.attacks[2], 'strike', 0.4)
  furfur.chargeTime = 0.8
  frame, _, lean = Anim.pose(g, furfur)
  check(
    'long charge retains its low head and body effort through the committed run',
    frame == 10 and near(Anim.actionPhase(furfur), 0.5) and near(lean, 0.03)
  )
  furfur.chargeTime = 0.3
  furfur.phase = 0.15
  check('short charge uses its own travel duration', near(Anim.actionPhase(furfur), 0.5))
  furfur = enemy('furfur', A.furfur.attacks[3], 'windup')
  furfur.windupDuration = 1.36
  furfur.windup = 0.68
  check(
    'offscreen fairness windup is also the visual anticipation clock',
    near(Anim.actionPhase(furfur), 0.5)
  )
  furfur.windup = 1.5
  check(
    'an anticipation preview before the action is clamped to its first pose',
    Anim.actionPhase(furfur) == 0
  )
  furfur.windup = -0.1
  check(
    'an anticipation preview after release is clamped to its final pose',
    Anim.actionPhase(furfur) == 1
  )
  local boss = enemy('boss', A.boss.attacks[1], 'recover', 0.5)
  boss.recover = 0.25
  local _, _, _, _, height = Anim.pose(g, boss)
  check(
    'boss visibly finishes its .75 second recovery instead of an imp recovery',
    near(Anim.actionPhase(boss), 2 / 3) and height < 1
  )
  boss.phase = 0.175
  boss.recover = 0.175
  check(
    'a wall-cancelled cast follows its actual shortened recovery',
    near(Anim.actionPhase(boss), 0.5)
  )
  furfur = enemy('furfur', A.furfur.attacks[1], 'strike', 0.14)
  furfur.attackSpec = A.furfur.attacks[2]
  check(
    'a stale attack cache cannot replace the action named by the simulation',
    near(Anim.actionPhase(furfur), 0.14 / 0.32) and furfur.attackSpec == A.furfur.attacks[2]
  )
  furfur.attackSpec = nil
  check(
    'catalogue poses can resolve an authored attack without mutating the enemy',
    near(Anim.actionPhase(furfur), 0.14 / 0.32) and furfur.attackSpec == nil
  )
  local saved =
    { furfur.phase, furfur.ai, furfur.attackKind, furfur.windup, furfur.recover, furfur.hp }
  for _ = 1, 120 do
    Anim.pose(g, furfur)
  end
  check(
    'repeated pose sampling never advances AI or modifies health',
    furfur.phase == saved[1]
      and furfur.ai == saved[2]
      and furfur.attackKind == saved[3]
      and furfur.windup == saved[4]
      and furfur.recover == saved[5]
      and furfur.hp == saved[6]
  )

  local function advanceTo(v, age)
    local remaining = age - Reload.age(v)
    if remaining > 0 then
      Reload.update(v, remaining)
    end
  end
  local contracts = {
    {
      slot = 1,
      open = 0.26,
      load = T.reloadLoadTime,
      close = 0.82,
      finish = T.shotgunCycle,
      mag = 'mag',
      reserve = 'reserve',
      opened = 'open',
      stock = 1,
    },
    {
      slot = 2,
      open = 0.20,
      load = T.revolverLoadTime,
      close = T.revolverCloseTime,
      finish = T.revolverReload,
      mag = 'mag',
      reserve = 'reserve',
      opened = 'open',
      stock = 3,
    },
  }
  for _, contract in ipairs(contracts) do
    local v = fresh(contract.slot)
    -- The live record of the weapon in that slot (content/weapons.lua).
    local p = require('src.content.weapons').state(v, contract.slot)
    p[contract.mag] = 0
    p[contract.reserve] = contract.stock
    assert(Reload.start(v, true), 'animation fixture failed to start a physical reload')
    advanceTo(v, contract.open - 1e-5)
    check(
      'weapon ' .. contract.slot .. ' stays shut before its mechanical opening',
      not p[contract.opened]
    )
    advanceTo(v, contract.open + 1e-5)
    check(
      'weapon ' .. contract.slot .. ' opens at its original mechanical time',
      p[contract.opened] == true
    )
    advanceTo(v, contract.load - 1e-5)
    check(
      'weapon ' .. contract.slot .. ' does not transfer reserve before physical insertion',
      p[contract.mag] == 0 and p[contract.reserve] == contract.stock
    )
    advanceTo(v, contract.load + 1e-5)
    check(
      'weapon ' .. contract.slot .. ' commits its partial reserve exactly once',
      p[contract.mag] == contract.stock and p[contract.reserve] == 0 and p[contract.opened]
    )
    local clock, ammo = v.player.reload, p[contract.mag]
    local phase, offset, duration =
      v.player.reloadStage, v.player.reloadOffset, v.player.reloadDuration
    for _ = 1, 120 do
      V.frame(v)
      V.sourceFrame(v)
      V.pose(v)
      M.pose(v)
      V.transform(v, 800, 450)
    end
    check(
      'weapon ' .. contract.slot .. ' pose sampling cannot change reload clocks or ammunition',
      v.player.reload == clock
        and p[contract.mag] == ammo
        and p[contract.reserve] == 0
        and v.player.reloadStage == phase
        and v.player.reloadOffset == offset
        and v.player.reloadDuration == duration
    )
    advanceTo(v, contract.close - 1e-5)
    check(
      'weapon ' .. contract.slot .. ' stays physically open until the latch closes',
      p[contract.opened]
    )
    advanceTo(v, contract.close + 1e-5)
    check(
      'weapon ' .. contract.slot .. ' closes on time but still waits for the ready pose',
      not p[contract.opened] and v.player.reload > 0 and not v:shoot()
    )
    advanceTo(v, contract.finish + 1e-5)
    check(
      'weapon ' .. contract.slot .. ' finishes without inventing a round or a second load',
      v.player.reload == 0
        and p[contract.mag] == contract.stock
        and p[contract.reserve] == 0
        and not p[contract.opened]
    )
  end

  -- Keep a demanding but ordinary carried pose constant while only the reload
  -- runs. The previous binary grip multiplier jumped more than six screen
  -- pixels at 450p on the last frame, independently of recoil or mouse input.
  for slot = 1, 2 do
    local v = fresh(slot)
    v.view.weaponCarry = 1
    v.view.weaponStride = math.pi / 2
    v.view.weaponAimX = 7
    v.view.weaponDip = 4
    v.view.weaponLean = 0.018
    v.view.weaponClock = 0
    local p = v.player
    if slot == 1 then
      p.arsenal.exorcist.mag = 0
      p.arsenal.exorcist.reserve = 2
    else
      p.arsenal.judge.mag = 0
      p.arsenal.judge.reserve = 6
    end
    local x, y, r = V.transform(v, 800, 450)
    assert(Reload.start(v, true))
    local nx, ny, nr = V.transform(v, 800, 450)
    check(
      'weapon ' .. slot .. ' begins reloading without snapping its carried position',
      math.abs(nx - x) < 0.02 and math.abs(ny - y) < 0.02 and math.abs(nr - r) < 0.0002
    )
    x, y, r = nx, ny, nr
    local maximum = 0
    local angular = 0
    for _ = 1, math.ceil((slot == 1 and T.shotgunCycle or T.revolverReload) * 120) + 2 do
      Reload.update(v, 1 / 120)
      nx, ny, nr = V.transform(v, 800, 450)
      maximum = math.max(maximum, math.abs(nx - x), math.abs(ny - y))
      angular = math.max(angular, math.abs(nr - r))
      x, y, r = nx, ny, nr
    end
    check(
      'weapon ' .. slot .. ' carries through reload completion without a one-frame jump',
      maximum < 2 and angular < 0.008
    )
    v.view.motion = false
    local px, py, pr = M.pose(v)
    check(
      'weapon ' .. slot .. ' reduced motion still removes decorative carry',
      px == 0 and py == 0 and pr == 0
    )
  end

  local function restartCase(name, slot, interruption, expectedOffset)
    local v = fresh(slot)
    local p = v.player
    if slot == 1 then
      p.arsenal.exorcist.mag = 0
      p.arsenal.exorcist.reserve = 4
    else
      p.arsenal.judge.mag = 0
      p.arsenal.judge.reserve = 9
    end
    if interruption then
      assert(Reload.start(v, true))
      advanceTo(v, interruption)
      Reload.cancel(v)
    end
    -- Include breathing here: it used to switch amplitude abruptly too.
    v.view.weaponClock = 1
    v.view.weaponCarry = 0.35
    v.view.weaponStride = math.pi / 2
    v.view.weaponAimX = 4
    v.view.weaponDip = 2
    local x, y, r = M.pose(v)
    assert(Reload.start(v, false))
    local nx, ny, nr = M.pose(v)
    check(
      name .. ' begins with a neutral grip despite its absolute action offset',
      near(v.player.reloadOffset, expectedOffset)
        and near(M.grip(v), 1)
        and near(nx, x)
        and near(ny, y)
        and near(nr, r)
    )
    -- The weapon's live record in the arsenal (content/weapons.lua).
    local w = require('src.content.weapons').state(v, slot)
    local clock, ammo, stock = v.player.reload, w.mag, w.reserve
    for _ = 1, 100 do
      M.grip(v)
    end
    check(
      name .. ' grip sampling cannot advance the resumed transaction',
      v.player.reload == clock and w.mag == ammo and w.reserve == stock
    )
    local bounded, braced = true, false
    local maximum = 0
    x, y, r = nx, ny, nr
    while v.player.reload > 0 do
      Reload.update(v, math.min(1 / 120, v.player.reload))
      local grip = M.grip(v)
      bounded = bounded and grip >= 0.48 - 1e-9 and grip <= 1 + 1e-9
      braced = braced or grip < 0.6
      nx, ny, nr = M.pose(v)
      maximum = math.max(maximum, math.abs(nx - x), math.abs(ny - y), math.abs(nr - r) * 100)
      x, y, r = nx, ny, nr
    end
    check(
      name .. ' braces and releases smoothly without exceeding carry bounds',
      bounded and braced and maximum < 1
    )
    check(
      name .. ' returns to full grip and conserves its original ammunition',
      M.grip(v) == 1 and w.mag + w.reserve == (slot == 1 and 4 or 9)
    )
  end
  restartCase('manual shotgun reload', 1, nil, 0.15)
  restartCase('manual revolver reload', 2, nil, 0)
  restartCase('resumed empty breech', 1, 0.4, 0.32)
  restartCase('resumed loaded breech', 1, 0.65, 0.68)
  restartCase('resumed empty cylinder', 2, 0.5, 0.68)
  restartCase('resumed loaded cylinder', 2, 1.3, T.revolverLoadTime)
end
return Tests

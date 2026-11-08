-- Exercise the heavy servant through real action, movement and restoration clocks.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local Actions = require('src.enemies.actions')
  local Enemies = require('src.content.enemies')
  local World = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local Anim = require('src.enemies.animation')
  local specs = {}
  for _, spec in ipairs(Enemies.armored.attacks) do
    specs[spec.id] = spec
  end
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'iron fight: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local dt = 1 / 120
  local function actor(distance)
    local g = F.arena(Game)
    g.player.armor, g.player.z = 0, 20 + distance
    for z = 8, 30 do
      for x = 8, 24 do
        World.setCell(g.world, x, z, Tiles.floor)
      end
    end
    local e = g:spawn('armored', 16, 20)
    e.target, e.awake, e.visible, e.memory, e.spawnAge, e.sense, e.facing =
      g.player.id, true, true, 60, 2, 10, 0
    return g, e
  end
  local function trial(id, distance, inputAt, input, wall, restoreAt)
    local g, e = actor(distance)
    local p = g.player
    local hp = p.hp
    Actions.begin(g, e, distance, specs[id])
    local used, restored = false, false
    local release, hit, ready
    for i = 1, 360 do
      local time = (i - 1) * dt
      local keys = {}
      if inputAt and not used and time >= inputAt then
        keys = input
        used = true
      end
      e.attack = 99
      g:update(dt, keys)
      if e.ai == 'strike' and not release then
        release = i * dt
      end
      if p.hp < hp and not hit then
        hit = i * dt
      end
      if release and e.ai == 'move' and not ready then
        ready = i * dt
      end
      if wall then
        World.setCell(g.world, 16, 21, Tiles.wall)
      end
      if restoreAt and not restored and time >= restoreAt then
        Snapshot.restore(g, Snapshot.capture(g))
        e, p, restored = g.enemies[1], g.player, true
      end
      -- A separate automatic answer is outside this single-attack trial.
      if ready or e.attackKind ~= id then
        break
      end
    end
    return hp - p.hp, release, hit, ready
  end
  for _, distance in ipairs({ 1, 1.6, 2 }) do
    local loss, release, hit = trial('claw', distance)
    check(
      'the visible forward claw reaches a stationary knight at ' .. distance .. ' m exactly once',
      loss == 30
    )
    check(
      'claw contact follows the visible preparation at ' .. distance .. ' m',
      release
        and release >= 0.55
        and release < 0.6
        and hit
        and hit >= release
        and hit < release + 0.23
    )
  end
  check(
    'a late sideways dodge escapes the claw',
    trial('claw', 1.6, 0.52, { strafe = 1, dash = true }) == 0
  )
  check('a restored claw retains its contact', trial('claw', 1.6, nil, nil, false, 0.6) == 30)
  check('a grounded knight meets the floor ridge once', trial('ground-slam', 3) == 26)
  check(
    'a jump at the downward fist clears the low ridge',
    trial('ground-slam', 3, 0.85, { jump = true }) == 0
  )
  check('jumping early lands in the ridge', trial('ground-slam', 3, 0.5, { jump = true }) == 26)
  check(
    'jumping late cannot erase the ridge contact',
    trial('ground-slam', 3, 1.15, { jump = true }) == 26
  )
  check('stone blocks the ridge', trial('ground-slam', 3, nil, nil, true) == 0)
  check(
    'Continue preserves the jump over a travelling ridge',
    trial('ground-slam', 3, 0.85, { jump = true }, false, 0.95) == 0
  )
  check(
    'Continue preserves the single ridge receipt',
    trial('ground-slam', 3, nil, nil, false, 1.2) == 26
  )
  check('a committed cleave meets its lane once', trial('cleave', 3) == 46)
  check('the shoulder meets a stationary knight once', trial('shoulder', 5) == 38)
  do
    local g, e = actor(5)
    Actions.begin(g, e, 5, specs.shoulder)
    -- Move out of the committed lane after release so the missed rush must turn.
    local pause
    for _ = 1, 240 do
      e.attack = 99
      g:update(dt, {})
      if e.ai == 'strike' then
        g.player.x = 22
      end
      if e.act.turnAt then
        pause = true
        break
      end
    end
    check('a missed shoulder reaches its real return pause', pause)
    if pause then
      local x, z, phase = e.x, e.z, e.phase
      local saved = Snapshot.capture(g)
      for _ = 1, 24 do
        e.attack = 99
        g:update(dt, {})
      end
      check(
        'the planted pause keeps the body still while time advances',
        math.abs(e.x - x) < 1e-8 and math.abs(e.z - z) < 1e-8 and e.phase > phase
      )
      for _ = 1, 96 do
        e.attack = 99
        g:update(dt, {})
      end
      local expected = Integrity.capture(g)
      local expectedFrame = Anim.pose(g, e)
      Snapshot.restore(g, saved)
      e = g.enemies[1]
      for _ = 1, 120 do
        e.attack = 99
        g:update(dt, {})
      end
      check(
        'Continue preserves the returning rush and its recovery',
        not Integrity.difference(expected, Integrity.capture(g))
          and Anim.pose(g, e) == expectedFrame
      )
    end
  end
  check(
    'the refinement keeps the ordinary heavy body at its existing health',
    Enemies.armored.body.hp == 560
  )
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T

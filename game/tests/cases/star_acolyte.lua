-- The owl remains a fragile caster. Its movement and painted tells must finish
-- on the same clocks the fight uses, including after a mid-action restore.
local Fixtures = require('tests.support.fixtures')
local Actions = require('src.enemies.actions')
local Archetypes = require('src.content.enemies')
local Animation = require('src.enemies.animation')
local Pose = require('src.enemies.pose')
local Snapshot = require('src.session.snapshot')
local Integrity = require('src.session.integrity')
local Tests = {}

function Tests.run(Game)
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'star acolyte: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local function actor()
    local g = Fixtures.arena(Game)
    local e = g:spawn('stolas', 16, 18)
    e.target, e.awake, e.visible, e.memory, e.spawnAge = g.player.id, true, true, 60, 2
    e.sense, e.attack = 10, 0
    return g, e
  end
  local function sidestep(e)
    e.ai, e.evadeTime, e.evadeReady = 'move', 0.2, 2
    e.evadeX, e.evadeZ, e.evadeSide = 1, 0, 1
  end
  local dt = 1 / 120
  for _, attack in ipairs(Archetypes.stolas.attacks) do
    if attack.kind == 'beam' then
      local g, e = actor()
      Actions.begin(g, e, 7, attack)
      local initial = e.aimX
      g.player.x = initial + 1.5
      e.windup = e.windupDuration * 0.6
      Actions.track(g, e, attack, dt)
      check(attack.id .. ' follows visible movement during preparation', e.aimX == g.player.x)
      Actions.execute(g, e)
      local h = g.hazards[#g.hazards]
      check(attack.id .. ' releases a finite painted footprint', h and (h.width or 0) >= 0.8)
      local angle = h and h.angle
      g.player.x = initial - 2
      e.attack = 99
      g:update(dt, {})
      check(attack.id .. ' leaves its released warning fixed', h and h.angle == angle)
      if attack.id == 'star-lance' then
        check('the lance lasts long enough to read its active phase', h and h.life >= 0.15)
      end
    end
  end
  do
    local World, Tiles = require('src.world.arena'), require('src.core.tiles')
    local function trial(offset, wall, restored)
      local g, e = actor()
      local p = g.player
      p.armor, p.x, p.z = 0, 16, 25
      for z = 18, 25 do
        for x = 15, 18 do
          World.setCell(g.world, x, z, Tiles.floor)
        end
      end
      local spec
      for _, attack in ipairs(Archetypes.stolas.attacks) do
        if attack.id == 'star-lance' then
          spec = attack
        end
      end
      Actions.begin(g, e, 7, spec)
      Actions.execute(g, e)
      p.x = p.x + offset
      if wall then
        World.setCell(g.world, 16, 21, Tiles.wall)
      end
      if restored then
        Snapshot.restore(g, Snapshot.capture(g))
        e, p = g.enemies[1], g.player
      end
      local hp = p.hp
      for _ = 1, 120 do
        e.attack = 99
        g:update(dt, {})
      end
      return hp - p.hp
    end
    check('the visible side of a straight tear can hit once', trial(0.75) == 42)
    check('leaving the tear avoids the entire active phase', trial(1.3) == 0)
    check('stone still blocks the widened tear', trial(0.1, true) == 0)
    check('restoring a warned tear preserves its finite footprint', trial(0.75, false, true) == 42)
  end
  -- The two floor rituals teach different movement responses on real jump clocks.
  do
    local World, Tiles = require('src.world.arena'), require('src.core.tiles')
    local function ritual(id, jumpAt, offset, wall, restoreAt, behind)
      local g, e = actor()
      local p = g.player
      p.armor, p.x, p.z = 0, 16, 24
      for z = 10, 28 do
        for x = 10, 22 do
          World.setCell(g.world, x, z, Tiles.floor)
        end
      end
      local spec
      for _, attack in ipairs(Archetypes.stolas.attacks) do
        if attack.id == id then
          spec = attack
        end
      end
      Actions.begin(g, e, 6, spec)
      Actions.execute(g, e)
      e.ai, e.phase = 'strike', 0
      if behind then
        p.z = 12
      end
      p.x = p.x + (offset or 0)
      if wall then
        World.setCell(g.world, 16, 21, Tiles.wall)
      end
      local hp, jumped, restored = p.hp, false, false
      for i = 1, 240 do
        local time = (i - 1) * dt
        local jump = jumpAt and not jumped and time >= jumpAt
        if jump then
          jumped = true
        end
        e.attack = 99
        g:update(dt, { jump = jump })
        if restoreAt and not restored and time >= restoreAt then
          Snapshot.restore(g, Snapshot.capture(g))
          e, p, restored = g.enemies[1], g.player, true
        end
      end
      return hp - p.hp
    end
    check('a grounded knight is caught once by the low wave', ritual('star-ray') == 40)
    check('a normal timed jump clears the whole low wave', ritual('star-ray', 0.72) == 0)
    check('jumping too early lands back into the wave', ritual('star-ray', 0.05) == 40)
    check(
      'the low wave reaches both sides of the caster',
      ritual('star-ray', nil, 0, false, nil, true) == 40
    )
    check('stone shelters a knight from the low wave', ritual('star-ray', nil, 0, true) == 0)
    check(
      'a restored travelling wave keeps the jump response',
      ritual('star-ray', 0.72, 0, false, 0.65) == 0
    )
    check(
      'a restored wave keeps its single hit receipt',
      ritual('star-ray', nil, 0, false, 1.1) == 40
    )
    check('a jump cannot clear the tall fissure', ritual('star-lance', 0.2) == 42)
    check('a step to the side clears the tall fissure', ritual('star-lance', nil, 1.3) == 0)
  end
  do
    local g, e = actor()
    sidestep(e)
    local started = 0
    g.bus:on('sim', 'AttackTelegraphed', function()
      started = started + 1
    end)
    local x, z = e.x, e.z
    g:update(dt, {})
    check(
      'a ready spell cannot cut short an active sidestep',
      e.ai == 'move' and started == 0 and e.evadeTime < 0.2 and e.x > x
    )
    check(
      'sidestep motion reports its actual velocity and stride',
      math.abs((e.walkSpeed or 0) - math.sqrt((e.x - x) ^ 2 + (e.z - z) ^ 2) / dt) < 1e-8
        and (e.walkSpeed or 0) > 0
    )
    for _ = 1, 40 do
      g:update(dt, {})
    end
    check(
      'the completed sidestep yields to a spell without a leftover motion',
      started > 0 and e.evadeTime == 0
    )
  end
  do
    local g, e = actor()
    Actions.begin(g, e, 7, Archetypes.stolas.attacks[1])
    e.evadeReady = 0.4
    for _ = 1, 12 do
      g:update(dt, {})
    end
    check('sidestep cooldown also elapses during a cast', math.abs(e.evadeReady - 0.3) < 1e-8)
  end
  do
    local g, e = actor()
    sidestep(e)
    local saved = Snapshot.capture(g)
    for _ = 1, 60 do
      g:update(dt, {})
    end
    local expected = Integrity.capture(g)
    Snapshot.restore(g, saved)
    for _ = 1, 60 do
      g:update(dt, {})
    end
    check(
      'restoring a mid-sidestep fight preserves the whole following second',
      not Integrity.difference(expected, Integrity.capture(g))
    )
  end
  do
    local g, e = actor()
    local tells = {}
    for _, id in ipairs({ 'star', 'talon-fan', 'star-trio', 'star-ray', 'star-lance', 'slip' }) do
      local spec
      for _, attack in ipairs(Archetypes.stolas.attacks) do
        if attack.id == id then
          spec = attack
        end
      end
      Actions.begin(g, e, math.min(spec.range, 6), spec)
      local sequence = {}
      for _, share in ipairs({ 0.3, 0.6, 0.9 }) do
        e.windup = e.windupDuration * (1 - share)
        sequence[#sequence + 1] = Animation.pose(g, e)
      end
      local key = table.concat(sequence, '/')
      check(id .. ' has a distinguishable painted preparation', tells[key] == nil)
      tells[key] = id
    end
    local watched = Integrity.capture(g)
    for _ = 1, 50 do
      Pose.sample(g, e)
    end
    check(
      'sampling the new tells never advances simulation',
      not Integrity.difference(watched, Integrity.capture(g))
    )
  end
  -- Presentation follows actual releases, including content with a different cadence.
  for _, interval in ipairs({ 0.21, 0.42, 0.65 }) do
    local g, e = actor()
    local spec
    for _, attack in ipairs(Archetypes.stolas.attacks) do
      if attack.id == 'star-trio' then
        spec = require('src.core.schema').copy(attack)
      end
    end
    spec.interval = interval
    Actions.begin(g, e, 7, spec)
    local frames, last, stable, restored = {}, 0, true, false
    for _ = 1, 480 do
      g.player.hp = g.player.maxHp
      g:update(dt, {})
      if e.ai == 'strike' and e.attackKind == spec.id and (e.released or 0) > 0 then
        local frame = Animation.pose(g, e)
        if e.released ~= last then
          frames[#frames + 1] = frame
          last = e.released
          if last == 2 then
            local saved = Snapshot.capture(g)
            local image = Pose.sample(g, e).frame
            g:update(dt, {})
            Snapshot.restore(g, saved)
            e = g.enemies[1]
            restored = e.released == 2 and Pose.sample(g, e).frame == image
          end
        else
          stable = stable and frame == frames[#frames]
        end
      elseif last == spec.count then
        break
      end
    end
    check(
      'three distinct gestures follow the real salvo at interval ' .. interval,
      #frames == 3
        and frames[1] ~= frames[2]
        and frames[2] ~= frames[3]
        and frames[1] ~= frames[3]
        and stable
    )
    check('restoring a salvo preserves its released gesture at interval ' .. interval, restored)
  end
  do
    local Styles = require('src.enemies.styles')
    local g, e = actor()
    sidestep(e)
    local x = e.x
    e.evadeTime = 0.003
    Styles.evade(g, e, 7, dt)
    check(
      'a final partial sidestep cannot overshoot its remaining time',
      e.evadeTime == 0 and math.abs(e.x - x - Archetypes.of(e).move.evade.speed * 0.003) < 1e-8
    )
    sidestep(e)
    require('src.combat.rules').interrupt(e)
    check(
      'a real stagger cancels the sidestep and its ability painting',
      e.evadeTime == 0 and e.ai == 'hurt'
    )
  end
  do
    local Styles = require('src.enemies.styles')
    local World = require('src.world.arena')
    local Tiles = require('src.core.tiles')
    local g, e = actor()
    e.ai = 'move'
    World.setCell(g.world, 15, 18, Tiles.wall)
    local began = Styles.evade(g, e, 7, dt)
    check('a wall on the preferred side makes the owl choose the open side', began and e.evadeX > 0)
    e.evadeTime, e.evadeReady = 0, 0
    local count = e.evades or 0
    World.setCell(g.world, 17, 18, Tiles.wall)
    check(
      'a blocked corridor does not spend a dodge or play a false escape',
      not Styles.evade(g, e, 7, dt) and (e.evades or 0) == count and e.evadeTime == 0
    )
  end
  for _, deferred in ipairs({ false, true }) do
    local g, e = actor()
    local blink
    for _, attack in ipairs(Archetypes.stolas.attacks) do
      if attack.kind == 'blink' then
        blink = attack
      end
    end
    Actions.begin(g, e, 3, blink)
    if deferred then
      g.bus:beginStep()
    end
    Actions.execute(g, e)
    local x, z = e.x, e.z
    if deferred then
      e.x = e.x + 2
      g.bus:flush()
    end
    local bursts = g.view.blinkBursts or {}
    local arrival = bursts[2]
    check(
      'teleport arrival remembers its actual destination (' .. tostring(deferred) .. ' deferred)',
      arrival and arrival.x == x and arrival.z == z and (x ~= 16 or z ~= 18)
    )
  end
  for _, line in ipairs(lines) do
    print(line)
  end
  assert(#failures == 0, table.concat(failures, '; '))
  return lines
end

return Tests

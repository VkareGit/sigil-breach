-- The storm elite must show and physically deliver the action it commits to.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local Enemies = require('src.content.enemies')
  local Actions = require('src.enemies.actions')
  local Selection = require('src.enemies.attack_selection')
  local World = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Rules = require('src.combat.rules')
  local MathX = require('src.core.mathx')
  local lines, failures, specs = {}, {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'furfur: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  for _, spec in ipairs(Enemies.furfur.attacks) do
    specs[spec.id] = spec
  end
  local function room(distance)
    local g = F.arena(Game)
    for z = 8, 30 do
      for x = 8, 26 do
        World.setCell(g.world, x, z, Tiles.floor)
      end
    end
    local p = g.player
    p.x, p.z, p.yaw, p.armor, p.hp, p.maxHp = 16, 15 + distance, math.pi, 0, 10000, 10000
    local e = g:spawn('furfur', 16, 15)
    e.target, e.awake, e.visible, e.memory, e.spawnAge, e.facing, e.sense =
      p.id, true, true, 60, 2, 0, 10
    g.rng.sim:seed(1)
    return g, e
  end
  local function step(g, e, dt, input)
    e.attack, e.chain = 999, nil
    e.answered =
      { dodged = 999, behind = 999, hugging = 999, drinking = 999, reloading = 999, sniped = 999 }
    g:update(dt, input or {})
  end
  check(
    'health and broken-guard opening are preserved',
    Enemies.furfur.body.hp == 2250 and Enemies.furfur.body.breakTime == 1.2
  )
  check(
    'the rush has only one return and a full punish window',
    specs.charge.turns == 1 and specs.charge.recover == 1.2
  )
  do
    local g, e = room(2.8)
    e.finishedAttack, e.finishedAt, e.finishedTarget, e.lastAttack = 'charge', 0, e.target, 'charge'
    local offered = false
    for _ = 1, 100 do
      local choice = Selection.choose(e, 2.8, specs.charge.recover + 0.05, g.rng.sim, g)
      offered = offered or choice and choice.id == 'antler-return'
    end
    check('the follow-up remains selectable after the protected recovery', offered)
  end
  for _, hz in ipairs({ 60, 120, 240 }) do
    do
      local g, e = room(2.8)
      e.ai, e.finishedAttack, e.finishedAt, e.finishedTarget = 'recover', 'charge', 0, e.target
      Actions.rest(e, specs.charge)
      local first
      g.bus:on('sim', 'AttackTelegraphed', function(event)
        if event.enemy == e then
          first = first or g.elapsed
        end
      end)
      for _ = 1, hz * 3 do
        g:update(1 / hz, {})
        if first then
          break
        end
      end
      check(
        'no fresh attack steals the full charge recovery / ' .. hz,
        first ~= nil and first >= 1.2 - 1e-6
      )
    end
    for _, distance in ipairs({ 1.6, 2.4, 3.2 }) do
      for _, id in ipairs({ 'antler-return', 'antler-pivot' }) do
        local g, e = room(distance)
        local spec = specs[id] or specs['hoof-kick']
        if id == 'antler-pivot' then
          e.facing = math.pi
        end
        Actions.begin(g, e, distance, spec)
        local hp, released, maxTurn = g.player.hp, false, 0
        for _ = 1, hz * 4 do
          local facing = e.facing
          step(g, e, 1 / hz)
          maxTurn = math.max(maxTurn, math.abs(MathX.wrapAngle(e.facing - facing)) * hz)
          released = released or e.ai == 'strike'
          if released and e.ai ~= 'strike' then
            break
          end
        end
        check(
          id .. ' contacts a stationary body at ' .. distance .. 'm / ' .. hz .. 'Hz',
          released and hp - g.player.hp == spec.packet.base
        )
        if id == 'antler-pivot' then
          check(
            'the rear answer turns visibly instead of snapping / ' .. distance .. '/' .. hz,
            maxTurn > 0 and maxTurn <= Enemies.furfur.move.turn + 1e-6
          )
        end
      end
    end
    do
      local g, e = room(6)
      g.player.x, g.player.z, g.player.yaw = 20, 16, math.atan2(-4, -1)
      for x = 8, 26 do
        World.setCell(g.world, x, 18, Tiles.wall)
      end
      check('the storm starts in sight / ' .. hz, Rules.sees(g, e, g.player))
      Actions.begin(g, e, math.sqrt(17), specs['storm-steps'])
      local hidden, seen, newMarks, hp = false, {}, 0, g.player.hp
      for _ = 1, hz * 4 do
        if not hidden and g.elapsed >= 0.75 then
          g.player.x, g.player.z, e.sense, hidden = 20, 21, 0, true
          check('the wall actually hides the target / ' .. hz, not Rules.sees(g, e, g.player))
        end
        step(g, e, 1 / hz)
        for _, h in ipairs(g.hazards) do
          if not seen[h] then
            seen[h] = true
            if hidden and h.z > 18 then
              newMarks = newMarks + 1
            end
          end
        end
      end
      check('later marks do not read a hidden target / ' .. hz, newMarks == 0 and g.player.hp == hp)
    end
    do
      local g, e = room(7)
      Actions.begin(g, e, 7, specs.charge)
      local turned, movingAligned, frozen, turnRate = false, true, true, 0
      local lastAim, oldTurn
      for _ = 1, hz * 5 do
        local facing, wasTurn = e.facing, e.act.turnAt
        step(g, e, 1 / hz, { strafe = 1 })
        if e.ai == 'strike' then
          if wasTurn then
            turned = true
            turnRate = math.max(turnRate, math.abs(MathX.wrapAngle(e.facing - facing)) * hz)
          end
          if e.rushVX and math.abs(e.rushVX) + math.abs(e.rushVZ) > 0 then
            local aim = math.atan2(e.lungeX, e.lungeZ)
            movingAligned = movingAligned and math.abs(MathX.wrapAngle(aim - e.facing)) < 1e-6
            if lastAim and not oldTurn and not wasTurn then
              frozen = frozen and math.abs(MathX.wrapAngle(aim - lastAim)) < 1e-6
            end
            lastAim = aim
          else
            lastAim = nil
          end
        end
        oldTurn = e.act.turnAt
      end
      check('a moving rush faces its actual direction / ' .. hz, movingAligned)
      check(
        'the planted return turns at the body rate / ' .. hz,
        turned and turnRate > 0 and turnRate <= Enemies.furfur.move.turn + 1e-6
      )
      check('a released rush cannot follow later input / ' .. hz, frozen)
    end
  end
  do
    local recipes = require('src.audio.recipes')
    local sounds = Enemies.furfur.sounds
    for _, role in ipairs({ 'breath', 'murmur', 'hurt', 'death', 'alert' }) do
      local voice = sounds[role] and recipes[sounds[role]]
      check(
        'own varied body voice for ' .. role,
        voice and voice.path and #(voice.variants or {}) >= (role == 'death' and 2 or 1)
      )
    end
    for _, id in ipairs({
      'charge',
      'gore',
      'gore-return',
      'crown',
      'antler-return',
      'antler-pivot',
      'lightning',
      'storm-steps',
      'recoil',
    }) do
      local spec = specs[id]
      check(
        id .. ' has a bodily preparation distinct from its material',
        spec and spec.windupVoice and spec.windupVoice ~= spec.windupSound
      )
    end
  end
  do
    local g, e = room(6)
    e.attack = -1
    local blocker = g:spawn('imp', 15, 19)
    local newcomer = g:spawn('imp', 17, 19)
    -- Deliberately put the elite last, as it is in a mixed hall encounter.
    g.enemies = { blocker, newcomer, e }
    for _, body in ipairs({ blocker, newcomer }) do
      body.target, body.awake, body.visible, body.memory, body.spawnAge, body.sense =
        g.player.id, true, true, 60, 2, 10
      body.dummy = true
    end
    Actions.begin(g, blocker, 2, Enemies.imp.attacks[1])
    blocker.ai, blocker.attackSpec, blocker.attackKind =
      'strike', Enemies.imp.attacks[1], Enemies.imp.attacks[1].id
    for _ = 1, 240 do
      g:update(1 / 120, {})
    end
    check(
      'waiting does not interrupt the committed attacker',
      blocker.ai == 'strike' and e.ai == 'move'
    )
    blocker.ai, blocker.recover = 'recover', 1
    newcomer.dummy, newcomer.attack = nil, -1
    g:update(1 / 120, {})
    check(
      'a fresh small attacker cannot steal the slot after the elite waited',
      e.ai == 'windup' and newcomer.ai ~= 'windup' and newcomer.ai ~= 'strike'
    )
  end
  for _, hz in ipairs({ 60, 120, 240 }) do
    for _, id in ipairs({ 'charge', 'antler-return', 'gore', 'antler-pivot' }) do
      local g, e = room(2.6)
      Actions.begin(g, e, 2.6, specs[id])
      for x = 8, 26 do
        World.setCell(g.world, x, 16, Tiles.wall)
      end
      local hp = g.player.hp
      for _ = 1, hz * 4 do
        step(g, e, 1 / hz)
      end
      check(id .. ' cannot deliver through a solid wall / ' .. hz, hp == g.player.hp)
    end
  end
  do
    local Slots = require('src.enemies.attack_slots')
    local Integrity = require('src.session.integrity')
    local g, e = room(6)
    local small = g:spawn('imp', 18, 19)
    small.target = e.target
    e.ai, e.attack, e.slotWaitAt, e.slotWaitTarget, g.elapsed = 'move', -1, 0, e.target, 2
    local before = Integrity.capture(g)
    check('an eligible waiting elite precedes a newcomer', Slots.yields(g, small))
    check(
      'queue inspection does not mutate simulation',
      not Integrity.difference(before, Integrity.capture(g))
    )
    small.chain = 'claw-late'
    check('a reserved connecting beat is not stolen', not Slots.yields(g, small))
    small.chain = nil
    for _, state in ipairs({
      'dead',
      'stunned',
      'recovering',
      'hidden',
      'distant',
      'different-target',
    }) do
      local hp, stun, spent, x, visible, target = e.hp, e.stun, e.spent, e.x, e.visible, e.target
      if state == 'dead' then
        e.hp = 0
      elseif state == 'stunned' then
        e.stun = 1
      elseif state == 'recovering' then
        e.spent = 1
      elseif state == 'hidden' then
        e.visible = false
      elseif state == 'distant' then
        e.x = 80
      else
        e.target = small.id
      end
      check(state .. ' claimant cannot block the target queue', not Slots.yields(g, small))
      e.hp, e.stun, e.spent, e.x, e.visible, e.target = hp, stun, spent, x, visible, target
    end
    for x = 8, 26 do
      World.setCell(g.world, x, 18, Tiles.wall)
    end
    check('fresh cover invalidates a stale visible claimant', not Slots.yields(g, small))
  end
  do
    local Snapshot = require('src.session.snapshot')
    local Integrity = require('src.session.integrity')
    local Save = require('src.storage.save')
    for _, id in ipairs({ 'charge', 'antler-pivot', 'lightning', 'storm-steps' }) do
      for _, at in ipairs({ 0.2, 0.85, 1.4 }) do
        local g, e = room(6)
        Actions.begin(g, e, 6, specs[id])
        for _ = 1, math.floor(at * 120) do
          step(g, e, 1 / 120, { strafe = 1 })
        end
        local before = Integrity.capture(g)
        local section = Save.section('pools')
        section.restore(g, section.unpack(section.pack(g)))
        e = g.enemies[1]
        check(
          id .. ' file Continue retains phase at ' .. at,
          not Integrity.difference(before, Integrity.capture(g))
        )
        local saved = Snapshot.capture(g)
        for _ = 1, 120 do
          step(g, e, 1 / 120, { strafe = -1 })
        end
        local future = Integrity.capture(g)
        Snapshot.restore(g, saved)
        e = g.enemies[1]
        for _ = 1, 120 do
          step(g, e, 1 / 120, { strafe = -1 })
        end
        check(
          id .. ' resumes the same contacts and clocks at ' .. at,
          not Integrity.difference(future, Integrity.capture(g))
        )
      end
    end
    local g, e = room(6)
    local old = require('src.content.migrations.furfur_045').attacks[2]
    Actions.begin(g, e, 6, old)
    local section = Save.section('pools')
    local encoded = section.pack(g)
    local function oldPaths(t)
      if type(t) ~= 'table' then
        return
      end
      if t['$def'] and t['$def'][1] == 'src.content.migrations.furfur_045' then
        t['$def'][1] = 'src.content.creatures.furfur'
      else
        for _, v in pairs(t) do
          oldPaths(v)
        end
      end
    end
    oldPaths(encoded)
    section.restore(g, section.unpack(section.migrations[5](encoded)))
    e = g.enemies[1]
    check(
      'an older Continue retains the already committed three-pass charge',
      e.attackSpec.turns == 2 and e.attackSpec.returnTurn == nil
    )
    e.ai = 'strike'
    Actions.execute(g, e)
    check('the legacy charge still executes', e.act.turnsLeft == 2 and e.chargeTime > 0)
    check(
      'new choices use the current charge after legacy completion',
      Enemies.furfur.attacks[2].turns == 1
    )
  end
  for _, id in ipairs({ 'lightning', 'storm-steps' }) do
    for _, at in ipairs({ 0.2, 0.85, 1.4 }) do
      local g, e = room(6)
      Actions.begin(g, e, 6, specs[id])
      for _ = 1, math.floor(at * 120) do
        step(g, e, 1 / 120)
      end
      e.hp, e.ai, e.deathTime = 0, 'dead', 0
      local hp = g.player.hp
      for _ = 1, 120 do
        g:update(1 / 120, {})
      end
      check(id .. ' death clears owned marks at ' .. at, #g.hazards == 0 and g.player.hp == hp)
    end
  end
  do
    local g, e = room(6)
    Actions.begin(g, e, 6, specs.lightning)
    local mark = g.hazards[1]
    local x, z, hp = mark.x, mark.z, g.player.hp
    for _ = 1, 150 do
      step(g, e, 1 / 120, { strafe = 1 })
    end
    check(
      'leaving the fixed lightning footprint avoids it',
      g.player.hp == hp and mark.x == x and mark.z == z
    )
    check('the last painted flash has no lingering damage field', #g.hazards == 0)
    check('the harmless remnant outlives contact briefly', #(g.view.lightningBursts or {}) == 1)
    for _ = 1, 48 do
      step(g, e, 1 / 120)
    end
    check('the harmless remnant expires', #(g.view.lightningBursts or {}) == 0)
  end
  for _, id in ipairs({ 'gore', 'gore-return' }) do
    local g, e = room(3)
    Actions.begin(g, e, 3, specs[id])
    local aligned, moved = true, false
    for _ = 1, 180 do
      step(g, e, 1 / 120, { strafe = 1 })
      if e.ai == 'strike' and e.rushVX then
        moved = true
        aligned = aligned
          and math.abs(MathX.wrapAngle(math.atan2(e.lungeX, e.lungeZ) - e.facing)) < 1e-6
      end
    end
    check(id .. ' turns the body with its visible antler delivery', moved and aligned)
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T

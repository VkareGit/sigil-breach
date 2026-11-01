-- Live room fights with finite magazines and real reloading. Perfect aiming
-- deliberately removes human skill: these are counterplay/pressure regressions,
-- not a claim about enjoyment or human completion time.
local F = require('tests.support.fixtures')
local Field = require('src.run.test_field')
local Chambers = require('src.run.field.chambers')
local B = require('src.combat.ballistics')
local Ground = require('src.physics.ground')
local A = require('src.content.enemies')
local Weapons = require('src.content.weapons')
local Actions = require('src.enemies.actions')
local Release = require('src.app.release')
local Journal = require('src.session.journal')
local Integrity = require('src.session.integrity')
local T = {}
function T.run(Game)
  -- Rules proven on the encounters they were tuned for (tests/support/v033_encounters.lua).
  Game = require('tests.support.v033_encounters').game(Game)
  local lines = {}
  local check = F.checker(lines, 'creature pressure: ', 'creature pressure: ')
  for _, trial in ipairs({ 'claws', 'iron', 'stars', 'resin' }) do
    for _, weapon in ipairs({ 1, 2 }) do
      local outcomes = {}
      for _, style in ipairs({ 'still', 'react' }) do
        local g = Game.new(
          'field',
          'proving',
          { features = Release.sessionOptions.field.features, attrition = false }
        )
        g.ephemeral = true
        assert(Chambers.start(Field, g, trial, 3))
        g:switchWeapon(weapon)
        local def, state = Weapons.inHand(g)
        local reserve = state.reserve
        local record = trial == 'iron' and weapon == 2 and style == 'react' and Journal.record(g)
        local released, started = 0, 0
        g.bus:on('sim', 'AttackReleased', function()
          released = released + 1
        end)
        g.bus:on('sim', 'AttackTelegraphed', function()
          started = started + 1
        end)
        for step = 1, 3600 do
          local p, nearest, distance = g.player, nil, math.huge
          for _, e in ipairs(g.enemies) do
            local d = math.sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2)
            if e.hp > 0 and d < distance then
              nearest, distance = e, d
            end
          end
          local input = {}
          if nearest then
            p.yaw = math.atan2(nearest.x - p.x, nearest.z - p.z)
            local _, eye = B.origin(g)
            p.pitch = math.atan2(Ground.of(g.world, nearest) + 1.25 - eye, distance)
            input.forward = distance > 8 and 1 or 0
            input.shoot = step % 24 < 12
            if style == 'react' then
              input.strafe = 1
              if nearest.ai == 'windup' and nearest.windup < 0.25 then
                input.dash, input.strafe = true, -1
              end
              input.jump = #g.hazards > 0
            end
            if state.mag == 0 and p.reload == 0 then
              g:reloadGun()
            end
          end
          g:update(1 / 120, input)
          if g.state == 'dead' or g.testField.roomTrial.status == 'complete' then
            break
          end
        end
        local label = trial .. '/' .. def.id .. '/' .. style
        check(
          label .. ' spends finite ammunition against active enemies',
          g.player.shots > 0
            and state.mag + state.reserve < def.ammo.capacity + reserve
            and Weapons.validAmmo(g)
            and started > 0
        )
        if trial == 'iron' then
          check(
            label .. ' crosses a real reload window',
            g.player.shots > def.ammo.capacity and state.reserve < reserve
          )
        end
        if style == 'react' then
          check(
            label .. ' remains winnable with finite ammunition',
            g.player.hp > 0 and g.testField.roomTrial.status == 'complete'
          )
        elseif weapon == 1 then
          -- The precision gun may kill fragile casters during their windup.
          -- Do not require guaranteed damage against a perfectly aimed counter.
          check(
            label .. ' standing and shooting incurs a real cost',
            g.player.hp < 100 or g.player.armor < 40
          )
        end
        outcomes[style] = g.player.hp + g.player.armor
        print(
          string.format(
            'FIGHT %s %.2fs HP=%.1f ward=%.1f shots=%d releases=%d %s',
            label,
            g.elapsed,
            g.player.hp,
            g.player.armor,
            g.player.shots,
            released,
            g.testField.roomTrial.status
          )
        )
        if record then
          Journal.stop(g)
          local replay = Game.new(
            'field',
            'proving',
            { features = Release.sessionOptions.field.features, attrition = false }
          )
          replay.ephemeral = true
          assert(Chambers.start(Field, replay, trial, 3))
          replay:switchWeapon(weapon)
          Journal.replay(replay, Journal.decode(Journal.encode(record)))
          check(
            'aiming, firing, reloading and reactive movement replay exactly',
            not Integrity.difference(Integrity.capture(g), Integrity.capture(replay))
          )
        end
      end
      check(
        trial .. '/' .. weapon .. ' reacting costs no more than standing',
        outcomes.react >= outcomes.still
      )
    end
  end
  for _, id in ipairs({ 'stolas', 'buer' }) do
    local g = F.arena(Game)
    local e = g:spawn(id, 16, 17)
    e.target, e.spawnAge = g.player.id, 2
    g.player.x, g.player.z, g.player.vx = 16, 23, 3
    Actions.begin(g, e, 6, A[id].attacks[1])
    local x, z = e.aimX, e.aimZ
    check(id .. ' predicts observed movement at tier one', x > g.player.x + 1)
    g.player.x, g.player.vx = 13, -3
    Actions.execute(g, e)
    check(id .. ' committed aim cannot track a later dodge', e.aimX == x and e.aimZ == z)
  end
  return lines
end
return T

-- Live acceptance of the bosses: one stock of health, three acts of it.
-- Historical phase fixtures are separate: these decisions, contacts and
-- movement use public content.
local F = require('tests.support.fixtures')
local A = require('src.content.enemies')
local Actions = require('src.enemies.actions')
local Selection = require('src.enemies.attack_selection')
local Release = require('src.app.release')
local Journal = require('src.session.journal')
local Integrity = require('src.session.integrity')
local T = {}
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'boss pressure: ', 'boss pressure: ')
  local function fresh(trial)
    local g = Game.new('field', 'proving', Release.sessionOptions.field)
    g.ephemeral = true
    assert(g:act('catalog', 'field_chamber_' .. trial))
    return g
  end
  for _, id in ipairs({ 'ash', 'storm' }) do
    for _, style in ipairs({ 'still', 'orbit', 'react' }) do
      local g = fresh(id)
      check(
        id .. ' live entry is mortal with normal ward: ' .. style,
        not g.testField.invincible and g.player.armor == 40
      )
      local released, moves = 0, {}
      g.bus:on('sim', 'AttackReleased', function(ev)
        released = released + 1
        moves[ev.attack.id] = true
      end)
      local record = style == 'still' and Journal.record(g)
      for _ = 1, 3600 do
        local e, input = g.enemies[1], {}
        if e and style ~= 'still' then
          g.player.yaw = math.atan2(e.x - g.player.x, e.z - g.player.z)
          input.strafe = 1
          if style == 'react' then
            if e.ai == 'windup' and e.windup < 0.3 then
              input.strafe, input.dash = -1, true
            end
            input.jump = #g.hazards > 0
          end
        end
        g:update(1 / 120, input)
        if g.state == 'dead' then
          break
        end
      end
      local count = 0
      for _ in pairs(moves) do
        count = count + 1
      end
      check(id .. ' uses several actual deliveries: ' .. style, count >= 2 and released >= 2)
      -- One beat of a dodge answers nothing any more: a knight who has learnt the
      -- fight is tests/cases/souls_bots.lua.
      if style ~= 'react' then
        check(
          id .. ' punishes ' .. style .. ' without raising HP',
          -- The 15 x 18 m halls allow a longer orbit than the former cramped
          -- courts. It must still fail within the full 30 s sample; reacting
          -- to the same windups must survive. This is not a human skill score.
          g.state == 'dead' and g.elapsed < 30
        )
      end
      print(
        string.format(
          'MEASURE %s/%s: %.3fs, HP %.1f, ward %.1f, releases %d',
          id,
          style,
          g.elapsed,
          g.player.hp,
          g.player.armor,
          released
        )
      )
      if record then
        Journal.stop(g)
        local replay = fresh(id)
        Journal.replay(replay, Journal.decode(Journal.encode(record)))
        check(
          id .. ' entire live lethal fight replays exactly',
          not Integrity.difference(Integrity.capture(g), Integrity.capture(replay))
        )
      end
    end
    local g = fresh(id)
    for _ = 1, 160 do
      g:update(1 / 120, {})
    end
    local e = assert(g.enemies[1])
    local stocks = 0
    for _, phase in ipairs(A.of(e).phases) do
      stocks = stocks + (phase.refill and 1 or 0)
    end
    check(id .. ' no second stock configured', stocks == 0)
    local deaths, phases = 0, 0
    g.bus:on('sim', 'EnemyKilled', function()
      deaths = deaths + 1
    end)
    g.bus:on('sim', 'EnemyPhaseChanged', function()
      phases = phases + 1
    end)
    g:damageEnemy(e, e.hp, 'weapon', nil, g.player.id)
    g:damageEnemy(e, 9999, 'weapon', nil, g.player.id)
    require('src.run.test_field').update(g, 0.01)
    check(
      id .. ' one exhaustion ends the room and rewards once',
      e.hp == 0 and deaths == 1 and phases == 0 and g.testField.roomTrial.status == 'complete'
    )
  end
  local g = F.arena(Game)
  local e = g:spawn('boss', 16, 17)
  e.target, e.spawnAge = g.player.id, 2
  g.player.x, g.player.z, g.player.vx, g.player.vz = 16, 23, 3, 0
  local fan = A.boss.attacks[1]
  Actions.begin(g, e, 6, fan)
  check('it predicts observed motion, not input buttons', e.aimX > g.player.x + 2)
  local x, z = e.aimX, e.aimZ
  g.player.vx, g.player.x = -3, 13
  Actions.execute(g, e)
  check(
    'changing direction after commitment cannot drag the locked shot',
    e.aimX == x and e.aimZ == z
  )
  check(
    'authored projectile speed and attributed body survive release',
    #g.bullets == fan.count and g.bullets[1].owner == e.id
  )
  check('the blade answers a close knight at once', Actions.choose(e, 1, g.elapsed).id == 'cleave')
  e = g:spawn('furfur', 16, 17)
  e.target = g.player.id
  local charge = A.furfur.attacks[2]
  check(
    'return is unavailable without its physical predecessor',
    Actions.choose(e, 2, 0).id == 'gore'
  )
  Selection.committed(e, charge, e.target)
  Selection.finished(e, charge, 0)
  check(
    'return is available in first stock after charge',
    Actions.choose(e, 2, 0.3).id == 'antler-return'
  )
  check(
    'return expires instead of stealing the next opening',
    Actions.choose(e, 2, 1.1).id == 'gore'
  )
  return lines
end
return T

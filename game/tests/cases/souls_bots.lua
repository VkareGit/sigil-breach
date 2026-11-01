-- Acceptance of the souls plan: every encounter kills a knight who stands there
-- and is won by a knight who learnt its tells, so no blow in it is unavoidable.
local F = require('tests.support.fixtures')
local Bot = require('qa.souls_bot')
local A = require('src.content.enemies')
local Actions = require('src.enemies.actions')
local Release = require('src.app.release')
local T = {}
local trials = { 'claws', 'iron', 'stars', 'resin', 'ash', 'storm' }
local function fight(Game, trial, knight, seconds, seed)
  local g = Game.new('field', 'proving', Release.sessionOptions.field)
  g.testing = true
  if seed then
    g.rng.sim:seed(seed)
  end
  assert(g:act('catalog', 'field_chamber_' .. trial))
  local memory, fired = {}, 0
  g.bus:on('sim', 'AttackReleased', function()
    fired = fired + 1
  end)
  for _ = 1, seconds * 120 do
    g:update(1 / 120, knight(g, memory))
    if g.state ~= 'playing' or g.testField.roomTrial.status ~= 'active' then
      break
    end
  end
  return g, fired
end
-- A pack: what a standing knight cannot survive however well he shoots.
local function pack(Game, knight)
  local g = F.arena(Game)
  g.player.x, g.player.z, g.player.yaw = 16, 24, math.pi
  for _, r in ipairs({
    { 'imp', 13, 18 },
    { 'imp', 19, 18 },
    { 'imp', 16, 16 },
    { 'stolas', 12, 14 },
    { 'buer', 20, 14 },
    { 'armored', 16, 13 },
  }) do
    local e = g:spawn(r[1], r[2], r[3])
    e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, g.player.id
  end
  local memory = {}
  for _ = 1, 90 * 120 do
    g:update(1 / 120, knight(g, memory))
    local alive = 0
    for _, e in ipairs(g.enemies) do
      alive = alive + (e.hp > 0 and 1 or 0)
    end
    if g.state ~= 'playing' or alive == 0 then
      return g, alive
    end
  end
  return g, -1
end
-- One blow of a creature, alone, at the distance it is made for, against a knight
-- who only dodges: the proof that this blow can be avoided from there.
local function blow(Game, id, attack, knight)
  local g = Game.new('field', 'proving', Release.sessionOptions.field)
  g.testing, g.state, g.testField.invincible = true, 'playing', false
  local distance = math.max(attack.minRange, math.min(attack.range, 3))
  g.player.x, g.player.z, g.player.yaw = 10, 19 + distance, math.pi
  local whole = g.player.hp + g.player.armor
  local e = g:spawn(id, 10, 19)
  e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, g.player.id
  e.attack = 99
  local memory, released = {}, 0
  g.bus:on('sim', 'AttackReleased', function(ev)
    released = released + (ev.attack.id == attack.id and 1 or 0)
  end)
  Actions.begin(g, e, distance, attack)
  for _ = 1, 6 * 120 do
    e.attack = 99
    local input = knight(g, memory)
    input.shoot = false
    g:update(1 / 120, input)
    if g.state ~= 'playing' then
      break
    end
  end
  return whole - g.player.hp - g.player.armor, released
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'souls bots: ', 'souls bots: ')
  for _, trial in ipairs(trials) do
    for _, name in ipairs({ 'careless', 'learning' }) do
      local g, fired = fight(Game, trial, Bot[name], 240)
      local won = g.testField.roomTrial.status == 'complete'
      print(
        string.format(
          'MEASURE souls %s/%s: %.1fs %s, HP %.0f, ward %.0f, blows %d',
          trial,
          name,
          g.elapsed,
          won and 'won' or g.state,
          g.player.hp,
          g.player.armor,
          fired
        )
      )
      if name == 'learning' then
        -- A body that rolls its blows is won most of the time, not every time.
        local wins = won and 1 or 0
        for seed = 1, 2 do
          local again = fight(Game, trial, Bot[name], 240, seed)
          wins = wins + (again.testField.roomTrial.status == 'complete' and 1 or 0)
        end
        print(string.format('MEASURE souls %s/learning wins %d of 3', trial, wins))
        check(trial .. ' is won by a knight who learnt it ' .. wins, wins >= 2)
      elseif trial == 'ash' or trial == 'storm' then
        check(trial .. ' kills a knight who stands there', g.state == 'dead' and g.elapsed < 20)
      end
    end
  end
  local failed = {}
  for _, def in A.each() do
    for _, attack in ipairs(def.attacks) do
      local harm, released = blow(Game, def.id, attack, Bot.learning)
      if harm > 0 or released == 0 then
        failed[#failed + 1] = string.format('%s/%s %.0f', def.id, attack.id, harm)
      end
    end
  end
  print('MEASURE blows that landed: ' .. table.concat(failed, ', '))
  check('every blow can be avoided: ' .. table.concat(failed, ', '), #failed == 0)
  for _, name in ipairs({ 'careless', 'learning' }) do
    local g, alive = pack(Game, Bot[name])
    print(
      string.format(
        'MEASURE souls pack/%s: %.1fs, left %d, %s, HP %.0f, ward %.0f',
        name,
        g.elapsed,
        alive,
        g.state,
        g.player.hp,
        g.player.armor
      )
    )
    if name == 'careless' then
      check('a pack kills a knight who stands in the open', g.state == 'dead')
    else
      check('and is beaten by one who learnt it', alive == 0 and g.state == 'playing')
    end
  end
  return lines
end
return T

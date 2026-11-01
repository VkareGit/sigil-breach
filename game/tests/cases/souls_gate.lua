-- The gate of plan v13: a knight who stands and shoots loses, and shooting does
-- not take a body's blows away. Each creature joins GATED when its blows are
-- rebuilt; until then its numbers are only printed.
local F = require('tests.support.fixtures')
local Bot = require('qa.souls_bot')
local Release = require('src.app.release')
local T = {}
local TRIALS = { 'ash', 'storm', 'claws', 'iron', 'stars', 'resin' }
local GATED = { ash = true, storm = true }
local UNSHOT = 30
local function fight(Game, trial, knight, seconds, unhurt, seed)
  local g = Game.new('field', 'proving', Release.sessionOptions.field)
  g.testing = true
  if seed then
    g.rng.sim:seed(seed)
  end
  assert(g:act('catalog', 'field_chamber_' .. trial))
  if unhurt then
    g.testField.invincible = true
  end
  local memory, blows, alive, last = {}, 0, 0, nil
  g.bus:on('sim', 'AttackReleased', function()
    blows = blows + 1
  end)
  for _ = 1, seconds * 120 do
    g:update(1 / 120, knight(g, memory))
    last = g.enemies[1] or last
    -- A broken guard is earned: only the time it stands free counts.
    alive = alive + ((last and last.hp > 0 and (last.stun or 0) == 0) and 1 / 120 or 0)
    if g.state ~= 'playing' or g.testField.roomTrial.status ~= 'active' then
      break
    end
  end
  return g, blows / math.max(alive, 1), last
end
local function idle()
  return {}
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'souls gate: ', 'souls gate: ')
  for _, trial in ipairs(TRIALS) do
    local g, _, e = fight(Game, trial, Bot.careless, 180)
    local _, unshot = fight(Game, trial, idle, UNSHOT, true)
    local _, shot = fight(Game, trial, Bot.careless, UNSHOT, true)
    local left = e and e.hp / e.maxHp or 1
    print(
      string.format(
        'MEASURE gate %s: %s after %.1fs, body left %.0f%%; blows per second %.2f unshot, %.2f shot',
        trial,
        g.state,
        g.elapsed,
        left * 100,
        unshot,
        shot
      )
    )
    if GATED[trial] then
      check(trial .. ' kills a knight who stands and shoots', g.state == 'dead')
      check(trial .. ' still has most of its life then ' .. left, left > 0.6)
      check(trial .. ' keeps its blows under fire ' .. shot / unshot, shot >= unshot * 0.8)
      -- Moving and dodging by habit is no answer: only knowing the blows is.
      local fell = 0
      for seed = 1, 3 do
        for _, name in ipairs({ 'reflex', 'oneSide' }) do
          local h = fight(Game, trial, Bot[name], 240, false, seed)
          print(
            string.format('MEASURE gate %s %s: %s after %.1fs', trial, name, h.state, h.elapsed)
          )
          fell = fell + (h.state == 'dead' and 1 or 0)
        end
      end
      check(trial .. ' beats a knight who only moves ' .. fell, fell == 6)
      -- The curve: who misreads half the blows does not win.
      local wins = 0
      for seed = 1, 3 do
        local stream = require('src.core.rng'):new(seed)
        local h = fight(
          Game,
          trial,
          Bot.human(0.5, function()
            return stream:random()
          end),
          240,
          false,
          seed
        )
        wins = wins + (h.testField.roomTrial.status == 'complete' and 1 or 0)
      end
      check(trial .. ' is not won by half a reading ' .. wins, wins <= 1)
    end
  end
  return lines
end
return T

-- The gate of plan v13: a knight who stands and shoots loses, and shooting does
-- not take a body's blows away. Each creature joins GATED when its blows are
-- rebuilt; until then its numbers are only printed.
local F = require('tests.support.fixtures')
local Bot = require('qa.souls_bot')
local Release = require('src.app.release')
local T = {}
local TRIALS = { 'ash', 'storm', 'claws', 'iron', 'stars', 'resin' }
local GATED = { ash = true, storm = true }
-- Trials whose body is a true boss, held to beating a knight who only moves (none yet).
local BOSS_GATE = {}
local UNSHOT = 30
local function fight(Game, trial, knight, seconds, unhurt, seed)
  local g = Game.new('field', 'proving', Release.sessionOptions.field)
  g.ephemeral = true
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
      -- 0.43 (owner, docs/WIZJA.md, Decyzje): elites are short fights; standing and
      -- shooting must fail, not be hopeless, so the body only has to outlive that knight.
      check(trial .. ' outlives a knight who stands and shoots ' .. left, left > 0)
      -- Furfur's charge is answered by a shot in its window (parry 0.2), and since 0.43 his
      -- lightning reaches 18 m, which raises his unshot rate: he keeps 0.7 of it (0.47 a second
      -- under fire, as the Margrave); the Margrave keeps 0.8.
      local keeps = trial == 'storm' and 0.7 or 0.8
      check(trial .. ' keeps its blows under fire ' .. shot / unshot, shot >= unshot * keeps)
      -- Moving and dodging by habit is no answer: only knowing the blows is.
      local fell = 0
      for seed = 1, 3 do
        for _, name in ipairs({ 'reflex', 'oneSide' }) do
          local h = fight(Game, trial, Bot[name], 240, false, seed)
          print(
            string.format(
              'MEASURE gate %s %s: %s after %.1fs, HP %.0f',
              trial,
              name,
              h.state,
              h.elapsed,
              h.player.hp
            )
          )
          fell = fell + (h.state == 'dead' and 1 or 0)
        end
      end
      -- Most of the time until the hardest bodies get their own pass. 0.43: the Margrave and
      -- Furfur are short elites by the owner's decision, not those bodies; against them a
      -- habit is measured above and judged in the owner's trial (ODBIOR-0.43), and the gate
      -- returns with the first true boss (BOSS_GATE).
      if BOSS_GATE[trial] then
        check(trial .. ' beats a knight who only moves ' .. fell, fell >= 4)
      end
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
        print(
          string.format(
            'MEASURE gate %s half a reading: %s after %.1fs, HP %.0f',
            trial,
            h.testField.roomTrial.status,
            h.elapsed,
            h.player.hp
          )
        )
      end
      -- Like the habit above: measured for the owner's trial, held for true bosses (0.43).
      if BOSS_GATE[trial] then
        check(trial .. ' is not won by half a reading ' .. wins, wins <= 1)
      end
    end
  end
  return lines
end
return T

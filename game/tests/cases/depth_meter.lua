-- PLAN B1: the meter of a fight's depth (qa/reviews/depth_meter.lua) is a tool that the
-- gate keeps alive: it counts a fight from the session's events, the same fight the same,
-- and its knights are what their names say. It judges nothing of the game.
local F = require('tests.support.fixtures')
local Meter = require('qa.reviews.depth_meter')
local T = {}
local function named(list, id)
  for _, entry in ipairs(list) do
    if entry.id == id then
      return entry
    end
  end
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'depth meter: ', 'depth meter: ')
  local seen = {}
  for _, knight in ipairs(Meter.knights) do
    check(
      'knight ' .. knight.id .. ' is named once and acts',
      not seen[knight.id] and type(knight.make(1)) == 'function'
    )
    seen[knight.id] = true
  end
  for _, fight in ipairs(Meter.fights) do
    check('fight ' .. fight.id .. ' names who stands in it', #Meter.cast(fight) > 0)
  end
  local claws, trio = named(Meter.fights, 'claws'), named(Meter.fights, 'trio')
  local restless, careless = named(Meter.knights, 'restless'), named(Meter.knights, 'careless')
  local novice = named(Meter.knights, 'novice')
  local first, again = Meter.fight(Game, claws, restless, 1), Meter.fight(Game, claws, restless, 1)
  local same = true
  for key, value in pairs(first) do
    same = same and again[key] == value
  end
  check('a fight counted twice is the same fight', same)
  check(
    'it ends, in a kill, a death or its time',
    first.time > 0
      and (first.outcome == 'won' or first.outcome == 'died' or first.outcome == 'time')
  )
  check(
    'the knight who reads nothing never stands still',
    first.dodges > 0 and first.jumps > 0 and first.shots > 0
  )
  local stood = Meter.fight(Game, claws, careless, 1)
  check('the knight who stands neither dodges nor jumps', stood.dodges == 0 and stood.jumps == 0)
  check('and still pulls the trigger', stood.shots > 0)
  -- A knight who rolls his mistakes rolls them the same for the same seed.
  local once, twice = Meter.fight(Game, claws, novice, 2), Meter.fight(Game, claws, novice, 2)
  check('a knight who errs errs the same for the same seed', once.time == twice.time)
  local group = Meter.fight(Game, trio, restless, 1)
  check('a group is a fight too: its blows are counted', group.blows > 0 and group.time > 0)
  -- A group is fought where effort is paid, like a chamber: on the plain test floor a dodge
  -- costs nothing, and the same knight dodged 56 times in ten seconds and was never hurt.
  -- Three dodges from whole stamina, then about one a second, and one more for each
  -- perfect one (content/knight.lua).
  check(
    'the knight who reads nothing dodges only as his stamina allows ('
      .. group.dodges
      .. ' in '
      .. string.format('%.1f', group.time)
      .. ' s)',
    group.dodges <= 3 + group.time * 1.2 + group.perfect
  )
  -- What he carries is part of the fight: a new way's knight has the Judge alone.
  local alone = Meter.fight(Game, claws, careless, 1, named(Meter.arms, 'judge'))
  check(
    'a knight armed as a new way arms him carries the Judge alone',
    alone.carried:find('judge', 1, true) ~= nil and alone.carried:find('exorcist', 1, true) == nil
  )
  check('and as the proving ground arms him, both', stood.carried:find('exorcist', 1, true) ~= nil)
  local report = Meter.report(Game, true)
  local text = table.concat(report, '\n')
  check(
    'the report has its table and its reading',
    text:find('FIGHT claws', 1, true) ~= nil and text:find('reading:', 1, true) ~= nil
  )
  return lines
end
return T

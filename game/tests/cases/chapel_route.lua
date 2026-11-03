-- The chapel played through, not piece by piece (audit E03): a reading knight walks from the
-- first fire toward the sanctuary for three minutes of the real map, with every creature at its
-- post, and the loop holds together: he fights, kills, is paid in souls and rounds, dies and
-- wakes at his fire, and no fire takes him in while he is hunted. Deterministic: the session's
-- rolls and the bot's own.
local Bot = require('qa.souls_bot')
local F = require('tests.support.fixtures')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local Stats = require('src.session.stats')
local T = {}
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'chapel route: ', 'chapel route: ')
  P.forget()
  local g = Game.new('pilgrimage', nil, { origin = false })
  g.ephemeral = true
  g:act('start')
  g.state = 'playing'
  local knight, memory = Bot.walker(Bot.learning), {}
  local deaths, packs, refused, rested, peak = 0, 0, 0, 0, 0
  for _ = 1, 90 * 120 do
    if g.state == 'dead' then
      deaths = deaths + 1
      g:act('retry')
      memory = {}
      check('a death wakes him at his fire', P.fireHere(g) ~= nil)
    elseif g.state == 'shop' then
      g:act('closeShop')
    end
    if g.state == 'playing' and P.fireHere(g) and P.fighting(g) then
      g:interact()
      refused = refused + (g.state == 'shop' and 1 or 0)
    end
    g:update(1 / 120, knight(g, memory, 24, 10.5))
    -- A creature's drop, not a cache the map laid (those carry the map's rewardId).
    for _, pickup in ipairs(Pools.of(g, 'pickups')) do
      packs = math.max(packs, (pickup.kind == 'ammo' and not pickup.rewardId) and 1 or 0)
    end
    local awake = 0
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      awake = awake + ((e.awake and e.hp > 0) and 1 or 0)
    end
    peak = math.max(peak, awake)
    rested = rested + (g.state == 'shop' and 1 or 0)
  end
  check('he fights his way in: creatures fall', Stats.total(g, 'kills') > 0)
  check('and souls are paid', g.run.wallet > 0 or g.run.echo ~= nil or deaths > 0)
  check('the alarm brings more than two at once', peak > 2)
  check('creatures leave rounds on the way', packs > 0)
  check('a hunted knight is never taken in by a fire', refused == 0)
  check(
    string.format(
      'the route is recorded: %d kills, %d deaths, at most %d awake, sanctuary %s',
      Stats.total(g, 'kills'),
      deaths,
      peak,
      g.run.lit.sanctuary and 'lit' or 'not reached'
    ),
    true
  )
  P.forget()
  return lines
end
return T

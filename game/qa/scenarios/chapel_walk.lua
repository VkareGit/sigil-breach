-- A walk from the first fire up the nave, the same every time: the golden master's
-- picture of the game as it is played. clumsy: a knight who misreads a third of it.
local Bot = require('qa.souls_bot')
local Way = require('src.run.pilgrimage')
local S = {}
local TICK = 1 / 120
function S.run(G, clumsy, observe, seconds)
  Way.forget()
  local g = G.new('pilgrimage')
  g.testing = true
  g:start()
  local seed = 1
  local function roll()
    seed = seed * 16807 % 2147483647
    return seed / 2147483647
  end
  local knight = Bot.walker(clumsy and Bot.human(0.3, roll) or Bot.learning)
  local memory = {}
  for tick = 1, seconds * 120 do
    if g.state == 'dead' then
      g:act('retry')
      memory = {}
    end
    g:update(TICK, knight(g, memory, 24, 10.5))
    if observe then
      observe(g, tick)
    end
  end
  Way.forget()
  return { session = g }
end
return S

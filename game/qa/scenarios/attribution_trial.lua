-- The attribution trial (plan v11 E0): one kill by every source a death can
-- name (session/damage_outcomes.lua: weapon, charge, ability, effect:<id>,
-- slam, collision, creature), each with the body steady and off balance,
-- in an expedition (its kills leave souls). The golden runs kill with the
-- weapon only; this is the reference of who is healed and rewarded for the
-- rest, the pattern E3's damage chain must keep for one player.
local Rules = require('src.combat.rules')
local Run = require('src.run.descent')
local S = {}
S.sources = { 'weapon', 'charge', 'ability', 'effect:burning', 'slam', 'collision', 'creature' }
-- observer(g, step) after every step, as the golden recorders take it.
function S.run(G, observer)
  local g = G.new('descent')
  g.testing = true
  g:start()
  Run.ready(g)
  local step = 0
  local function advance()
    step = step + 1
    g:update(1 / 120, {})
    if observer then
      observer(g, step)
    end
  end
  advance()
  local n = 0
  for _, source in ipairs(S.sources) do
    for _, broken in ipairs({ false, true }) do
      n = n + 1
      local e = g:spawn('imp', 10 + n * 0.5, 12)
      e.spawnAge, e.rewardId, e.rewardSouls = 1, 'trial_' .. n, 10 + n
      if broken then
        Rules.markBroken(e, 'guard')
      end
      g.player.hp = 40
      g:damageEnemy(e, e.hp + 5, source)
      advance()
    end
  end
  return g
end
return S

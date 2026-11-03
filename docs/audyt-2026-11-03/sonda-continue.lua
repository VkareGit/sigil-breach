-- Audit probe (2026-11-03, not part of the game): what a quit and Continue leave.
local F = require('tests.support.fixtures')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local T = {}
local function byPost(g, post)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.post == post then
      return e
    end
  end
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'probe continue: ', 'probe continue: ')
  P.forget()
  local g = Game.new('pilgrimage')
  g:act('start')
  for _, post in ipairs({ 'nave_1', 'nave_2', 'nave_3' }) do
    local e = byPost(g, post)
    g:damageEnemy(e, e.hp + 1, 'weapon', nil, g.player.id)
  end
  g.player.hp = 20
  local wallet = g.run.wallet
  g:act('flush')
  local again = Game.new('pilgrimage')
  again:act('start')
  local back = 0
  for _, post in ipairs({ 'nave_1', 'nave_2', 'nave_3' }) do
    local e = byPost(again, post)
    back = back + ((e and e.hp > 0) and 1 or 0)
  end
  print(
    string.format(
      'MEASURE continue: wallet before %d after %d; hp before 20 after %d of %d; killed standing again %d of 3; fire %s',
      wallet,
      again.run.wallet,
      again.player.hp,
      again.player.maxHp,
      back,
      tostring(again.run.fire)
    )
  )
  check('souls kept after Continue', again.run.wallet == wallet and wallet > 0)
  check('health refilled after Continue', again.player.hp == again.player.maxHp)
  check('the killed stand again after Continue', back == 3)
  P.forget()
  return lines
end
return T

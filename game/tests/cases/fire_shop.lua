local F = require('tests.support.fixtures')
local W = require('src.content.weapons')
local P = require('src.run.pilgrimage')
local E = require('src.run.economy')
local Save = require('src.storage.save')
local Supplies = require('src.session.interactions').supplies
local Encounter = require('src.session.encounter')
local T = {}
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'fire shop: ', 'fire shop: ')
  local g = Game.new('pilgrimage', nil, { origin = false })
  g.ephemeral, g.state = true, 'playing'
  local p = g.player
  check('a new way has Judge alone', #p.loadout == 1 and p.loadout[1] == 'judge')
  check(
    'unowned shells stay on the ground',
    not Supplies.ammo.wanted(p, { weapon = 'exorcist', amount = 2 })
  )
  check('Exorcist costs 300', E.quote(g, 'weapon_exorcist') == 300)
  local temperPrice, temperReason = E.quote(g, 'temper_exorcist')
  check(
    'locked temper keeps its real price and names the missing weapon',
    temperPrice == 250 and temperReason ~= nil and temperReason:find('EXORCIST', 1, true) ~= nil
  )
  check('a purchase outside the fire is refused', not E.buy(g, 'weapon_exorcist'))
  Encounter.clearStage(g)
  p.x, p.z = 27, 35
  g:interact()
  g.run.wallet = 299
  check('299 souls cannot buy the gun', not E.buy(g, 'weapon_exorcist') and g.run.wallet == 299)
  g.run.wallet = 600
  local bought = g:act('buy', 'weapon_exorcist')
  check('purchase pays once', bought and g.run.wallet == 300 and W.slotOf(g, 'exorcist') ~= nil)
  check('second purchase is refused', not E.buy(g, 'weapon_exorcist') and g.run.wallet == 300)
  if W.slotOf(g, 'exorcist') then
    local mag, reserve = W.meter(g, W.slotOf(g, 'exorcist'))
    check('purchase fills chamber and target reserve', mag == 2 and reserve == 20)
    check(
      'owned shells can now be picked up after spending',
      (function()
        W.stock(g, 'exorcist', 0)
        return Supplies.ammo.wanted(p, { weapon = 'exorcist', amount = 2 })
      end)()
    )
  end
  local data =
    Save.decode('pilgrimage', Save.encode('pilgrimage', Save.capture('pilgrimage', g), 1))
  local resumed = Game.new('pilgrimage', nil, { origin = data })
  resumed.ephemeral = true
  check(
    'Continue retains purchase and wallet',
    W.slotOf(resumed, 'exorcist') ~= nil and resumed.run.wallet == 300
  )
  g:act('closeShop')
  p.hp, p.armor = 1, 0
  g:damagePlayer(1000, p.x, p.z)
  g:act('retry')
  check('death retains the purchased gun', W.slotOf(g, 'exorcist') ~= nil)
  check('tempering II stays closed', require('src.content.shop').get('temper_judge').limit == 1)
  return lines
end
return T

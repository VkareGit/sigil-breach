-- Plan v12 R7: a run of three stages on two maps, two glyphs, a new supply and a
-- new offer, through public registries alone.
local Proof = require('tests.support.extension.proof')
local Glyphs = require('src.content.glyphs')
local Interactions = require('src.session.interactions')
local Descent = require('src.run.descent')
local Pools = require('src.session.world')
local Runs = require('src.content.runs')
local RunSave = require('src.storage.run_save')
local Schema = require('src.core.schema')
local Shop = require('src.content.shop')
local Spawn = require('src.session.spawn')
local Supplies = require('src.content.supplies')
local Waves = require('src.content.waves')
local Weapons = require('src.content.weapons')
local R = {}
local function wave()
  return { cap = 1, tip = 'wave_tip_1', queue = { 'imp' }, pack = 1 }
end
function R.run(Game, check)
  check(
    'a stage on an unknown map is refused',
    not pcall(Runs.register, Runs, 'proof_wrong', { stages = { { map = 'nowhere', waves = {} } } })
  )
  check('an unknown glyph is refused by a save', Glyphs.problem('proof_nothing') ~= nil)
  local g = Game.new('expedition')
  check('the expedition is a run of one stage', g.run.plan == 'expedition' and g.run.stage == 1)
  check('and it has no second', not pcall(Descent.nextStage, g))
  Proof.with({
    function()
      Runs:unregister('proof_circles')
      Glyphs:unregister('proof_rune')
      Supplies:unregister('proof_relic')
      Interactions.supplies.proof_relic = nil
      Shop.undefine('proof_offer')
      Weapons.get('judge').glyphs.proof_rune = nil
    end,
  }, function()
    Runs:register('proof_circles', {
      stages = {
        { map = 'limbo', waves = { wave(), wave() } },
        { map = 'proving', waves = { wave(), wave() } },
        { map = 'limbo', waves = { wave(), wave() } },
      },
    })
    g = Game.new('expedition')
    g.testing, g.state = true, 'playing'
    local r = g.run
    r.plan = 'proof_circles'
    check('its waves come from its stage', Runs.total(r) == 1 and #Runs.stage(r).waves == 2)
    Descent.nextStage(g)
    check('a stage changes the world', g.world.mapId == 'proving' and r.stage == 2 and r.wave == 1)
    check('the knight stands at its spawn', g.player.x == g.world.spawn.x)
    check('and keeps what it carries', Weapons.state(g) ~= nil)
    r.phase = 'preparing'
    local data = Descent.snapshot(g)
    check('a save between stages names its stage', data.stage == 2 and data.plan == 'proof_circles')
    local kept = Game.new('expedition')
    kept.testing = true
    Descent.load(kept, data)
    check('and loads there', kept.run.stage == 2 and kept.run.plan == 'proof_circles')
    r.wave = 2
    r.phase = 'wave'
    Descent.finishWave(g)
    check('the last wave of a stage leads to the next', r.stage == 3 and g.world.mapId == 'limbo')
    r.wave, r.phase = 2, 'wave'
    Descent.finishWave(g)
    check('the last stage ends the run', r.phase == 'complete' and g.state == 'won')
    -- A defeat goes back to the same stage.
    check('nothing lies past the last stage', not pcall(Descent.nextStage, g))
    -- Two glyphs at once, a third entry beside the two of production.
    Glyphs:register('proof_rune', { icon = 'ring' })
    Weapons.get('judge').glyphs.proof_rune = { set = {}, scale = { impact = 2 }, spread = 0.5 }
    g = Game.new('expedition')
    g.testing, g.state = true, 'playing'
    g.player.weapon = 2
    local plain = Weapons.attack(g, 2).impact
    local one = Weapons.attack(g, 2, { 'proof_rune' }).impact
    local two = Weapons.attack(g, 2, { 'proof_rune', 'proof_rune' }).impact
    check('a glyph is a registry entry', one == plain * 2)
    check('two work at once', two == plain * 4)
    g.run.owned.proof_rune, g.run.glyph = true, 'proof_rune'
    local saved = Schema.copy(Descent.snapshot(g))
    check('a save reads the registry', Glyphs.ownedProblem(saved.owned) == nil)
    check('RunSave keeps its schema', RunSave ~= nil)
    -- A new supply: drawn, wanted, taken.
    Supplies:register('proof_relic', { icon = 'ring', size = 0.4 })
    Interactions.supplies.proof_relic = {
      wanted = function()
        return true
      end,
      take = function(player, pickup)
        player.armor = player.armor + pickup.amount
        return 'relic'
      end,
    }
    local armor = g.player.armor
    Spawn.make(g, 'pickup', { kind = 'proof_relic', amount = 5, x = g.player.x, z = g.player.z })
    Interactions.collectSupplies(g)
    check('a new supply is taken', g.player.armor == armor + 5 and #Pools.of(g, 'pickups') == 0)
    Shop.define({
      id = 'proof_offer',
      kind = 'charge',
      ability = 'powder',
      icon = 'ammo',
      price = 1,
    })
    check('a new offer enters the shop', Shop.get('proof_offer').price == 1)
  end)
  check('its entries leave with it', not Runs:has('proof_circles') and not Glyphs:has('proof_rune'))
  check('the wave list stays the run of one stage', #Runs.stage({}).waves == #Waves)
end
return R

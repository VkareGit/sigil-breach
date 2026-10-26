-- Plan v5 G1: values the code used to repeat now come from one place, and a
-- view command replays exactly. Each check is a regression of one fix.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'consistency: ', 'consistency: ')
  local Tuning = require('src.content.tuning')
  local Field = require('src.run.test_field')
  local Run = require('src.run.descent')
  local Dodge = require('src.combat.dodge')
  local Weapons = require('src.content.weapons')
  local Damage = require('src.combat.damage')
  local Journal = require('src.session.journal')
  local Reload = require('src.combat.reload')

  -- A1: the knight's dodge charges are data, wherever they are refilled.
  local charges = Tuning.knight.dashCharges
  Tuning.knight.dashCharges = 3
  local ok, err = pcall(function()
    local g = Field.new(G)
    g.testing = true
    Field.refill(g)
    check('the proving ground refills every dodge charge of the data', g.player.dash == 3)
    Field.close(g)
    g.testField.invincible = false
    g.player.dash = 2.5
    Dodge.perfect(g, { impact = 10 }, nil)
    check('a perfect dodge refunds up to the data, not up to two', g.player.dash == 3)
    g = Fixtures.expedition(G)
    g.run.phase = 'wave'
    g.player.dash = 0
    Run.finishWave(g)
    check('a cleansed wave restores every dodge charge of the data', g.player.dash == 3)
  end)
  Tuning.knight.dashCharges = charges
  assert(ok, err)

  -- A2: the proving ground's weapon buttons follow the knight's loadout.
  local g = Field.new(G)
  g.testing = true
  local same = #Field.weapons(g) == #g.player.loadout
  for slot, entry in ipairs(Field.weapons(g)) do
    same = same and entry.id == slot and entry.name == Weapons.get(g.player.loadout[slot]).name
  end
  check('the proving ground lists the weapons of the loadout', same)

  -- A3: the FOCUS engraving is the shotgun's glyph data.
  g.run.glyph = 'choke'
  g.player.weapon = 1
  local shotgun = require('src.combat.loadout').spread(g)
  g.player.weapon = 2
  check(
    'FOCUS narrows the shotgun by its data and leaves the revolver as made',
    shotgun == Weapons.get('exorcist').glyphs.choke.spread
      and require('src.combat.loadout').spread(g) == 1
  )

  -- A4: the reload timeline is data; the opened breech announces its cases.
  g = Field.new(G)
  g.testing = true
  Field.close(g)
  local state = g.player.arsenal.exorcist
  state.mag, state.spent = 0, 2
  local stages = {}
  g.bus:on('present', 'ReloadStage', function(e)
    stages[#stages + 1] = e
  end)
  Reload.start(g, true)
  local open = Tuning.reload.breech.open
  Reload.update(g, open - 0.001)
  local before = state.open
  Reload.update(g, 0.002)
  check(
    'the breech opens at its data time and the event carries the spent cases',
    not before and state.open and stages[1] and stages[1].stage == 'open' and stages[1].spent == 2
  )

  -- B1: the armour a report shows is the armour the wound met.
  g = Field.new(G)
  g.testing = true
  local boss = g:spawn('boss', 16, 20)
  local attack = Weapons.get('judge').attack
  check(
    "the Margrave's bare skull shows no armour, its torso does",
    Damage.armorLoss(attack, boss, 6, 'head') == 0
      and Damage.armorLoss(attack, boss, 6, 'torso') > 0
  )

  -- A8: the mouse is a command; a journal replays the aim exactly.
  g = Field.new(G)
  g.testing = true
  Field.close(g)
  local journal = Journal.record(g)
  g:look(0.25, 5)
  check(
    'looking turns the yaw and keeps the pitch within the camera limit',
    g.player.pitch == Tuning.camera.pitchLimit
  )
  g:look(-0.1, -0.3)
  g:update(1 / 120, {})
  Journal.stop(g)
  local copy = Field.new(G)
  copy.testing = true
  Field.close(copy)
  Journal.replay(copy, journal)
  local looks = 0
  for _, entry in ipairs(journal.entries) do
    looks = looks + (entry[1] == 'look' and 1 or 0)
  end
  check(
    'the journal keeps every look and the replay ends with the same aim',
    looks == 2 and copy.player.yaw == g.player.yaw and copy.player.pitch == g.player.pitch
  )
  return lines
end
return Tests

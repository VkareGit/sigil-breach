-- Plan v5 G4: the feel of the fight as rules. A staggered knight cannot
-- aim; a pull stops a reload while rounds remain; a broken guard holds the
-- world's missiles too; the view looks further; a dodge through a blow is a
-- perfect dodge even when the knight left its reach (the afterimage).
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'fight rules: ', 'fight rules: ')
  local Field = require('src.run.test_field')
  local Rules = require('src.combat.rules')
  local Tuning = require('src.content.tuning')
  local Telemetry = require('src.combat.telemetry')
  local Spawn = require('src.session.spawn')
  local Attacks = require('src.enemies.actions')
  local function field()
    local g = Field.new(G)
    g.testing = true
    Field.close(g)
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 26, math.pi, 0
    return g
  end
  local function step(g, seconds, input)
    for _ = 1, math.floor(seconds * 120 + 0.5) do
      g:update(1 / 120, input or {})
    end
  end

  -- The guard meter follows the same current threshold as a physical hit.
  local guardGame = field()
  local iron = guardGame:spawn('armored', 16, 20)
  iron.attackSpec = iron.archetype.attacks[1]
  local threshold = Rules.body(iron).poise
  for _, state in ipairs({ 'windup', 'strike', 'recover', 'move' }) do
    iron.ai = state
    local expected = (state == 'windup' or state == 'strike') and threshold * iron.attackSpec.hyper
      or threshold
    check(
      'effective guard follows the ' .. state .. ' phase',
      Rules.guardThreshold(iron) == expected
    )
  end
  iron.ai = 'windup'
  local broke = Rules.guard(iron, 44)
  local rectangle, width = love.graphics.rectangle
  love.graphics.rectangle = function(_, x, y, w)
    if x == 13 and y == 17 then
      width = w
    end
  end
  local drawn, problem = pcall(require('src.ui.hud').guardStrip, guardGame, iron, 13, 17, 144)
  love.graphics.rectangle = rectangle
  assert(drawn, problem)
  check('44 impact fills only 44 of 72 hyperarmoured guard', not broke and width == 88)
  check('the remaining 28 impact breaks that same guard', Rules.guard(iron, 28))

  -- D2: off balance, the knight cannot aim.
  local g = field()
  g.weapon = 2
  Rules.addCondition(g.player, 'staggered', 0.3)
  local blocked = not g:shoot()
  step(g, 0.31)
  check('a staggered knight cannot fire until he finds his balance', blocked and g:shoot())

  -- D3: a pull stops the Judge's reload while rounds remain.
  g = field()
  g.weapon = 2
  local judge = g.player.arsenal.judge
  judge.mag = 3
  g:reloadGun()
  step(g, 0.1)
  local early = g:shoot()
  check(
    'before the cylinder swings out, a pull fires and stops the reload',
    early and g.reload == 0
  )
  g = field()
  g.weapon = 2
  judge = g.player.arsenal.judge
  judge.mag = 3
  g:reloadGun()
  step(g, 0.5)
  local snapped = not g:shoot() and g.reload == 0 and not judge.open
  step(g, Tuning.reload.cylinder.closeOnFire + 0.01)
  check('a swung-out cylinder snaps shut, then its rounds fire', snapped and g:shoot())
  g = field()
  g.weapon = 2
  judge = g.player.arsenal.judge
  judge.mag = 3
  g:reloadGun()
  step(g, Tuning.revolverLoadTime + 0.05)
  check('once the new rounds are in, the reload runs to its end', not g:shoot() and g.reload > 0)

  -- D4: a broken guard holds the demons' missiles with the world.
  g = field()
  local bolt =
    Spawn.make(g, 'projectile', { x = 16, y = 1.2, z = 20, vx = 0, vy = 0, vz = 5, life = 3 })
  g.worldStop = Tuning.feel.guardBreakStop
  local z = bolt.z
  step(g, 1 / 120)
  local held = bolt.z == z
  step(g, Tuning.feel.guardBreakStop)
  check('a missile waits while the world holds its breath, then flies on', held and bolt.z > z)

  -- D6: the view looks further up and down.
  g = field()
  g:look(0, 5)
  check('the view looks up to its limit of 1.2 rad', g.player.pitch == Tuning.camera.pitchLimit)

  -- G6: the shot is felt in the view and is back before the next pull.
  local Weapons = require('src.content.weapons')
  for slot = 1, 2 do
    g = field()
    g.weapon = slot
    local def = Weapons.inHand(g)
    g:shoot()
    local peak = 0
    local t = 0
    while t < def.cycle - 1e-9 do
      g:update(1 / 120, {})
      t = t + 1 / 120
      peak = math.max(peak, g.view.aimKick or 0)
    end
    check(
      def.name .. ': the view climbs and is back on the firing ray before the next pull',
      peak > 0.8 * def.weight.viewKick
        and math.abs(g.view.aimKick) < 0.02 * def.weight.viewKick
        and g.player.pitch == 0
    )
  end
  g = field()
  g.view.motion = false
  g:shoot()
  step(g, 0.05)
  check('reduced motion keeps the view still on a shot', (g.view.aimKick or 0) == 0)

  -- The afterimage: a claw meeting the place the dodge began.
  g = field()
  g.testField.invincible = false
  local e = g:spawn('imp', 16, 24.4)
  e.awake, e.memory, e.spawnAge = true, 60, 1
  local claw = e.archetype.attacks[1]
  Attacks.begin(g, e, 1.6, claw)
  while e.ai == 'windup' and e.windup > 0.04 do
    g:update(1 / 120, {})
  end
  local hp = g.player.hp
  g:update(1 / 120, { strafe = 1, dash = true })
  step(g, 0.4)
  check(
    'a dodge through a claw is a perfect dodge (no wound, the charge back)',
    Telemetry.get(g).perfectDodges == 1 and g.player.hp == hp
  )
  return lines
end
return Tests

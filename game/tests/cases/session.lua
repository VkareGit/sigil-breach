-- Session contracts: isolation, reset scopes, temporal input and one-time
-- outcomes. These protect behavior across structural changes, not filenames.
local Fixtures = require('tests.support.fixtures')
local Tests = {}

function Tests.run(Game)
  local Encounter = require('src.session.encounter')
  local Simulation = require('src.session.simulation')
  local Run = require('src.run.descent')
  local Field = require('src.run.test_field')
  local lines = {}
  local check = Fixtures.checker(lines, 'session contract: ', 'session contract: ')
  local function fresh(mode)
    local g = Game.new(mode or 'classic')
    g.testing = true
    return g
  end

  local first, second = fresh(), fresh()
  first.player.hp = 17
  first.world.map[1][1] = 0
  first.enemies[1].hp = 0
  first.events[1] = 'sentinel'
  check(
    'new games own independent mutable player/world/actor/event state',
    second.player.hp == 100
      and second.world.map[1][1] == 1
      and second.enemies[1].hp > 0
      and #second.events == 0
  )

  local g = fresh('descent')
  check(
    'expedition begins without classic actors or free classic supplies',
    g.state == 'menu'
      and g.run.phase == 'preparing'
      and g.run.wallet == 100
      and #g.enemies == 0
      and #g.pickups == 0
  )
  g:start()
  local player, world, run = g.player, g.world, g.run
  g.score, g.kills, g.elapsed = 1800, 7, 16
  local body, shell, receipt = {}, {}, {}
  g.enemies, g.view.shells, g.view.shotReport = { body }, { shell }, receipt
  g.pickups, g.view.effects = { {} }, { {} }
  g.bullets, g.hazards, g.charges = { {} }, { {} }, { {} }
  Encounter.clearThreats(g)
  check(
    'stopping attacks keeps bodies, supplies and visual remnants',
    #g.bullets == 0
      and #g.hazards == 0
      and #g.charges == 0
      and g.enemies[1] == body
      and #g.pickups == 1
      and #g.view.effects == 1
      and g.view.shells[1] == shell
  )

  g.view.particles, g.view.traces, g.view.surfaceMarks, g.view.decals =
    { {} }, { {} }, { {} }, { {} }
  Encounter.clearStage(g)
  check(
    'a new stage clears encounter objects while shells finish their lifetime',
    #g.enemies == 0
      and #g.pickups == 0
      and #g.view.effects == 0
      and #g.view.particles == 0
      and #g.view.traces == 0
      and #g.view.surfaceMarks == 0
      and #g.view.decals == 0
      and g.view.shells[1] == shell
  )
  check(
    'stage reset preserves player, geometry, run and accumulated results',
    g.player == player
      and g.world == world
      and g.run == run
      and g.run.wallet == 100
      and g.score == 1800
      and g.kills == 7
      and g.elapsed == 16
      and g.view.shotReport == receipt
  )

  g.explosionReport, g._shotBodies = {}, {}
  g.bossDead, g.bossSpawned, g.threat = true, true, 3
  Encounter.clearWorld(g)
  check(
    'full reset additionally discards shells, attack caches and boss flags',
    #g.view.shells == 0
      and g.explosionReport == nil
      and g._shotBodies == nil
      and not g.bossDead
      and not g.bossSpawned
      and g.threat == 0
  )
  check(
    'full encounter reset still preserves run ownership and score',
    g.player == player and g.world == world and g.run == run and g.score == 1800
  )

  local steps, elapsed, presses = 0, 0, 0
  local probe = {
    simulate = function(_, dt, input)
      assert(dt <= 1 / 120, 'unbounded simulation step')
      steps, elapsed = steps + 1, elapsed + dt
      if input.dash then
        presses = presses + 1
      end
      assert(input.forward == 1 and input.shoot == true, 'held input lost during substeps')
    end,
  }
  local input = { forward = 1, shoot = true, dash = true, slide = true }
  Simulation.update(probe, 3, input)
  check(
    'a long update is capped at 24 bounded steps / 0.2 seconds',
    steps == 24 and math.abs(elapsed - 0.2) < 1e-9
  )
  check('a one-shot dash is consumed once while held inputs persist', presses == 1)
  check(
    'substepping never edits the callers input table',
    input.dash and input.slide and input.forward == 1
  )
  for _, dt in ipairs({ 0, -1, math.huge, 0 / 0, 'bad' }) do
    Simulation.update(probe, dt, input)
  end
  check('invalid time never advances simulation', steps == 24)

  g = fresh()
  g:start()
  local enemy = g.enemies[1]
  local hp = enemy.hp
  for _, amount in ipairs({ 0, -1, math.huge, 0 / 0, 'bad' }) do
    g:damageEnemy(enemy, amount, 'weapon')
  end
  check(
    'invalid enemy damage cannot change health or award kills',
    enemy.hp == hp and g.kills == 0 and g.score == 0
  )
  g:damageEnemy(enemy, hp * 2, 'weapon')
  local score, particles = g.score, #g.view.particles
  g:damageEnemy(enemy, hp, 'weapon')
  check(
    'enemy death awards score and effects only once',
    g.kills == 1 and g.score == score and score > 0 and #g.view.particles == particles
  )

  g = fresh('descent')
  g:start()
  local health, armor = g.player.hp, g.player.armor
  g:damagePlayer(1000)
  check(
    'preparation remains safe when damage is requested directly',
    g.player.hp == health and g.player.armor == armor and g.state == 'playing'
  )
  local shellAtReady = { life = 1 }
  g.view.shells = { shellAtReady }
  g.view.surfaceMarks = { {} }
  check(
    'readiness starts one countdown and retains an ejected shell',
    Run.ready(g)
      and g.run.phase == 'countdown'
      and g.view.shells[1] == shellAtReady
      and #g.view.surfaceMarks == 0
  )
  local supplies = #g.pickups
  check(
    'repeated readiness cannot duplicate wave supplies',
    not Run.ready(g) and #g.pickups == supplies
  )

  g = fresh()
  g:start()
  g.state = 'paused'
  g.fireBuffer = 0.1
  g.view.particles = { { life = 0.5 } }
  local startTime, startElapsed = g.time, g.elapsed
  g:update(0.1, { forward = 1, shoot = true })
  check(
    'paused sessions age their ambient clock without moving or aging combat effects',
    g.time > startTime
      and g.elapsed == startElapsed
      and g.player.x == 16
      and g.player.z == 27.5
      and g.view.particles[1].life == 0.5
      and g.fireBuffer == 0
  )

  local expedition = fresh('descent')
  expedition.run.wallet = 317
  local field = Field.new(Game)
  field.testing = true
  check(
    'the proving ground owns an independent encounter and run',
    field.player ~= expedition.player
      and field.run ~= expedition.run
      and field.world ~= expedition.world
  )
  Field.shop(field)
  require('src.run.modes').act(field, 'ready')
  check(
    'leaving a sandbox shop returns to combat, never wave progression',
    field.state == 'playing'
      and field.run.phase == 'wave'
      and #(field.run.pending or {}) == 0
      and expedition.run.wallet == 317
      and expedition.run.phase == 'preparing'
  )
  field.testField.invincible = false
  field.player.hp, field.player.armor, field.player.invuln = 1, 0, 0
  field:damagePlayer(1000)
  check(
    'sandbox death leaves expedition persistence and currency untouched',
    field.state == 'dead'
      and field.run.echo == nil
      and field.run.deaths == 0
      and expedition.run.wallet == 317
  )

  love.mouse.setRelativeMode(false)
  return lines
end

return Tests

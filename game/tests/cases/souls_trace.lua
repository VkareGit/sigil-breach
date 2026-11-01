-- Plan v13, W1 and W2: a blow is a path in time and goes where the body came to
-- face. Each proof stands a knight where the path passes, or where it does not.
local F = require('tests.support.fixtures')
local Proof = require('tests.support.extension.proof')
local A = require('src.content.enemies')
local Action = require('src.content.defs.action')
local Attacks = require('src.enemies.actions')
local Creature = require('src.content.defs.creature')
local Melee = require('src.combat.melee')
local Packet = require('src.content.defs.packet')
local T = {}
local function trial(Game, attack, spot, knight, move)
  A.register(Creature.define({
    extends = A.imp,
    id = 'trial_trace',
    kind = 'imp',
    variant = 'trial_trace',
    name = 'creature_imp',
    catalog = {},
    body = { hp = 3000, poise = 400 },
    move = move,
    attacks = { attack },
  }))
  local g = F.arena(Game)
  g.player.x, g.player.z, g.player.yaw = knight[1], knight[2], math.pi
  local e = g:spawn('trial_trace', spot[1], spot[2])
  e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, g.player.id
  e.facing, e.attack = 0, 99
  return g, e
end
local function done()
  A.unregister('trial_trace')
end
local function run(g, seconds, policy)
  for _ = 1, math.floor(seconds * 120 + 0.5) do
    if policy then
      policy()
    end
    g:update(1 / 120, {})
  end
end
local function hurt(g)
  return 100 - g.player.hp + 40 - g.player.armor
end
-- Left to right before the body, at the height of a chest, in a quarter second.
local function cut(changes)
  local def = {
    id = 'cut',
    range = 4,
    windup = 0.4,
    trace = {
      { at = 0.05, angle = -1.3, reach = 3, height = 1.2 },
      { at = 0.3, angle = 1.3, reach = 3, height = 1.2 },
    },
    duration = 0.4,
    recover = 3,
    cooldown = 4,
    packet = Packet.new(30, 0),
  }
  for key, value in pairs(changes or {}) do
    def[key] = value
  end
  return Action.sweep(def)
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'souls trace: ', 'souls trace: ')
  Proof.with({ done }, function()
    local built = Action.build(cut())
    check('a path gives its reach', built.reach == 3)
    check('its width', math.abs(built.arc - 2.6) < 1e-9)
    check('its window', built.active[1] == 0.05 and built.active[2] == 0.3)
    local angle, reach, height = Melee.tip(built.trace, 0.175)
    check('the middle of a path', math.abs(angle) < 1e-9 and reach == 3 and height == 1.2)
    check('a path out of order is refused', not pcall(
      Action.build,
      cut({
        trace = {
          { at = 0.3, angle = 0, reach = 3, height = 1 },
          { at = 0.1, angle = 1, reach = 3, height = 1 },
        },
      })
    ))
    check('a blow without path or reach is refused', not pcall(
      Action.build,
      Action.sweep({
        id = 'none',
        range = 3,
        windup = 0.2,
        packet = Packet.new(1, 0),
      })
    ))
    -- Faces +z. The path reaches the side it starts from long before the other.
    local function when(x, z)
      local g, e = trial(Game, cut(), { 16, 16 }, { x, z })
      local hitAt
      g.bus:on('sim', 'PlayerHit', function()
        hitAt = hitAt or e.phase
      end)
      Attacks.begin(g, e, 3, A.of(e).attacks[1])
      e.aimX, e.aimZ = 16, 19
      local aimed = false
      run(g, 1.2, function()
        if e.ai == 'windup' then
          e.aimX, e.aimZ = 16, 19
          aimed = true
        end
      end)
      done()
      return hitAt, aimed
    end
    local atStart = when(16 + math.sin(-1.2) * 2.5, 16 + math.cos(-1.2) * 2.5)
    local atEnd = when(16 + math.sin(1.2) * 2.5, 16 + math.cos(1.2) * 2.5)
    check(
      'the path meets one side first ' .. tostring(atStart) .. ' ' .. tostring(atEnd),
      atStart and atEnd and atEnd - atStart > 0.15
    )
    check('behind the body it meets nothing', when(16, 13.5) == nil)
    check('beyond its reach neither', when(16, 19.8) == nil)
    -- A high blow passes over a crouched knight.
    do
      local over = cut({
        trace = {
          { at = 0.05, angle = -1.3, reach = 3, height = 1.9 },
          { at = 0.3, angle = 1.3, reach = 3, height = 1.9 },
        },
      })
      local g, e = trial(Game, over, { 16, 16 }, { 16, 18 })
      Attacks.begin(g, e, 2, A.of(e).attacks[1])
      e.aimX, e.aimZ = 16, 19
      g.player.crouch = 0.8
      run(g, 1, function()
        g.player.crouch = 0.8
        if e.ai == 'windup' then
          e.aimX, e.aimZ = 16, 19
        end
      end)
      check('a high path passes over a crouch ' .. hurt(g), hurt(g) == 0)
      done()
    end
    -- W2: the body turns at its rate until it locks.
    local function turning(rate)
      return cut({ turn = rate, lockAt = 0.5, windup = 1 })
    end
    do
      local g, e = trial(Game, turning(1), { 16, 16 }, { 19, 16 })
      Attacks.begin(g, e, 3, A.of(e).attacks[1])
      run(g, 0.25)
      check('the body turns at its rate ' .. e.facing, math.abs(e.facing - 0.25) < 0.02)
      run(g, 0.5)
      local locked = e.facing
      check('until it locks ' .. locked, math.abs(locked - e.windupDuration * 0.5) < 0.02)
      g.player.x, g.player.z = 13, 16
      run(g, 0.2)
      check('then it no longer follows', e.facing == locked)
      done()
    end
    do
      -- Slow enough: a knight at the body's side is not reached.
      local g, e = trial(Game, turning(0.2), { 16, 16 }, { 16, 13.5 })
      Attacks.begin(g, e, 3, A.of(e).attacks[1])
      run(g, 1.6)
      check('a slow body cannot find who stands behind it ' .. hurt(g), hurt(g) == 0)
      done()
    end
    do
      -- Fast enough: the same place is reached.
      local g, e = trial(Game, turning(8), { 16, 16 }, { 16, 13.5 })
      Attacks.begin(g, e, 3, A.of(e).attacks[1])
      run(g, 1.6)
      check('a fast one does ' .. hurt(g), hurt(g) > 0)
      done()
    end
    do
      -- A dodge before the lock is followed, after it is not.
      local g, e = trial(Game, turning(4), { 16, 16 }, { 16, 18.5 })
      Attacks.begin(g, e, 3, A.of(e).attacks[1])
      run(g, 0.2)
      g.player.x, g.player.z = 13.8, 16.6
      run(g, 1.2)
      check('stepping aside early is followed ' .. hurt(g), hurt(g) > 0)
      done()
      g, e = trial(Game, turning(4), { 16, 16 }, { 16, 18.5 })
      Attacks.begin(g, e, 3, A.of(e).attacks[1])
      run(g, 0.75)
      g.player.x, g.player.z = 16, 13.5
      run(g, 1)
      check('stepping behind after the lock is not ' .. hurt(g), hurt(g) == 0)
      done()
    end
    do
      -- W3: the bench. Any blow of the selected demon, on demand.
      local Release = require('src.app.release')
      local Tools = require('src.app.field_tools')
      local g = Game.new('field', 'proving', Release.sessionOptions.field)
      g.testing, g.state = true, 'playing'
      local Field = require('src.run.test_field')
      g.testField.selected = 'boss'
      assert(g:act('catalog', 'field_blow_go'))
      check('no body, no blow', g.testField.message:find('No body') ~= nil)
      local e = g:spawn('boss', g.player.x, g.player.z - 5)
      e.fieldKind, e.spawnAge = 'boss', 2
      for _ = 1, 3 do
        g:act('catalog', 'field_blow_next')
      end
      assert(g:act('catalog', 'field_blow_go'))
      local wanted = A.boss.attacks[3].id
      check('F3 and F4 strike the blow chosen', e.ai == 'windup' and e.attackKind == wanted)
      local attacks = A.boss.attacks
      check('F5 reads the creatures again', Tools.reloadCreatures(g))
      check('and the table stays the same one', A.boss.attacks ~= attacks and A.of(e) == A.boss)
      local app = { game = g, timeScale = 0.25 }
      check('a slowed clock is the bench', Tools.time(app, 1) == 0.25)
      check(
        'the keys need the proving ground',
        not Tools.key({ game = { state = 'playing' } }, 'f4')
      )
      check('the field answers', Field.action ~= nil)
    end
    do
      -- move.turn: outside a blow too, at a rate and not at once.
      local g, e = trial(Game, cut(), { 16, 16 }, { 19, 16 }, { speed = 0, turn = 1 })
      e.lastX, e.lastZ = 19, 16
      run(g, 0.5)
      check('a body turns at its own rate ' .. e.facing, math.abs(e.facing - 0.5) < 0.03)
      done()
    end
  end)
  return lines
end
return T

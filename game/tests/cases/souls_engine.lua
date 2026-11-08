-- The combat engine of the souls plan, each mechanic alone: a test creature of
-- one attack against a knight who stands, or who answers the way a player can.
-- Every blow here is avoidable: a test proves the answer, not the damage.
local F = require('tests.support.fixtures')
local Proof = require('tests.support.extension.proof')
local A = require('src.content.enemies')
local Action = require('src.content.defs.action')
local Attacks = require('src.enemies.actions')
local Attributes = require('src.combat.attributes')
local Conditions = require('src.content.conditions')
local Creature = require('src.content.defs.creature')
local Effects = require('src.combat.effects')
local Packet = require('src.content.defs.packet')
local Pools = require('src.session.world')
local Rules = require('src.combat.rules')
local World = require('src.world.arena')
local T = {}
local function trial(Game, attacks, spot)
  A.register(Creature.define({
    extends = A.imp,
    id = 'trial_souls',
    kind = 'imp',
    variant = 'trial_souls',
    name = 'creature_imp',
    catalog = {},
    body = { hp = 3000, poise = 400 },
    attacks = attacks,
  }))
  local g = F.arena(Game)
  g.player.x, g.player.z, g.player.yaw = 16, 22, math.pi
  local x, z = (spot or { 16, 19 })[1], (spot or { 16, 19 })[2]
  local e = g:spawn('trial_souls', x, z)
  e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, g.player.id
  e.attack = 0
  return g, e
end
local function done()
  A.unregister('trial_souls')
end
local function run(g, seconds, policy)
  for _ = 1, math.floor(seconds * 120 + 0.5) do
    g:update(1 / 120, policy and policy() or {})
    if g.state ~= 'playing' then
      break
    end
  end
end
local function strikes(g)
  local list = {}
  g.bus:on('sim', 'AttackReleased', function(ev)
    list[#list + 1] = { id = ev.attack.id, at = g.elapsed }
  end)
  return list
end
local function claw(id, changes)
  local def = {
    id = id,
    range = 6,
    windup = 0.4,
    lungeSpeed = 0,
    lungeTime = 0.1,
    active = { 0.02, 0.08 },
    duration = 0.2,
    recover = 0.5,
    cooldown = 0.7,
    packet = Packet.new(1, 0),
  }
  for key, value in pairs(changes or {}) do
    def[key] = value
  end
  return Action.lunge(def)
end
local function hurt(g)
  return 100 - g.player.hp + 40 - g.player.armor
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'souls engine: ', 'souls engine: ')
  Proof.with({ done }, function()
    -- A string: the second blow follows after its beat, not after a rest.
    local g, e = trial(Game, {
      claw('first', { string = { into = 'second', gap = 0.1 }, recover = 2, cooldown = 3 }),
      claw('second', { windup = 0.3 }),
    })
    local list = strikes(g)
    run(g, 4)
    check('a string flows into its next blow', list[2] and list[2].id == 'second')
    check('after its beat', list[2] and list[2].at - list[1].at < 1)
    done()
    g, e = trial(Game, {
      claw('first', { string = { into = 'second', every = 2 }, recover = 1.5, cooldown = 1.8 }),
      claw('second', { minRange = 100, range = 100 }),
    })
    list = strikes(g)
    run(g, 1)
    check('a string only flows on its turn', #list == 1 and list[1].id == 'first')
    run(g, 2)
    check('a target out of its reach ends it in the full rest', e.chain == nil)
    done()
    -- A hold: the same windup, a different moment, in a fixed order.
    g, e = trial(Game, { claw('held', { hold = { 0, 0.35 }, recover = 0.2, cooldown = 0.3 }) })
    list = strikes(g)
    run(g, 4)
    local first, second = list[2].at - list[1].at, list[3].at - list[2].at
    check('a hold changes the beat ' .. first .. ' ' .. second, math.abs(first - second) > 0.3)
    done()
    -- Tracking: the aim follows, then it is frozen.
    g, e = trial(Game, { claw('tracking', { track = 0.5, windup = 1 }) })
    Attacks.begin(g, e, 3, A.of(e).attacks[1])
    g.player.x = 18
    g:update(1 / 120, {})
    check('the aim follows through its share', e.aimX == g.player.x)
    run(g, 0.6)
    local frozen = e.aimX
    g.player.x = 14
    run(g, 0.2)
    check('and then it is frozen', e.aimX == frozen)
    done()
    -- A sweep: the arc, a jump, a dodge.
    local function sweep(volume)
      return Action.sweep({
        id = 'wide',
        range = 3,
        windup = 0.5,
        reach = 3,
        arc = 2,
        active = { 0.05, 0.2 },
        duration = 0.3,
        recover = 3,
        cooldown = 4,
        volume = volume,
        packet = Packet.new(30, 0),
      })
    end
    g, e = trial(Game, { sweep() }, { 16, 20 })
    run(g, 1.2)
    check('a sweep strikes in its arc', hurt(g) > 0)
    done()
    g, e = trial(Game, { sweep() }, { 16, 20 })
    Attacks.begin(g, e, 2, A.of(e).attacks[1])
    run(g, 0.4)
    g.player.x, g.player.z = 16, 17.5
    run(g, 0.8)
    check('behind the body it does not', hurt(g) == 0)
    done()
    local low = { bottom = 0, top = 0.5, sample = 'feet', includeRadius = true }
    g, e = trial(Game, { sweep(low) }, { 16, 20 })
    run(g, 1.2, function()
      return { jump = e.ai == 'windup' and e.windup < 0.18 }
    end)
    check('a low one is jumped ' .. hurt(g), hurt(g) == 0)
    done()
    g, e = trial(Game, { sweep() }, { 16, 20 })
    run(g, 1.2, function()
      return { dash = e.ai == 'windup' and e.windup < 0.1, strafe = 1 }
    end)
    check('a dodge passes through it ' .. hurt(g), hurt(g) == 0)
    done()
    -- A grip: only a dodge saves, a faltering holder lets go.
    local function grip()
      return Action.seize({
        id = 'grip',
        range = 3,
        windup = 0.5,
        reach = 2.6,
        arc = 1.6,
        grip = 0.8,
        active = { 0.05, 0.2 },
        duration = 0.3,
        recover = 3,
        cooldown = 4,
        packet = Packet.new(40, 0),
      })
    end
    g, e = trial(Game, { grip() }, { 16, 20 })
    run(g, 0.75)
    check('a grip holds', e.act.holding == g.player.id and Rules.has(g.player, 'seized'))
    check('nothing lands yet', hurt(g) == 0)
    check('it forbids the trigger', Attributes.forbids(g.player, 'fire'))
    local x, z = g.player.x, g.player.z
    run(g, 0.2, function()
      return { forward = 1, dash = true }
    end)
    check('and every step', g.player.x == x and g.player.z == z)
    run(g, 0.6)
    check('then it closes', hurt(g) > 0 and not e.act.holding)
    done()
    g, e = trial(Game, { grip() }, { 16, 20 })
    run(g, 1.5, function()
      return { dash = e.ai == 'windup' and e.windup < 0.1, strafe = 1 }
    end)
    check('a dodge leaves it empty ' .. hurt(g), hurt(g) == 0 and not e.act.holding)
    done()
    g, e = trial(Game, { grip() }, { 16, 20 })
    run(g, 0.75)
    e.ai = 'hurt'
    require('src.combat.action_kinds').abandon(e)
    run(g, 0.3)
    check('a holder knocked out of it lets go', not Rules.has(g.player, 'seized'))
    done()
    -- A wave: above it, or already behind it.
    local function ring()
      return Action.wave({
        id = 'ring',
        range = 6,
        windup = 0.3,
        speed = 8,
        reach = 7,
        recover = 3,
        cooldown = 4,
        packet = Packet.new(30, 0),
      })
    end
    g, e = trial(Game, { ring() })
    run(g, 1.5)
    check('a wave reaches who stands', hurt(g) > 0)
    done()
    g, e = trial(Game, { ring() })
    run(g, 1.5, function()
      local h = Pools.of(g, 'hazards')[1]
      local distance = h and math.abs(g.player.z - h.z) - h.radius
      return { jump = distance and distance < 1.6 and distance > 0 }
    end)
    check('and passes under who jumps ' .. hurt(g), hurt(g) == 0)
    done()
    -- A ray: crossing the room, stopped by stone.
    local function ray()
      return Action.beam({
        id = 'ray',
        range = 8,
        windup = 0.4,
        length = 8,
        arc = 1.6,
        spin = 2,
        recover = 3,
        cooldown = 4,
        packet = Packet.new(30, 0),
      })
    end
    g, e = trial(Game, { ray() })
    run(g, 2)
    check('a ray crosses who stands', hurt(g) > 0)
    done()
    g, e = trial(Game, { ray() })
    local column
    for cx = 3, 28 do
      for cz = 3, 28 do
        if
          not column
          and World.solid(g.world, cx, cz, 0)
          and not World.solid(g.world, cx, cz - 3, 0.5)
          and not World.solid(g.world, cx, cz + 3, 0.5)
          and not World.visible(g.world, cx, cz - 3, cx, cz + 3)
        then
          column = { cx, cz }
        end
      end
    end
    if column then
      e.x, e.z = column[1], column[2] - 3
      g.player.x, g.player.z = column[1], column[2] + 3
      local kinds = require('src.enemies.hazards').kinds
      require('src.session.spawn').make(g, 'hazard', {
        kind = 'sweepline',
        owner = e.id,
        side = 'demons',
        x = e.x,
        z = e.z,
        delay = 0,
        maxDelay = 0,
        radius = 8,
        angle = -0.5,
        spin = 2,
        life = 0.5,
        volume = A.of(e).attacks[1].volume,
        packet = Packet.new(30, 0),
      })
      e.attack = 99
      run(g, 0.6)
      check('and stone stands in its way ' .. hurt(g), kinds and hurt(g) == 0)
    end
    done()
    -- A summons: bounded by its living.
    g, e = trial(Game, {
      Action.summon({
        id = 'call',
        creature = 'trial_souls',
        range = 8,
        windup = 0.2,
        count = 2,
        limit = 2,
        recover = 0.2,
        cooldown = 0.3,
      }),
    })
    run(g, 3)
    local called = 0
    for _, other in ipairs(Pools.of(g, 'enemies')) do
      called = called + (other.summoner == e.id and 1 or 0)
    end
    check('it calls up to its limit ' .. called, called == 2)
    done()
    -- A hop, a blink, a salvo, a storm.
    g, e = trial(Game, {
      Action.hop({
        id = 'back',
        range = 8,
        windup = 0.1,
        speed = 8,
        lungeTime = 0.2,
        duration = 0.25,
        recover = 5,
        cooldown = 5,
      }),
    }, { 16, 20 })
    run(g, 0.5)
    check('a hop leaves its target', e.z < 19.5)
    done()
    g, e = trial(Game, {
      Action.blink({
        id = 'away',
        range = 8,
        windup = 0.1,
        distance = 5,
        recover = 5,
        cooldown = 5,
      }),
    })
    local x0, z0 = e.x, e.z
    run(g, 0.4)
    check('a blink stands elsewhere', e.x ~= x0 or e.z ~= z0)
    done()
    g, e = trial(Game, {
      Action.salvo({
        id = 'trio',
        range = 8,
        windup = 0.2,
        speed = 2,
        count = 3,
        interval = 0.2,
        duration = 0.1,
        recover = 5,
        cooldown = 5,
        packet = Packet.new(5, 0),
      }),
    })
    run(g, 0.45)
    local shot = #Pools.of(g, 'projectiles')
    run(g, 0.3)
    check('a salvo lets its missiles go in turn', shot == 2 and #Pools.of(g, 'projectiles') == 3)
    done()
    g, e = trial(Game, {
      Action.storm({
        id = 'steps',
        range = 8,
        windup = 0.2,
        count = 3,
        interval = 0.3,
        delay = 0.5,
        radius = 1,
        duration = 0.1,
        recover = 5,
        cooldown = 5,
        packet = Packet.new(20, 0),
      }),
    })
    run(g, 2, function()
      return { strafe = 1 }
    end)
    check('a storm misses who keeps moving ' .. hurt(g), hurt(g) == 0)
    done()
    g, e = trial(Game, {
      Action.tempest({
        id = 'room',
        range = 8,
        windup = 0.2,
        radius = 2,
        delay = 0.4,
        life = 1,
        pulse = 0.4,
        recover = 5,
        cooldown = 5,
        packet = Packet.new(10, 0),
      }),
    })
    run(g, 1.8)
    check('inside the circle nothing strikes ' .. hurt(g), hurt(g) == 0)
    done()
    g, e = trial(Game, {
      Action.tempest({
        id = 'room',
        range = 8,
        windup = 0.2,
        radius = 2,
        delay = 0.4,
        life = 1,
        pulse = 0.4,
        recover = 5,
        cooldown = 5,
        packet = Packet.new(10, 0),
      }),
    })
    run(g, 0.3)
    g.player.z = 27
    run(g, 1.5)
    check('outside it the room does', hurt(g) > 0)
    done()
    -- Turns of a rush.
    g, e = trial(Game, {
      Action.charge({
        id = 'rush',
        range = 8,
        windup = 0.2,
        speed = 9,
        minTime = 0.2,
        maxTime = 0.3,
        contactY = 1,
        contactRadius = 0.4,
        reach = 0.5,
        turns = 1,
        turnPause = 0.2,
        recover = 5,
        cooldown = 5,
        packet = Packet.new(20, 0),
      }),
    }, { 13, 19 })
    g.player.x = 22
    run(g, 0.75)
    local aimFirst = e.aimX
    g.player.x, g.player.z = 13, 25
    run(g, 0.5)
    check('a rush with a turn looks again', e.aimX ~= aimFirst)
    done()
    -- Exposure that gathers.
    g = F.arena(Game)
    local venom = Effects.kinds:get('buildup')
      and {
        id = 'proof_venom',
        kind = 'buildup',
        duration = 6,
        amount = 40,
        threshold = 100,
        decay = 10,
        results = { { id = 'proof_bound', kind = 'condition', condition = 'rooted', duration = 2 } },
      }
    Effects.apply(g, g.player, { venom }, nil)
    Effects.apply(g, g.player, { venom }, nil)
    check('exposure below its threshold does nothing yet', not Rules.has(g.player, 'rooted'))
    Effects.apply(g, g.player, { venom }, nil)
    check('at the threshold it falls', Rules.has(g.player, 'rooted'))
    check('a condition can be read back', Conditions.find('seized') ~= nil)
  end)
  return lines
end
return T

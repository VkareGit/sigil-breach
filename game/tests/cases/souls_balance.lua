-- Plan v13, W4 to W6, each mechanic alone: a guard that falls when the blow ends, the
-- execution, what effort costs, the flask, what a body answers.
local F = require('tests.support.fixtures')
local Proof = require('tests.support.extension.proof')
local A = require('src.content.enemies')
local Action = require('src.content.defs.action')
local Attacks = require('src.enemies.actions')
local Creature = require('src.content.defs.creature')
local Execution = require('src.combat.execution')
local Packet = require('src.content.defs.packet')
local Release = require('src.app.release')
local Resources = require('src.combat.resources')
local Rules = require('src.combat.rules')
local Selection = require('src.enemies.attack_selection')
local T = {}
local function field(Game)
  local g = Game.new('field', 'proving', Release.sessionOptions.field)
  g.ephemeral, g.state, g.testField.invincible = true, 'playing', false
  g.player.x, g.player.z, g.player.yaw = 10, 24, math.pi
  return g
end
local function cut(id, changes)
  local def = {
    id = id,
    range = 6,
    windup = 0.4,
    trace = {
      { at = 0.05, angle = -1.2, reach = 3, height = 1.2 },
      { at = 0.2, angle = 1.2, reach = 3, height = 1.2 },
    },
    duration = 0.3,
    recover = 0.5,
    cooldown = 99,
    packet = Packet.new(10, 0),
  }
  for key, value in pairs(changes or {}) do
    def[key] = value
  end
  return Action.sweep(def)
end
local function guardian(g, attacks, more)
  local def = {
    extends = A.armored,
    id = 'trial_guardian',
    kind = 'armored',
    variant = 'trial_guardian',
    name = 'creature_armored',
    catalog = {},
    body = {
      tier = 'elite',
      hp = 5000,
      poise = 100,
      breakTime = 2,
      execution = 0.2,
      steadfast = true,
    },
    attacks = attacks,
    tactics = {
      moves = { { attack = attacks[1].id, ideal = 3 } },
    },
  }
  for key, value in pairs(more or {}) do
    def[key] = value
  end
  A.register(Creature.define(def))
  local e = g:spawn('trial_guardian', 10, 21)
  e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, g.player.id
  return e
end
local function done()
  A.unregister('trial_guardian')
end
local function run(g, seconds)
  for _ = 1, math.floor(seconds * 120 + 0.5) do
    g:update(1 / 120, {})
  end
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'souls balance: ', 'souls balance: ')
  Proof.with({ done }, function()
    -- W4: a steady blow is not stopped, its body falls when it has struck.
    local g = field(Game)
    local whole = g.player.hp + g.player.armor
    local e = guardian(g, { cut('sure', { steady = true }) })
    Attacks.begin(g, e, 3, A.of(e).attacks[1])
    Rules.guard(e, 500)
    check('a guard broken in a steady blow does not stop it', e.ai == 'windup' and e.stun == 0)
    run(g, 0.9)
    check('the blow lands', g.player.hp + g.player.armor < whole)
    check('and the body falls after it', (e.stun or 0) > 0 and Rules.has(e, 'exposed'))
    done()
    g = field(Game)
    e = guardian(g, { cut('open') })
    Attacks.begin(g, e, 3, A.of(e).attacks[1])
    Rules.guard(e, 500)
    check('any other blow is thrown away', e.ai == 'hurt' and e.stun > 1.5)
    -- The execution.
    check('out of reach it is nothing', Execution.target(g) == nil)
    g.player.z = 23
    check('within reach it is offered', Execution.target(g) == e)
    check('the prompt says so', g:context() ~= nil and g:context():find('EXECUTE') ~= nil)
    g.player.yaw = 0
    check('looking away it is not', Execution.target(g) == nil)
    g.player.yaw = math.pi
    local before = e.hp
    check('E performs it', g:interact())
    check('it takes the share of the body', math.abs(before - e.hp - 1000) < 1)
    check('and closes the opening', not Rules.has(e, 'exposed') and (e.poise or 0) == 0)
    check('the knight is untouchable through it', g.player.invuln > 0.5)
    check('once', not g:interact())
    done()
    -- Only what his arm reaches: no execution through stone or across a floor's height.
    g = field(Game)
    e = guardian(g, { cut('open') })
    Attacks.begin(g, e, 3, A.of(e).attacks[1])
    Rules.guard(e, 500)
    g.player.z = 23
    check('a body in reach is offered', Execution.target(g) == e)
    g:setCell(10, 22, 1)
    check('not through a wall', Execution.target(g) == nil and Execution.prompt(g) == nil)
    g:setCell(10, 22, 0)
    g.player.jump = 8
    check('not from far above it', Execution.target(g) == nil)
    g.player.jump = 0
    check('back in reach it is again', Execution.target(g) == e)
    done()
    -- Steadfast: blows do not hold it.
    g = field(Game)
    e = guardian(g, { cut('open') })
    Rules.react(g, e, 40, true, nil, 10, { push = 200 })
    check('a steadfast body takes no hit-stop', (e.hitPause or 0) == 0 and (e.stun or 0) == 0)
    done()
    -- Personal room: a great body is not walked into.
    g = field(Game)
    e = guardian(g, { cut('open') }, { body = { hp = 500, personal = 1.3 } })
    e.attack, e.dummy = 99, true
    for _ = 1, 120 do
      g:update(1 / 120, { forward = 1 })
    end
    local gap = math.sqrt((e.x - g.player.x) ^ 2 + (e.z - g.player.z) ^ 2)
    check('a knight stops at its room ' .. gap, gap > 1.4)
    done()
    -- W5: effort.
    g = field(Game)
    local p = g.player
    local full = p.resources.stamina
    check('the knight has effort', full == 100)
    assert(g:shoot())
    check('a pull costs none of it ' .. p.resources.stamina, p.resources.stamina == full)
    check('but the moment after it', not g:dash(1, 0) and p.recoverAt > g.elapsed)
    p.cooldown, p.resources.stamina, p.recoverAt = 0, 0, 0
    Resources.exert(p, 'stamina', 0)
    p.arsenal.exorcist.readyAt = 0
    check('spent, no dodge', not g:dash(1, 0))
    p.resources.stamina, p.resourcePause.stamina = 25, 0.2
    check('a dodge takes its whole price', not g:dash(1, 0))
    p.resources.stamina = 26
    check('and that pays for it', g:dash(1, 0))
    check('leaving no debt', p.resources.stamina == 0)
    check('a dodge is long here', p.invuln == 0.32)
    check('and the hands stay free', p.cooldown == 0)
    local debt = p.resources.stamina
    run(g, 0.3)
    check('it does not come back at once', p.resources.stamina == debt)
    run(g, 0.5)
    check('then it does', p.resources.stamina > debt)
    local classic = F.arena(Game)
    local stamina = classic.player.resources.stamina
    classic:shoot()
    check('nothing of this outside the rule', classic.player.resources.stamina == stamina)
    -- The flask.
    g = field(Game)
    p = g.player
    p.hp = 30
    local flasks = p.abilityState.flask.uses
    check('the flask starts', g:cast(2))
    check('the knight walks slowly', Rules.speedScale(p) < 0.6)
    check('nor dodge', require('src.combat.attributes').forbids(p, 'dash'))
    check('nothing yet', p.hp == 30)
    run(g, 1)
    check('then it heals ' .. p.hp, p.hp == 75)
    check('and one swallow is gone', p.abilityState.flask.uses == flasks - 1)
    p.hp = 30
    g:update(1 / 120, {})
    run(g, 0.4)
    g:cast(2)
    g:damageBody(p, 5, p.x, p.z, Packet.new(5, 0), nil)
    run(g, 1.1)
    check('a blow spills it ' .. p.hp, p.hp < 30)
    check('unpaid', p.abilityState.flask.uses == flasks - 1)
    -- W6: answers.
    g = field(Game)
    p = g.player
    e = guardian(g, { cut('open', { recover = 0, cooldown = 99 }), cut('answer') }, {
      answers = { { when = 'drinking', attack = 'answer', rest = 3 } },
    })
    e.attack = 50
    run(g, 0.3)
    check('with nothing to answer it waits', e.ai ~= 'windup')
    g:cast(2)
    run(g, 0.1)
    check('a swallow is answered at once', e.ai == 'windup' and e.attackKind == 'answer')
    done()
    g = field(Game)
    p = g.player
    p.x, p.z = 10, 18
    e = guardian(g, { cut('open'), cut('answer') }, {
      answers = { { when = 'behind', attack = 'answer', rest = 3, within = 4 } },
    })
    e.attack, e.facing = 50, 0
    run(g, 0.05)
    check('who stands behind is answered', e.ai == 'windup' and e.attackKind == 'answer')
    done()
    g = field(Game)
    p = g.player
    p.z = 22.6
    e = guardian(g, { cut('open'), cut('answer') }, {
      answers = { { when = 'hugging', attack = 'answer', rest = 3, within = 2.4, after = 0.5 } },
    })
    e.attack = 50
    run(g, 0.3)
    check('who just came close is not yet', e.ai ~= 'windup')
    run(g, 0.4)
    check('who stays is', e.ai == 'windup' and e.attackKind == 'answer')
    done()
    -- A counter: a shot in the window throws the blow away and opens the body.
    g = field(Game)
    local solid =
      { body = { tier = 'elite', hp = 5000, poise = 5000, breakTime = 2, execution = 0.2 } }
    e = guardian(g, { cut('open', { parry = 0.2, windup = 0.6 }) }, solid)
    Attacks.begin(g, e, 3, A.of(e).attacks[1])
    Rules.react(g, e, 100, true)
    check('too early it is only a shot', e.ai == 'windup')
    run(g, 0.45)
    Rules.react(g, e, 20, true)
    check('a weak one does not turn it', e.ai == 'windup')
    Rules.react(g, e, 100, true)
    check('in the window the blow is gone', e.ai == 'hurt' and Rules.has(e, 'exposed'))
    g.player.z = 23
    check('and it stands open to an execution', Execution.target(g) == e)
    done()
    g = field(Game)
    e = guardian(g, { cut('open', { windup = 0.6 }) }, solid)
    Attacks.begin(g, e, 3, A.of(e).attacks[1])
    run(g, 0.5)
    Rules.react(g, e, 100, true)
    check('a blow without a window has none', e.ai == 'windup')
    done()
    -- The shell: shots are for the openings.
    g = field(Game)
    e = guardian(g, { cut('open') }, { body = { hp = 5000, shell = 0.3 } })
    check('at rest it takes everything', Rules.shell(e) == 1)
    Attacks.begin(g, e, 3, A.of(e).attacks[1])
    check('in its blow only its share', Rules.shell(e) == 0.3)
    local Hit = require('src.combat.hit')
    local hard = Hit.measure({ base = 100 }, e, 1)
    e.ai = 'recover'
    local soft = Hit.measure({ base = 100 }, e, 1)
    check('the measure says so', math.abs(hard - soft * 0.3) < 1e-6)
    done()
    -- The chase: who goes with the swing is followed, who goes against it is not.
    local function chased(side)
      g = field(Game)
      e = guardian(g, {
        cut('swing', {
          chase = 8,
          trace = {
            { at = 0.02, angle = -1, reach = 3, height = 1.2 },
            { at = 0.3, angle = 1, reach = 3, height = 1.2 },
          },
          duration = 0.4,
        }),
      })
      Attacks.begin(g, e, 3, A.of(e).attacks[1])
      e.facing = 0
      g.player.x, g.player.z = 10 + side * 1.5, 23.5
      for _ = 1, 72 do
        g:update(1 / 120, {})
      end
      local yaw = math.atan2(e.lungeX or 0, e.lungeZ or 1)
      done()
      return yaw
    end
    check('with the swing the body follows', chased(1) > 0.1)
    check('against it the body does not', math.abs(chased(-1)) < 0.75)
    -- The rally: what a blow took can be fought back for a moment.
    g = field(Game)
    p = g.player
    p.armor = 0
    g:damagePlayer(30)
    local wounded = p.hp
    check('a blow opens a rally', p.rally > 0)
    local post = g:spawn('imp', 10, 20)
    post.dummy = true
    g:damageEnemy(post, 100, 'weapon', nil, p.id)
    check('a hit brings health back ' .. p.hp, p.hp > wounded)
    run(g, 4)
    check('and it does not last', p.rally == nil)
    -- A roll by weight: the same place, different blows, every one in its turn.
    g = field(Game)
    e = guardian(g, { cut('one'), cut('two') }, {
      tactics = {
        roll = true,
        moves = { { attack = 'one', ideal = 3, weight = 2 }, { attack = 'two', ideal = 3 } },
      },
    })
    local seen = {}
    for _ = 1, 60 do
      local choice = Selection.choose(e, 3, g.elapsed, g.rng.sim)
      seen[choice.id] = (seen[choice.id] or 0) + 1
    end
    check('a roll gives both', (seen.one or 0) > 0 and (seen.two or 0) > 0)
    check('in their weights', (seen.one or 0) > (seen.two or 0))
    done()
  end)
  return lines
end
return T

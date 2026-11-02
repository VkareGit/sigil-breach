-- A press is not lost: what cannot happen yet happens when it can, what cannot happen says why,
-- and what the knight is looking at does not stand and wait for him.
local F = require('tests.support.fixtures')
local Intent = require('src.player.intent')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local Rules = require('src.combat.rules')
local T = {}
local TICK = 1 / 120
local function fresh(Game)
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    e.alertRange, e.dummy = 0, true
  end
  return g, g.player
end
local function run(g, seconds, input)
  for _ = 1, math.ceil(seconds * 120) do
    g:update(TICK, input or {})
  end
end
local function dodges(check, Game)
  local g, p = fresh(Game)
  p.resources.stamina = 0
  g:update(TICK, { dash = true, forward = 1 })
  check('a dodge with no breath does not happen', p.dashTimer == 0)
  check('and says why', g.view.refusal == 'hud_no_breath' and g.view.refusalTimer > 0)
  p.resources.stamina = 100
  run(g, 0.05, { forward = 1 })
  check('but it was not lost: it goes when it can', p.dashTimer > 0)
  g, p = fresh(Game)
  p.resources.stamina = 0
  g:update(TICK, { dash = true })
  run(g, 0.4)
  p.resources.stamina = 100
  run(g, 0.1)
  check('a press too old is forgotten', p.dashTimer == 0)
  -- Stamina is the only limit: three dodges from whole breath, the fourth waits for it.
  g, p = fresh(Game)
  local count = 0
  for _ = 1, 4 do
    if g:dash(1, 0) then
      count = count + 1
    end
    run(g, 0.2)
  end
  check('three dodges in a row, not four', count == 3)
  g, p = fresh(Game)
  p.resources.stamina = -5
  g:update(TICK, { dash = true, forward = 1 })
  check('no breath is said', g.view.refusal == 'hud_no_breath')
end
local function shots(check, Game)
  local g, p = fresh(Game)
  local before = p.shots
  g:dash(0, 1, p)
  Intent.queue(g, 'fire', nil)
  run(g, 0.34)
  check('a shot pressed during a dodge fires when the hands are free', p.shots == before + 1)
  g, p = fresh(Game)
  before = p.shots
  Rules.addCondition(p, 'staggered', 0.25)
  Intent.queue(g, 'fire', nil)
  run(g, 0.05)
  check('off balance the pull waits', p.shots == before)
  check('and says why', g.view.refusal == 'hud_off_balance')
  run(g, 0.25)
  check('then fires', p.shots == before + 1)
  check(
    'what was seen at a press lives as long as the press',
    require('src.combat.observation').maxAge >= require('src.content.tuning').input.fireWindow
  )
  g, p = fresh(Game)
  before = p.shots
  p.resources.stamina = -5
  run(g, 0.01, { shoot = true })
  check('out of breath the gun still answers', p.shots == before + 1)
  g:update(TICK, { dash = true, forward = 1 })
  check('but no breath is no dodge', p.dashTimer == 0 and g.view.refusal == 'hud_no_breath')
end
local function cost(check, Game)
  local g, p = fresh(Game)
  p.resources.stamina = 100
  g:shoot(nil)
  check('a shot costs no breath', p.resources.stamina == 100)
  g:update(TICK, { dash = true, forward = 1 })
  check('it costs the moment after it', p.dashTimer == 0)
  check('and the wait is said, not thudded', g.view.refusal == 'hud_recovering')
  run(g, 0.25)
  check('and the dodge pressed in it follows', p.dashTimer > 0 or p.resources.stamina < 100)
  g, p = fresh(Game)
  p.resources.stamina, p.resourcePause = 25, { stamina = 9 }
  check('a dodge takes its whole price', not g:dash(1, 0))
  p.resources.stamina = 26
  check('and leaves no debt', g:dash(1, 0) and p.resources.stamina == 0)
end
local function hands(check, Game)
  local g, p = fresh(Game)
  local before = p.shots
  g:dash(0, 1, p)
  run(g, 0.02)
  check('a dodge leaves the hands free', g:shoot(nil) and p.shots == before + 1)
  check('and a shot out of it gives up its safety', p.invuln == 0)
  g, p = fresh(Game)
  before = p.shots
  Rules.addCondition(p, 'shaken', 0.3)
  check('a light stagger takes the feet, not the hands', g:shoot(nil) and p.shots == before + 1)
  g, p = fresh(Game)
  before = p.shots
  p.abilityState.flask.uses = 2
  g:cast(2)
  check('the flask is at the lips', p.casting ~= nil)
  check('a shot stops the drink', g:shoot(nil) and p.shots == before + 1 and not p.casting)
  check('and the flask keeps its draught', p.abilityState.flask.uses == 2)
  g, p = fresh(Game)
  p.cooldown = 0.2
  local aimed = { yaw = p.yaw + 1, pitch = 0 }
  Intent.queue(g, 'fire', aimed)
  local fired
  local shoot = g.shoot
  g.shoot = function(session, command, actor)
    fired = command or 'now'
    return shoot(session, command, actor)
  end
  run(g, 0.25)
  check('a press that waited goes where he looks now', fired == 'now')
  g, p = fresh(Game)
  p.arsenal.exorcist.mag = 0
  require('src.combat.reload').start(g, false, p)
  Intent.queue(g, 'fire', nil)
  run(g, 0.02)
  check('a pull during a reload says so', g.view.refusal == 'hud_reloading')
end
local function reward(check, Game)
  local g, p = fresh(Game)
  local first, second = Pools.of(g, 'enemies')[1], Pools.of(g, 'enemies')[2]
  local wallet = g.run.wallet
  g:damageEnemy(first, first.hp + 1, 'weapon', nil, p.id)
  g:update(TICK, {})
  local paid = g.run.wallet - wallet
  check('a kill shows what the purse gained', paid > 0 and g.view.soulsGain == paid)
  check('not points the way never spends', g.view.feedback == nil or g.view.feedbackTimer == 0)
  g:damageEnemy(second, second.hp + 1, 'weapon', nil, p.id)
  g:update(TICK, {})
  check('kills close together add up', g.view.soulsGain == g.run.wallet - wallet)
  run(g, 1.6)
  check('and it fades', g.view.soulsGainTimer == 0)
end
local function sight(check, Game)
  local g, p = fresh(Game)
  local e
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    if body.post == 'nave_2' then
      e = body
    end
  end
  e.dummy, e.alertRange = nil, 6
  p.x, p.z, p.yaw = e.x, e.z + 14, 0
  run(g, 0.3)
  check('what he has his back to does not know him', not e.awake)
  -- The rest of the hall is behind him now, and asleep.
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    if body ~= e then
      body.x, body.z, body.awake = 24, 39, false
    end
  end
  p.yaw = math.pi
  run(g, 0.3)
  check('what he looks at does', e.awake)
  -- No queue (owner, D4): what he sees comes, however many are already coming.
  local second, third
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    if body.post == 'nave_3' then
      second = body
    elseif body.post == 'nave_4' then
      third = body
    end
  end
  second.dummy, third.dummy = nil, nil
  second.x, second.z, third.x, third.z = e.x + 2, e.z, e.x - 2, e.z
  e.dummy, e.memory = true, 9
  e.awake = true
  run(g, 0.3)
  check('a second comes with it', second.awake)
  check('and a third: a hall does not wait in turns', third.awake)
  -- The alarm: one that notices him wakes the sleeping ones that see it, behind him too, but
  -- not one walled off.
  g, p = fresh(Game)
  local caller, behind, walled
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    body.awake, body.dummy = false, nil
    if body.post == 'nave_2' then
      caller = body
    elseif body.post == 'nave_3' then
      behind = body
    elseif body.post == 'crypt_1' then
      walled = body
    end
  end
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    if body ~= caller and body ~= behind and body ~= walled then
      body.x, body.z = 24, 39
    end
  end
  p.x, p.z, p.yaw = caller.x, caller.z + 3, 0
  behind.x, behind.z = caller.x + 1.5, caller.z - 3
  -- Four metres from the caller, with stone between them.
  walled.x, walled.z = caller.x - 4, caller.z
  local wx, wz = math.floor(caller.x - 2 + 0.5), math.floor(caller.z + 0.5)
  for dz = -1, 1 do
    g:setCell(wx, wz + dz, 1)
  end
  check('the wall hides them from each other', not Rules.sees(g, walled, caller))
  caller.alertRange, behind.alertRange, walled.alertRange = 6, 0, 0
  run(g, 0.3)
  check('the one near him notices him', caller.awake)
  check('and its alarm wakes one he has his back to', behind.awake)
  check('but not one behind the walls', not walled.awake)
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'responsiveness: ', 'responsiveness: ')
  dodges(check, Game)
  shots(check, Game)
  cost(check, Game)
  hands(check, Game)
  reward(check, Game)
  sight(check, Game)
  P.forget()
  return lines
end
return T

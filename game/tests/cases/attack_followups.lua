local F = require('tests.support.fixtures')
local A = require('tests.support.phase_encounters')
local Actions = require('src.enemies.actions')
local Select = require('src.enemies.attack_selection')
local Schema = require('src.core.schema')
local Creature = require('src.content.defs.creature')
local Snapshot = require('src.session.snapshot')
local Integrity = require('src.session.integrity')
local Journal = require('src.session.journal')
local Pools = require('src.session.world')
local Tests = {}
local function attack(e, id)
  for _, a in ipairs(A.of(e).attacks) do
    if a.id == id then
      return a
    end
  end
  error('missing action ' .. id)
end
function Tests.run(Game)
  local Real = Game
  Game = A.game(Game)
  local lines = {}
  local check = F.checker(lines, 'follow-ups: ', 'follow-ups: ')
  local function fresh(kind)
    local g = F.arena(Game)
    g.player.x, g.player.z, g.player.yaw = 16, 22, math.pi
    local e = g:spawn(kind or 'furfur', 16, 17)
    e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, g.player.id
    e.phaseIndex, e.attack = 2, 0
    return g, e
  end
  local g, e = fresh()
  local charge, finish = attack(e, 'tempest-charge'), attack(e, 'antler-return')
  check('continuation is not an opener', Actions.choose(e, 2, 0).id ~= finish.id)
  Actions.begin(g, e, 5, charge)
  check('windup is not completion', not e.finishedAttack and e.windup >= charge.windup)
  Actions.execute(g, e)
  check('release is not completion', not e.finishedAttack)
  e.ai, e.phase = 'strike', 2
  Actions.strike(g, e, 1 / 120)
  check(
    'real strike exit records completion and target',
    e.finishedAttack == charge.id and e.finishedAt == g.elapsed and e.finishedTarget == e.target
  )
  check('nearby knight offers the return', Actions.choose(e, 2, g.elapsed).id == finish.id)
  check('moving outside reach removes the return', Actions.choose(e, 5, g.elapsed).id ~= finish.id)
  check(
    'expired opportunity cannot be banked',
    Actions.choose(e, 2, g.elapsed + 1.01).id ~= finish.id
  )
  e.target = -99
  check(
    'changing opponent does not transfer the continuation',
    Actions.choose(e, 2, g.elapsed).id ~= finish.id
  )
  e.target = e.finishedTarget
  e.restUntil[finish.id] = g.elapsed + 2
  check('follow-up still obeys its own cooldown', Actions.choose(e, 2, g.elapsed).id ~= finish.id)
  e.restUntil[finish.id] = nil
  local before, snapshot = Integrity.capture(g), Snapshot.capture(g)
  for _ = 1, 30 do
    Actions.choose(e, 2, g.elapsed)
  end
  check('repeated decisions are read-only', not Integrity.difference(before, Integrity.capture(g)))
  Select.clear(e)
  Snapshot.restore(g, snapshot)
  e = g.enemies[1]
  check(
    'snapshot restores the pending opportunity',
    not Integrity.difference(before, Integrity.capture(g))
  )
  local Save = require('src.storage.session_save')
  local restored = F.arena(Game)
  assert(Save.load(restored, Save.encode(g)))
  check(
    'disk body save preserves completion and target',
    restored.enemies[1].finishedAttack == charge.id
      and restored.enemies[1].finishedAt == e.finishedAt
      and restored.enemies[1].finishedTarget == e.finishedTarget
  )
  Actions.begin(g, e, 2, finish)
  check('commit consumes the opportunity before execution', not e.finishedAttack)
  e.ai, e.phase = 'strike', 2
  Actions.strike(g, e, 1 / 120)
  check(
    -- 0.43: it stands for recoverStill of it and walks the rest, striking nothing until the
    -- whole recovery is spent; the pause between attacks runs beside it.
    'finisher restores a full punishable recovery, no loop',
    e.spent == 1.25
      and e.recover <= 1.25
      and math.abs(e.attack - finish.cooldown / Select.pace(e)) < 1e-9
      and not e.finishedAttack
      and Actions.choose(e, 2, g.elapsed).id ~= finish.id
  )
  g, e = fresh()
  e.phaseIndex = 1
  e.finishedAttack, e.finishedAt, e.finishedTarget = charge.id, g.elapsed, e.target
  g:damageEnemy(e, e.hp, 'weapon')
  check('phase boundary clears old opportunities', e.phaseIndex == 2 and not e.finishedAttack)
  -- Cancel before a release through a real wall, using the existing FSM.
  g, e = fresh()
  Actions.begin(g, e, 5, charge)
  for x = 12, 20 do
    g.world.map[20][x] = 1
  end
  require('src.world.arena').rebuild(g.world)
  e.windup = 0
  require('src.enemies.ai').states.windup(g, e, 5, 0.01)
  check(
    'blocked/cancelled charge cannot grant a return',
    e.ai == 'recover' and not e.finishedAttack
  )
  g, e = fresh()
  Actions.begin(g, e, 5, charge)
  e.target = -99
  Select.finished(e, charge, g.elapsed)
  check('target lost during the predecessor cancels the opportunity', not e.finishedAttack)
  -- Each string uses the actual simulation, not scripted direct execution.
  local function live()
    return fresh()
  end
  local scene, demon = live()
  local events, finishAt = {}, nil
  scene.bus:on('sim', 'AttackTelegraphed', function(ev)
    if ev.enemy == demon then
      events[#events + 1] = { id = ev.attack.id, at = scene.elapsed }
    end
  end)
  local record = Journal.record(scene)
  for _ = 1, 540 do
    scene:update(1 / 120, {})
    if demon.finishedAttack == charge.id then
      finishAt = finishAt or demon.finishedAt
    end
  end
  Journal.stop(scene)
  check(
    'live AI completes charge then begins physical continuation',
    #events >= 2 and events[1].id == charge.id and events[2].id == finish.id
  )
  check(
    'continuation respects the authored recovery',
    finishAt and events[2].at - finishAt >= charge.recover - 1e-7
  )
  local replay = live()
  Journal.replay(replay, Journal.decode(Journal.encode(record)))
  check(
    'full live string replays exactly',
    not Integrity.difference(Integrity.capture(scene), Integrity.capture(replay))
  )
  -- Inner pocket, warned ring and jumping are actual hazard contacts.
  for _, stance in ipairs({ 'inside', 'ring', 'jump' }) do
    g, e = fresh('boss')
    e.x, e.z = 16, 18
    g.player.x, g.player.z = 16, 20
    Actions.begin(g, e, 2, attack(e, 'furnace'))
    Actions.execute(g, e)
    check(
      'furnace has eight attributed warned marks: ' .. stance,
      #g.hazards == 8 and g.hazards[1].owner == e.id and g.hazards[1].delay == 0.7
    )
    g.player.z = stance == 'inside' and 19 or 20.2
    if stance == 'jump' then
      g.player.jump = 0.6
    end
    local hp = g.player.hp
    require('src.enemies.hazards').update(g, 0.69)
    check('no contact before the warning: ' .. stance, g.player.hp == hp)
    require('src.enemies.hazards').update(g, 0.02)
    check('ring has a genuine ' .. stance .. ' response', (g.player.hp < hp) == (stance == 'ring'))
  end
  for _, id in ipairs({ 'stolas', 'buer' }) do
    g, e = fresh(id)
    local near, far = Actions.choose(e, 2, 0), Actions.choose(e, 7, 0)
    check(id .. ' changes delivery with distance', near.id ~= far.id)
    e.restUntil = { [near.id] = 10 }
    check(
      id .. ' close defence cannot spam through cooldown',
      Actions.choose(e, 2, 0).id ~= near.id
    )
  end
  for _, response in ipairs({ 'retreat', 'approach', 'flank' }) do
    g, e = fresh('buer')
    e.x, e.z = 16, 18
    g.player.x, g.player.z = 16, 20.8
    Actions.begin(g, e, 2.8, attack(e, 'root-brace'))
    Actions.execute(g, e)
    if response == 'approach' then
      g.player.z = 19.7
    end
    if response == 'flank' then
      g.player.x, g.player.z = 18.5, 19.2
    end
    local hp = g.player.hp
    require('src.enemies.hazards').update(g, 0.59)
    check('root defence leaves time for ' .. response, g.player.hp == hp)
    require('src.enemies.hazards').update(g, 0.02)
    check(
      'root defence contacts approach, leaves retreat/flank: ' .. response,
      (g.player.hp < hp) == (response == 'approach')
    )
  end
  local function rejects(edit)
    local def = Schema.copy(A.furfur)
    edit(def.phases[2].tactics.moves)
    return not pcall(Creature.define, def)
  end
  check(
    'unknown predecessor rejected',
    rejects(function(m)
      m[4].after.attack = 'typo'
    end)
  )
  check(
    'zero window rejected',
    rejects(function(m)
      m[4].after.within = 0
    end)
  )
  check(
    'infinite window rejected',
    rejects(function(m)
      m[4].after.within = math.huge
    end)
  )
  check(
    'self-loop rejected',
    rejects(function(m)
      m[4].after.attack = m[4].attack
    end)
  )
  check(
    'cyclic chain rejected',
    rejects(function(m)
      m[2].after = { attack = m[4].attack, within = 2 }
    end)
  )
  check(
    'disabled predecessor rejected',
    rejects(function(m)
      table.remove(m, 2)
    end)
  )
  -- 0.43 (audit F04): after a heavy blow nothing comes before its whole recovery, an answer
  -- included. A knight hugging the armoured body is answered by a slam, not 0.7 s in.
  do
    local arena = F.arena(Game)
    arena.player.x, arena.player.z, arena.player.yaw = 16, 18.6, math.pi
    local body = arena:spawn('armored', 16, 17)
    body.awake, body.visible, body.memory, body.spawnAge = true, true, 60, 2
    body.target, body.facing = arena.player.id, 0
    local cleave = attack(body, 'cleave')
    Actions.rest(body, cleave)
    body.ai, body.attack = 'recover', 0
    local first
    for step = 1, 240 do
      body.closeFor = 5
      arena.player.hp = arena.player.maxHp
      arena:update(1 / 120, {})
      if not first and (body.ai == 'windup' or body.ai == 'strike') then
        first = step / 120
      end
    end
    check(
      'no blow nor answer before the whole recovery ' .. tostring(first),
      first ~= nil and first >= cleave.recover - 1e-6 and first < cleave.recover + 0.4
    )
  end
  -- 0.43 (audit F04): a dodge in the beat of a string is met by the answer the body waits
  -- with (Furfur: gore-return); the flow used to clear the string before the answer was asked.
  do
    local arena = F.arena(Real)
    arena.player.x, arena.player.z, arena.player.yaw = 16, 20, math.pi
    local body = arena:spawn('furfur', 16, 17)
    body.awake, body.visible, body.memory, body.spawnAge = true, true, 60, 2
    body.target, body.facing = arena.player.id, 0
    body.ai, body.recover, body.spent, body.attack = 'recover', 0, 0, 5
    body.chain, body.chainFrom = 'crown', 'gore'
    arena:dash(1, 0)
    arena:update(1 / 120, {})
    check(
      'a dodge in the beat of a string is answered',
      body.attackSpec ~= nil and body.attackSpec.id == 'gore-return' and body.chain == nil
    )
  end
  -- 0.43 (owner, R01): Stolas's lance. Its line is drawn before it strikes; a knight who stays
  -- on it is struck at once along all of it, one who steps off in time is not.
  local function lance(step)
    local arena = F.arena(Real)
    arena.player.x, arena.player.z, arena.player.yaw = 16, 26, math.pi
    local body = arena:spawn('stolas', 16, 17)
    body.awake, body.visible, body.memory, body.spawnAge = true, true, 60, 2
    body.target, body.facing, body.attack = arena.player.id, 0, 5
    local spec
    for _, atk in ipairs(require('src.content.enemies').of(body).attacks) do
      spec = atk.id == 'star-lance' and atk or spec
    end
    Actions.begin(arena, body, 9, spec)
    local drawn, hp = false, arena.player.hp
    for _ = 1, 240 do
      arena.player.hp = math.max(arena.player.hp, 1)
      arena:update(1 / 120, {})
      local mark = Pools.of(arena, 'hazards')[1]
      if mark and not drawn then
        drawn = true
        if step then
          arena.player.x = arena.player.x + 2
        end
      end
    end
    return drawn, hp - arena.player.hp
  end
  local drawn, lost = lance(false)
  check('the lance draws its line before it strikes', drawn)
  check('who stays on the line is struck ' .. lost, lost > 0)
  local _, spared = lance(true)
  check('who leaves it in time is not ' .. spared, spared == 0)
  return lines
end
return Tests

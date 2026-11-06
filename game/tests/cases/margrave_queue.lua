-- An eligible elite eventually receives a free slot without stealing a committed string.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local E = require('src.content.enemies')
  local A = require('src.enemies.actions')
  local Slots = require('src.enemies.attack_slots')
  local W = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Integrity = require('src.session.integrity')
  local lines = {}
  local check = F.checker(lines, 'margrave queue: ', 'margrave queue: ')
  for _, hz in ipairs({ 60, 120, 240 }) do
    local g = F.arena(Game)
    for z = 8, 30 do
      for x = 8, 26 do
        W.setCell(g.world, x, z, Tiles.floor)
      end
    end
    g.player.x, g.player.z, g.player.hp, g.player.maxHp = 16, 21, 10000, 10000
    local e = g:spawn('boss', 16, 15)
    local blocker = g:spawn('imp', 15, 19)
    local newcomer = g:spawn('imp', 17, 19)
    g.enemies = { blocker, newcomer, e }
    for _, b in ipairs(g.enemies) do
      b.target, b.awake, b.visible, b.memory, b.spawnAge, b.sense =
        g.player.id, true, true, 60, 2, 10
    end
    e.attack = -1
    blocker.dummy, newcomer.dummy = true, true
    A.begin(g, blocker, 2, E.imp.attacks[1])
    blocker.ai, blocker.attackSpec, blocker.attackKind =
      'strike', E.imp.attacks[1], E.imp.attacks[1].id
    for _ = 1, hz * 2 do
      g:update(1 / hz, {})
    end
    check('the current attacker keeps its slot', blocker.ai == 'strike' and e.ai == 'move')
    local Save = require('src.storage.save')
    local ids = { e.id, blocker.id, newcomer.id }
    local wait = e.slotWaitAt
    local path = 'margrave-queue-test.save'
    local written = Save.write(path, Save.encode('session', Save.capture('session', g), 1))
    local values = written and Save.read('session', path)
    if values then
      Save.restore('session', g, values)
    end
    Save.erase(path)
    local Pools = require('src.session.world')
    e, blocker, newcomer = Pools.get(g, ids[1]), Pools.get(g, ids[2]), Pools.get(g, ids[3])
    check(
      'Continue preserves the patient claimant / ' .. hz,
      values and wait and e.slotWaitAt == wait and e.slotWaitTarget == e.target
    )
    blocker.ai, blocker.recover = 'recover', 1
    newcomer.dummy, newcomer.attack = nil, -1
    g:update(1 / hz, {})
    check(
      'a waiting Margrave precedes a fresh small attacker',
      e.ai == 'windup' and newcomer.ai ~= 'windup' and newcomer.ai ~= 'strike'
    )
    e.ai, e.attack, e.slotWaitAt, e.slotWaitTarget, g.elapsed = 'move', -1, 0, e.target, 2
    local before = Integrity.capture(g)
    check('ready claimant is visible to the shared queue', Slots.yields(g, newcomer))
    check(
      'queue inspection has no simulation side effects',
      not Integrity.difference(before, Integrity.capture(g))
    )
    newcomer.chain = 'claw-late'
    check('a connecting beat cannot be stolen', not Slots.yields(g, newcomer))
    newcomer.chain = nil
    for _, state in ipairs({
      'dead',
      'stunned',
      'recovering',
      'hidden',
      'distant',
      'different-target',
    }) do
      local hp, stun, spent, x, visible, target = e.hp, e.stun, e.spent, e.x, e.visible, e.target
      if state == 'dead' then
        e.hp = 0
      elseif state == 'stunned' then
        e.stun = 1
      elseif state == 'recovering' then
        e.spent = 1
      elseif state == 'hidden' then
        e.visible = false
      elseif state == 'distant' then
        e.x = 80
      else
        e.target = newcomer.id
      end
      check(state .. ' does not block fresh attackers', not Slots.yields(g, newcomer))
      e.hp, e.stun, e.spent, e.x, e.visible, e.target = hp, stun, spent, x, visible, target
    end
  end
  return lines
end
return T

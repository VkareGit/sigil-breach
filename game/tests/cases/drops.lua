-- Rounds from creatures (owner, D2): each family its own, a chance on a kill with a pack of
-- slightly varying size, a sure modest pack for an execution, shells always from the hardest
-- bodies; the session's rolls, so the same play drops the same.
local Encounter = require('src.session.encounter')
local Execution = require('src.combat.execution')
local F = require('tests.support.fixtures')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local Rules = require('src.combat.rules')
local T = {}
local function fresh(Game)
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  Encounter.clearStage(g)
  return g, g.player
end
local function kill(g, p, creature)
  local e = g:spawn(creature, p.x + 8, p.z - 8)
  g:damageEnemy(e, e.hp + 1, 'weapon', nil, p.id, p.loadout[1])
end
local function packs(g)
  local found = {}
  for _, pickup in ipairs(Pools.of(g, 'pickups')) do
    if pickup.kind == 'ammo' then
      found[#found + 1] = pickup
    end
  end
  return found
end
local function exposed(g, p, creature, hp)
  local e = g:spawn(creature, p.x, p.z - 1.5)
  e.stun, e.hp = 2, hp or e.hp
  Rules.addCondition(e, 'exposed', 2)
  p.yaw = math.pi
  return e
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'drops: ', 'drops: ')
  local g, p = fresh(Game)
  for _ = 1, 40 do
    kill(g, p, 'imp')
  end
  local light = packs(g)
  check('a light body sometimes leaves rounds', #light > 4 and #light < 36)
  local judge, sized = true, true
  for _, pack in ipairs(light) do
    judge = judge and pack.weapon == 'judge'
    sized = sized and pack.amount >= 2 and pack.amount <= 4
  end
  check('always the revolver rounds of its family', judge)
  check('in a small pack of varying size', sized)
  g, p = fresh(Game)
  for _ = 1, 20 do
    kill(g, p, 'armored')
  end
  local heavy = packs(g)
  check('a heavy body leaves the shells', #heavy > 0 and heavy[1].weapon == 'exorcist')
  g, p = fresh(Game)
  kill(g, p, 'boss')
  local hardest = packs(g)
  check(
    'the hardest body always leaves shells',
    #hardest == 1 and hardest[1].weapon == 'exorcist' and hardest[1].amount >= 2
  )
  -- An execution: a sure modest pack, once, whether the body falls or rises.
  g, p = fresh(Game)
  exposed(g, p, 'imp', 1)
  check('an execution that kills', Execution.perform(g))
  local sure = packs(g)
  check('pays one sure pack, not two', #sure == 1 and sure[1].amount == 3)
  g, p = fresh(Game)
  local hard = exposed(g, p, 'boss')
  check('an execution the body survives', Execution.perform(g) and hard.hp > 0)
  local edge = packs(g)
  check('pays too, at his feet', #edge == 1 and edge[1].weapon == 'exorcist')
  require('src.content.weapons').give(g, 'exorcist')
  require('src.content.weapons').stock(g, 'exorcist', 0)
  local before = p.arsenal.exorcist.reserve
  g:update(1 / 120, {})
  check('where he takes it at once', #packs(g) == 0 and p.arsenal.exorcist.reserve > before)
  -- 0.42: an elite's fight is short, so its second act drops no shells (the phase drops of a
  -- true boss lie beyond its edge, session/listeners.lua: spill).
  g, p = fresh(Game)
  local margrave = g:spawn('boss', p.x, p.z - 4)
  margrave.dummy = true
  g:damageEnemy(margrave, margrave.hp * 0.6, 'weapon', nil, p.id, p.loadout[1])
  check('an elite drops nothing at its second act', #packs(g) == 0 and margrave.hp > 0)
  -- The same play drops the same.
  local function sample()
    local s = fresh(Game)
    for _ = 1, 12 do
      kill(s, s.player, 'imp')
    end
    local out = {}
    for _, pack in ipairs(packs(s)) do
      out[#out + 1] = pack.amount
    end
    return table.concat(out, ',')
  end
  check('the session rolls them, the same each time', sample() == sample())
  P.forget()
  return lines
end
return T

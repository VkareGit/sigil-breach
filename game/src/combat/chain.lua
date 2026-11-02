-- A chain of kills (content/chain.lua): it grows with each kill by the same weapon, ends when its
-- window runs out or a blow lands, and puts its edge on that weapon alone.
local Characters = require('src.content.characters')
local K = require('src.content.chain')
local Signal = require('src.session.signal')
local Chain = {}
-- The step a knight's chain stands on, or nil.
function Chain.step(p)
  local reached
  if (p.chainLeft or 0) > 0 then
    for _, step in ipairs(K.steps) do
      if (p.chainCount or 0) >= step.count then
        reached = step
      end
    end
  end
  return reached
end
-- A kill by a weapon's rounds (EnemyKilled: weapon), counted for that weapon whatever is in
-- hand by now. A kill by no weapon (a charge, an execution, a slam, a burn) neither grows the
-- chain nor ends it.
function Chain.kill(g, p, weapon)
  if not weapon then
    return
  end
  local going = (p.chainLeft or 0) > 0 and p.chainWeapon == weapon
  p.chainCount, p.chainWeapon = going and p.chainCount + 1 or 1, weapon
  p.chainLeft = K.window
  local step = Chain.step(p)
  if step then
    if step.heal and p.hp > 0 then
      p.hp = math.min(Characters.maxHp(p), p.hp + step.heal)
    end
    if step.count == p.chainCount or step == K.steps[#K.steps] then
      Signal(g, 'ChainGrew', { actor = p.id, step = step, count = p.chainCount })
    end
  end
end
function Chain.broken(p)
  p.chainLeft, p.chainCount = 0, 0
end
-- The attack of a pull with the chain's edge on it: only on the weapon that made the chain.
function Chain.edge(p, weapon, attack)
  local step = Chain.step(p)
  if not step or not step.penetration or p.chainWeapon ~= weapon then
    return attack
  end
  local edged = {}
  for key, value in pairs(attack) do
    edged[key] = value
  end
  edged.penetration = math.min(1, (attack.penetration or 0) + step.penetration)
  edged.impact = attack.impact * (step.impact or 1)
  return edged
end
return Chain

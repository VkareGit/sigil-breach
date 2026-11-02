-- A fresh start of one knight: a rest, a retry, a journey, a new trial of the proving
-- ground. What the last fight left on him ends here, each by its owner. Never rebuild the
-- knight from a prefab or delete unknown fields: identity, equipment, progress and future
-- persistent extensions belong to their owners and must survive this boundary. Health,
-- rounds and charges are the caller's: a rest fills them, a trial sets its own.
local Cast = require('src.combat.abilities')
local Effects = require('src.combat.effects')
local Reset = {}

function Reset.actor(g, p)
  -- combat/abilities: a cast under way ends unpaid; a drink begun before a rest does not
  -- land after it on the refilled flask.
  Cast.stop(g, p)
  -- combat/rules/{conditions,knight,balance}: every named condition (including
  -- stagger), partial guard damage, shove provenance and the wall-slam lock; what burns.
  p.conditions, p.poise, p.guardQuiet = nil, nil, nil
  p.pushX, p.pushZ, p.pushOwner, p.slamLock = nil, nil, nil, nil
  Effects.clear(p)
  -- combat/rally and combat/chain: health to fight back and a run of kills end with the
  -- fight they belonged to.
  p.rally, p.rallyLeft = nil, nil
  p.chainCount, p.chainLeft, p.chainWeapon = nil, nil, nil
  -- player/feel, physics/ground, combat/dodge: movement left over from the moment before.
  p.vx, p.vz = 0, 0
  p.jump, p.jumpV, p.dashTimer = 0, 0, 0
  p.level, p.airCap = nil, nil
  p.dashX, p.dashZ, p.perfectUsed, p.dodgeEnds, p.recoverAt = nil, nil, nil, nil, nil
  p.dodgeFromX, p.dodgeFromZ, p.slideX, p.slideZ = nil, nil, nil, nil
  -- player/intent: nothing pressed before the start fires or dodges after it.
  p.dashBuffer, p.jumpBuffer, p.fireBuffer, p.fireCommand = nil, nil, 0, nil
end

return Reset

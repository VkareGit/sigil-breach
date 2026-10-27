-- The proving ground's full trial boundary, not resupply or a new wave.
-- Clear known transient state by its owner. Never rebuild the knight from
-- a prefab or delete unknown fields: identity, equipment and future persistent
-- extensions belong to their owners and must survive this boundary.
local Effects = require('src.combat.effects')
local Reset = {}

-- The caller supplies the knight whose existing movement/resupply contract
-- it is resetting. This does not change another actor's inventory or spawn.
function Reset.actor(p)
  -- combat/rules/{conditions,knight,balance}: every named condition (including
  -- stagger), partial guard damage, shove provenance and the wall-slam lock.
  p.conditions, p.poise, p.guardQuiet = nil, nil, nil
  p.pushX, p.pushZ, p.pushOwner, p.slamLock = nil, nil, nil, nil
  Effects.clear(p)
  -- player/feel, physics/ground and combat/dodge: movement left over from the
  -- previous location. Feel.init resets velocity/slide/intent; refill restores
  -- charges and cancels weapon/ability actions through their existing owners.
  p.jump, p.jumpV, p.dashTimer = 0, 0, 0
  p.level, p.airCap = nil, nil
  p.dashX, p.dashZ, p.perfectUsed = nil, nil, nil
  p.dodgeFromX, p.dodgeFromZ, p.slideX, p.slideZ = nil, nil, nil, nil
end

function Reset.session(g)
  -- session/listeners: no inherited hit-stop or pacing from an old wound.
  g.worldStop, g.intensity = nil, nil
  -- physics/contact and AI: diagnostics describe this trial, not the last one.
  g.lastSlam, g.collisions, g.slams = nil, nil, nil
  g.cancelledAttacks, g.evadeCount, g.retargets = nil, nil, nil
  g.attackStarts, g.leapStarts = nil, nil
  -- Scratch must not retain removed bodies or the support under the old pose.
  g.frame, g._projectileEvents = nil, nil
  g.events = {}
  -- feedback/{damage_numbers,listeners,world_feedback,movement_marks}:
  -- lingering numbers, flashes and trail clocks are not part of Feel.init.
  g.view.damageNumbers, g.view.numberSerial, g.view.markClocks = nil, nil, nil
  g.view.staggerFlash, g.view.killPunch, g.view.breakKill, g.view.perfectDodge = nil, nil, nil, nil
  g.view.armorHit, g.view.damageDir = nil, 0
  if g.bus then
    g.bus:clear()
  end
  g.testField.returnState = nil
  -- Session clock/step, RNG, actor ids, nextId and observation generations are
  -- lifetime identities, not fight state. Field.reset invalidates observations
  -- monotonically and resets elapsed/stats separately; never rewind identities.
end

return Reset

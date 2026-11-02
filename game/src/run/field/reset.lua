-- The proving ground's full trial boundary for the session, not resupply. The
-- knight's own boundary is the one every fresh start shares (run/actor_reset.lua).
-- Clear known transient state by its owner.
local Reset = {}

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
  g.view.armorHit, g.view.damageDir, g.view.damageTrail = nil, 0, nil
  if g.bus then
    g.bus:clear()
  end
  g.testField.returnState = nil
  -- Session clock/step, RNG, actor ids, nextId and observation generations are
  -- lifetime identities, not fight state. Field.reset invalidates observations
  -- monotonically and resets elapsed/stats separately; never rewind identities.
end

return Reset

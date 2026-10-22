-- What the session's mode allows the simulation (0.24 F8). Every mode
-- declares its policy here when it registers (run/modes.lua):
--   phased        it fights only in its wave phase (g.run.phase == 'wave')
--   freezable     its record (g.testField) may stop time (frozen)
--   invincible    its record (g.testField) may make the knight unhurt
-- A session names its mode (g.mode). A hand-made record without a mode (a
-- test fixture) is read from its flags as before. Systems, rules and
-- outcomes ask here, never the flags themselves.
local Capabilities = { policies = {} }
function Capabilities.define(mode, policy)
  Capabilities.policies[mode] = policy
end
local function policyOf(g)
  return g.mode and Capabilities.policies[g.mode]
end
-- The proving ground can stop time for inspection.
function Capabilities.frozen(g)
  local policy = policyOf(g)
  if policy and not policy.freezable then
    return false
  end
  return g.testField ~= nil and g.testField.frozen == true
end
-- A phased mode (expedition, proving ground) fights only in its wave phase;
-- between waves the knight rests and shops.
function Capabilities.combatPhase(g)
  local policy = policyOf(g)
  if policy then
    return not policy.phased or (g.run ~= nil and g.run.phase == 'wave')
  end
  return not g.run or g.run.phase == 'wave'
end
-- Demons decide, walk and attack.
function Capabilities.demonsAct(g)
  return not Capabilities.frozen(g) and Capabilities.combatPhase(g)
end
-- The world holds its breath (0.25: the knight's guard broke): what flies
-- or is marked on the ground waits with the demons (g.worldStop).
function Capabilities.held(g)
  return (g.worldStop or 0) > 0
end
-- Shots and thrown charges keep flying.
function Capabilities.missilesFly(g)
  return not Capabilities.frozen(g) and not Capabilities.held(g)
end
-- Marked ground (pools, lines, strikes) burns and strikes.
function Capabilities.groundActs(g)
  return Capabilities.demonsAct(g) and not Capabilities.held(g)
end
-- The knight may shoot and throw.
function Capabilities.armed(g)
  return Capabilities.combatPhase(g)
end
-- Blows and walls can hurt the knight.
function Capabilities.vulnerable(g)
  local policy = policyOf(g)
  local shielded = (not policy or policy.invincible) and g.testField and g.testField.invincible
  return not shielded and Capabilities.combatPhase(g)
end
return Capabilities

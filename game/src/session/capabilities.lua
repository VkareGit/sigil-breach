-- What the session's mode allows the simulation (0.24 F8). Every mode
-- declares its policy here when it registers (run/modes.lua), and answers
-- for its own record through its handlers:
--   phased        it fights only while waveActive(g)
--   freezable     time may stop: frozen(g)
--   invincible    the knight may be unhurt: invincible(g)
-- A session names its mode (g.mode). A hand-made record without a mode (a
-- test fixture) is read from its flags as before. Systems, rules and
-- outcomes ask here, never the flags themselves.
local Capabilities = { policies = {}, modes = {} }
local policyHandlers = { phased = 'waveActive', freezable = 'frozen', invincible = 'invincible' }
function Capabilities.define(id, policy, mode)
  for name, enabled in pairs(policy) do
    local handler = policyHandlers[name]
    assert(
      handler and type(enabled) == 'boolean',
      'mode ' .. id .. ': invalid policy ' .. tostring(name)
    )
    assert(
      not enabled or type(mode[handler]) == 'function',
      'mode ' .. id .. ': policy ' .. name .. ' needs ' .. handler
    )
  end
  Capabilities.policies[id] = policy
  Capabilities.modes[id] = mode or {}
end
function Capabilities.undefine(id)
  Capabilities.policies[id], Capabilities.modes[id] = nil, nil
end
local function policyOf(g)
  return g.mode and Capabilities.policies[g.mode]
end
-- The mode's answer to name(g); false when it has no such handler.
local function ask(g, name)
  local handler = Capabilities.modes[g.mode][name]
  return handler ~= nil and handler(g)
end
-- The proving ground can stop time for inspection.
function Capabilities.frozen(g)
  local policy = policyOf(g)
  if policy then
    return policy.freezable == true and ask(g, 'frozen') == true
  end
  return g.testField ~= nil and g.testField.frozen == true
end
-- A phased mode (expedition, proving ground) fights only in its wave phase;
-- between waves the knight rests and shops.
function Capabilities.combatPhase(g)
  local policy = policyOf(g)
  if policy then
    return not policy.phased or ask(g, 'waveActive') == true
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
-- The sanctuary is a place; the active mode decides whether trading there
-- is available now. This does not impose a shared wallet or phase layout.
function Capabilities.canTrade(g)
  return policyOf(g) ~= nil and ask(g, 'canTrade') == true
end
-- Blows and walls can hurt the knight.
function Capabilities.vulnerable(g)
  local policy = policyOf(g)
  local shielded
  if policy then
    shielded = policy.invincible and ask(g, 'invincible')
  else
    shielded = g.testField and g.testField.invincible
  end
  return not shielded and Capabilities.combatPhase(g)
end
return Capabilities

-- What the session's mode allows the simulation (0.24 F8). Every mode
-- declares its policy here when it registers (run/modes.lua), and answers
-- for its own record through its handlers:
--   freezable     time may stop: frozen(g)
--   invincible    the knight may be unhurt: invincible(g)
--   attrition     effort is paid: stamina, the flask, no healing from kills: attrition(g)
-- A session names its mode (g.mode). Systems, rules and outcomes ask here, never a mode's
-- record.
local Capabilities = { policies = {}, modes = {} }
local policyHandlers = {
  freezable = 'frozen',
  invincible = 'invincible',
  attrition = 'attrition',
}
function Capabilities.define(id, policy, mode)
  for name, enabled in pairs(policy) do
    local handler = policyHandlers[name]
    assert(
      handler and type(enabled) == 'boolean',
      'mode ' .. id .. ': invalid policy ' .. tostring(name)
    )
    assert(
      not enabled or type(mode[handler]) == 'function',
      'mode ' .. id .. ': policy ' .. name .. ' needs ' .. tostring(handler)
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
  local mode = g.mode and Capabilities.modes[g.mode]
  local handler = mode and mode[name]
  return handler ~= nil and handler(g)
end
Capabilities.ask = ask
-- The proving ground can stop time for inspection.
function Capabilities.frozen(g)
  local policy = policyOf(g)
  return policy ~= nil and policy.freezable == true and ask(g, 'frozen') == true
end
-- Demons decide, walk and attack.
function Capabilities.demonsAct(g)
  return not Capabilities.frozen(g)
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
-- The sanctuary is a place; the active mode decides whether trading there
-- is available now.
function Capabilities.canTrade(g)
  return policyOf(g) ~= nil and ask(g, 'canTrade') == true
end
-- A proving ground holds a catalogue pose on its targets (previewFrame).
function Capabilities.posed(g)
  return ask(g, 'posed') == true
end
-- A shot and a dodge cost effort, and health comes only from the flask.
function Capabilities.attrition(g)
  local policy = policyOf(g)
  return policy ~= nil and policy.attrition == true and ask(g, 'attrition') == true
end
-- Blows and walls can hurt the knight.
function Capabilities.vulnerable(g)
  local policy = policyOf(g)
  local shielded = policy and policy.invincible and ask(g, 'invincible')
  return not shielded
end
return Capabilities

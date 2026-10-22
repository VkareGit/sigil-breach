-- The fixed order of the systems of one simulation step. The order is part
-- of the rules (see docs/ARCHITEKTURA.txt): it is declared here once and
-- never decided by who registered first at run time. A system returning
-- false stops the rest of the step (the player died, the mode paused).
local Class = require('src.core.class')
local Scheduler = Class:extend('Scheduler')
function Scheduler:init(name)
  self.name = name
  self.systems = {}
  self.byName = {}
end
-- fn(context, dt, ...) ; returns false to end the step early.
function Scheduler:add(name, fn)
  assert(not self.byName[name], self.name .. ': duplicate system ' .. name)
  local s = { name = name, fn = fn, enabled = true }
  self.systems[#self.systems + 1] = s
  self.byName[name] = s
  return self
end
function Scheduler:enable(name, on)
  assert(self.byName[name], self.name .. ': unknown system ' .. tostring(name)).enabled = on
    ~= false
end
function Scheduler:run(...)
  for _, s in ipairs(self.systems) do
    if s.enabled and s.fn(...) == false then
      return false, s.name
    end
  end
  return true
end
function Scheduler:names()
  local out = {}
  for i, s in ipairs(self.systems) do
    out[i] = s.name
  end
  return out
end
return Scheduler

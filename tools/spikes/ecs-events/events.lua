-- Spike: event bus with two phases that keeps the simulation order.
--  'sim'     handlers run immediately, in the order of their declared
--            priority (then registration), inside the emitting system:
--            exactly like today's direct calls, but decoupled.
--  'present' handlers are queued and flushed once after the simulation step
--            (audio, particles, camera, telemetry). They can never change
--            the simulation, so their order cannot break determinism.
local Bus = {}
Bus.__index = Bus
function Bus.new()
  return setmetatable({ sim = {}, present = {}, queue = {}, serial = 0 }, Bus)
end
function Bus:on(phase, kind, priority, fn)
  local list = self[phase]
  list[kind] = list[kind] or {}
  self.serial = self.serial + 1
  local l = list[kind]
  l[#l + 1] = { priority = priority, serial = self.serial, fn = fn }
  table.sort(l, function(a, b)
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    return a.serial < b.serial
  end)
end
function Bus:emit(kind, event)
  event.kind = kind
  for _, h in ipairs(self.sim[kind] or {}) do
    h.fn(event)
  end
  if self.present[kind] then
    self.queue[#self.queue + 1] = event
  end
end
function Bus:flushPresent()
  local q = self.queue
  self.queue = {}
  for _, event in ipairs(q) do
    for _, h in ipairs(self.present[event.kind]) do
      h.fn(event)
    end
  end
  return #q
end
return Bus

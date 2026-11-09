-- Event bus with two phases that keeps the order of the simulation
-- (verified by tools/spikes/ecs-events).
--   'sim'      handlers run immediately inside the emitting system, in the
--              order of their priority, then of registration. They may change
--              the simulation (rewards, healing, pacing): exactly like a
--              direct call, but the emitter does not know who listens.
--   'present'  handlers show what happened (sounds, particles, camera,
--              captions). During a simulation step (beginStep .. flush) they
--              are queued and run after the step; outside a step (menus,
--              tools, a direct call) they run at once. They must never
--              change the simulation.
-- Every event kind is declared first (bus:define): an unknown kind is an
-- error, so a typo cannot silently drop an effect.
local Class = require('src.core.class')
local Bus = Class:extend('EventBus')
function Bus:init()
  self.kinds = {}
  self.handlers = { sim = {}, present = {} }
  self.queue = {}
  self.serial = 0
  self.flushing = false
  self.stepping = false
end
-- Presentation is deferred from here until flush().
function Bus:beginStep()
  self.stepping = true
end
-- kind: name; doc: one line on what happened (catalogue in docs).
function Bus:define(kind, doc)
  self.kinds[kind] = doc or true
  return self
end
function Bus:known(kind)
  return self.kinds[kind] ~= nil
end
-- phase 'sim' or 'present'; priority: lower runs first (default 50).
function Bus:on(phase, kind, fn, priority)
  assert(self.handlers[phase], 'unknown event phase ' .. tostring(phase))
  assert(self.kinds[kind], 'unknown event kind ' .. tostring(kind))
  local list = self.handlers[phase][kind] or {}
  self.handlers[phase][kind] = list
  self.serial = self.serial + 1
  list[#list + 1] = { priority = priority or 50, serial = self.serial, fn = fn } -- constant: the middle priority
  table.sort(list, function(a, b)
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    return a.serial < b.serial
  end)
  return fn
end
function Bus:off(phase, kind, fn)
  local list = self.handlers[phase][kind] or {}
  for i = #list, 1, -1 do
    if list[i].fn == fn then
      table.remove(list, i)
    end
  end
end
-- Emit: sim handlers now, present handlers at the next flush.
function Bus:emit(kind, event)
  if not self.kinds[kind] then
    error('unknown event kind ' .. tostring(kind), 2)
  end
  event = event or {}
  event.kind = kind
  local sim = self.handlers.sim[kind]
  if sim then
    for i = 1, #sim do
      sim[i].fn(event)
    end
  end
  local present = self.handlers.present[kind]
  if present then
    if self.stepping then
      self.queue[#self.queue + 1] = event
    else
      for i = 1, #present do
        present[i].fn(event)
      end
    end
  end
  return event
end
-- Run the queued presentation handlers in emission order. Returns count.
function Bus:flush()
  self.stepping = false
  if self.flushing then
    return 0
  end
  self.flushing = true
  local queue = self.queue
  self.queue = {}
  for _, event in ipairs(queue) do
    for _, h in ipairs(self.handlers.present[event.kind] or {}) do
      h.fn(event)
    end
  end
  self.flushing = false
  return #queue
end
-- Drop queued presentation (a reset or a new encounter).
function Bus:clear()
  self.queue = {}
end
return Bus

-- Cooperative application loading. Providers supply named jobs; checkpointed
-- jobs resume only after a displayed progress frame, never during gameplay. A displayed
-- frame goes on through slices of work until its budget is spent (PLAN Z8: content/
-- tuning.lua, clocks.loadingWork): steps counts the frames that worked, slices each resume.
local Tuning = require('src.content.tuning')
local LoadPlan = {}
LoadPlan.__index = LoadPlan
function LoadPlan.new(label, jobs, clock, budget)
  return setmetatable({
    label = label,
    jobs = jobs,
    total = #jobs,
    remaining = #jobs,
    index = 1,
    shown = false,
    steps = 0,
    slices = 0,
    maxStep = 0,
    budget = budget or Tuning.clocks.loadingWork,
    timings = {},
    clock = clock or love.timer.getTime,
  }, LoadPlan)
end
-- One slice of the current provider: to its next checkpoint or its end.
function LoadPlan:slice()
  local job = self.jobs[self.index]
  if not job then
    self.done = true
    return
  end
  self.stage = job.label or self.label
  if not self.worker then
    self.worker = coroutine.create(function()
      job.run(function(detail)
        coroutine.yield(detail)
      end)
    end)
  end
  local start = self.clock()
  local ok, detail = coroutine.resume(self.worker)
  local elapsed = self.clock() - start
  self.slices, self.maxStep = self.slices + 1, math.max(self.maxStep, elapsed)
  self.timings[#self.timings + 1] = { stage = self.stage, detail = detail, seconds = elapsed }
  if not ok then
    self.error = tostring(detail)
    self.worker = nil
  elseif coroutine.status(self.worker) == 'dead' then
    self.worker = nil
    self.index = self.index + 1
    self.remaining = self.total - self.index + 1
    self.done = self.remaining == 0
  end
end
function LoadPlan:step()
  if not self.shown or self.error or self.cancelled or self.done then
    return false
  end
  self.shown = false
  local began, worked = self.clock(), false
  repeat
    worked = worked or self.jobs[self.index] ~= nil
    self:slice()
  until self.done or self.error or self.clock() - began >= self.budget
  if worked then
    self.steps = self.steps + 1
  end
  return self.done or false
end
function LoadPlan:cancel()
  self.cancelled, self.worker, self.jobs = true, nil, {}
end
return LoadPlan

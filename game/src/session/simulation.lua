-- The fixed-step session update: the clock, the pause gate, then every
-- system in the order of src/systems/index.lua (core/scheduler), then the
-- presentation listeners of the step's events (core/events, phase
-- 'present'). Ordering is gameplay; it is declared, never emergent.
local Presentation = require('src.session.presentation')
local Intent = require('src.player.intent')
local Scheduler = require('src.core.scheduler')
local Systems = require('src.systems.index')
local Simulation = {}
local Step = Scheduler:new('simulation')
for _, system in ipairs(Systems) do
  Step:add(system.name, system.run)
end
Simulation.systems = Step
-- Reuse held input; copy only records with one-shot edges. Unknown fields
-- remain part of the envelope, including actor inputs supplied by controllers.
local function withoutEdges(input)
  if not (input.dash or input.slide) then
    return input
  end
  local held = {}
  for key, value in pairs(input) do
    held[key] = value
  end
  held.dash, held.slide = nil, nil
  return held
end
local function heldInput(input)
  local held = withoutEdges(input)
  local actors
  if input.actors then
    for id, own in pairs(input.actors) do
      local nextInput = withoutEdges(own)
      if nextInput ~= own then
        if not actors then
          actors = {}
          for key, value in pairs(input.actors) do
            actors[key] = value
          end
        end
        actors[id] = nextInput
      end
    end
  end
  if actors then
    if held == input then
      held = {}
      for key, value in pairs(input) do
        held[key] = value
      end
    end
    held.actors = actors
  end
  return held
end
function Simulation.step(g, dt, input)
  g.time = g.time + dt
  Presentation.call(g, 'audio', dt)
  if g.state ~= 'playing' or g.map or g.help then
    Intent.clear(g)
    return
  end
  g.elapsed = g.elapsed + dt
  input = input or {}
  local frame = g.frame or {}
  g.frame = frame
  if g.bus then
    g.bus:beginStep()
  end
  Step:run(g, dt, input, frame)
  -- Presentation listeners of this step's events (sounds, particles...).
  if g.bus then
    g.bus:flush()
  end
end
function Simulation.update(g, dt, input)
  if type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge then
    return
  end
  -- The application runs at 120 Hz. Non-application callers get the same
  -- bounded integration; a dash/slide press is consumed only on the first step.
  local remaining = math.min(dt, 0.20)
  input = input or {}
  while remaining > 1e-10 do
    local step = math.min(remaining, require('src.core.rate').step)
    g:simulate(step, input)
    remaining = remaining - step
    if remaining > 1e-10 then
      input = heldInput(input)
    end
  end
end

return Simulation

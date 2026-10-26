-- Common presentation asks for a mode's contract, not its private state.
-- Views are borrowed until the next call and must not be mutated or retained.
local Modes = require('src.run.modes')
local Queries = {}
local empty = { gates = {}, paintedPickups = false, classicSecret = false }
function Queries.world(g)
  return Modes.act(g, 'worldView') or empty
end
function Queries.tools(g)
  return Modes.act(g, 'tools') or nil
end
function Queries.objective(g)
  return Modes.act(g, 'objective') or ''
end
-- The run of the session's mode (phase, wave, wallet, echo...; nil when it
-- keeps none) and its proving ground (nil outside one): read-only views.
function Queries.run(g)
  return Modes.act(g, 'runView') or nil
end
function Queries.field(g)
  return Modes.act(g, 'fieldView') or nil
end
return Queries

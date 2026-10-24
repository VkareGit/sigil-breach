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
return Queries

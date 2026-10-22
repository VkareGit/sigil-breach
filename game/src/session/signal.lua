-- Announce an event of the session (session/event_catalog.lua). A bare
-- session without a bus (a hand-made test fixture) announces nothing.
return function(g, kind, event)
  local bus = g and g.bus
  if bus then
    return bus:emit(kind, event or {})
  end
  return event
end

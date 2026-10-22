-- A planted step is a distance event, shared by the carried weapon and audio.
-- Each half-cycle plants one foot: pi / 2.5 = 1.257 m. Keeping the remainder
-- prevents sound/hand drift when render frames have unequal durations.
local G = { radiansPerMetre = 2.5 }
G.stepDistance = math.pi / G.radiansPerMetre
function G.init(g)
  g.view.gaitPhase = 0
  g.view.gaitSteps = 0
end
function G.planted(p)
  return p.jump <= 0 and p.slideTimer == 0 and p.dashTimer == 0
end
function G.advance(g, distance, planted)
  if
    not planted
    or type(distance) ~= 'number'
    or distance <= 0
    or distance >= math.huge
    or distance ~= distance
  then
    return 0
  end
  local before = g.view.gaitPhase or 0
  local after = before + distance * G.radiansPerMetre
  -- The epsilon only resolves floating-point noise at a foot-plant boundary.
  local steps = math.floor(after / math.pi + 1e-9) - math.floor(before / math.pi + 1e-9)
  g.view.gaitPhase = after
  g.view.gaitSteps = (g.view.gaitSteps or 0) + steps
  return steps
end
return G

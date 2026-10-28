-- Pure presentation curves. Neither input latency nor encounter timing is
-- changed: the altar responds to the already accepted trial command.
local Motion = {}
function Motion.sample(view, id, time)
  if view.summoningSeal ~= id or not view.summoningStarted then
    return 0, 1, 0, false
  end
  local age = math.max(0, time - view.summoningStarted)
  if view.summoningStatus ~= 'active' then
    local fade = math.max(0, 1 - (time - (view.summoningFinished or time)) / 0.9)
    return fade * 0.25, 1, 0, view.summoningStatus == 'complete'
  end
  local reveal = math.min(1, age / 0.65)
  local glow = age < 0.65 and math.sin(reveal * math.pi / 2) or math.exp(-(age - 0.65) * 1.8)
  -- A slow ember after the tracing stroke, never a strobe or a rotating seal.
  glow = math.max(glow, 0.10 + 0.025 * math.sin(age * 2))
  return glow, reveal, 0.16 * math.sin(math.min(1, age / 1.6) * math.pi), false
end
return Motion

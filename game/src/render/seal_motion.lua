-- Pure presentation curves. Neither input latency nor encounter timing is
-- changed: the altar responds to the already accepted trial command.
local SummoningLook = require('src.content.art.ritual_look').summoning
local Motion = {}
function Motion.sample(view, id, time)
  if view.summoningSeal ~= id or not view.summoningStarted then
    return 0, 1, 0, false
  end
  local age = math.max(0, time - view.summoningStarted)
  if view.summoningStatus ~= 'active' then
    local fade = math.max(0, 1 - (time - (view.summoningFinished or time)) / SummoningLook.fadeOut)
    return fade * SummoningLook.rest, 1, 0, view.summoningStatus == 'complete'
  end
  local reveal = math.min(1, age / SummoningLook.reveal)
  local glow = age < SummoningLook.reveal and math.sin(reveal * math.pi / 2)
    or math.exp(-(age - SummoningLook.reveal) * SummoningLook.decay)
  -- A slow ember after the tracing stroke, never a strobe or a rotating seal.
  glow = math.max(
    glow,
    SummoningLook.ember + SummoningLook.emberPulse * math.sin(age * SummoningLook.emberRate)
  )
  return glow,
    reveal,
    SummoningLook.lift * math.sin(math.min(1, age / SummoningLook.liftTime) * math.pi),
    false
end
return Motion

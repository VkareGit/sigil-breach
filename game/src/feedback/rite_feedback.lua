-- A ray's damage can last less than a display frame. Remember its released
-- geometry for a brief painted afterimage, without extending the hazard.
local Pools = require('src.session.world')
local Rites = require('src.content.art.rites')
local Feedback = {}
require('src.session.fields').declareView('feedback.rite_feedback', { 'riteBursts' }, 'world')
function Feedback.released(g, event)
  if event.attack.kind ~= 'beam' then
    return
  end
  local bursts = g.view.riteBursts or {}
  g.view.riteBursts = bursts
  local hazards = Pools.of(g, 'hazards')
  -- Present events are flushed after hazards have advanced this step. The
  -- latest ray of this owner carries the remaining authoritative warning.
  for i = #hazards, 1, -1 do
    local h = hazards[i]
    if h.kind == 'sweepline' and h.owner == event.enemy.id then
      bursts[#bursts + 1] = {
        x = h.x,
        z = h.z,
        level = h.level,
        angle = h.angle,
        radius = h.radius,
        starts = g.elapsed + h.delay,
      }
      break
    end
  end
  while #bursts > Rites.ray.limit do
    table.remove(bursts, 1)
  end
end
function Feedback.update(g)
  local bursts = g.view.riteBursts
  for i = #(bursts or {}), 1, -1 do
    if g.elapsed - bursts[i].starts > Rites.ray.embers then
      table.remove(bursts, i)
    end
  end
end
return Feedback

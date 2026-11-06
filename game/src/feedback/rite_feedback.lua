-- Remember the end of a released tear for a brief, harmless settling painting.
local Pools = require('src.session.world')
local Rites = require('src.content.art.rites')
local Feedback = {}
require('src.session.fields').declareView(
  'feedback.rite_feedback',
  { 'riteBursts', 'blinkBursts', 'lightningBursts' },
  'world'
)
function Feedback.struck(g, event)
  local h = event.hazard
  local style = Rites.lightnings[h.art]
  if not style then
    return
  end
  local list = g.view.lightningBursts or {}
  g.view.lightningBursts = list
  list[#list + 1] = {
    x = h.x,
    z = h.z,
    level = h.level,
    radius = h.radius,
    art = h.art,
    starts = event.at + math.max(0, h.life),
  }
  while #list > style.limit do
    table.remove(list, 1)
  end
end
function Feedback.blinked(g, event)
  local list = g.view.blinkBursts or {}
  g.view.blinkBursts = list
  local starts = event.at or g.elapsed
  list[#list + 1] =
    { x = event.fromX, z = event.fromZ, level = event.level, starts = starts, arriving = false }
  list[#list + 1] =
    { x = event.toX, z = event.toZ, level = event.level, starts = starts, arriving = true }
  while #list > Rites.blink.limit do
    table.remove(list, 1)
  end
end
function Feedback.released(g, event)
  if event.attack.kind ~= 'beam' and event.attack.kind ~= 'wave' then
    return
  end
  if event.attack.kind == 'wave' and not Rites.waves[event.attack.art] then
    return
  end
  local bursts = g.view.riteBursts or {}
  g.view.riteBursts = bursts
  local hazards = Pools.of(g, 'hazards')
  -- Present events are flushed after hazards have advanced this step. The
  -- latest ray of this owner carries the remaining authoritative warning.
  for i = #hazards, 1, -1 do
    local h = hazards[i]
    if (h.kind == 'sweepline' or h.kind == 'wave') and h.owner == event.enemy.id then
      local wave = h.kind == 'wave'
      local life = wave and (h.reach - h.radius) / h.spread or h.life
      bursts[#bursts + 1] = {
        kind = h.kind,
        art = h.art,
        height = h.volume and h.volume.top,
        width = h.width,
        x = h.x,
        z = h.z,
        level = h.level,
        angle = not wave and h.angle + h.spin * h.life or 0,
        radius = wave and h.reach or h.radius,
        starts = g.elapsed + math.max(0, h.delay) + life,
      }
      break
    end
  end
  while #bursts > Rites.ray.limit do
    table.remove(bursts, 1)
  end
end
function Feedback.update(g)
  local lightning = g.view.lightningBursts
  for i = #(lightning or {}), 1, -1 do
    local burst = lightning[i]
    if g.elapsed - burst.starts >= Rites.lightnings[burst.art].embers then
      table.remove(lightning, i)
    end
  end
  local blinks = g.view.blinkBursts
  for i = #(blinks or {}), 1, -1 do
    if g.elapsed - blinks[i].starts >= Rites.blink.duration then
      table.remove(blinks, i)
    end
  end
  local bursts = g.view.riteBursts
  for i = #(bursts or {}), 1, -1 do
    if g.elapsed - bursts[i].starts > Rites.ray.embers then
      table.remove(bursts, i)
    end
  end
end
return Feedback

-- Remember the end of a released tear for a brief, harmless settling painting.
local Pools = require('src.session.world')
local Rites = require('src.content.art.rites')
local HazardDefs = require('src.content.hazards')
local Action = require('src.content.defs.action')
local Registry = require('src.core.registry')
local Feedback = {}
-- What the release of a mark leaves to settle on the floor, by its kind (content/hazards.lua,
-- PLAN Z7): burst(g, h), the settling painting at the end of the mark; a kind without an
-- entry leaves nothing.
Feedback.bursts = Registry:new('hazard bursts', function(entry, id)
  HazardDefs:get(id)
  assert(type(entry) == 'function', 'hazard burst ' .. id .. ' is a function')
end)
local function burst(g, h, life, angle, radius)
  return {
    kind = h.kind,
    art = h.art,
    height = h.volume and h.volume.top,
    width = h.width,
    x = h.x,
    z = h.z,
    level = h.level,
    angle = angle,
    radius = radius,
    starts = g.elapsed + math.max(0, h.delay) + life,
  }
end
-- A ring settles at its reach when it gets there.
Feedback.bursts:register('wave', function(g, h)
  return burst(g, h, (h.reach - h.radius) / h.spread, 0, h.reach)
end)
-- A ray where it stops turning.
Feedback.bursts:register('sweepline', function(g, h)
  return burst(g, h, h.life, h.angle + h.spin * h.life, h.radius)
end)
require('src.session.fields').declareView(
  'feedback.rite_feedback',
  { 'riteBursts', 'blinkBursts', 'lightningBursts', 'impactBursts', 'poolBursts' },
  'world'
)
function Feedback.landed(g, event)
  local spec = event.attack
  local style = spec and Rites.impacts[spec.landArt]
  if not style then
    return
  end
  local e = event.enemy
  local list = g.view.impactBursts or {}
  g.view.impactBursts = list
  list[#list + 1] = {
    x = e.x,
    z = e.z,
    level = e.level,
    radius = spec.landRadius,
    art = spec.landArt,
    starts = event.at or g.elapsed,
  }
  while #list > style.limit do
    table.remove(list, 1)
  end
end
function Feedback.ended(g, event)
  local h = event.hazard
  local style = Rites.pools[h.art]
  if not style then
    return
  end
  local list = g.view.poolBursts or {}
  g.view.poolBursts = list
  list[#list + 1] =
    { x = h.x, z = h.z, level = h.level, radius = h.radius, art = h.art, starts = event.at }
  while #list > style.limit do
    table.remove(list, 1)
  end
end
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
-- A release that settles, as its kind of attack says (content/defs/action.lua: settles,
-- PLAN A4); one that names its rites settles only in an art they paint.
function Feedback.released(g, event)
  local settles = Action.trait(event.attack, 'settles')
  if not settles or (settles ~= true and not Rites[settles][event.attack.art]) then
    return
  end
  local bursts = g.view.riteBursts or {}
  g.view.riteBursts = bursts
  local hazards = Pools.of(g, 'hazards')
  -- Present events are flushed after hazards have advanced this step. The
  -- latest ray of this owner carries the remaining authoritative warning.
  for i = #hazards, 1, -1 do
    local h = hazards[i]
    local settle = Feedback.bursts:find(h.kind or HazardDefs.default)
    if settle and h.owner == event.enemy.id then
      bursts[#bursts + 1] = settle(g, h)
      break
    end
  end
  while #bursts > Rites.ray.limit do
    table.remove(bursts, 1)
  end
end
function Feedback.update(g)
  local pools = g.view.poolBursts
  for i = #(pools or {}), 1, -1 do
    if g.elapsed - pools[i].starts >= Rites.pools[pools[i].art].embers then
      table.remove(pools, i)
    end
  end
  local impacts = g.view.impactBursts
  for i = #(impacts or {}), 1, -1 do
    if g.elapsed - impacts[i].starts >= Rites.impacts[impacts[i].art].life then
      table.remove(impacts, i)
    end
  end
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

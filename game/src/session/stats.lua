-- The fight's counters by actor (plan v11 E3d): kills, score, the combo and
-- its window, damage taken. They are kept per actor id in the session's
-- ledger (g.stats), so a knight's record stays after he falls or leaves; the
-- session and the modes read sums (Stats.total), the HUD the controlled
-- knight's record.
-- A consequence of a damage chain belongs to the chain's owner when it is a
-- knight. A chain with no knight behind it (a demon's blow, a collision no
-- knight caused) belongs, in a session of one knight, to that knight, as in
-- 0.33; with several knights it is the world's (Stats.world) and heals no one.
local Roles = require('src.core.roles')
local Pools = require('src.session.world')
local Stats = { world = 'world' }
Stats.fields = { 'kills', 'score', 'combo', 'comboTimer', 'damageTaken' }
-- The record of an actor id (created at zero).
function Stats.record(g, id)
  local ledger = g.stats
  if not ledger then
    ledger = {}
    g.stats = ledger
  end
  id = id or Stats.world
  local r = ledger[id]
  if not r then
    r = { kills = 0, score = 0, combo = 0, comboTimer = 0, damageTaken = 0 }
    ledger[id] = r
  end
  return r
end
local function idOf(knight)
  return knight and knight.id or Stats.world
end
-- The controlled knight's record, to change it.
function Stats.controlled(g)
  return Stats.record(g, idOf(Roles.controlled(g)))
end
-- A record to read (never created by reading): the HUD, reports, QA.
local zero = { kills = 0, score = 0, combo = 0, comboTimer = 0, damageTaken = 0 }
function Stats.read(g, id)
  return (g.stats and g.stats[id or Stats.world]) or zero
end
function Stats.readControlled(g)
  return Stats.read(g, idOf(Roles.controlled(g)))
end
local function ids(g)
  local out = {}
  for id in pairs(g.stats or {}) do
    out[#out + 1] = id
  end
  table.sort(out)
  return out
end
-- A counter summed over every record, in id order.
function Stats.total(g, field)
  local sum = 0
  for _, id in ipairs(ids(g)) do
    sum = sum + (g.stats[id][field] or 0)
  end
  return sum
end
-- Every record back at zero (a new encounter, the proving ground's reset).
function Stats.reset(g)
  g.stats = nil
end
-- A checkpoint's counters given back to the controlled knight (the rest
-- cleared): kills, score and damage taken.
function Stats.restore(g, kills, score, damageTaken)
  Stats.reset(g)
  local r = Stats.controlled(g)
  r.kills, r.score, r.damageTaken = kills, score, damageTaken
end
-- The knights of the session: the pool, or a hand-made controlled one alone.
local function knights(g)
  local list = Pools.of(g, 'knights')
  local controlled = Roles.controlled(g)
  for _, k in ipairs(list) do
    if k == controlled then
      return list
    end
  end
  return { controlled }
end
-- The one knight of a session that has exactly one.
local function only(g)
  local list = knights(g)
  return #list == 1 and list[1] or nil
end
-- Whose record a consequence of a chain with owner id counts in: a knight's
-- id (present, fallen or gone) is his; anything else is the only knight's,
-- else the world's.
function Stats.owner(g, owner)
  if type(owner) == 'string' then
    return owner
  end
  return idOf(only(g))
end
-- Who a chain's healing reaches: its owner knight, present and standing; for
-- a chain with no knight behind it, the only knight; else nobody.
function Stats.healed(g, owner)
  local knight
  if type(owner) == 'string' then
    knight = Pools.get(g, owner)
    local controlled = Roles.controlled(g)
    if not knight and controlled and controlled.id == owner then
      knight = controlled
    end
  else
    knight = only(g)
  end
  if knight and (knight.hp or 0) > 0 then
    return knight
  end
end
-- Each record's combo window runs down.
function Stats.tick(g, dt)
  for _, id in ipairs(ids(g)) do
    local r = g.stats[id]
    r.comboTimer = math.max(0, r.comboTimer - dt)
  end
end
return Stats

-- The proving ground's targets (plan v10 V6: run/test_field.lua split by
-- responsibility): where catalogue demons may stand, standing them at once
-- or summoning them through portals, and the manual pose preview. Every
-- function takes the field module (run/test_field.lua) and the session.
local Animation = require('src.enemies.animation')
local Chambers = require('src.run.field.chambers')
local MathX = require('src.core.mathx')
local Signal = require('src.session.signal')
local Arena = require('src.world.arena')
local Archetypes = require('src.content.enemies')
local Gates = require('src.run.gates')
local Pools = require('src.session.world')
local Grid = require('src.physics.grid')
local Roles = require('src.core.roles')
local Text = require('src.content.text')
local FieldData = require('src.content.field')
local Placement = {}
local distance = MathX.distance
-- A catalogue demon set on the knight: awake, remembering where he stands,
-- facing him, its first blow a moment off.
local function engage(g, e, kind)
  local p = Roles.controlled(g)
  e.fieldKind = kind
  e.awake = true
  e.memory = FieldData.engage.memory
  e.lastX = p.x
  e.lastZ = p.z
  e.facing = math.atan2(p.x - e.x, p.z - e.z)
  e.attack = FieldData.engage.firstBlow
end
-- Check catalogue requests before a caller replaces an active trial.
function Placement.request(field, g, kind, count)
  if not g.testField or not Archetypes.get(kind) then
    return nil, Text.get('field_unknown_kind')
  end
  local allowed = false
  for _, e in ipairs(field.catalog.enemies) do
    if e.id == kind then
      allowed = true
    end
  end
  if not allowed or (count ~= 1 and count ~= 3) then
    return nil, Text.get('field_count')
  end
  return true
end
-- Where count demons of kind may stand (free, in sight, 3 m or more from
-- the knight, apart from the living and from open gates), or nil and why.
-- Gates still opening count toward the limit of live demons.
local function place(field, g, kind, count)
  local allowed, reason = Placement.request(field, g, kind, count)
  if not allowed then
    return nil, reason
  end
  local alive = #g.run.pending
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      alive = alive + 1
    end
  end
  if alive + count > field.limit then
    field.tell(g, 'field_limit', { limit = field.limit })
    return nil, g.testField.message
  end
  local p = Roles.controlled(g)
  local radius = Archetypes.get(kind).appearance.fieldRing
  local spots = {}
  local function legal(x, z)
    local candidate = { x = x, z = z }
    if
      Arena.solid(g.world, x, z, radius)
      or distance(p, candidate) < FieldData.placement.near
      or not Arena.visible(g.world, p.x, p.z, x, z)
    then
      return false
    end
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      if e.hp > 0 and distance(e, candidate) < FieldData.placement.spacing then
        return false
      end
    end
    for _, list in ipairs({ g.run.pending, spots }) do
      for _, s in ipairs(list) do
        if distance(s, candidate) < FieldData.placement.spacing then
          return false
        end
      end
    end
    return true
  end
  for _, d in ipairs(FieldData.placement.rings) do
    for _, offset in ipairs(FieldData.placement.offsets) do
      local x = p.x + math.sin(p.yaw) * d + math.cos(p.yaw) * offset
      local z = p.z + math.cos(p.yaw) * d - math.sin(p.yaw) * offset
      if #spots < count and legal(x, z) then
        spots[#spots + 1] = { x = x, z = z }
      end
    end
  end
  if #spots < count then
    local candidates = {}
    for z = 2, Grid.depth(g.world) - 1 do
      for x = 2, Grid.width(g.world) - 1 do
        local d = distance(p, { x = x, z = z })
        if d >= FieldData.placement.near and d < FieldData.placement.search and legal(x, z) then
          candidates[#candidates + 1] = { x = x, z = z, d = d }
        end
      end
    end
    table.sort(candidates, function(a, b)
      return a.d < b.d
    end)
    for _, s in ipairs(candidates) do
      if #spots < count and legal(s.x, s.z) then
        spots[#spots + 1] = s
      end
    end
  end
  if #spots < count then
    field.tell(g, 'field_no_space')
    return nil, g.testField.message
  end
  -- Remove old bodies only when adding a new batch, keeping death inspection intact.
  Pools.keep(g, 'enemies', function(e)
    return e.hp > 0
  end)
  Pools.clear(g, 'remains')
  g.testField.selected = kind
  g.testField.poseIndex = 1
  return spots
end
local function targets(kind, count)
  return Text.get(
    count == 1 and 'field_targets_one' or 'field_targets_many',
    { name = Text.get(Archetypes.get(kind).name), count = count }
  )
end
-- Demons of kind standing at once (pose preview, tools, tests): no portal,
-- no arrival (spawnAge 1). Returns the created demons, or nil and why.
function Placement.spawn(field, g, kind, count)
  local spots, why = place(field, g, kind, count)
  if not spots then
    return nil, why
  end
  local created = {}
  for _, s in ipairs(spots) do
    local e = g:spawn(kind, s.x, s.z)
    engage(g, e, kind)
    e.spawnAge = 1
    created[#created + 1] = e
  end
  field.update(g, 0)
  field.tell(g, 'field_spawned', { targets = targets(kind, count) })
  return created
end
-- The catalogue's summons (F2) come through portals: each opens a gate at
-- its place and the demon steps out when it has glowed (Gates.gate; the
-- arrivals run with the stations). Returns the gates, or nil and why.
function Placement.summon(field, g, kind, count)
  local spots, why = place(field, g, kind, count)
  if not spots then
    return nil, why
  end
  local gates = {}
  for _, s in ipairs(spots) do
    local gate = Gates.gate(kind, s.x, s.z)
    gate.fieldKind = kind
    g.run.pending[#g.run.pending + 1] = gate
    gates[#gates + 1] = gate
    Signal(g, 'PortalOpened', { gate = gate })
  end
  field.tell(
    g,
    count == 1 and 'field_summoned_one' or 'field_summoned_many',
    { targets = targets(kind, count) }
  )
  return gates
end
-- What a demon stepping out of a gate here is given: a catalogue summons
-- is set on the knight.
function Placement.arrive(g, e, gate)
  if gate.fieldKind then
    engage(g, e, gate.fieldKind)
  else
    Gates.welcome(g, e, gate)
  end
  Chambers.arrived(g, e, gate)
end
function Placement.pose(field, g, delta)
  if not g.testField then
    return false
  end
  local t = g.testField
  local kind = t.selected
  local chosen = {}
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.fieldKind == kind then
      chosen[#chosen + 1] = e
    end
  end
  if #chosen == 0 then
    chosen = Placement.spawn(field, g, kind, 1)
    if not chosen then
      return false
    end
  end
  local frames = Animation.frameCount(kind)
  t.poseIndex = ((t.poseIndex - 1 + (delta or 1)) % frames) + 1
  t.frozen = true
  for _, e in ipairs(chosen) do
    e.previewFrame = t.poseIndex
  end
  field.tell(g, 'field_pose', { pose = t.poseIndex, frames = frames })
  return true
end
return Placement

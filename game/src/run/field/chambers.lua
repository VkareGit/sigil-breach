-- One map-authored trial at a time. Definitions are immutable; the mode
-- record holds only its id, arrivals and outcome for snapshots and replay.
local Maps = require('src.content.maps.index')
local A = require('src.content.enemies')
local W = require('src.world.arena')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Spawner = require('src.run.spawner')
local Signal = require('src.session.signal')
local Text = require('src.content.text')
local K = require('src.content.field')
local C = {}
function C.layout(g)
  return Maps:get(g.world.mapId).proving
end
local function find(list, id)
  for _, value in ipairs(list) do
    if value.id == id then
      return value
    end
  end
end
function C.validate(g)
  local layout = C.layout(g)
  if not layout then
    return
  end
  local Weapons = require('src.content.weapons')
  for _, trial in ipairs(layout.trials) do
    local def = A.get(trial.creature)
    assert(def, 'unknown chamber creature: ' .. trial.creature)
    local room = find(layout.chambers, trial.chamber)
    local entry = room.entry
    assert(
      not W.solid(
        g.world,
        entry.x,
        entry.z,
        require('src.content.characters').standard().body.radius
      ),
      'blocked chamber entry'
    )
    for i, spot in ipairs(room.slots) do
      assert(not W.solid(g.world, spot.x, spot.z, def.body.radius), 'blocked chamber spawn')
      assert(
        (spot.x - entry.x) ^ 2 + (spot.z - entry.z) ^ 2 >= K.placement.near ^ 2,
        'spawn too close to entry'
      )
      for j = 1, i - 1 do
        local other = room.slots[j]
        assert(
          (spot.x - other.x) ^ 2 + (spot.z - other.z) ^ 2 > (2 * def.body.radius) ^ 2,
          'overlapping chamber spawns'
        )
      end
    end
  end
  for _, pad in ipairs(require('src.world.proving_pads').forWorld(g.world)) do
    assert(
      not W.solid(g.world, pad.x, pad.z, require('src.content.characters').standard().body.radius),
      'blocked trial pad'
    )
    if pad.weapon then
      assert(Weapons.get(pad.weapon), 'unknown pad weapon')
    end
  end
end
-- Read-only authored boundary, independent of creature kind and phase count.
function C.arena(g, state)
  local active = state.roomTrial
  if not active or active.status ~= 'active' then
    return nil
  end
  local layout = C.layout(g)
  local trial = layout and find(layout.trials, active.id)
  local room = trial and find(layout.chambers, trial.chamber)
  return room and room.fire
end
-- Presentation receives authored identity and authoritative encounter clocks,
-- not a renderer-owned timer which can restart on camera changes or replay.
function C.ritual(g, state, out)
  local active = state.roomTrial
  local layout = active and C.layout(g)
  for _, pad in ipairs(layout and layout.pads or {}) do
    if pad.trial == active.id and pad.altar then
      out.summoningSeal = pad.altar
      out.summoningStarted, out.summoningFinished = active.started, active.finished
      out.summoningStatus = active.status
      return
    end
  end
end
function C.forCreature(g, kind)
  local layout = C.layout(g)
  for _, trial in ipairs(layout and layout.trials or {}) do
    if trial.creature == kind then
      return trial.id
    end
  end
end
function C.start(field, g, id, count)
  local layout = C.layout(g)
  local trial = layout and find(layout.trials, id)
  local room = trial and find(layout.chambers, trial.chamber)
  count = count or 1
  -- Validate before resetting anything. The same API can be used by pads,
  -- catalogue commands and later authoring tools, without partial mutations.
  if
    not g.testField
    or not room
    or type(count) ~= 'number'
    or count % 1 ~= 0
    or count < 1
    or count > math.min(#room.slots, field.limit)
  then
    return false
  end
  C.validate(g)
  local elapsed = g.elapsed
  field.reset(g)
  g.elapsed = elapsed -- trial time is separate; walking between rooms is continuous
  local p = Roles.controlled(g)
  p.x, p.z, p.yaw, p.pitch = room.entry.x, room.entry.z, room.entry.yaw, 0
  g.testField.selected, g.testField.frozen = trial.creature, false
  -- Entering a live fight is not an invulnerable atlas inspection. The
  -- explicit GOD MODE tool can still be enabled after starting the trial.
  g.testField.invincible = false
  p.armor = K.armor
  g.testField.roomTrial =
    { id = id, count = count, actors = {}, status = 'active', started = g.elapsed }
  for i = 1, count do
    local spot = room.slots[i]
    local gate = Spawner.gate(trial.creature, spot.x, spot.z)
    gate.fieldKind, gate.roomTrial = trial.creature, id
    g.run.pending[#g.run.pending + 1] = gate
    Signal(g, 'PortalOpened', { gate = gate })
  end
  -- Use the lower existing context field, not a new central announcement.
  g.view.messageTimer = 0
  field.close(g)
  return true
end
function C.arrived(g, e, gate)
  local trial = g.testField and g.testField.roomTrial
  if trial and gate.roomTrial == trial.id then
    trial.actors[#trial.actors + 1] = e.id
    local definition = find(C.layout(g).trials, trial.id)
    if definition.readyDelay ~= nil then
      e.attack = definition.readyDelay
    end
  end
end
function C.update(g)
  local trial = g.testField and g.testField.roomTrial
  if not trial or trial.status ~= 'active' or #trial.actors < trial.count then
    return
  end
  for _, id in ipairs(trial.actors) do
    local body = Pools.get(g, id)
    if body and body.hp > 0 then
      return
    end
  end
  trial.status, trial.finished = 'complete', g.elapsed
end
function C.failed(g)
  local trial = g.testField and g.testField.roomTrial
  if trial and trial.status == 'active' then
    trial.status, trial.finished = 'failed', g.elapsed
  end
end
function C.context(g)
  local trial = g.testField and g.testField.roomTrial
  if trial then
    local definition = find(C.layout(g).trials, trial.id)
    return Text.get(trial.status == 'complete' and 'field_room_complete' or 'field_room_active', {
      name = Text.get(A.get(definition.creature).name),
    })
  end
end
return C

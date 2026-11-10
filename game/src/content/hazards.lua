-- The kinds of marked ground. A kind is three entries: this one (its default
-- volume and the state it keeps), what it does (enemies/hazards.lua) and how it looks
-- (render/hazard_kinds.lua). A session refuses a kind missing from any of them. Where it
-- is heard from (audio/field_voices.lua: V.points) and what its release leaves on the
-- floor (feedback/rite_feedback.lua: Feedback.bursts) are optional entries of its own.
--
-- What a kind keeps on its mark beyond what every mark has (session/components.lua: hazard)
-- it declares here (PLAN Z7): state = { field = { desc = meaning, smooth = how the image
-- blends it } }, smooth as a component declares it. A kind that changes the shape of its
-- state declares version (1 when absent) and migrations[v], which bring a mark of version
-- v to v + 1; a save records the version of every kind that has one (session/world.lua).
local Registry = require('src.core.registry')
local smooths = { linear = true, clock = true }
local Kinds = Registry:new('hazard kinds', function(kind, id)
  assert(type(kind.volume) == 'string', 'hazard kinds: ' .. id .. ' needs a volume')
  for field, spec in pairs(kind.state or {}) do
    assert(
      type(field) == 'string'
        and type(spec) == 'table'
        and (spec.smooth == nil or smooths[spec.smooth]),
      'hazard kinds: ' .. id .. ' declares its state field ' .. tostring(field) .. ' badly'
    )
  end
  for v = 1, (kind.version or 1) - 1 do
    assert(
      kind.migrations and type(kind.migrations[v]) == 'function',
      'hazard kinds: ' .. id .. ' has no migration from state version ' .. v
    )
  end
end)
Kinds.default = 'pool'
-- What a deposit's pool keeps: its family, the eruption bound to a windup, the last contact.
Kinds:register('pool', {
  volume = 'pool',
  state = {
    garden = { desc = 'owned deposit family counted against its capacity' },
    harvest = { desc = 'pending eruption warning bound to the owner windup' },
    erupting = { desc = 'a consumed deposit in its final brief contact' },
  },
})
-- A bolt marked in a windup: it waits for the cast and falls once.
Kinds:register('lightning', {
  volume = 'lightning',
  state = {
    damage = { desc = 'its blow when it carries no packet' },
    waitForCast = { desc = 'it falls only when the windup is cast' },
    cancelled = { desc = 'the cast broke: it is gone' },
    justReleased = { desc = 'released in this step, after movement' },
    struck = { desc = 'it has fallen' },
  },
})
-- A ring that grows from the body.
Kinds:register('wave', {
  volume = 'wave',
  state = {
    reach = { desc = 'where a wave dies out (m)' },
    spread = { desc = 'how fast a wave grows (m/s)' },
    width = { desc = 'depth of a wave or full width of a floor tear (m)' },
    hits = { desc = 'ids of the bodies already struck' },
  },
})
-- A ray turning about its origin.
Kinds:register('sweepline', {
  volume = 'beam',
  state = {
    width = { desc = 'depth of a wave or full width of a floor tear (m)' },
    angle = { desc = 'where a sweeping line points (radians, not wrapped)', smooth = 'linear' },
    spin = { desc = 'how fast it turns (radians/s)' },
    hits = { desc = 'ids of the bodies already struck' },
  },
})
-- The room strikes; only the circle that wanders is safe.
Kinds:register('tempest', {
  volume = 'lightning',
  state = {
    angle = { desc = 'where the safe circle stands on its round (radians)', smooth = 'linear' },
    spin = { desc = 'how fast it goes round (radians/s)' },
    centerX = { desc = 'the place a safe circle wanders around' },
    centerZ = { desc = 'the place a safe circle wanders around' },
    orbit = { desc = 'how far from it (m)' },
  },
})
-- A schema check: nil when the id names a kind.
function Kinds.problem(id)
  if not Kinds:has(id) then
    return 'unknown hazard kind ' .. tostring(id)
  end
end
-- Every field a kind keeps, as the hazard component carries them all: two kinds that keep
-- a field of one name keep it alike.
function Kinds.fields()
  local fields, owners = {}, {}
  for id, kind in Kinds:each() do
    for field, spec in pairs(kind.state or {}) do
      local known = fields[field]
      assert(
        not known or known.smooth == spec.smooth,
        'hazard kinds: '
          .. id
          .. ' and '
          .. tostring(owners[field])
          .. ' blend '
          .. field
          .. ' apart'
      )
      fields[field], owners[field] = known or spec, owners[field] or id
    end
  end
  return fields
end
-- The version of every kind that has one (a save records them).
function Kinds.versions()
  local versions = {}
  for id, kind in Kinds:each() do
    if (kind.version or 1) > 1 then
      versions[id] = kind.version
    end
  end
  return versions
end
-- A mark from a save that recorded these versions, brought up to the version of its kind.
function Kinds.resume(h, versions)
  local id = h.kind or Kinds.default
  local kind = Kinds:find(id)
  if not kind then
    return
  end
  for v = versions and versions[id] or 1, (kind.version or 1) - 1 do
    kind.migrations[v](h)
  end
end
return Kinds

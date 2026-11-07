-- A displayed view is an explicit, serializable input observation, never a
-- renderer hook in the simulation. Only geometry is retained; health, armour,
-- rewards and world cover are resolved now. Static art is identified by keys.
local Ballistics = require('src.combat.ballistics')
local Anatomy = require('src.content.art.anatomy_regions')
local Masks = require('src.content.art.hit_masks')
local Surface = require('src.enemies.surface')
local Geometry = require('src.enemies.geometry')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Tuning = require('src.content.tuning')
local Weapons = require('src.content.weapons')
local BallisticPattern = require('src.content.ballistic_pattern')
local O = { maxAge = Tuning.observation.maxAge }
-- Angle (rad) added to the corridor against rounding at its edge.
local corridorSlack = 1e-6
local serial = 0
local surfaceKeys = {
  'x',
  'z',
  'baseY',
  'width',
  'height',
  'rx',
  'rz',
  'nx',
  'nz',
  'mirror',
  'lean',
  'alive',
  'atlas',
  'frame',
  'regions',
  'ability',
  'abilityFrame',
}
function O.copy(value)
  if type(value) ~= 'table' then
    return value
  end
  local out = {}
  for key, item in pairs(value) do
    out[key] = O.copy(item)
  end
  return out
end
-- Two scopes (plan v11 E4). The world's generation (a reset, a new map, the
-- application leaving play) ends every observation; an actor's (his teleport,
-- death, loss or gain of control, leave) ends only his.
function O.invalidate(g)
  O.session(g)
  g._observationGeneration = g._observationGeneration + 1
end
function O.invalidateActor(_, actor)
  if actor then
    actor.observationGeneration = (actor.observationGeneration or 0) + 1
  end
end
function O.session(g)
  if not g._observationSession then
    serial = serial + 1
    g._observationSession, g._observationGeneration = serial, 0
  end
  return g._observationSession
end
-- An observation of the view shown to a shooter (plan v11 E4): the drawn
-- sample shown, the live session owner, the shooter (default the controlled
-- knight of both). The origin and every body come from that one sample, seen
-- from that shooter's eye; it names him and his generation.
function O.capture(shown, owner, shooter)
  owner = owner or shown
  shooter = shooter or Roles.controlled(owner)
  -- The eye is the shooter as the sample shows him.
  local eye = Roles.controlled(shown)
  if shooter and eye and shooter.id ~= eye.id then
    eye = Pools.get(shown, shooter.id) or shooter
  end
  owner._observationSequence = (owner._observationSequence or 0) + 1
  local out = {
    version = 1,
    session = O.session(owner),
    generation = owner._observationGeneration,
    shooter = shooter and shooter.id,
    actorGeneration = shooter and shooter.observationGeneration or 0,
    time = owner.elapsed,
    sequence = owner._observationSequence,
    map = owner.world.mapId,
    origin = { Ballistics.origin(shown, eye) },
    bodies = {},
  }
  for _, enemy in ipairs(Pools.of(shown, 'enemies')) do
    if Ballistics.blocks(enemy) then
      local body = { id = enemy.id, kind = enemy.kind, x = enemy.x, z = enemy.z }
      if not Geometry.uses(enemy) then
        local surface = Surface.prepare(shown, enemy, nil, eye)
        body.surface = {}
        for _, key in ipairs(surfaceKeys) do
          body.surface[key] = surface[key]
        end
      else
        body.volumes = O.copy(Geometry.volumes(shown, enemy, eye))
      end
      out.bodies[#out.bodies + 1] = body
    end
  end
  return out
end
-- The corridor of a shot (plan v10 V5): every ray a weapon the knight
-- carries can fire leaves the observed origin within this half-angle of the
-- aim (its pellet pattern at its widest spread and glyph) and ends within
-- this range. The resolver meets nothing outside it, so a command keeps only
-- the bodies whose bounds reach into it.
local patternBound = 1
for _, v in ipairs(BallisticPattern) do
  patternBound = math.max(patternBound, math.abs(v[1]), math.abs(v[2]))
end
function O.corridor(g, shooter)
  local p = shooter or Roles.controlled(g)
  local widest, range = 0, 0
  for _, id in ipairs(p.loadout or {}) do
    local def = Weapons.get(id)
    local spread = def.fire.spread or 1
    local glyph = 1
    for _, mod in pairs(def.glyphs or {}) do
      glyph = math.max(glyph, mod.spread or 1)
    end
    widest = math.max(widest, spread * glyph)
    range = math.max(range, def.range or 0)
  end
  local h = math.tan(Tuning.pelletSpread * patternBound * widest)
  local v = math.tan(Tuning.pelletVerticalSpread * patternBound * widest)
  return math.atan(math.sqrt(h * h + v * v)), range
end
-- The bounding sphere (centre, radius) of an observed body's geometry.
local function bounds(body)
  local s = body.surface
  if s then
    local cell = (s.width + s.height * (1 + math.abs(s.lean))) / Masks.grid
    local across = s.width * 0.5 + s.height * math.abs(s.lean) + cell
    local up = s.height * 0.5 + cell
    return s.x, s.baseY + s.height * 0.5, s.z, math.sqrt(across * across + up * up)
  end
  local count, cx, cz, low, high = 0, 0, 0, math.huge, -math.huge
  for _, v in ipairs(body.volumes or {}) do
    count, cx, cz = count + 1, cx + v.x, cz + v.z
    low, high = math.min(low, v.bottom), math.max(high, v.top)
  end
  if count == 0 then
    return body.x, 0, body.z, 0
  end
  cx, cz = cx / count, cz / count
  local across = 0
  for _, v in ipairs(body.volumes) do
    across = math.max(across, math.sqrt((v.x - cx) ^ 2 + (v.z - cz) ^ 2) + v.radius)
  end
  local up = (high - low) * 0.5
  return cx, low + up, cz, math.sqrt(across * across + up * up)
end
-- Whether an observed body can lie in the corridor of a shot aimed at yaw,
-- pitch from origin (half-angle, range as O.corridor gives them).
function O.inCorridor(body, origin, yaw, pitch, half, range)
  local cx, cy, cz, r = bounds(body)
  local vx, vy, vz = cx - origin[1], cy - origin[2], cz - origin[3]
  local d = math.sqrt(vx * vx + vy * vy + vz * vz)
  if d <= r then
    return true
  end
  if d - r > range then
    return false
  end
  local fx, fy, fz = Ballistics.direction(yaw, pitch)
  local cosine = math.max(-1, math.min(1, (vx * fx + vy * fy + vz * fz) / d))
  return math.acos(cosine) <= half + math.asin(math.min(1, r / d)) + corridorSlack
end
-- The command of a shooter (default the controlled knight) from his
-- observation: his aim now, the bodies in his weapons' corridor.
function O.command(observation, g, shooter)
  shooter = shooter or Roles.controlled(g)
  local yaw, pitch = shooter.yaw, shooter.pitch
  local half, range = O.corridor(g, shooter)
  local kept = {}
  for key, value in pairs(observation) do
    if key ~= 'bodies' then
      kept[key] = O.copy(value)
    end
  end
  kept.bodies = {}
  for _, body in ipairs(observation.bodies) do
    if O.inCorridor(body, observation.origin, yaw, pitch, half, range) then
      kept.bodies[#kept.bodies + 1] = O.copy(body)
    end
  end
  return { observation = kept, yaw = yaw, pitch = pitch }
end
-- An actor's (default the controlled knight's) observation among those kept
-- by shooter.
function O.mine(g, store, actor)
  local shooter = actor or Roles.controlled(g)
  return store[shooter and shooter.id or false]
end
-- Valid for shooter (default the controlled knight): the same session,
-- world generation and map, his own observation of his own generation, and
-- not older than maxAge.
function O.valid(g, observation, shooter)
  shooter = shooter or Roles.controlled(g)
  return observation
    and observation.version == 1
    and observation.session == g._observationSession
    and observation.generation == g._observationGeneration
    and (observation.shooter == nil or (shooter and observation.shooter == shooter.id))
    and (observation.actorGeneration or 0) == (shooter and shooter.observationGeneration or 0)
    and observation.map == g.world.mapId
    and observation.time <= g.elapsed + 1e-8
    and g.elapsed - observation.time <= O.maxAge
end
function O.prepare(g, observation, shooter)
  assert(O.valid(g, observation, shooter), 'expired or foreign shot observation')
  local live, bodies = {}, {}
  for _, enemy in ipairs(Pools.of(g, 'enemies')) do
    live[enemy.id] = enemy
  end
  for _, body in ipairs(observation.bodies) do
    -- A disappeared body remains geometric cover for this observation, but a
    -- tombstone can never receive health, impulse, rewards or be resurrected.
    local enemy = live[body.id]
      or { id = body.id, kind = body.kind, hp = 0, x = body.x, z = body.z }
    local entry = { enemy = enemy, observed = true }
    if body.surface then
      local p = O.copy(body.surface)
      local group = p.ability and Anatomy.abilities[p.ability] or Anatomy.layouts[p.regions]
      local index = p.abilityFrame or p.frame
      p.parts = assert(group and group.frames[index], 'unknown observed anatomy').parts
      p.mask = (p.ability and Masks.abilities[p.ability] or Masks.layouts[p.atlas])[index]
      entry.surface = p
    else
      entry.volumes = O.copy(body.volumes)
    end
    bodies[#bodies + 1] = entry
  end
  return bodies
end
return O

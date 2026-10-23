-- A displayed view is an explicit, serializable input observation, never a
-- renderer hook in the simulation. Only geometry is retained; health, armour,
-- rewards and world cover are resolved now. Static art is identified by keys.
local B = require('src.combat.ballistics')
local Anatomy = require('src.content.art.anatomy_regions')
local Masks = require('src.content.art.hit_masks')
local Surface = require('src.enemies.surface')
local Geometry = require('src.enemies.geometry')
local O = { maxAge = require('src.content.tuning').observation.maxAge }
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
function O.invalidate(g)
  O.session(g)
  g._observationGeneration = g._observationGeneration + 1
end
function O.session(g)
  if not g._observationSession then
    serial = serial + 1
    g._observationSession, g._observationGeneration = serial, 0
  end
  return g._observationSession
end
function O.capture(shown, owner)
  owner = owner or shown
  owner._observationSequence = (owner._observationSequence or 0) + 1
  local out = {
    version = 1,
    session = O.session(owner),
    generation = owner._observationGeneration,
    time = owner.elapsed,
    sequence = owner._observationSequence,
    map = owner.world.mapId,
    origin = { B.origin(shown) },
    bodies = {},
  }
  for _, enemy in ipairs(shown.enemies) do
    if B.blocks(enemy) then
      local body = { id = enemy.id, kind = enemy.kind, x = enemy.x, z = enemy.z }
      if not Geometry.uses(enemy) then
        local surface = Surface.prepare(shown, enemy)
        body.surface = {}
        for _, key in ipairs(surfaceKeys) do
          body.surface[key] = surface[key]
        end
      else
        body.volumes = O.copy(Geometry.volumes(shown, enemy))
      end
      out.bodies[#out.bodies + 1] = body
    end
  end
  return out
end
function O.command(observation, g)
  return {
    observation = O.copy(observation),
    yaw = g.player.yaw,
    pitch = g.player.pitch,
  }
end
function O.valid(g, observation)
  return observation
    and observation.version == 1
    and observation.session == g._observationSession
    and observation.generation == g._observationGeneration
    and observation.map == g.world.mapId
    and observation.time <= g.elapsed + 1e-8
    and g.elapsed - observation.time <= O.maxAge
end
function O.prepare(g, observation)
  assert(O.valid(g, observation), 'expired or foreign shot observation')
  local live, bodies = {}, {}
  for _, enemy in ipairs(g.enemies) do
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

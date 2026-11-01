-- Source-art ability anchors and authored timing; immutable content, no GPU or hitboxes.
local Poses = require('src.content.art.poses')
local Frames = require('src.content.art.ability_frames')
local Registry = require('src.core.registry')
local AbilityArt = {
  leap = {
    sampler = 'leap',
    anatomy = 'src.content.art.anatomy.leap',
    scale = 1,
    -- The base thrall atlas is matte ochre, not the supplement's bright orange.
    -- RGB grouping at atlas-like detail; exact source alpha/geometry retained.
    pigment = {
      grid = { 192, 256 },
      tone = { 0.64, 0.92, 0.72 },
      lift = { 0.075, 0.045, 0.024 },
      -- Red-dominance gate, strength, target R/G. Keep ochre skin unchanged.
      red = { 0.45, 0.66, 0.90, 2.15 },
    },
    -- Source-pixel skull centre, virtual ground line, and ribcage centre.
    -- Flight poses retain a virtual ground under their tucked legs.
    anchors = {
      { 280, 207, 420, 209, 269 },
      { 662, 212, 420, 607, 282 },
      { 1046, 188, 446, 979, 247 },
      { 1420, 215, 467, 1343, 259 },
      { 282, 695, 947, 216, 749 },
      { 654, 670, 906, 593, 747 },
      { 1045, 670, 907, 985, 746 },
      { 1417, 656, 908, 1367, 737 },
    },
    actions = { 'crouch', 'gather', 'launch', 'flight', 'descend', 'land', 'rise', 'ready' },
  },
  evade = {
    sampler = 'evade',
    anatomy = 'src.content.art.anatomy.evade',
    scale = 1,
    -- A gentler match for the owl: keep the pale face readable, quiet the sheen.
    pigment = { grid = { 192, 256 }, tone = { 0.89, 0.96, 0.65 }, lift = { 0.035, 0.022, 0.015 } },
    anchors = {
      { 214, 214, 430, 221, 284 },
      { 626, 211, 431, 597, 281 },
      { 957, 216, 429, 964, 276 },
      { 1276, 217, 423, 1309, 278 },
      { 215, 683, 884, 216, 744 },
      { 573, 664, 881, 576, 740 },
      { 957, 664, 882, 956, 742 },
      { 1342, 663, 881, 1343, 741 },
    },
    actions = { 'brace', 'push', 'sweep', 'coast', 'catch', 'recover', 'ready', 'ready' },
  },
}

for key, entry in pairs(AbilityArt) do
  entry.path, entry.columns, entry.rows = Frames[key].path, Frames[key].columns, Frames[key].rows
  entry.frames, entry.feet = Frames[key].frames, Frames[key].feet
end
-- The one sequence catalogue. Behaviour names and anatomy module paths are
-- data; content never imports a sampler, renderer or GPU object.
local registry = Registry:new('ability artwork', function(entry, id)
  local prefix = 'ability artwork ' .. tostring(id) .. ': '
  assert(type(entry.path) == 'string' and entry.path ~= '', prefix .. 'missing atlas path')
  assert(type(entry.sampler) == 'string' and entry.sampler ~= '', prefix .. 'missing sampler id')
  assert(
    type(entry.anatomy) == 'string' or type(entry.anatomy) == 'table',
    prefix .. 'missing anatomy'
  )
  assert(type(entry.frames) == 'table' and #entry.frames > 0, prefix .. 'missing frames')
  assert(type(entry.feet) == 'table' and #entry.feet == #entry.frames, prefix .. 'feet/frame count')
  assert(
    type(entry.actions) == 'table' and #entry.actions == #entry.frames,
    prefix .. 'action/frame count'
  )
end)
for _, key in ipairs({ 'leap', 'evade' }) do
  registry:register(key, AbilityArt[key])
end
AbilityArt.entries = registry.entries
function AbilityArt.each()
  return registry:each()
end
function AbilityArt.get(id)
  return registry:get(id)
end
function AbilityArt.register(id, entry)
  assert(AbilityArt[id] == nil, 'ability artwork id already exists: ' .. tostring(id))
  registry:register(id, entry)
  AbilityArt[id] = entry
  return entry
end
function AbilityArt.unregister(id)
  local entry = registry:unregister(id)
  if entry then
    AbilityArt[id] = nil
  end
  return entry
end
AbilityArt.timing = {
  arrival = 0.6,
  coil = 0.52,
  launch = 0.16,
  land = 0.28,
  rise = 0.76,
  minimumFlight = 0.001,
  evade = { 0.08, 0.20, 0.43, 0.64, 0.78, 0.90, 0.96 },
}
-- The thresholds are boundaries of action phases (0..1): the same check as
-- the bounds of a sheet's named poses (content/art/poses.lua, plan v11 E1).
-- AbilityPose (enemies/ability_pose.lua) stays the one mechanism that reads them.
function AbilityArt.timingProblems(timing)
  local out = {}
  for _, list in ipairs({ { timing.coil }, { timing.launch }, { timing.land, timing.rise } }) do
    for _, problem in ipairs(Poses.boundsProblems(list, 0, 1)) do
      out[#out + 1] = problem
    end
  end
  for _, problem in ipairs(Poses.boundsProblems(timing.evade or {}, 0, 1)) do
    out[#out + 1] = 'evade ' .. problem
  end
  return out
end
assert(
  #AbilityArt.timingProblems(AbilityArt.timing) == 0,
  'ability timing: ' .. table.concat(AbilityArt.timingProblems(AbilityArt.timing), '; ')
)
return AbilityArt

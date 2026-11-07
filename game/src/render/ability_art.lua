local ArtContract = require('src.enemies.art_contract')
local Context = require('src.session.context')
-- GPU handles for authored ability animations. Placement is owned by enemies.pose;
-- changing a hit shape cannot move, scale or otherwise repaint an ability.
local AbilitySequences = require('src.content.ability_art')
local AbilityPose = require('src.enemies.ability_pose')
local Pose = require('src.enemies.pose')
local AbilityArt = { entries = AbilitySequences.entries }
AbilityArt.select = AbilityPose.select
function AbilityArt.load(resources)
  local loaded = {}
  for key, entry in AbilitySequences.each() do
    local problems = ArtContract.sequenceProblems(key)
    assert(#problems == 0, table.concat(problems, '\n'))
    local image = resources and resources:image(entry.path) or love.graphics.newImage(entry.path)
    image:setFilter('nearest', 'nearest')
    loaded[key] = { image = image, feet = entry.feet, frames = entry.frames }
  end
  return loaded
end
-- Compatibility adapter for source-art QA; no geometry or numeric shape index.
function AbilityArt.resolve(loaded, g, e)
  local p = Pose.sample(g, e, nil, Context.viewer(g))
  if not p.ability then
    return nil
  end
  local entry = assert(loaded[p.ability], 'ability artwork not loaded: ' .. p.ability)
  return entry.image, p.region, p.sx, p.sy, p.baseY, p.mirror, p.shift
end
return AbilityArt

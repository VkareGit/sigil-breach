-- GPU handles for authored ability animations. Placement is owned by enemies.pose;
-- changing a hit shape cannot move, scale or otherwise repaint an ability.
local Metadata = require('src.content.ability_art')
local AbilityPose = require('src.enemies.ability_pose')
local Pose = require('src.enemies.pose')
local AbilityArt = { entries = Metadata.entries }
AbilityArt.select = AbilityPose.select
function AbilityArt.load()
  local loaded = {}
  for key, entry in Metadata.each() do
    local problems = require('src.enemies.art_contract').sequenceProblems(key)
    assert(#problems == 0, table.concat(problems, '\n'))
    local image = love.graphics.newImage(entry.path)
    image:setFilter('nearest', 'nearest')
    loaded[key] = { image = image, feet = entry.feet, frames = entry.frames }
  end
  return loaded
end
-- Compatibility adapter for source-art QA; no geometry or numeric shape index.
function AbilityArt.resolve(loaded, g, e)
  local p = Pose.sample(g, e)
  if not p.ability then
    return nil
  end
  local entry = assert(loaded[p.ability], 'ability artwork not loaded: ' .. p.ability)
  return entry.image, p.region, p.sx, p.sy, p.baseY, p.mirror, p.shift
end
return AbilityArt

-- Allocate GPU images for the shared authored sprite catalogue. Frame placement
-- belongs to content, so loading or releasing textures cannot change collision.
local EnemyArt = require('src.content.enemy_art')
local Schema = require('src.core.schema')
local FrescoEnemies = { kinds = EnemyArt.kinds, entries = EnemyArt.entries }
FrescoEnemies.frameCount = EnemyArt.frameCount
function FrescoEnemies.load(kind)
  local entry = assert(EnemyArt.entries[kind], 'Unknown fresco enemy: ' .. tostring(kind))
  local layout = assert(EnemyArt.layouts[kind])
  local image = love.graphics.newImage(entry.path)
  image:setFilter('nearest', 'nearest')
  local images, mirrors, supplements, sources = {}, {}, {}, { [entry.path] = image }
  for _, replacement in ipairs(entry.replacements or {}) do
    local painted = love.graphics.newImage(replacement.path, { mipmaps = true })
    painted:setFilter('linear', 'linear')
    painted:setMipmapFilter('linear')
    supplements[#supplements + 1] = painted
    sources[replacement.path] = painted
  end
  for index, frame in ipairs(layout.frames) do
    if frame.sourcePath ~= entry.path then
      images[index] = assert(sources[frame.sourcePath])
    end
  end
  return image, Schema.copy(layout.feet), Schema.copy(layout.frames), images, mirrors, supplements
end
function FrescoEnemies.loadAll(renderer)
  renderer.animations = renderer.animations or {}
  renderer.feet = renderer.feet or {}
  renderer.frames = renderer.frames or {}
  renderer.frameImages = renderer.frameImages or {}
  renderer.frameMirrors = renderer.frameMirrors or {}
  renderer.frescoEnemySupplements = {}
  for _, kind in ipairs(FrescoEnemies.kinds) do
    local image, feet, frames, images, mirrors, supplements = FrescoEnemies.load(kind)
    renderer.animations[kind], renderer.feet[kind], renderer.frames[kind] = image, feet, frames
    renderer.frameImages[kind], renderer.frameMirrors[kind] = images, mirrors
    renderer.frescoEnemySupplements[kind] = supplements
  end
end
return FrescoEnemies

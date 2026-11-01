-- Allocate GPU images for the shared authored sprite catalogue. Frame placement
-- belongs to content, so loading or releasing textures cannot change collision.
local EnemyArt = require('src.content.enemy_art')
local Schema = require('src.core.schema')
local FrescoEnemies = { kinds = EnemyArt.kinds, entries = EnemyArt.entries }
FrescoEnemies.frameCount = EnemyArt.frameCount
function FrescoEnemies.load(kind, resources)
  local entry = assert(EnemyArt.entries[kind], 'Unknown fresco enemy: ' .. tostring(kind))
  local layout = assert(EnemyArt.layouts[kind])
  local image = resources and resources:image(entry.path) or love.graphics.newImage(entry.path)
  image:setFilter('nearest', 'nearest')
  local images, mirrors, supplements, sources = {}, {}, {}, { [entry.path] = image }
  for _, replacement in ipairs(entry.replacements or {}) do
    local painted = resources
        and resources:image(
          replacement.path,
          { mipmaps = true, filter = 'linear', mipmapFilter = 'linear' }
        )
      or love.graphics.newImage(replacement.path, { mipmaps = true })
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
-- One atlas into the renderer (an atlas registered after it was built, a
-- mod, a test: content/art/atlases.lua).
function FrescoEnemies.add(renderer, kind)
  local image, feet, frames, images, mirrors, supplements =
    FrescoEnemies.load(kind, renderer.resources)
  renderer.animations[kind], renderer.feet[kind], renderer.frames[kind] = image, feet, frames
  renderer.frameImages[kind], renderer.frameMirrors[kind] = images, mirrors
  renderer.frescoEnemySupplements[kind] = supplements
end
-- An atlas enters the renderer the first time something asks for it: the loading page asks
-- for the creatures of the world it prepares, so a species not on this map costs nothing.
function FrescoEnemies.onDemand(renderer)
  renderer.frescoEnemySupplements = {}
  local function demand(t, kind)
    if EnemyArt.entries[kind] then
      FrescoEnemies.add(renderer, kind)
      return rawget(t, kind)
    end
  end
  for _, field in ipairs({ 'animations', 'feet', 'frames', 'frameImages', 'frameMirrors' }) do
    renderer[field] = setmetatable(renderer[field] or {}, { __index = demand })
  end
end
return FrescoEnemies

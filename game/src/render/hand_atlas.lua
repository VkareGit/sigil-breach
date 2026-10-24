-- GPU realization of validated CPU hand-atlas metadata. Frame count, crop,
-- registration and image size come from the entry, never from a gun name.
local Resources = require('src.render.resources')
local Atlas = {}
function Atlas.load(entry, checkpoint)
  local resources = Resources.new('hand atlas ' .. entry.path, checkpoint)
  local image = resources:image(entry.path)
  local width, height = image:getDimensions()
  if width ~= entry.width or height ~= entry.height then
    resources:release()
    error('Hand atlas dimensions differ from metadata: ' .. entry.path)
  end
  local loaded = { image = image, resources = resources, quads = {}, origins = {}, centers = {} }
  for index, frame in ipairs(entry.frames) do
    local rect = frame.rect
    loaded.quads[index] =
      resources:own(love.graphics.newQuad(rect[1], rect[2], rect[3], rect[4], width, height))
    loaded.centers[index], loaded.origins[index] = frame.grip[1], frame.grip[2]
  end
  resources.checkpoint = nil
  return loaded
end
function Atlas.release(loaded)
  loaded.resources:release()
end
return Atlas

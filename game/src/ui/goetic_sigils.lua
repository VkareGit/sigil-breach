-- Historical seals, not generated pseudo-writing. See assets/art/sigils/SOURCES.txt.
-- PNG files are kept byte-for-byte as downloaded; the shader only displays their ink.
local S = { images = {}, order = require('src.content.occult_catalog').seals }
local Resources = require('src.render.resources')
local Seals = require('src.content.goetic_seals')
S.entries, S.edition, S.primary = Seals.entries, Seals.edition, Seals.primary

function S.init()
  if S.shader then
    return S
  end
  S.resources = Resources.new('application historical seals')
  for _, key in ipairs(S.order) do
    local img = S.resources:image('assets/art/sigils/' .. S.entries[key].file)
    S.images[key] = img
  end
  S.shader = S.resources:own(love.graphics.newShader([[
  vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
   vec4 sample = Texel(image, uv);
   float ink = 1.0 - min(sample.r, min(sample.g, sample.b));
   return vec4(color.rgb, color.a * sample.a * ink);
  }
 ]]))
  return S
end
function S.release()
  if S.resources then
    S.resources:release()
  end
  S.resources, S.shader, S.images = nil, nil, {}
end

function S.image(name)
  local key = tostring(name or ''):lower()
  if not S.entries[key] then
    return nil
  end
  S.init()
  return S.images[key]
end

-- x/y are the top-left corner; size is the square's side in current canvas units.
-- The original orientation and all strokes remain intact. No generic fallback seal.
function S.draw(name, x, y, size, color, alpha)
  local img = S.image(name)
  if not img or not size or size <= 0 then
    return false
  end
  color = color or { 1, 1, 1 }
  love.graphics.push('all')
  love.graphics.setShader(S.shader)
  love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
  love.graphics.draw(img, x, y, 0, size / img:getWidth(), size / img:getHeight())
  love.graphics.pop()
  return true
end
return S

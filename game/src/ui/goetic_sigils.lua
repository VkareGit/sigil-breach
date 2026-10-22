-- Historical seals, not generated pseudo-writing. See assets/art/sigils/SOURCES.txt.
-- PNG files are kept byte-for-byte as downloaded; the shader only displays their ink.
local S = { images = {}, order = { 'asmoday', 'stolas', 'buer' } }
local commons = 'https://commons.wikimedia.org/wiki/File:'
S.entries = {
  asmoday = {
    name = 'ASMODAY',
    number = 32,
    file = 'asmoday-1904.png',
    printedPages = '20-21',
    plateScan = 26,
    figure = 37,
    source = commons .. '32-Asmoday_seal.png',
  },
  stolas = {
    name = 'STOLAS',
    number = 36,
    file = 'stolas-1904.png',
    printedPages = '22',
    plateScan = 26,
    figure = 41,
    source = commons .. '36-Stolas_seal.png',
  },
  buer = {
    name = 'BUER',
    number = 10,
    file = 'buer-1904.png',
    printedPages = '15',
    plateScan = 6,
    figure = 11,
    source = commons .. '10-Buer_seal.png',
  },
}
S.edition = 'The Book of the Goetia of Solomon the King, Mathers / Crowley, 1904'
S.primary =
  'https://commons.wikimedia.org/wiki/File:The_Book_of_the_Goetia_(Mathers-Crowley,_1904).djvu'

function S.init()
  if S.shader then
    return S
  end
  for _, key in ipairs(S.order) do
    local img = love.graphics.newImage('assets/art/sigils/' .. S.entries[key].file)
    img:setFilter('nearest', 'nearest')
    S.images[key] = img
  end
  S.shader = love.graphics.newShader([[
  vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
   vec4 sample = Texel(image, uv);
   float ink = 1.0 - min(sample.r, min(sample.g, sample.b));
   return vec4(color.rgb, color.a * sample.a * ink);
  }
 ]])
  return S
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

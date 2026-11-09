-- Individually illustrated fresco numerals, assembled without a system font.
local Ink = require('src.ui.ink')
local N = { order = '0123456789%/' }
local NumeralLook = require('src.content.ui_look').numerals
local Resources = require('src.render.resources')
function N.init(checkpoint)
  if N.image then
    return N
  end
  local meta = require('assets.fonts.painted-v16.numerals')
  N.path = meta.image
  N.inkStyle = 'flat-painted'
  N.resources = Resources.new('UI painted numbers', checkpoint)
  N.image = N.resources:image(meta.image)
  N.glyphs = {}
  local w, h = N.image:getDimensions()
  for i = 1, #N.order do
    local char = N.order:sub(i, i)
    local g = assert(meta.glyphs[char], 'Missing illustrated numeral ' .. char)
    N.glyphs[char] =
      { q = N.resources:own(love.graphics.newQuad(g.x, g.y, g.w, g.h, w, h)), w = g.w, h = g.h }
  end
  N.resources.checkpoint = nil
  return N
end
function N.release()
  if N.resources then
    N.resources:release()
  end
  N.resources, N.image, N.glyphs = nil, nil, nil
end
function N.measure(value, height)
  N.init()
  local s = tostring(value)
  local width = 0
  for i = 1, #s do
    local g = assert(N.glyphs[s:sub(i, i)], 'Unsupported illustrated numeral: ' .. s)
    width = width + g.w / g.h * height + (i > 1 and height * NumeralLook.gap or 0)
  end
  return width
end
-- inkOnLime=false keeps the painted glyph's own light pigment for values
-- floating over the scene instead of a lime writing ground.
function N.draw(value, cx, y, maxW, maxH, color, inkOnLime)
  N.init()
  local s = tostring(value)
  local natural = N.measure(s, maxH)
  local height = maxH * math.min(1, maxW / math.max(natural, 1))
  local width = N.measure(s, height)
  local x = math.floor(cx - width / 2 + 0.5)
  local px = x
  local r, g, b, a = love.graphics.getColor()
  color = color or { 1, 1, 1 }
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
  local previous = love.graphics.getShader()
  love.graphics.setShader(Ink.ink(inkOnLime ~= false))
  for i = 1, #s do
    local glyph = N.glyphs[s:sub(i, i)]
    local scale = height / glyph.h
    love.graphics.draw(N.image, glyph.q, px, y, 0, scale, scale)
    px = px + glyph.w * scale + height * NumeralLook.gap
  end
  love.graphics.setShader(previous)
  love.graphics.setColor(r, g, b, a)
  return x, y, width, height
end
return N

-- Complete illustrated inscriptions. Crop their ink, never stretch letterforms.
local T = {
  names = {
    'sigil',
    'breach',
    'limbo',
    'merchant',
    'circles',
    'settings',
    'new_run',
    'interrupted',
  },
}
function T.init()
  if T.image then
    return T
  end
  local meta = require('assets.fonts.painted-v16.titles')
  T.path = meta.image
  T.inkStyle = 'flat-painted'
  T.image = love.graphics.newImage(meta.image)
  T.image:setFilter('nearest', 'nearest')
  T.entries = {}
  local w, h = T.image:getDimensions()
  for _, name in ipairs(T.names) do
    local e = assert(meta.entries[name], 'Missing painted inscription: ' .. name)
    T.entries[name] = { q = love.graphics.newQuad(e.x, e.y, e.w, e.h, w, h), w = e.w, h = e.h }
  end
  return T
end
function T.draw(name, x, y, maxW, maxH, alpha, lightGround)
  T.init()
  local e = assert(T.entries[name], 'Unknown painted inscription: ' .. tostring(name))
  local s = math.min(maxW / e.w, maxH / e.h)
  local w, h = e.w * s, e.h * s
  x = math.floor(x + (maxW - w) * 0.5 + 0.5)
  y = math.floor(y + (maxH - h) * 0.5 + 0.5)
  local r, g, b, a = love.graphics.getColor()
  love.graphics.setColor(0.89, 0.84, 0.73, alpha or 1)
  local previous = love.graphics.getShader()
  love.graphics.setShader(require('src.ui.ink').ink(lightGround))
  love.graphics.draw(T.image, e.q, x, y, 0, s, s)
  love.graphics.setShader(previous)
  love.graphics.setColor(r, g, b, a)
  return x, y, w, h
end
return T

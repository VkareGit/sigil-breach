-- Complete illustrated inscriptions. Crop their ink, never stretch letterforms.
-- The registry of paintings (names): an inscription whose name has no
-- painting in the atlas is written in glyphs instead (ui/skin.lua:
-- inscription; its words: content/text.lua, inscription_<name>).
local TitleInk = require('src.content.ui_look').titleInk
local Ink = require('src.ui.ink')
local Resources = require('src.render.resources')
local T = {
  names = {
    'sigil',
    'breach',
    'merchant',
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
  T.resources = Resources.new('UI painted titles')
  T.image = T.resources:image(meta.image)
  T.entries = {}
  local w, h = T.image:getDimensions()
  for _, name in ipairs(T.names) do
    local e = meta.entries[name]
    if e then
      T.entries[name] =
        { q = T.resources:own(love.graphics.newQuad(e.x, e.y, e.w, e.h, w, h)), w = e.w, h = e.h }
    end
  end
  return T
end
-- Whether the atlas holds a painting of the inscription name.
function T.has(name)
  T.init()
  return T.entries[name] ~= nil
end
function T.release()
  if T.resources then
    T.resources:release()
  end
  T.resources, T.image, T.entries = nil, nil, nil
end
function T.draw(name, x, y, maxW, maxH, alpha, lightGround)
  T.init()
  local e = assert(T.entries[name], 'Unknown painted inscription: ' .. tostring(name))
  local s = math.min(maxW / e.w, maxH / e.h)
  local w, h = e.w * s, e.h * s
  x = math.floor(x + (maxW - w) * 0.5 + 0.5)
  y = math.floor(y + (maxH - h) * 0.5 + 0.5)
  local r, g, b, a = love.graphics.getColor()
  love.graphics.setColor(TitleInk[1], TitleInk[2], TitleInk[3], alpha or 1)
  local previous = love.graphics.getShader()
  love.graphics.setShader(Ink.ink(lightGround))
  love.graphics.draw(T.image, e.q, x, y, 0, s, s)
  love.graphics.setShader(previous)
  love.graphics.setColor(r, g, b, a)
  return x, y, w, h
end
return T

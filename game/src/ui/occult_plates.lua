-- Historical plate kept unchanged; only the original figure regions are displayed.
local GoeticSigils = require('src.ui.goetic_sigils')
local Palette = require('src.ui.palette')
local Resources = require('src.render.resources')
local P = { order = { 'saturn_1', 'saturn_2', 'saturn_3' } }
local Plates = require('src.content.occult_plates')
P.entries, P.path = Plates.entries, Plates.path
function P.init()
  if P.image then
    return P
  end
  P.resources = Resources.new('UI historical plates')
  P.image = P.resources:image(P.path)
  local w, h = P.image:getDimensions()
  -- The quads live beside the entries: the entries are sealed content.
  P.quads = {}
  for key, entry in pairs(P.entries) do
    local r = entry.rect
    P.quads[key] = P.resources:own(love.graphics.newQuad(r[1], r[2], r[3], r[4], w, h))
  end
  P.shader = GoeticSigils.init().shader
  return P
end
function P.release()
  if P.resources then
    P.resources:release()
  end
  P.resources, P.image, P.shader, P.quads = nil, nil, nil, nil
end
function P.draw(name, x, y, w, h, color)
  local e = P.entries[name]
  if not e then
    return false
  end
  P.init()
  local scale = math.min(w / e.rect[3], h / e.rect[4])
  local dw, dh = e.rect[3] * scale, e.rect[4] * scale
  x = x + (w - dw) / 2
  y = y + (h - dh) / 2
  color = color or Palette.gilt
  love.graphics.push('all')
  love.graphics.setShader(P.shader)
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
  love.graphics.draw(P.image, P.quads[name], x, y, 0, scale, scale)
  love.graphics.pop()
  return x, y, dw, dh
end
return P

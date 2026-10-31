-- Writes each hall surface's layout template. The painter receives it as a
-- reference, so what is painted lands where the relief is built.
--   lovec tools/art/chapel_hall <output directory>
package.path = '../../../game/?.lua;' .. package.path
local Hall
local STONE, RED, DARK, IVORY, PALE = { 150, 128, 96 }, { 120, 34, 26 }, { 62, 46, 40 }, { 240, 225, 190 }, { 190, 170, 130 }
local KEY = { 255, 0, 255 }
local SIZES = {
  south = { 1536, 1024 },
  chancel = { 1254, 1254 },
  door_wall = { 1254, 1254 },
  nave_chancel = { 1254, 1254 },
  nave_south = { 1254, 1254 },
}
local function classify(surface, u, v, line)
  local colour = STONE
  for _, f in ipairs(surface.features) do
    if f.kind == 'dado' and v < f.top and (not f.to or u < f.to) then
      colour = RED
    elseif f.kind == 'panel' or f.kind == 'niche' then
      local s = Hall.inside(f, u, v)
      if s > 0 then
        colour = s < line and IVORY or (f.kind == 'panel' and RED or DARK)
      end
    elseif f.kind == 'colonnette' and math.abs(u - f.cx) < f.radius and v < f.top and v > f.sill then
      colour = PALE
    end
  end
  for _, f in ipairs(surface.features) do
    if f.kind == 'opening' and Hall.inside(f, u, v) > 0 then
      colour = KEY
    elseif f.kind == 'ruin' and v > Hall.edgeAt(f.edge, u) then
      colour = KEY
    end
  end
  return colour
end
function love.load(arguments)
  local output = arguments[1]
  local file = assert(io.open('../../../game/src/content/art/chapel_hall.lua', 'r'))
  Hall = assert(load(file:read('*a')))()
  file:close()
  for name, surface in pairs(Hall.surfaces) do
    if #surface.features > 0 then
      local size = SIZES[name] or { 1024, 1536 }
      local w, h = size[1], size[2]
      local data = love.image.newImageData(w, h)
      data:mapPixel(function(x, y)
        local u, v = (x + 0.5) / w * surface.width, (1 - (y + 0.5) / h) * surface.height
        local c = classify(surface, u, v, 0.06)
        return c[1] / 255, c[2] / 255, c[3] / 255, 1
      end)
      local png = data:encode('png')
      local out = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
      out:write(png:getString())
      out:close()
      print(name, w, h)
    end
  end
  love.event.quit(0)
end

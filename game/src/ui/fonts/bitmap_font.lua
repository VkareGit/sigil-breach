-- Every glyph comes from its individually illustrated manuscript PNG source.
local B = {}
local F = {}
F.__index = F
local utf8 = require('utf8')
local Resources = require('src.render.resources')
local lg = love.graphics
-- Clocks and counters produce new strings throughout a session. Keep only a
-- bounded working set, including a byte limit so long captions cannot grow it.
local CACHE_LIMIT, CACHE_TEXT_LIMIT = 256, 256 -- constant: a working set, not a look
-- The code points the walk treats apart.
local NEWLINE, TAB, SPACE, UNKNOWN = ('\n'):byte(), ('\t'):byte(), (' '):byte(), ('?'):byte()
function B.new(meta, image, resources)
  local self = setmetatable({
    meta = meta,
    image = image,
    resources = resources or Resources.new('bitmap glyphs'),
    glyphs = {},
    inkCache = {},
    inkCacheKeys = {},
    inkCacheNext = 1,
  }, F)
  local w, h = image:getDimensions()
  for cp, g in pairs(meta.glyphs) do
    local glyph = {}
    for key, value in pairs(g) do
      if key ~= 'quad' then
        glyph[key] = value
      end
    end
    self.glyphs[cp] = glyph
    if g.w then
      glyph.quad = self.resources:own(lg.newQuad(g.x, g.y, g.w, g.h, w, h))
    end
  end
  return self
end
function B.load(size, checkpoint)
  local meta = assert(require('assets.fonts.painted-v16.catalog').sizes[size], size)
  local resources = Resources.new('bitmap font ' .. size, checkpoint)
  local font = B.new(meta, resources:image(meta.image), resources)
  resources.checkpoint = nil
  return font
end
function F:release()
  self.resources:release()
  self.glyphs, self.inkCache, self.inkCacheKeys = {}, {}, {}
end
function F:walk(t, visit)
  local x, y, maximum, previous = 0, 0, 0, nil
  for _, cp in utf8.codes(tostring(t)) do
    if cp == NEWLINE then
      maximum = math.max(maximum, x)
      x = 0
      y = y + self.meta.height
      previous = nil
    else
      if cp == TAB then
        cp = SPACE
      end
      local g = self.glyphs[cp] or self.glyphs[UNKNOWN]
      local kerning = previous and self.meta.kern[previous]
      x = x + (kerning and kerning[cp] or 0) + (previous and (self.meta.tracking or 0) or 0)
      if visit and g.w then
        visit(g, x, y)
      end
      x = x + g.advance
      previous = cp
    end
  end
  return math.max(maximum, x)
end
function F:getWidth(t)
  return self:walk(t)
end
function F:getHeight()
  return self.meta.height
end
function F:hasGlyphs(t)
  for _, cp in utf8.codes(tostring(t)) do
    if cp ~= NEWLINE and cp ~= TAB and not self.glyphs[cp] then
      return false, cp
    end
  end
  return true
end
function F:setFilter(a, b)
  -- A new sampling variant must not change another font sharing the source.
  self.image = self.resources:image(self.meta.image, { min = a, mag = b })
end
function F:draw(t, x, y, color)
  if color then
    lg.setColor(color[1], color[2], color[3], color[4] or 1)
  end
  self:walk(t, function(g, ox, oy)
    lg.draw(self.image, g.quad, x + ox + g.dx, y + oy + g.dy)
  end)
end
function F:getInk(t)
  t = tostring(t)
  local cached = self.inkCache[t]
  if cached then
    return cached
  end
  local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
  self:walk(t, function(g, x, y)
    x1 = math.min(x1, x + g.dx)
    y1 = math.min(y1, y + g.dy)
    x2 = math.max(x2, x + g.dx + g.w)
    y2 = math.max(y2, y + g.dy + g.h)
  end)
  local box = x1 == math.huge and { x = 0, y = 0, w = 0, h = 0 }
    or { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
  if #t <= CACHE_TEXT_LIMIT then
    local slot = self.inkCacheNext
    local retired = self.inkCacheKeys[slot]
    if retired then
      self.inkCache[retired] = nil
    end
    self.inkCache[t] = box
    self.inkCacheKeys[slot] = t
    self.inkCacheNext = slot % CACHE_LIMIT + 1
  end
  return box
end
return B

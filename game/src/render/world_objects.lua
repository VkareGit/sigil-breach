-- What stands in the world besides the bodies (plan v10 V6): seals, the
-- Ember, gates, supplies, decor, a mode's tools. Each kind registers how it
-- is drawn: in which pass of the frame (render/passes/) and where in that
-- pass. The renderer runs the passes and never names a kind; a new kind of
-- world object is one registration (render/world_art.lua holds the built-in
-- ones). An entry:
--   { { pass = 'architecture' | 'ground' | 'sprites' | 'translucent', order = n,
--       draw = function(r, g, view, time) }, ...,
--     init = function(r, shader)       its GPU resources, with the renderer's
--     overlay = function(r, g, x, y, w, h)  screen space, after the frame
--     release = function(r) }           its resources, with the renderer's
-- view: the mode's world view (session/queries.lua: world). Within a pass the
-- drawings run by order (then kind), so what overlaps what never depends on
-- when a kind was registered.
local Registry = require('src.core.registry')
local WorldObjects =
  { passes = { architecture = true, ground = true, sprites = true, translucent = true } }
local optional = { 'init', 'overlay', 'release' }
local kinds = Registry:new('world object kind', function(entry, kind)
  assert(type(entry) == 'table', 'world object ' .. kind .. ': expected an entry')
  for _, name in ipairs(optional) do
    assert(
      entry[name] == nil or type(entry[name]) == 'function',
      'world object ' .. kind .. ': ' .. name .. ' must be a function'
    )
  end
  for _, drawing in ipairs(entry) do
    assert(WorldObjects.passes[drawing.pass], 'world object ' .. kind .. ': unknown pass')
    assert(type(drawing.order) == 'number', 'world object ' .. kind .. ': expected an order')
    assert(type(drawing.draw) == 'function', 'world object ' .. kind .. ': expected draw')
  end
end)
local ordered
local function arrange()
  ordered = {}
  for pass in pairs(WorldObjects.passes) do
    ordered[pass] = {}
  end
  for kind, entry in kinds:each() do
    for _, drawing in ipairs(entry) do
      local list = ordered[drawing.pass]
      list[#list + 1] = { kind = kind, order = drawing.order, draw = drawing.draw }
    end
  end
  for _, list in pairs(ordered) do
    table.sort(list, function(a, b)
      if a.order == b.order then
        return a.kind < b.kind
      end
      return a.order < b.order
    end)
  end
end
function WorldObjects.register(kind, entry)
  assert(not kinds:has(kind), 'world object already registered: ' .. tostring(kind))
  kinds:register(kind, entry)
  arrange()
  return entry
end
function WorldObjects.unregister(kind)
  local entry = kinds:unregister(kind)
  arrange()
  return entry
end
function WorldObjects.has(kind)
  return kinds:has(kind)
end
-- Every kind's resources, when a renderer is built (shader: the renderer's
-- shader compiler, which reports loading progress).
function WorldObjects.init(r, shader)
  for _, entry in kinds:each() do
    if entry.init then
      entry.init(r, shader)
    end
  end
end
function WorldObjects.draw(r, g, pass, view, time)
  for _, drawing in ipairs(ordered[pass]) do
    drawing.draw(r, g, view, time)
  end
end
function WorldObjects.overlay(r, g, x, y, w, h)
  for _, entry in kinds:each() do
    if entry.overlay then
      entry.overlay(r, g, x, y, w, h)
    end
  end
end
function WorldObjects.release(r)
  for _, entry in kinds:each() do
    if entry.release then
      entry.release(r)
    end
  end
end
arrange()
return WorldObjects

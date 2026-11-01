-- World-space pigment from the existing illustrated glyphs, baked once per
-- inscription per renderer. No HUD styling changes, generated letters or I/O.
local Text = require('src.content.text')
local BitmapFont = require('src.ui.fonts.bitmap_font')
local Definitions = require('src.content.art.inscriptions')
local Ritual = require('src.render.ritual_art')
local Ground = require('src.physics.ground')
local Layout = require('src.content.maps.inscription_layout')
local I = {}
local function bake(r, id)
  r.wallInscriptions = r.wallInscriptions or {}
  local saved = r.wallInscriptions[id]
  if saved then
    return saved
  end
  local def = assert(Definitions[id])
  local lines = {}
  for _, key in ipairs(def.lines) do
    -- The text catalogue preserves the original wording of these excerpts.
    lines[#lines + 1] = Text.get(key)
  end
  local font = BitmapFont.load(48)
  local width, margin = 0, 16
  for _, line in ipairs(lines) do
    assert(font:hasGlyphs(line), 'missing inscription glyph: ' .. id)
    width = math.max(width, font:getWidth(line))
  end
  width = math.ceil(width + 2 * margin)
  local height = #lines * font:getHeight() + 2 * margin
  local image = r.native:own(love.graphics.newCanvas(width, height))
  image:setFilter('linear', 'linear')
  love.graphics.push('all')
  love.graphics.setCanvas(image)
  love.graphics.origin()
  love.graphics.setShader()
  love.graphics.setScissor()
  love.graphics.setDepthMode()
  love.graphics.setBlendMode('alpha', 'alphamultiply')
  love.graphics.clear(0, 0, 0, 0)
  for index, line in ipairs(lines) do
    font:draw(
      line,
      (width - font:getWidth(line)) / 2,
      margin + (index - 1) * font:getHeight(),
      { 1, 1, 1 }
    )
  end
  love.graphics.pop()
  font:release()
  local aspect = height / width
  local mesh = r.native:own(
    love.graphics.newMesh({ { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } }, {
      { 0.5, 0, 0, 0, 1 },
      { -0.5, 0, 0, 1, 1 },
      { -0.5, aspect, 0, 1, 0 },
      { 0.5, 0, 0, 0, 1 },
      { -0.5, aspect, 0, 1, 0 },
      { 0.5, aspect, 0, 0, 0 },
    }, 'triangles', 'static')
  )
  saved = { image = image, mesh = mesh, aspect = aspect }
  r.wallInscriptions[id] = saved
  return saved
end
function I.init(r)
  -- Pay glyph/canvas preparation during renderer loading, not on the first
  -- frame after walking into the chapel. The catalogue is small and bounded.
  for id in pairs(Definitions) do
    bake(r, id)
  end
end
function I.draw(r, g, view)
  -- Static mural visibility is owned by the same mode view. Never leave the
  -- lettering suspended in a mode that does not submit its painted surface.
  if view and not view.shrine then
    return
  end
  r.inscriptionPlacement = r.inscriptionPlacement or {}
  for _, item in ipairs((g.world.decor or {}).inscriptions or {}) do
    local art = bake(r, item.id)
    local place = Layout.resolve(item, g.world.decor, art.aspect, r.inscriptionPlacement)
    love.graphics.push('all')
    love.graphics.setColor(1, 1, 1)
    love.graphics.setDepthMode('less', true)
    Ritual.layer(
      r,
      art.image,
      place.x,
      Ground.of(g.world, place.surface) + place.y,
      place.z,
      place.width,
      place.yaw,
      nil,
      false,
      1,
      { 0.42, 0.075, 0.045 },
      art.mesh
    )
    love.graphics.pop()
  end
end
return I

-- Sparse painted fractures stand on the real footprint, visible from inside it.
-- All panels share one bounded mesh; the source paintings remain unchanged.
local Art = require('src.render.hazard_art')
local Rites = require('src.content.art.rites')
local Ground = require('src.physics.ground')
local Context = require('src.session.context')
local Storm = {}
local corners = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 0 }, { 1, 1 }, { 0, 1 } }
local function geometry(r, count)
  local cache = r.stormArt
  if not cache then
    for _, style in pairs(Rites.lightnings) do
      count = math.max(count, style.columns)
    end
    local vertices = {}
    for _ = 1, count * 6 do
      vertices[#vertices + 1] = { 0, 0, 0, 0, 0 }
    end
    cache = {
      vertices = vertices,
      mesh = r.native:own(
        love.graphics.newMesh(
          { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } },
          vertices,
          'triangles',
          'dynamic'
        )
      ),
    }
    r.stormArt = cache
  end
  return cache
end
local function panels(r, g, h, style, cell, count, radius, width, height, alpha, base)
  local cache = geometry(r, style.columns)
  local viewer = Context.viewer(g)
  for i = 1, count do
    local a = (i - 0.5) / count * math.pi * 2
    local x, z = math.sin(a) * radius, math.cos(a) * radius
    local dx, dz = viewer.x - h.x - x, viewer.z - h.z - z
    local near = math.min(1, (dx * dx + dz * dz) / (style.near * style.near))
    local yaw = math.atan2(dx, dz)
    for j, corner in ipairs(corners) do
      local v = cache.vertices[(i - 1) * 6 + j]
      local side = (0.5 - corner[1]) * width * near
      v[1], v[2], v[3] =
        x + math.cos(yaw) * side,
        (base or 0) + height * (0.5 + (corner[2] - 0.5) * near),
        z - math.sin(yaw) * side
      v[4], v[5] = corner[1], 1 - corner[2]
    end
  end
  cache.mesh:setVertices(cache.vertices)
  cache.mesh:setDrawRange(1, count * 6)
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  Art.mesh(r, h, cell, cache.mesh, Ground.of(g.world, h), alpha)
  love.graphics.pop()
end
function Storm.ground(r, g, h)
  local style = Rites.lightnings[h.art]
  if not style then
    return false
  end
  if h.delay > 0 then
    Art.circle(r, g, h, 'circle', h.radius, style.warningAlpha)
  end
  return true
end
function Storm.air(r, g, h)
  local style = Rites.lightnings[h.art]
  if not style then
    return false
  end
  local preparing = h.delay > 0
  local progress = preparing and 1 - h.delay / math.max(h.maxDelay, 0.001)
    or 1 - h.life / style.flash
  local top = h.volume.top
  local cell = Art.sequence(style.frames, progress)
  local alpha = preparing and style.warningAlpha + (1 - style.warningAlpha) * progress
    or style.edgeAlpha
  panels(
    r,
    g,
    h,
    style,
    cell,
    style.columns,
    h.radius,
    style.warningWidth,
    style.warningWidth,
    alpha,
    style.warningBase
  )
  if not preparing then
    panels(r, g, h, style, cell, 1, 0, style.strikeWidth, top, 1 - math.max(0, progress) * 0.5)
  end
  return true
end
function Storm.residue(r, g, h, age)
  local style = Rites.lightnings[h.art]
  if style and age >= 0 and age < style.embers then
    Art.circle(r, g, h, style.spent, h.radius * 0.5, 0.45 * (1 - age / style.embers))
  end
end
return Storm

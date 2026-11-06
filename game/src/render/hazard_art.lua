-- Ground hazards use painted pigment throughout their existing simulation
-- clock. Owns renderer resources only; samples hazards without changing them.
local Definition = require('src.content.art.hazards')
local Ground = require('src.physics.ground')
local Rites = require('src.content.art.rites')
local HazardArt = {}
local WHITE = { 1, 1, 1 }
local function clamp(value)
  return math.max(0, math.min(1, value))
end
-- Sample a finite painted sequence from the existing action or view clock.
function HazardArt.sequence(frames, progress)
  return frames[math.min(#frames, 1 + math.floor(clamp(progress) * #frames))]
end
local function vertices()
  local out = {}
  for index = 0, Definition.segments - 1 do
    local a, b =
      index / Definition.segments * math.pi * 2, (index + 1) / Definition.segments * math.pi * 2
    out[#out + 1] = { 0, 0, 0, 0.5, 0.5 }
    for _, angle in ipairs({ a, b }) do
      local x, z = math.cos(angle) * 0.5, math.sin(angle) * 0.5
      out[#out + 1] = { x, 0, z, 0.5 - x, 0.5 + z }
    end
  end
  return out
end
HazardArt.vertices = vertices
local function quad()
  -- A band along local z: the ray's length is the atlas's width.
  return {
    { -0.5, 0, -0.5, 0, 1 },
    { 0.5, 0, -0.5, 0, 0 },
    { 0.5, 0, 0.5, 1, 0 },
    { -0.5, 0, -0.5, 0, 1 },
    { 0.5, 0, 0.5, 1, 0 },
    { -0.5, 0, 0.5, 1, 1 },
  }
end
local function stripVertices()
  local out = {}
  for _ = 1, Rites.ray.tileLimit do
    for _, vertex in ipairs(quad()) do
      out[#out + 1] = vertex
    end
  end
  return out
end
local stripCorners = quad()
local function ribbonVertices()
  local result = {}
  for _ = 1, Rites.ribbon.capacity * 6 do
    result[#result + 1] = { 0, 0, 0, 0, 0 }
  end
  return result
end
function HazardArt.init(renderer)
  local image = renderer.resources:image(Definition.path)
  assert(
    image:getWidth() == Definition.width and image:getHeight() == Definition.height,
    'hazard atlas dimensions changed'
  )
  local frames = {}
  for index = 0, Definition.columns * Definition.rows - 1 do
    local column, row = index % Definition.columns, math.floor(index / Definition.columns)
    local x, y =
      math.floor(column * Definition.width / Definition.columns),
      math.floor(row * Definition.height / Definition.rows)
    local right, bottom =
      math.floor((column + 1) * Definition.width / Definition.columns),
      math.floor((row + 1) * Definition.height / Definition.rows)
    frames[index + 1] = {
      x / Definition.width,
      y / Definition.height,
      (right - x) / Definition.width,
      (bottom - y) / Definition.height,
    }
  end
  local cells = {}
  for name, cell in pairs(Rites.cells) do
    cells[name] =
      { cell[1] / Rites.columns, cell[2] / Rites.rows, 1 / Rites.columns, 1 / Rites.rows }
  end
  local format = { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } }
  renderer.hazardArt = {
    image = image,
    frames = frames,
    light = { 1, 1, 1 },
    rites = renderer.resources:image(Rites.path),
    cells = cells,
    mesh = renderer.native:own(love.graphics.newMesh(format, vertices(), 'triangles', 'static')),
    band = renderer.native:own(love.graphics.newMesh(format, quad(), 'triangles', 'static')),
    strip = renderer.native:own(
      love.graphics.newMesh(format, stripVertices(), 'triangles', 'dynamic')
    ),
    stripVertices = stripVertices(),
    ribbonVertices = ribbonVertices(),
    ribbon = renderer.native:own(
      love.graphics.newMesh(format, ribbonVertices(), 'triangles', 'dynamic')
    ),
  }
  renderer.hazardArt.images = {}
  for _, sheet in ipairs(Rites.supplements or {}) do
    local extra = renderer.resources:image(sheet.path)
    for name, cell in pairs(sheet.cells) do
      renderer.hazardArt.images[name] = extra
      cells[name] =
        { cell[1] / sheet.columns, cell[2] / sheet.rows, 1 / sheet.columns, 1 / sheet.rows }
      local crop = sheet.crops and sheet.crops[name]
      if crop then
        cells[name] = {
          (cell[1] + crop[1]) / sheet.columns,
          (cell[2] + crop[2]) / sheet.rows,
          crop[3] / sheet.columns,
          crop[4] / sheet.rows,
        }
      end
    end
  end
end
function HazardArt.sample(hazard)
  local kind = hazard.packet and hazard.packet.damageType
  local row = Definition.styles[kind] or Definition.defaultStyle
  local preparing = hazard.delay > 0
  if preparing then
    local progress = clamp(1 - hazard.delay / math.max(0.001, hazard.maxDelay))
    return {
      stage = 'telegraph',
      first = row * 4 + 1,
      second = row * 4 + 1,
      mix = 0,
      alpha = 0.72,
      warning = Definition.warningAlpha,
      warningFrame = 9 + math.min(3, math.floor(progress * 4)),
      radius = hazard.radius,
    }
  end
  local age = math.max(0, -hazard.delay)
  local phase = age * Definition.cycleRate
  local first = row * 4 + 2 + math.floor(phase) % 2
  local alpha = Definition.stainAlpha
  local stage = 'active'
  if hazard.life < Definition.fadeTime then
    stage = 'fading'
    first = row * 4 + 4
  end
  return {
    stage = stage,
    first = first,
    second = first,
    mix = 0,
    alpha = alpha,
    warning = Definition.liveBoundaryAlpha,
    warningFrame = 12,
    radius = hazard.radius,
  }
end
local upright = {}
local function layer(renderer, hazard, image, rect, alpha, height, scale, yaw, mesh)
  if alpha <= 0 then
    return
  end
  local art, shader = renderer.hazardArt, renderer.ritualArt.shader
  local red, green, blue = renderer.lighting:sample(hazard.x, height, hazard.z)
  art.light[1], art.light[2], art.light[3] =
    math.max(Definition.pigmentLightFloor, red),
    math.max(Definition.pigmentLightFloor, green),
    math.max(Definition.pigmentLightFloor, blue)
  renderer:cameraUniforms(shader)
  shader:send('objectPos', renderer:vec3(hazard.x, height, hazard.z))
  shader:send('objectYaw', yaw or 0)
  shader:send('objectScale', scale or hazard.radius * 2)
  shader:send('frameRect', rect)
  shader:send('light', art.light)
  shader:send('tint', WHITE)
  shader:send('inkMask', 0)
  shader:send('objectAlpha', alpha)
  mesh = mesh or art.mesh
  mesh:setTexture(image)
  love.graphics.setShader(shader)
  love.graphics.draw(mesh)
end
-- An authored cell on a caller-owned world mesh, sharing the same matte lighting.
function HazardArt.mesh(renderer, at, name, mesh, height, alpha)
  local art = renderer.hazardArt
  layer(
    renderer,
    at,
    art.images[name] or art.rites,
    assert(art.cells[name]),
    alpha or 1,
    height,
    1,
    0,
    mesh
  )
end
-- A painted circle of the rites atlas on the floor, its rim at this radius.
function HazardArt.circle(renderer, game, at, name, radius, alpha)
  local art = renderer.hazardArt
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  local height = Ground.of(game.world, at) + Definition.groundOffset
  layer(
    renderer,
    at,
    art.images[name] or art.rites,
    art.cells[name],
    alpha,
    height,
    radius * 2 / Rites.rim
  )
  love.graphics.pop()
end
-- A single connected ground tear, fitted to the authoritative footprint.
-- Repeat at the painting's scale instead of stretching the damned across a hall.
-- One bounded mesh serves every caster, including very long modded spells.
function HazardArt.strip(renderer, game, at, name, length, width, yaw, alpha)
  local art = renderer.hazardArt
  local count = math.min(Rites.ray.tileLimit, math.max(1, math.ceil(length / Rites.ray.tileLength)))
  local span = length / count
  for i, vertex in ipairs(art.stripVertices) do
    local segment = math.floor((i - 1) / 6)
    local corner = stripCorners[(i - 1) % 6 + 1]
    vertex[1] = (0.5 - corner[5]) * width
    vertex[3] = -length / 2 + (segment + corner[4]) * span
    -- Inner joins crop the transparent tips; outer ends keep their painted taper.
    local left, right = segment == 0 and 0 or 0.07, segment == count - 1 and 1 or 0.93
    vertex[4] = left + corner[4] * (right - left)
  end
  art.strip:setVertices(art.stripVertices)
  art.strip:setDrawRange(1, count * 6)
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  layer(
    renderer,
    at,
    art.images[name] or art.rites,
    art.cells[name],
    alpha,
    Ground.of(game.world, at) + Definition.groundOffset,
    1,
    yaw,
    art.strip
  )
  love.graphics.pop()
end
-- A vertical crest or a flat residue uses the same bounded reusable mesh.
-- Ring width extends inward from the authoritative leading radius; line width
-- spans the two edges of the fissure. Pigment never invents damage height.
function HazardArt.ribbon(renderer, game, at, name, shape, reach, width, height, yaw, alpha, tiling)
  local art, settings = renderer.hazardArt, tiling or Rites.ribbon
  assert(settings.segments <= Rites.ribbon.capacity, 'painted ribbon exceeds its bounded mesh')
  local ring = shape == 'ring'
  local repeats = math.min(
    settings.segments / 4,
    math.max(1, math.floor(2 * math.pi * reach / settings.tileLength + 0.5))
  )
  local count = ring and repeats * 4
    or math.min(settings.segments / 2, math.max(1, math.ceil(reach / settings.tileLength)))
  local sheets = ring and 1 or 2
  local vertexIndex = 0
  for sheet = 1, sheets do
    for segment = 0, count - 1 do
      for _, corner in ipairs(stripCorners) do
        vertexIndex = vertexIndex + 1
        local v = art.ribbonVertices[vertexIndex]
        local along, up = corner[4], 1 - corner[5]
        local t = (segment + along) / count
        if ring then
          local a = t * math.pi * 2
          local radius = settings.upright and reach or reach - width * (1 - up)
          v[1], v[3] = math.sin(a) * radius, math.cos(a) * radius
          v[4] = (segment % 4 + along) / 4
        else
          v[1], v[3], v[4] = (sheet - 1.5) * width, t * reach, along
        end
        v[2], v[5] = up * height, 1 - up
      end
    end
  end
  art.ribbon:setVertices(art.ribbonVertices)
  art.ribbon:setDrawRange(1, vertexIndex)
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  layer(
    renderer,
    at,
    art.images[name] or art.rites,
    art.cells[name],
    alpha,
    Ground.of(game.world, at) + Definition.groundOffset,
    1,
    yaw or 0,
    art.ribbon
  )
  love.graphics.pop()
end
-- A painted sheet of the rites atlas standing in the air, its foot at y.
function HazardArt.upright(renderer, x, y, z, name, size, yaw, alpha)
  local art = renderer.hazardArt
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  upright.x, upright.z = x, z
  layer(
    renderer,
    upright,
    art.images[name] or art.rites,
    art.cells[name],
    alpha,
    y,
    size,
    yaw,
    renderer.ritualArt.upright
  )
  love.graphics.pop()
end
-- One length of a painted band on the floor, along yaw.
function HazardArt.band(renderer, game, at, name, size, yaw, alpha)
  local art = renderer.hazardArt
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  local height = Ground.of(game.world, at) + Definition.groundOffset
  layer(
    renderer,
    at,
    art.images[name] or art.rites,
    art.cells[name],
    alpha,
    height,
    size,
    yaw,
    art.band
  )
  love.graphics.pop()
end
function HazardArt.draw(renderer, game, hazard)
  local sample = HazardArt.sample(hazard)
  local height = Ground.of(game.world, hazard) + Definition.groundOffset
  local art = renderer.hazardArt
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  layer(renderer, hazard, art.image, art.frames[sample.first], sample.alpha, height)
  layer(
    renderer,
    hazard,
    art.rites,
    art.cells.circle,
    sample.warning,
    height + Definition.warningOffset,
    hazard.radius * 2 / Rites.rim
  )
  love.graphics.pop()
end
return HazardArt

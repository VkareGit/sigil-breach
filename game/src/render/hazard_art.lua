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
  }
  renderer.hazardArt.images = {}
  for _, sheet in ipairs(Rites.supplements or {}) do
    local extra = renderer.resources:image(sheet.path)
    for name, cell in pairs(sheet.cells) do
      renderer.hazardArt.images[name] = extra
      cells[name] =
        { cell[1] / sheet.columns, cell[2] / sheet.rows, 1 / sheet.columns, 1 / sheet.rows }
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
-- A painted circle of the rites atlas on the floor, its rim at this radius.
function HazardArt.circle(renderer, game, at, name, radius, alpha)
  local art = renderer.hazardArt
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  local height = Ground.of(game.world, at) + Definition.groundOffset
  layer(renderer, at, art.rites, art.cells[name], alpha, height, radius * 2 / Rites.rim)
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

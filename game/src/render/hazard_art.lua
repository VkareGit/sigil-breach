-- Ground hazards use painted pigment throughout their existing simulation
-- clock. Owns renderer resources only; samples hazards without changing them.
local Definition = require('src.content.art.hazards')
local Ground = require('src.physics.ground')
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
  renderer.hazardArt = {
    image = image,
    frames = frames,
    light = { 1, 1, 1 },
    mesh = renderer.native:own(
      love.graphics.newMesh(
        { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } },
        vertices(),
        'triangles',
        'static'
      )
    ),
  }
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
      alpha = 0.16 + 0.20 * progress,
      warning = Definition.warningAlpha,
      warningFrame = 9 + math.min(3, math.floor(progress * 4)),
      radius = hazard.radius,
    }
  end
  local age = math.max(0, -hazard.delay)
  local phase = age * Definition.cycleRate
  local first = row * 4 + 2 + math.floor(phase) % 2
  local second = row * 4 + 2 + (math.floor(phase) + 1) % 2
  local mix = phase % 1
  local alpha = Definition.stainAlpha
  local stage = 'active'
  if age < Definition.emergeTime then
    first, second, mix = row * 4 + 1, row * 4 + 2, clamp(age / Definition.emergeTime)
    alpha = 0.36 + (alpha - 0.36) * mix
  elseif hazard.life < Definition.fadeTime then
    stage = 'fading'
    second, mix = row * 4 + 4, clamp(1 - hazard.life / Definition.fadeTime)
    alpha = alpha * (0.25 + 0.75 * clamp(hazard.life / Definition.fadeTime))
  end
  return {
    stage = stage,
    first = first,
    second = second,
    mix = mix,
    alpha = alpha,
    warning = Definition.warningAlpha
      + (Definition.liveBoundaryAlpha - Definition.warningAlpha)
        * clamp(age / Definition.emergeTime),
    warningFrame = 12,
    radius = hazard.radius,
  }
end
local function layer(renderer, hazard, image, rect, alpha, height)
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
  shader:send('objectYaw', 0)
  shader:send('objectScale', hazard.radius * 2)
  shader:send('frameRect', rect)
  shader:send('light', art.light)
  shader:send('tint', WHITE)
  shader:send('inkMask', 0)
  shader:send('objectAlpha', alpha)
  art.mesh:setTexture(image)
  love.graphics.setShader(shader)
  love.graphics.draw(art.mesh)
end
function HazardArt.draw(renderer, game, hazard)
  local sample = HazardArt.sample(hazard)
  local height = Ground.height(game.world, hazard.x, hazard.z) + Definition.groundOffset
  local art = renderer.hazardArt
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  layer(
    renderer,
    hazard,
    art.image,
    art.frames[sample.first],
    sample.alpha * (1 - sample.mix),
    height
  )
  layer(renderer, hazard, art.image, art.frames[sample.second], sample.alpha * sample.mix, height)
  layer(
    renderer,
    hazard,
    renderer.spells,
    renderer.spellFrames[sample.warningFrame].rect,
    sample.warning,
    height + Definition.warningOffset
  )
  love.graphics.pop()
end
return HazardArt

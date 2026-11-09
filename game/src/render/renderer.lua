local RenderNumbers = require('src.render.numbers')
local Context = require('src.session.context')
local Mesh = require('src.render.mesh')
local WorldMesh = require('src.render.world_mesh')
local Tuning = require('src.content.tuning')
local Weapon = require('src.render.weapon')
local WeaponArt = require('src.render.weapon_art')
local Pose = require('src.enemies.pose')
local AbilityArt = require('src.render.ability_art')
local AbilitySequences = require('src.content.ability_art')
local Pigment = require('src.render.creature_pigment')
local PaintCutout = require('src.render.paint_cutout')
local FX = require('src.feedback.effects')
local Queries = require('src.session.queries')
local Ground = require('src.physics.ground')
local Layout = require('src.ui.layout')
local Camera = require('src.render.camera')
-- What stands in the world besides the bodies draws by registration
-- (render/world_objects.lua); the renderer never names a kind of it.
local WorldObjects = require('src.render.world_objects')
require('src.render.world_art')
local Archetypes = require('src.content.enemies')
local R = {}
local Batch = require('src.render.batch')
local Instances = require('src.render.instances')
local Lights = require('src.render.lights')
local Shadows = require('src.render.shadows')
local RenderFX = require('src.render.effects')
local HazardArt = require('src.render.hazard_art')
local HazardKinds = require('src.render.hazard_kinds')
local HazardDefs = require('src.content.hazards')
local SurfaceMarks = require('src.render.surface_marks')
local Trails = require('src.feedback.shot_trails')
local Death = require('src.feedback.death_response')
-- The frame is a fixed sequence of passes (0.24; one module each, plan v10
-- V6). The order is the depth and blending contract: opaque world,
-- floor marks, opaque sprites, depth-tested translucent portals, effects
-- and the hands. A
-- new kind of thing on screen belongs to one pass; the passes share only
-- the renderer and the session. pass.draw(r, g, time, view).
local Halls = require('src.render.kit.halls')
local Characters = require('src.content.characters')
local Environment = require('src.content.art.environment')
local Ash = require('src.render.passes.ash')
local FrameLook = require('src.content.art.frame_look')
-- Six vertices draw one tracer.
local TRACE_VERTICES = FrameLook.tracers * 6
R.passes = {
  require('src.render.passes.architecture'),
  require('src.render.passes.projectiles'),
  require('src.render.passes.ground'),
  require('src.render.passes.enemy_marks'),
  require('src.render.passes.hazards'),
  Ash,
  require('src.render.passes.sprites'),
  require('src.render.passes.translucent'),
  require('src.render.passes.effects'),
}
local WHITE = { 1, 1, 1 }
local ZERO = { 0, 0, 0 }
-- The billboard quad: x in [-0.5, 0.5], y in [0, 1] (position, uv).
local SPRITE_QUAD = {
  { -0.5, 0, 0, 0, 1 },
  { 0.5, 0, 0, 1, 1 },
  { 0.5, 1, 0, 1, 0 },
  { -0.5, 0, 0, 0, 1 },
  { 0.5, 1, 0, 1, 0 },
  { -0.5, 1, 0, 0, 0 },
}
-- A painted body's record (render/instances.lua, shaders: body): place and
-- yaw, size, stretch and lean, the frame, mirror, pain, brightness and
-- silhouette, the key light.
local BODY_FORMAT = {
  { 'BodyPlace', 'float', 4 },
  { 'BodyShape', 'float', 4 },
  { 'BodyFrame', 'float', 4 },
  { 'BodyLook', 'float', 4 },
  { 'BodyKey', 'float', 2 },
}
local Shaders = require('src.render.shaders')
local Assets = require('src.render.assets')
local Resources = require('src.render.resources')
function R.new(checkpoint)
  local r = setmetatable({}, { __index = R })
  r.native = Resources.new('renderer meshes and shaders')
  r.resources = Resources.new('renderer artwork', checkpoint)
  local function shader(source, name)
    local result = r.native:own(love.graphics.newShader(source))
    if checkpoint then
      checkpoint(name)
    end
    return result
  end
  r.shader = shader(Shaders.world, 'world shader')
  r.spriteShader = shader(Shaders.sprite, 'sprite shader')
  r.post = shader(Shaders.post, 'postprocess shader')
  r.particleShader = shader(Shaders.particle, 'particle shader')
  r.skyShader = shader(Shaders.sky, 'sky shader')
  local white = love.image.newImageData(1, 1)
  white:setPixel(0, 0, 1, 1, 1, 1)
  r.blank = r.native:own(love.graphics.newImage(white))
  white:release()
  Assets.load(r)
  r.abilityArt = AbilityArt.load(r.resources)
  r.spriteShader:send('effectTint', WHITE)
  r.tracerShader = shader(Shaders.tracer, 'tracer shader')
  r.tracerMesh = Mesh.dynamic(TRACE_VERTICES)

  r.sprite = love.graphics.newMesh(
    { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } },
    SPRITE_QUAD,
    'triangles',
    'static'
  )
  -- Bodies and their cast shadows: one draw per image (plan v10 V3).
  r.bodyShader = shader(Shaders.body, 'body shader')
  r.bodyShader:send('effectAlpha', 1)
  r.bodyShader:send('effectTint', WHITE)
  r.bodies = Instances.new(SPRITE_QUAD, BODY_FORMAT, r.native)
  r.bodyPigments = {}
  r.bodyCutouts = {}
  r.bodyPigment = function(image)
    Pigment.apply(r.bodyShader, r.bodyPigments[image] or nil)
    PaintCutout.apply(r.bodyShader, r.bodyCutouts[image] or nil)
  end
  r.stampShader = shader(Shaders.stamp, 'stamp shader')
  HazardArt.init(r)
  for id in HazardDefs:each() do
    HazardKinds:get(id)
  end
  local v = {}
  local spark = FrameLook.spark
  Mesh.box(v, 0, spark.lift, 0, spark.half, spark.half, spark.half, spark.color)
  r.spark = Mesh.finish(v)
  r.particleBatch = Batch.new(v, spark.count)
  r.ashBatch = Batch.new(v, Ash.count)
  v = {}
  local S = FrameLook.sigil
  local star = S.star
  Mesh.ring(v, 0, 0, 0, S.outer.radius, S.outer.width, { 1, 1, 1, 1 }, S.sides, true)
  Mesh.ring(v, 0, 0, 0, S.inner.radius, S.inner.width, { 1, 1, 1, 1 }, S.sides, true)
  for i = 0, 4 do
    local a = i * math.pi * 4 / 5
    local b = (i + 1) * math.pi * 4 / 5
    Mesh.beam(
      v,
      { math.cos(a) * star.reach, math.sin(a) * star.reach, 0 },
      { math.cos(b) * star.reach, math.sin(b) * star.reach, 0 },
      star.width,
      { 1, 1, 1, 1 },
      star.sides
    )
  end
  r.sigil = Mesh.finish(v)
  v = {}
  local warning = FrameLook.warning
  Mesh.ring(v, 0, 0, 0, 1, warning.width, warning.color, warning.sides)
  r.warning = Mesh.finish(v)
  v = {}
  local shadow = FrameLook.shadow
  Mesh.cone(v, 0, 0, 0, shadow.radius, shadow.radius, shadow.height, shadow.color, shadow.sides)
  r.shadow = Mesh.finish(v)
  r.shadowStamps = Batch.new(v, shadow.count, true)
  v = {}
  local stain = FrameLook.stain
  Mesh.cone(v, 0, 0, 0, stain.radius, stain.radius, stain.height, stain.color, stain.sides)
  for i = 1, 7 do
    local a = i * stain.turn
    local d = stain.near + (i % 3) * stain.step
    local radius = stain.drop + (i % 3) * stain.dropStep
    Mesh.cone(
      v,
      math.sin(a) * d,
      0,
      math.cos(a) * d,
      radius,
      radius,
      stain.height,
      stain.color,
      stain.dropSides
    )
  end
  r.stain = Mesh.finish(v)
  r.lighting = Lights.new()
  r.castShadowShader = Shadows.new()
  r.castShadows = Instances.new(SPRITE_QUAD, Shadows.format, r.native)
  r.vector2 = { 0, 0 }
  r.vector3 = { 0, 0, 0 }
  r.camera = { 0, 0, 0 }
  r.right = { 1, 0, 0 }
  r.up = { 0, 1, 0 }
  r.forward = { 0, 0, 1 }
  r.effectOrder = {}
  r.effectSort = function(a, b)
    return (a.x - r.camera[1]) ^ 2 + (a.z - r.camera[3]) ^ 2
      > (b.x - r.camera[1]) ^ 2 + (b.z - r.camera[3]) ^ 2
  end
  r.canvasTarget = {}
  r.lastViewport = {}
  r.traceVertices = {}
  for i = 1, TRACE_VERTICES do
    r.traceVertices[i] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
  end
  RenderFX.init(r)
  SurfaceMarks.init(r)
  for _, name in ipairs({
    'shader',
    'spriteShader',
    'post',
    'particleShader',
    'skyShader',
    'blank',
    'tracerShader',
    'tracerMesh',
    'sprite',
    'spark',
    'sigil',
    'warning',
    'shadow',
    'stain',
    'castShadowShader',
    'groundSprite',
    'markMesh',
    'markShader',
  }) do
    r.native:own(r[name])
  end
  -- The world objects' own resources (render/world_objects.lua).
  WorldObjects.init(r, shader)
  for _, batch in ipairs({ r.particleBatch, r.ashBatch, r.shadowStamps }) do
    r.native:own(batch.mesh)
    r.native:own(batch.instances)
  end
  if checkpoint then
    checkpoint('renderer geometry')
  end
  Weapon.init(checkpoint)
  r:resize(FrameLook.startWidth, FrameLook.startHeight)
  r.resources.checkpoint = nil
  return r
end
function R:resize(w, h, resolution)
  resolution = resolution or Tuning.renderHeight
  self.w, self.h = math.floor(resolution * w / h + 0.5), resolution
  local targets = Resources.new('renderer viewport')
  local canvas = targets:own(love.graphics.newCanvas(self.w, self.h, { format = 'rgba8' }))
  local depth =
    targets:own(love.graphics.newCanvas(self.w, self.h, { format = 'depth24', readable = false }))
  if self.targets then
    self.targets:release()
  end
  self.targets, self.canvas, self.depth = targets, canvas, depth
  self.canvas:setFilter('nearest', 'nearest')
end
function R:release()
  if self.released then
    return
  end
  self.released = true
  WorldObjects.release(self)
  self.lighting:release()
  self.targets:release()
  self.native:release()
  self.resources:release()
  if self.worldResources then
    self.worldResources:release()
  end
  self.worldResources, self.worldMesh, self.meshWorld, self.meshRevision = nil, nil, nil, nil
end
function R:vec2(x, y)
  local v = self.vector2
  v[1], v[2] = x, y
  return v
end
function R:vec3(x, y, z)
  local v = self.vector3
  v[1], v[2], v[3] = x, y, z
  return v
end
function R:object(mesh, x, y, z, yaw, scale, tint, alpha)
  local s = self.shader
  s:send('objectPos', self:vec3(x or 0, y or 0, z or 0))
  s:send('objectYaw', yaw or 0)
  s:send('objectScale', scale or 1)
  s:send('tint', tint or WHITE)
  s:send('objectAlpha', alpha or 1)
  love.graphics.draw(mesh)
end
function R:cameraUniforms(s)
  s:send('camera', self.camera)
  s:send('rightDir', self.right)
  s:send('upDir', self.up)
  s:send('forwardDir', self.forward)
  s:send('aspect', self.w / self.h)
  s:send('projectionScale', self.projection)
end
function R:project(x, y, z)
  local dx, dy, dz = x - self.camera[1], y - self.camera[2], z - self.camera[3]
  local d = dx * self.forward[1] + dy * self.forward[2] + dz * self.forward[3]
  if d < FrameLook.near then
    return nil
  end
  return self.w * 0.5
    + (dx * self.right[1] + dy * self.right[2] + dz * self.right[3])
      * self.projection
      / (self.w / self.h)
      / d
      * self.w
      * 0.5,
    self.h * 0.5
      - (dx * self.up[1] + dy * self.up[2] + dz * self.up[3]) * self.projection / d * self.h * 0.5,
    d
end
-- Brightening of a body: the hit flash, the flash of a major wound, and the
-- soulslike tell: the last instant before the blow goes pulses so the dodge can be timed. A
-- held blow is still waiting: the pulse comes at the end of the hold, not of the windup.
function R.tell(e)
  local T = FrameLook.tell
  local hit = math.min(1, (e.hit or 0) * T.hit)
  local wound = math.min(1, (e.woundFlash or 0) * T.wound)
  local broke = math.min(1, (e.breakFlash or 0) * T.broke) * T.brokeGlow
  local tell = 0
  local left = (e.windup or 1) + (e.holdLeft or 0)
  if e.ai == 'windup' and left < T.last then
    tell = T.base + T.pulse * math.abs(math.sin(left * T.pulseRate))
  end
  -- An exposed boss glows in slow pulses for its whole window.
  local exposed = e.conditions and e.conditions.exposed or 0
  -- 0.43 (owner: it must be seen): brighter and slower, a beat a third of a second.
  local open = exposed > 0
      and (T.exposed + T.exposedPulse * math.abs(math.sin(exposed * T.exposedRate)))
    or 0
  return math.max(hit, wound, broke, tell, open)
end
-- Where and how a demon's painting is placed: the one transform the sprite
-- shader applies (quad x in [-0.5, 0.5], y in [0, 1]; stretched by sx, sy;
-- sheared by lean; scaled by size; turned to the knight; raised to baseY;
-- shifted across by shift). The hit-truth review (qa/hit_truth.lua) reads
-- the same placement, so what is measured is what is drawn. Reuses one
-- table; copy it to keep it.
local placement = {}
function R:enemyPlacement(g, e)
  -- Drawn as the camera's viewer sees it (presentation only, plan v11 E4).
  local p = Pose.sample(g, e, placement, Context.viewer(g))
  p.baseY = p.baseY + Ground.of(g.world, e)
  if p.ability then
    p.image = self.abilityArt[p.ability].image
  else
    p.image = self.frameImages[p.atlas][p.frame] or self.animations[p.atlas]
  end
  return p
end
-- batch (optional): add the body to this frame's bodies (R:drawBodies)
-- instead of drawing it now.
function R:enemy(g, e, batch)
  local p = self:enemyPlacement(g, e)
  -- Demons emerge from darkness: a low ambient, torchlight from one side (its
  -- direction becomes the lit and shadow sides of the body), a faint presence
  -- of the bearer, and the muzzle flash as a brief frontal light. Readability
  -- comes from the rim and the sinopia outline, not from flooding the body.
  local lr, lg, lb, lx, lz = self.lighting:sample(e.x, Ground.of(g.world, e) + 1, e.z)
  local brightness = lr * 0.30 + lg * 0.59 + lb * 0.11 -- constant: luma weights (BT.601)
  local B = FrameLook.body
  local side = (lx * self.right[1] + lz * self.right[3])
  local strength = math.min(1, math.sqrt(lx * lx + lz * lz) * B.direction)
  local flash = g.view.muzzle * B.flash
  brightness = math.min(B.brightest, brightness + flash)
  local key = self.keyLight or { 0, 0 }
  self.keyLight = key
  key[1] = math.max(-1, math.min(1, side * B.side))
  key[2] = strength * (1 - math.min(1, flash * B.flatten))
  local yaw, shift = p.yaw, p.shift
  if batch then
    local v = batch:add(p.image)
    self.bodyPigments[p.image] = p.ability and AbilitySequences[p.ability].pigment or false
    self.bodyCutouts[p.image] = not p.ability and PaintCutout.of(p.atlas)[p.sourcePath] or false
    v[1], v[2], v[3], v[4] = e.x + math.cos(yaw) * shift, p.baseY, e.z - math.sin(yaw) * shift, yaw
    v[5], v[6], v[7], v[8] = p.size, p.sx, p.sy, p.lean
    local rect = p.region.rect
    v[9], v[10], v[11], v[12] = rect[1], rect[2], rect[3], rect[4] -- constant: BodyFrame
    v[13], v[14] = p.mirror, e.hp > 0 and R.tell(e) or Death.pain(e) -- constant: BodyLook
    v[15] = e.hp > 0 and brightness or brightness * Death.shade(e) -- constant: BodyLook
    v[16] = e.hp > 0 and 1 or 0 -- constant: BodyLook
    v[17], v[18] = key[1], key[2] -- constant: BodyKey
    key[1], key[2] = 0, 0
    return
  end
  local s = self.spriteShader
  Pigment.apply(s, p.ability and AbilitySequences[p.ability].pigment)
  PaintCutout.apply(s, not p.ability and PaintCutout.of(p.atlas)[p.sourcePath] or nil)
  self.sprite:setTexture(p.image)
  s:send('silhouette', e.hp > 0 and 1 or 0)
  s:send('spriteStretch', self:vec2(p.sx, p.sy))
  s:send('effectAlpha', 1)
  s:send('soft', 0)
  s:send('mirror', p.mirror)
  s:send('frameRect', p.region.rect)
  s:send('objectPos', self:vec3(e.x + math.cos(yaw) * shift, p.baseY, e.z - math.sin(yaw) * shift))
  s:send('objectYaw', yaw)
  s:send('objectScale', p.size)
  s:send('lean', p.lean)
  s:send('pain', e.hp > 0 and R.tell(e) or Death.pain(e))
  s:send('brightness', e.hp > 0 and brightness or brightness * Death.shade(e))
  s:send('keyLight', key)
  love.graphics.draw(self.sprite)
  Pigment.apply(s)
  PaintCutout.apply(s)
  key[1], key[2] = 0, 0
  s:send('keyLight', key) -- props and effects stay evenly lit
end
function R:effect(g, e)
  local frame = FX.frame(e)
  local profile = FX.profile(e)
  local s = self.spriteShader
  local size = e.size
  local region = self.effectFrames[frame]
  s:send('effectTint', e.tint or WHITE)
  self.sprite:setTexture(self.effects)
  s:send('silhouette', 0)
  s:send('spriteStretch', self:vec2(region.width, region.height))
  s:send('soft', 0)
  s:send('effectAlpha', profile.alpha)
  s:send('frameRect', region.rect)
  s:send('objectPos', self:vec3(e.x, e.y - size * region.height * 0.5, e.z))
  s:send('objectYaw', math.atan2(Context.viewer(g).x - e.x, Context.viewer(g).z - e.z))
  s:send('objectScale', size)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', profile.brightness)
  love.graphics.draw(self.sprite)
  s:send('effectTint', WHITE)
end
-- Trauma rolls around the view axis; recoil pitch is handled by the shared
-- presentation camera, whose projection also positions the HUD's firing reticle.
function R:cameraRoll(g)
  return Camera.roll(g)
end
function R:sky(g)
  local s = self.skyShader
  s:send('rightDir', self.right)
  s:send('upDir', self.up)
  s:send('forwardDir', self.forward)
  s:send('aspect', self.w / self.h)
  s:send('projectionScale', self.projection)
  s:send('time', g.time or 0)
  love.graphics.setShader(s)
  local decor = g.world.decor
  local look = decor and decor.atmosphere
  local horizon = decor and decor.horizon and Environment[decor.horizon]
  s:send('horizon', horizon and self.resources:image(horizon.path, horizon) or self.horizon)
  s:send('gain', look and look.skyGain or FrameLook.skyGain)
  s:send('smoke', look and look.skySmoke or 0)
  local zenith = decor and decor.zenith and Environment[decor.zenith]
  if zenith then
    s:send('zenith', self.resources:image(zenith.path, zenith))
  end
  if look then
    love.graphics.setColor(look.sky)
  else
    love.graphics.setColor(1, 1, 1)
  end
  love.graphics.draw(self.blank, 0, 0, 0, self.w, self.h)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setShader()
end
-- The first-person weapon is lit by the same torches, presence and muzzle flash.
function R:weaponTint(g)
  local p = Context.actor(g)
  local r, green, b = self.lighting:sample(p.x, Ground.of(g.world, p) + 1, p.z)
  local H = FrameLook.hands
  local f = math.min(1, (g.view.muzzle or 0) * H.flash)
  local c = self.weaponColor or { 1, 1, 1 }
  self.weaponColor = c
  -- Never darker than the hands' floor (render/weapon_art.lua: look); the
  -- muzzle flash warms the iron for its instant.
  local floor = WeaponArt.look.floor
  c[1] = math.min(1, math.max(floor, r) + f * H.warm[1])
  c[2] = math.min(1, math.max(floor * H.floorGreen, green) + f * H.warm[2])
  c[3] = math.min(1, math.max(floor * H.floorBlue, b) + f * H.warm[3])
  return c
end
function R:tracers(g)
  if #g.view.traces == 0 then
    return
  end
  local vertices = self.traceVertices
  local most = FrameLook.tracers
  local count = math.min(most, #g.view.traces) * 6
  for i, t in ipairs(g.view.traces) do
    if i > most then
      break
    end
    local a, b = Trails.bounds(t)
    local dx, dy, dz = t.x2 - t.x1, t.y2 - t.y1, t.z2 - t.z1
    local exposure = self.traceExposure or {}
    self.traceExposure = exposure
    exposure.x1, exposure.y1, exposure.z1 = t.x1 + dx * a, t.y1 + dy * a, t.z1 + dz * a
    exposure.x2, exposure.y2, exposure.z2 = t.x1 + dx * b, t.y1 + dy * b, t.z1 + dz * b
    exposure.color = t.color
    local ex, ey, ez = t.x1 - self.camera[1], t.y1 - self.camera[2], t.z1 - self.camera[3]
    local rx, ry, rz = dy * ez - dz * ey, dz * ex - dx * ez, dx * ey - dy * ex
    local len = math.sqrt(rx * rx + ry * ry + rz * rz)
    local look = FrameLook.tracer
    local width = t.width * look.width
    if len < 1e-5 then
      rx, ry, rz = self.right[1] * width, self.right[2] * width, self.right[3] * width
    else
      rx, ry, rz = rx / len * width, ry / len * width, rz / len * width
    end
    local alpha = math.max(0, t.life / t.maxLife) * look.alpha
    Mesh.traceQuad(vertices, (i - 1) * 6, exposure, rx, ry, rz, alpha)
    if t.swept then
      for _, j in ipairs({ 1, 2, 4 }) do
        vertices[(i - 1) * 6 + j][10] = alpha * look.swept -- constant: the alpha slot
      end
    end
  end
  self.tracerMesh:setVertices(vertices, 1, count)
  self.tracerMesh:setDrawRange(1, count)
  local shader = self.tracerShader
  self:cameraUniforms(shader)
  shader:send('objectPos', ZERO)
  shader:send('objectYaw', 0)
  shader:send('objectScale', 1)
  love.graphics.setShader(shader)
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.tracerMesh)
end
-- Camera basis from the authoritative view; the canvas follows the layout.
function R:frameCamera(g, w, h)
  local lg = love.graphics
  local _, _, vw, vh = Layout.scene(g, w, h)
  local rw, rh = Camera.dimensions(g, w, h)
  if self.w ~= rw or self.h ~= rh then
    self:resize(vw, vh, rh)
  end
  self.canvasTarget[1] = self.canvas
  self.canvasTarget.depthstencil = self.depth
  lg.setCanvas(self.canvasTarget)
  local clear = FrameLook.clear
  lg.clear(clear[1], clear[2], clear[3], 1, 0, 1)
  lg.setShader()
  lg.setDepthMode()
  lg.setColor(1, 1, 1)
  -- The HUD uses this same camera to project the physical ray, including a
  -- still-settling kick when another weapon is drawn before the old cycle ends.
  local fov = Camera.basis(g, self.right, self.up, self.forward)
  self.camera[1], self.camera[2], self.camera[3] = Camera.origin(g)
  self.projection = (self.w / self.h) / math.tan(math.rad(fov) * 0.5)
end
-- This frame's bodies, one instanced draw per image. Bodies are opaque and
-- depth tested, so drawing them by image changes nothing on screen.
function R:drawBodies()
  local s = self.bodyShader
  self:cameraUniforms(s)
  love.graphics.setShader(s)
  self.bodies:draw(self.bodyPigment)
  love.graphics.setShader(self.spriteShader)
end
-- Whether a point lies behind the camera by more than margin (m): nothing there can reach
-- the screen, so it costs nothing to skip.
function R:behind(x, y, z, margin)
  local c, f = self.camera, self.forward
  return (x - c[1]) * f[1] + (y - c[2]) * f[2] + (z - c[3]) * f[3] < -margin
end
-- The art of these creatures, on the loading page instead of on first sight.
function R:prepareCreatures(ids, checkpoint)
  for _, id in ipairs(ids) do
    local _ = self.frames[Archetypes.get(id).appearance.atlas]
    if checkpoint then
      checkpoint(id)
    end
  end
end
function R:prepareWorld(g, checkpoint)
  assert(not self.released, 'renderer has been released')
  local revision = g.world.viewRevision or g.world.geometryRevision
  if self.meshWorld ~= g.world or self.meshRevision ~= revision then
    local resources = Resources.new('renderer world geometry')
    local mesh = WorldMesh.prepare(g.world, resources)
    local halls = Halls.prepare(g.world, resources, self.resources)
    local previous = self.worldResources
    self.worldResources, self.worldMesh, self.hallMeshes = resources, mesh, halls
    self.meshWorld, self.meshRevision = g.world, revision
    if previous then
      previous:release()
    end
  end
  if checkpoint then
    checkpoint('world mesh')
  end
  self.lighting:prepare(g.world, checkpoint)
end
function R:draw(g, w, h)
  self:prepareWorld(g)
  local lg = love.graphics
  local time = g.time
  self:frameCamera(g, w, h)
  local view = Queries.world(g)
  for _, pass in ipairs(R.passes) do
    pass.draw(self, g, time, view)
  end
  lg.setDepthMode()
  lg.setShader()
  lg.setColor(1, 1, 1)
  Weapon.draw(g, self.w, self.h, self:weaponTint(g))
  lg.setCanvas()
  self:present(g, w, h)
end
-- Below 40 HP the frame drains of colour and the edges darken with a heartbeat.
function R.lowHealth(g)
  local p = Context.actor(g)
  if not p or g.state ~= 'playing' or (p.hp or 1) <= 0 then
    return 0
  end
  local share = Characters.share(p)
  local low = math.max(0, math.min(1, (Tuning.lowHealthFade - share) / Tuning.lowHealth))
  if low == 0 then
    return 0
  end
  local B = FrameLook.heartbeat
  local beat = (g.time or 0) * (B.rate + low * B.faster) % 1
  local pulse = math.exp(-beat * B.first)
    + B.second * math.exp(-math.max(0, beat - B.gap) * B.secondFade) * (beat > B.gap and 1 or 0)
  return low * (B.floor + B.swing * math.min(1, pulse))
end
function R:present(g, w, h)
  local lg = love.graphics
  local x, y, vw, vh = Layout.scene(g, w, h)
  local viewport = self.lastViewport
  viewport.x, viewport.y, viewport.w, viewport.h = x, y, vw, vh
  local border = FrameLook.border
  lg.clear(border[1], border[2], border[3], 1)
  self.post:send('hurt', math.min(1, g.view.hurt + (g.view.staggerFlash or 0)))
  self.post:send('surge', g.view.surge)
  self.post:send('still', math.min(1, (g.view.perfectDodge or 0) / Tuning.feel.perfectDodgeFlash))
  self.post:send('low', R.lowHealth(g))
  self.post:send('kill', math.min(1, (g.view.killPunch or 0) * FrameLook.kill))
  self.post:send('size', self:vec2(self.w, self.h))
  lg.setShader(self.post)
  lg.setColor(1, 1, 1)
  lg.draw(self.canvas, x, y, 0, vw / self.w, vh / self.h)
  lg.setShader()
  self:damageNumbers(g, x, y, vw, vh)
  WorldObjects.overlay(self, g, x, y, vw, vh)
end
-- Damage numbers painted where the blow landed (Risk of Rain-style feedback):
-- they rise and fade in 0.7 s; heads and kills are larger and in red ochre.
function R:damageNumbers(g, x, y, vw, vh)
  return RenderNumbers.draw(self, g, x, y, vw, vh)
end
return R

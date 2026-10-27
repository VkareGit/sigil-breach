local Context = require('src.session.context')
local M = require('src.render.mesh')
local WorldMesh = require('src.render.world_mesh')
local T = require('src.content.tuning')
local Weapon = require('src.render.weapon')
local WeaponArt = require('src.render.weapon_art')
local Pose = require('src.enemies.pose')
local AbilityArt = require('src.render.ability_art')
local AbilityMetadata = require('src.content.ability_art')
local Pigment = require('src.render.creature_pigment')
local FX = require('src.feedback.effects')
local Queries = require('src.run.queries')
local Ground = require('src.physics.ground')
local Layout = require('src.ui.layout')
local Camera = require('src.render.camera')
-- What stands in the world besides the bodies draws by registration
-- (render/world_objects.lua); the renderer never names a kind of it.
local WorldObjects = require('src.render.world_objects')
require('src.render.world_art')
local R = {}
local Batch = require('src.render.batch')
local Instances = require('src.render.instances')
local Lights = require('src.render.lights')
local Shadows = require('src.render.shadows')
local RenderFX = require('src.render.effects')
local HazardArt = require('src.render.hazard_art')
local SurfaceMarks = require('src.render.surface_marks')
local Trails = require('src.feedback.shot_trails')
local Death = require('src.feedback.death_response')
-- The frame is a fixed sequence of passes (0.24; one module each, plan v10
-- V6). The order is the depth and blending contract: opaque world,
-- depth-tested transparent marks, then sprites, effects and the hands. A
-- new kind of thing on screen belongs to one pass; the passes share only
-- the renderer and the session. pass.draw(r, g, time, view).
local Ash = require('src.render.passes.ash')
R.passes = {
  require('src.render.passes.architecture'),
  require('src.render.passes.projectiles'),
  require('src.render.passes.ground'),
  require('src.render.passes.enemy_marks'),
  require('src.render.passes.hazards'),
  Ash,
  require('src.render.passes.sprites'),
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
  r.tracerMesh = M.dynamic(384)

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
  r.bodyPigment = function(image)
    Pigment.apply(r.bodyShader, r.bodyPigments[image] or nil)
  end
  r.stampShader = shader(Shaders.stamp, 'stamp shader')
  HazardArt.init(r)
  local v = {}
  M.sphere(v, 0, 0, 0, 0.09, 0.09, 0.09, { 1, 1, 1, 1 }, 6)
  r.orb = M.finish(v)
  v = {}
  M.box(v, 0, -0.025, 0, 0.045, 0.045, 0.045, { 1, 1, 1, 0.6 })
  r.spark = M.finish(v)
  r.particleBatch = Batch.new(v, 240)
  r.ashBatch = Batch.new(v, Ash.count)
  v = {}
  M.ring(v, 0, 0, 0, 0.48, 0.025, { 1, 1, 1, 1 }, 40, true)
  M.ring(v, 0, 0, 0, 0.37, 0.015, { 1, 1, 1, 1 }, 40, true)
  for i = 0, 4 do
    local a = i * math.pi * 4 / 5
    local b = (i + 1) * math.pi * 4 / 5
    M.beam(
      v,
      { math.cos(a) * 0.36, math.sin(a) * 0.36, 0 },
      { math.cos(b) * 0.36, math.sin(b) * 0.36, 0 },
      0.012,
      { 1, 1, 1, 1 },
      5
    )
  end
  r.sigil = M.finish(v)
  v = {}
  M.ring(v, 0, 0, 0, 1, 0.035, { 1, 1, 1, 0.7 }, 40)
  r.warning = M.finish(v)
  v = {}
  M.cone(v, 0, 0, 0, 0.44, 0.44, 0.006, { 0.025, 0.018, 0.025, 0.05 }, 24)
  r.shadow = M.finish(v)
  r.shadowStamps = Batch.new(v, 2 * 1024, true)
  v = {}
  M.cone(v, 0, 0, 0, 0.45, 0.45, 0.003, { 1, 1, 1, 0.05 }, 16)
  for i = 1, 7 do
    local a = i * 2.4
    local d = 0.22 + (i % 3) * 0.14
    local radius = 0.04 + (i % 3) * 0.025
    M.cone(v, math.sin(a) * d, 0, math.cos(a) * d, radius, radius, 0.003, { 1, 1, 1, 0.05 }, 7)
  end
  r.stain = M.finish(v)
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
  for i = 1, 384 do
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
    'orb',
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
  r:resize(1280, 720)
  r.resources.checkpoint = nil
  return r
end
function R:resize(w, h, resolution)
  resolution = resolution or T.renderHeight
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
  if d < 0.1 then
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
-- soulslike tell: the last instant of a windup pulses so the dodge can be timed.
function R.tell(e)
  local hit = math.min(1, (e.hit or 0) * 13)
  local wound = math.min(1, (e.woundFlash or 0) * 5)
  local broke = math.min(1, (e.breakFlash or 0) * 7) * 0.85
  local tell = 0
  if e.ai == 'windup' and (e.windup or 1) < 0.18 then
    tell = 0.35 + 0.30 * math.abs(math.sin((e.windup or 0) * 40))
  end
  -- An exposed boss glows in slow pulses for its whole window.
  local exposed = e.conditions and e.conditions.exposed or 0
  local open = exposed > 0 and (0.18 + 0.16 * math.abs(math.sin(exposed * 9))) or 0
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
  local brightness = lr * 0.30 + lg * 0.59 + lb * 0.11
  local side = (lx * self.right[1] + lz * self.right[3])
  local strength = math.min(1, math.sqrt(lx * lx + lz * lz) * 4)
  local flash = g.view.muzzle * 2.4
  brightness = math.min(1.05, brightness + flash)
  local key = self.keyLight or { 0, 0 }
  self.keyLight = key
  key[1] = math.max(-1, math.min(1, side * 6))
  key[2] = strength * (1 - math.min(1, flash * 3))
  local yaw, shift = p.yaw, p.shift
  if batch then
    local v = batch:add(p.image)
    self.bodyPigments[p.image] = p.ability and AbilityMetadata[p.ability].pigment or false
    v[1], v[2], v[3], v[4] = e.x + math.cos(yaw) * shift, p.baseY, e.z - math.sin(yaw) * shift, yaw
    v[5], v[6], v[7], v[8] = p.size, p.sx, p.sy, p.lean
    local rect = p.region.rect
    v[9], v[10], v[11], v[12] = rect[1], rect[2], rect[3], rect[4]
    v[13], v[14] = p.mirror, e.hp > 0 and R.tell(e) or Death.pain(e)
    v[15] = e.hp > 0 and brightness or brightness * Death.shade(e)
    v[16] = e.hp > 0 and 1 or 0
    v[17], v[18] = key[1], key[2]
    key[1], key[2] = 0, 0
    return
  end
  local s = self.spriteShader
  Pigment.apply(s, p.ability and AbilityMetadata[p.ability].pigment)
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
  s:send('soft', 1)
  s:send('effectAlpha', math.min(1, (1 - e.age / e.duration) * 3) * profile.alpha)
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
  local look = g.world.decor and g.world.decor.atmosphere
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
  local f = math.min(1, (g.view.muzzle or 0) * 16)
  local c = self.weaponColor or { 1, 1, 1 }
  self.weaponColor = c
  -- Never darker than the hands' floor (render/weapon_art.lua: look); the
  -- muzzle flash warms the iron for its instant.
  local floor = WeaponArt.look.floor
  c[1] = math.min(1, math.max(floor, r) + f * 0.40)
  c[2] = math.min(1, math.max(floor * 0.97, green) + f * 0.22)
  c[3] = math.min(1, math.max(floor * 0.95, b) + f * 0.06)
  return c
end
function R:tracers(g)
  if #g.view.traces == 0 then
    return
  end
  local vertices = self.traceVertices
  local count = math.min(64, #g.view.traces) * 6
  for i, t in ipairs(g.view.traces) do
    if i > 64 then
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
    local width = t.width * 0.009
    if len < 0.00001 then
      rx, ry, rz = self.right[1] * width, self.right[2] * width, self.right[3] * width
    else
      rx, ry, rz = rx / len * width, ry / len * width, rz / len * width
    end
    local alpha = math.max(0, t.life / t.maxLife) * 0.46
    M.traceQuad(vertices, (i - 1) * 6, exposure, rx, ry, rz, alpha)
    if t.swept then
      for _, j in ipairs({ 1, 2, 4 }) do
        vertices[(i - 1) * 6 + j][10] = alpha * 0.18
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
  lg.clear(0.035, 0.02, 0.035, 1, 0, 1)
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
function R:draw(g, w, h)
  assert(not self.released, 'renderer has been released')
  if self.meshWorld ~= g.world or self.meshRevision ~= g.world.geometryRevision then
    local resources = Resources.new('renderer world geometry')
    local mesh = WorldMesh.prepare(g.world, resources)
    local previous = self.worldResources
    self.worldResources, self.worldMesh = resources, mesh
    self.meshWorld, self.meshRevision = g.world, g.world.geometryRevision
    if previous then
      previous:release()
    end
  end
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
  if not p or g.state ~= 'playing' or (p.hp or 100) <= 0 then
    return 0
  end
  local low = math.max(0, math.min(1, (40 - p.hp) / 30))
  if low == 0 then
    return 0
  end
  local beat = (g.time or 0) * (1.05 + low * 0.55) % 1
  local pulse = math.exp(-beat * 9)
    + 0.6 * math.exp(-math.max(0, beat - 0.18) * 11) * (beat > 0.18 and 1 or 0)
  return low * (0.55 + 0.45 * math.min(1, pulse))
end
function R:present(g, w, h)
  local lg = love.graphics
  local x, y, vw, vh = Layout.scene(g, w, h)
  local viewport = self.lastViewport
  viewport.x, viewport.y, viewport.w, viewport.h = x, y, vw, vh
  lg.clear(0.008, 0.007, 0.011, 1)
  self.post:send('hurt', math.min(1, g.view.hurt + (g.view.staggerFlash or 0)))
  self.post:send('surge', g.view.surge)
  self.post:send('still', math.min(1, (g.view.perfectDodge or 0) / T.feel.perfectDodgeFlash))
  self.post:send('low', R.lowHealth(g))
  self.post:send('kill', math.min(1, (g.view.killPunch or 0) * 7))
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
  return require('src.render.numbers').draw(self, g, x, y, vw, vh)
end
return R

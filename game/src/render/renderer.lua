local M = require('src.render.mesh')
local WorldMesh = require('src.render.world_mesh')
local T = require('src.content.tuning')
local Weight = require('src.feedback.weight')
local Gallery = require('src.render.gallery')
local Archetypes = require('src.content.enemies')
local Portals = require('src.render.portals')
local Ritual = require('src.render.ritual_art')
local Weapon = require('src.render.weapon')
local WeaponArt = require('src.render.weapon_art')
local Pose = require('src.enemies.pose')
local Atlas = require('src.render.atlas')
local AbilityArt = require('src.render.ability_art')
local AbilityMetadata = require('src.content.ability_art')
local Pigment = require('src.render.creature_pigment')
local FX = require('src.feedback.effects')
local Descent = require('src.run.descent')
local Skin = require('src.ui.skin')
local Layout = require('src.ui.layout')
local Camera = require('src.render.camera')
local Ballistics = require('src.combat.ballistics')
local Goetic = require('src.ui.goetic_sigils')
-- The knight's body (reach rings are drawn with its real radius).
local KNIGHT = require('src.content.enemies').player.body
local R = {}
local Batch = require('src.render.batch')
local Lights = require('src.render.lights')
local Shadows = require('src.render.shadows')
local RenderFX = require('src.render.effects')
local SurfaceMarks = require('src.render.surface_marks')
local Trails = require('src.feedback.shot_trails')
local Death = require('src.feedback.death_response')
local COLORS = RenderFX.colors
local WHITE = { 1, 1, 1 }
local ZERO = { 0, 0, 0 }
local UNIT = { 1, 1 }
local ASH = { 0.30, 0.25, 0.22 }
local EMBER = { 1.25, 0.52, 0.16 } -- dull cinder: fire accent, not a bright speck
local ASH_COUNT = 96
-- A particle closer to the eye than this (m) shrinks away instead of
-- swelling into a block over the view (a fleck the knight runs through).
local PARTICLE_NEAR = 0.7
local PROP_POS = { { 10.9, 28.5 }, { 21.1, 28.5 }, { 3.8, 12.8 }, { 28.5, 20.5 } }
local function rects(cols, rows, padX, padY)
  local t = {}
  for i = 1, cols * rows do
    t[i] = {
      ((i - 1) % cols) / cols + padX,
      math.floor((i - 1) / cols) / rows + padY,
      1 / cols - 2 * padX,
      1 / rows - 2 * padY,
    }
  end
  return t
end
local MURAL_RECTS = rects(2, 2, 0.001, 0.001)
local Shaders = require('src.render.shaders')
local Assets = require('src.render.assets')
function R.new()
  local r = setmetatable({
    shader = love.graphics.newShader(Shaders.world),
    spriteShader = love.graphics.newShader(Shaders.sprite),
    post = love.graphics.newShader(Shaders.post),
  }, { __index = R })
  r.particleShader = love.graphics.newShader(Shaders.particle)
  r.skyShader = love.graphics.newShader(Shaders.sky)
  local white = love.image.newImageData(1, 1)
  white:setPixel(0, 0, 1, 1, 1, 1)
  r.blank = love.graphics.newImage(white)
  white:release()
  r.goetic = Goetic.init()
  r.goeticShader = love.graphics.newShader(Shaders.seal)
  Assets.load(r)
  r.abilityArt = AbilityArt.load()
  r.spriteShader:send('effectTint', WHITE)
  r.tracerShader = love.graphics.newShader(Shaders.tracer)
  r.tracerMesh = M.dynamic(384)
  -- The first effigy's hood starts above the nominal half-sheet boundary.
  -- Cut through the empty gutter, not through the painted hood.
  r.props, r.propFeet, r.propFrames = Atlas.load(
    'assets/art/props-fresco-v12.png',
    4,
    2,
    { { 0, 425, 887 }, { 0, 443, 887 }, { 0, 443, 887 }, { 0, 443, 887 } }
  )
  r.sprite = love.graphics.newMesh(
    { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } },
    {
      { -0.5, 0, 0, 0, 1 },
      { 0.5, 0, 0, 1, 1 },
      { 0.5, 1, 0, 1, 0 },
      { -0.5, 0, 0, 0, 1 },
      {
        0.5,
        1,
        0,
        1,
        0,
      },
      {
        -0.5,
        1,
        0,
        0,
        0,
      },
    },
    'triangles',
    'static'
  )
  Portals.init(r)
  Ritual.init(r)
  local v = {}
  M.sphere(v, 0, 0, 0, 0.09, 0.09, 0.09, { 1, 1, 1, 1 }, 6)
  r.orb = M.finish(v)
  v = {}
  M.box(v, 0, -0.025, 0, 0.045, 0.045, 0.045, { 1, 1, 1, 0.6 })
  r.spark = M.finish(v)
  r.particleBatch = Batch.new(v, 240)
  r.ashBatch = Batch.new(v, ASH_COUNT)
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
  M.box(v, 0, 0, 0, 0.22, 0.28, 0.15, { 0.5, 0.2, 0.09 })
  M.box(v, 0, 0.27, 0, 0.23, 0.05, 0.16, { 1, 0.65, 0.2, 0.1 })
  r.ammo = M.finish(v)
  v = {}
  M.box(v, 0, 0.1, 0, 0.30, 0.10, 0.10, { 0.25, 1, 0.6, 0.6 })
  M.box(v, 0, 0, 0, 0.10, 0.30, 0.10, { 0.25, 1, 0.6, 0.6 })
  r.health = M.finish(v)
  v = {}
  M.ring(v, 0, 0, 0, 1, 0.035, { 1, 1, 1, 0.7 }, 40)
  r.warning = M.finish(v)
  v = {}
  M.cone(v, 0, 0, 0, 0.44, 0.44, 0.006, { 0.025, 0.018, 0.025, 0.05 }, 24)
  r.shadow = M.finish(v)
  -- Plague bile is a dark verdigris stain lit by the room, not a flat green disc.
  v = {}
  M.cone(v, 0, 0, 0, 1, 1, 0.005, { 0.10, 0.15, 0.05, 0.06 }, 32)
  r.pool = M.finish(v)
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
  Weapon.init()
  r:resize(1280, 720)
  return r
end
function R:resize(w, h, resolution)
  resolution = resolution or T.renderHeight
  self.w, self.h = math.floor(resolution * w / h + 0.5), resolution
  if self.canvas then
    self.canvas:release()
    self.depth:release()
  end
  self.canvas = love.graphics.newCanvas(self.w, self.h, { format = 'rgba8' })
  self.canvas:setFilter('nearest', 'nearest')
  self.depth = love.graphics.newCanvas(self.w, self.h, { format = 'depth24', readable = false })
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
  local p = Pose.sample(g, e, placement)
  if p.ability then
    p.image = self.abilityArt[p.ability].image
  else
    p.image = self.frameImages[p.atlas][p.frame] or self.animations[p.atlas]
  end
  return p
end
function R:enemy(g, e)
  local p = self:enemyPlacement(g, e)
  -- Demons emerge from darkness: a low ambient, torchlight from one side (its
  -- direction becomes the lit and shadow sides of the body), a faint presence
  -- of the bearer, and the muzzle flash as a brief frontal light. Readability
  -- comes from the rim and the sinopia outline, not from flooding the body.
  local lr, lg, lb, lx, lz = self.lighting:sample(e.x, 1, e.z)
  local brightness = lr * 0.30 + lg * 0.59 + lb * 0.11
  local side = (lx * self.right[1] + lz * self.right[3])
  local strength = math.min(1, math.sqrt(lx * lx + lz * lz) * 4)
  local flash = g.view.muzzle * 2.4
  brightness = math.min(1.05, brightness + flash)
  local key = self.keyLight or { 0, 0 }
  self.keyLight = key
  key[1] = math.max(-1, math.min(1, side * 6))
  key[2] = strength * (1 - math.min(1, flash * 3))
  local s = self.spriteShader
  Pigment.apply(s, p.ability and AbilityMetadata[p.ability].pigment)
  self.sprite:setTexture(p.image)
  s:send('silhouette', e.hp > 0 and 1 or 0)
  s:send('spriteStretch', self:vec2(p.sx, p.sy))
  s:send('effectAlpha', 1)
  s:send('soft', 0)
  s:send('mirror', p.mirror)
  s:send('frameRect', p.region.rect)
  local yaw, shift = p.yaw, p.shift
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
function R:prop(g, frame, x, y, z, scale, bright)
  local region = self.propFrames[frame]
  if frame > 4 then
    local lr, lg, lb = self.lighting:sample(x, y + 1, z)
    bright = (bright or 0.9) * (lr * 0.30 + lg * 0.59 + lb * 0.11)
  end
  self.spriteShader:send('silhouette', 0)
  self.spriteShader:send('spriteStretch', self:vec2(region.width, region.height))
  self.spriteShader:send('effectAlpha', 1)
  self.spriteShader:send('soft', 0)
  local s = self.spriteShader
  self.sprite:setTexture(self.props)
  s:send('frameRect', region.rect)
  s:send('objectPos', self:vec3(x, y - self.propFeet[frame] * scale * region.height, z))
  s:send('objectYaw', math.atan2(g.player.x - x, g.player.z - z))
  s:send('objectScale', scale)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', bright or 0.9)
  love.graphics.draw(self.sprite)
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
  s:send('objectYaw', math.atan2(g.player.x - e.x, g.player.z - e.z))
  s:send('objectScale', size)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', profile.brightness)
  love.graphics.draw(self.sprite)
  s:send('effectTint', WHITE)
end
function R:mural(frame, x, y, z, yaw, size)
  local s = self.spriteShader
  self.sprite:setTexture(self.frescoes)
  s:send('silhouette', 0)
  s:send('spriteStretch', UNIT)
  s:send('effectAlpha', 1)
  s:send('soft', 0)
  s:send('mirror', 0)
  s:send('frameRect', MURAL_RECTS[frame])
  s:send('objectPos', self:vec3(x, y, z))
  s:send('objectYaw', yaw)
  s:send('objectScale', size)
  local lr, lg, lb = self.lighting:sample(x, y + 1, z)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('brightness', lr * 0.30 + lg * 0.59 + lb * 0.11)
  love.graphics.draw(self.sprite)
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
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.blank, 0, 0, 0, self.w, self.h)
  love.graphics.setShader()
end
-- The first-person weapon is lit by the same torches, presence and muzzle flash.
function R:weaponTint(g)
  local p = g.player
  local r, green, b = self.lighting:sample(p.x, 1, p.z)
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
function R:seal(g, seal)
  Ritual.seal(self, g, seal)
end
function R:pickup(g, a)
  local name = a.kind == 'health' and 'health' or (a.kind == 'ammo' and 'ammo' or 'soul')
  local icon = Skin.icons[name]
  local x, y, w, h = icon.q:getViewport()
  local iw, ih = Skin.image:getDimensions()
  local s = self.spriteShader
  self.sprite:setTexture(Skin.image)
  s:send('spriteStretch', self:vec2(w / h, 1))
  s:send('silhouette', 1)
  s:send('soft', 0)
  s:send('effectAlpha', 1)
  s:send('frameRect', { x / iw, y / ih, w / iw, h / ih })
  s:send('objectPos', self:vec3(a.x, 0.27 + math.sin(g.time * 3 + a.x) * 0.04, a.z))
  s:send('objectYaw', math.atan2(g.player.x - a.x, g.player.z - a.z))
  s:send('objectScale', a.kind == 'soul' and 0.42 or 0.48)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', 1.15)
  s:send('paint', 1)
  love.graphics.draw(self.sprite)
  s:send('paint', 0)
end
function R:shrine(g)
  local frame = 1 + math.floor(g.time * 5) % 4
  local data = self.shrineFrames[frame]
  local s = self.spriteShader
  local size = 3
  local active = g.run.phase == 'preparing'
  local spot = Descent.shrine
  self.sprite:setTexture(self.shrineImage)
  s:send('spriteStretch', self:vec2(0.5, 1))
  s:send('silhouette', 1)
  s:send('soft', 0)
  s:send('effectAlpha', 1)
  s:send('frameRect', data.rect)
  s:send('objectPos', self:vec3(spot.x, -self.shrineFeet[frame] * size, spot.z))
  s:send('objectYaw', math.atan2(g.player.x - spot.x, g.player.z - spot.z))
  s:send('objectScale', size)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', active and 0.92 or 0.32)
  love.graphics.draw(self.sprite)
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
-- The frame is a fixed sequence of passes (0.24). The order is the depth and
-- blending contract: opaque world, depth-tested transparent marks, then
-- sprites, effects and the hands. A new kind of thing on screen belongs to
-- one pass; the passes share only the renderer and the session.

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
  self.camera[1], self.camera[2], self.camera[3] = Ballistics.origin(g)
  self.projection = (self.w / self.h) / math.tan(math.rad(fov) * 0.5)
end

-- Opaque architecture, lamps' sparks and the seals.
function R:architecturePass(g, time)
  local lg = love.graphics
  self:sky(g)
  self:cameraUniforms(self.shader)
  self:cameraUniforms(self.spriteShader)
  -- The infernal witness is painted into the distant panorama. Reusing a live
  -- boss sprite here made it read as a giant hovering combat target.
  lg.setColor(1, 1, 1)
  lg.setShader(self.shader)
  lg.setDepthMode('less', true)
  lg.setMeshCullMode('none')
  self.shader:send('flash', g.view.muzzle * 7)
  self.shader:send('flashColor', g.view.flashColor)
  self.lighting:send(self.shader, g)
  self:object(g.world.mesh)
  for _, l in ipairs(g.world.lamps) do
    self:object(
      self.spark,
      l.x + 0.06 * math.sin(time * 4 + l.phase),
      l.y + 0.3 + (time * 0.6 + l.phase) % 0.4,
      l.z,
      0,
      1,
      { 1, 0.5, 0.1 }
    )
  end
  for _, s in ipairs(g.world.seals) do
    self:seal(g, s)
  end
end

-- Incoming weight is readable before it lands: the orb grows with the
-- packet's impact, its ember takes the damage-type colour and a short
-- trail behind it shows speed and direction (src/feedback/weight.lua colours).
function R:projectilesPass(g)
  local lg = love.graphics
  lg.setShader(self.shader)
  lg.setDepthMode('less', false)
  for _, b in ipairs(g.bullets) do
    local packet = b.packet or {}
    local heavy = math.min(1, (packet.impact or (b.big and 60 or 40)) / 120)
    -- Fairness: the painted rim is the collision radius (orb mesh radius .09),
    -- never smaller; impact shows in the trail and the core, not in the hitbox.
    local radius = b.radius or (b.big and 0.26 or 0.12)
    local scale = radius / 0.09 / 0.82 * 1.04
    local tint = Weight.typeColor(packet.damageType)
    -- Floor marker: where the projectile passes, readable while dodging.
    lg.setDepthMode('less', false)
    self:object(self.warning, b.x, 0.03, b.z, 0, radius * 2.2, tint, 0.45)
    local vx, vy, vz = b.vx or 0, b.vy or 0, b.vz or 0
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
    if speed > 0.01 then
      local step = math.min(0.22, speed * 0.035) / speed
      for i = 3, 1, -1 do
        local k = 1 - i * 0.24
        local trail = self.trailTint or { 0, 0, 0 }
        self.trailTint = trail
        trail[1], trail[2], trail[3] = tint[1] * 0.55, tint[2] * 0.55, tint[3] * 0.55
        self:object(
          self.orb,
          b.x - vx * step * i,
          b.y - vy * step * i,
          b.z - vz * step * i,
          0,
          scale * 0.62 * k,
          trail
        )
      end
    end
    -- A dark rim of the same pigment (not a black disc) keeps the silhouette
    -- readable on bright plaster without punching a hole in the fresco.
    local rim = self.rimTint or { 0, 0, 0 }
    self.rimTint = rim
    rim[1], rim[2], rim[3] = 0.04 + tint[1] * 0.16, 0.03 + tint[2] * 0.12, 0.03 + tint[3] * 0.12
    self:object(self.orb, b.x, b.y, b.z, 0, scale * 0.82, rim)
    self:object(self.orb, b.x, b.y, b.z, 0, scale * 0.56, tint)
    self:object(self.orb, b.x, b.y, b.z, 0, scale * (0.22 + 0.12 * heavy), COLORS.bone)
  end
end

-- Particles, ground objects of the mode (pickups, shrine, echo, portals,
-- sigils) and the stains on the floor.
function R:groundPass(g, time)
  local lg = love.graphics
  lg.setDepthMode('less', true)
  self.particleBatch:clear()
  local cx, cy, cz = self.camera[1], self.camera[2], self.camera[3]
  for _, a in ipairs(g.view.particles) do
    local near = math.min(1, ((a.x - cx) ^ 2 + (a.y - cy) ^ 2 + (a.z - cz) ^ 2) / PARTICLE_NEAR ^ 2)
    self.particleBatch:add(a.x, a.y, a.z, (a.size or 1) * math.min(1, a.life * 6) * near, a.color)
  end
  self.particleBatch:draw(self, g)
  if not g.run then
    for _, a in ipairs(g.pickups) do
      self:object(
        a.kind == 'ammo' and self.ammo or self.health,
        a.x,
        0.15 + math.sin(time * 3 + a.x) * 0.06,
        a.z,
        time * 0.4,
        1.25
      )
    end
  end
  if g.run then
    local active = g.run.phase == 'preparing'
    local sx, sz = Descent.shrine.x, Descent.shrine.z
    self:object(
      self.warning,
      sx,
      0.035,
      sz,
      0,
      0.72,
      active and { 0.50, 0.85, 0.72 } or { 0.12, 0.13, 0.14 }
    )
    local echo = g.run.echo
    if echo then
      self:object(
        self.sigil,
        echo.x,
        1.1 + math.sin(time * 2) * 0.07,
        echo.z,
        time * 0.7,
        0.8,
        { 0.15, 0.7, 1 }
      )
      self:object(self.warning, echo.x, 0.03, echo.z, 0, 0.8, { 0.2, 0.7, 1 })
    end
    lg.setDepthMode('less', false)
    for _, gate in ipairs(g.run.pending or {}) do
      Portals.draw(self, gate, time)
    end
    lg.setDepthMode('less', true)
  end
  if g.bossDead then
    self:object(self.sigil, 16, 2.1, 2.8, time * 0.3, 2.9, { 0.35, 0.85, 1 })
  end
  if not g.run and not g.secretFound then
    self:object(self.sigil, 3.7, 1.15, 20.4, 0.4, 0.34, { 0.38, 0.26, 0.12 })
  end
  lg.setDepthMode('less', false)
  for _, d in ipairs(g.view.decals or {}) do
    local def = Archetypes.get(d.kind)
    local color = def and def.appearance.stain or COLORS.blood
    self:object(
      self.stain,
      d.x,
      0.012,
      d.z,
      d.rotation,
      d.size,
      color,
      0.75 * math.min(1, (24 - d.age) / 3)
    )
  end
end

-- Under every living demon: shadows, the windup ring, the portal it climbs
-- out of and the landing point of a leap.
function R:enemyMarksPass(g)
  local lg = love.graphics
  lg.setDepthMode('less', true)
  Shadows.draw(self, g)
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      lg.setDepthMode('less', false)
      local look = Archetypes.look(e)
      local size = look.shadow
      self:object(self.shadow, e.x, 0.015, e.z, 0, size * 1.35, nil, 0.24)
      self:object(self.shadow, e.x, 0.016, e.z, 0, size * 0.95, nil, 0.38)
      lg.setDepthMode('less', true)
      if e.ai == 'windup' then
        local progress = 1 - e.windup / (e.windupDuration or 1)
        self:object(
          self.warning,
          e.x,
          0.025,
          e.z,
          0,
          0.42 + progress * 0.35,
          look.warning or COLORS.ember
        )
      end
      if (e.spawnAge or 1) < 0.6 then
        Portals.arrival(self, g, e)
      end
      -- A leap marks its landing point from the crouch to the landing: the
      -- player always sees where the arc ends (dodgeable, never a surprise).
      -- The ring is the real reach: landing radius plus the knight's body.
      local spec = e.attackSpec
      if spec and spec.kind == 'leap' and (e.ai == 'windup' or e.leaping) and e.aimX then
        local reachLand = spec.landRadius + KNIGHT.radius
        self:object(self.warning, e.aimX, 0.03, e.aimZ, 0, reachLand * 1.04, COLORS.ember, 0.85)
      end
    end
  end
end

-- Pools, lines and lightning marks: telegraph colour, then the live ground.
function R:hazardsPass(g, time)
  for _, haz in ipairs(g.hazards or {}) do
    self:object(
      self.warning,
      haz.x,
      0.03,
      haz.z,
      0,
      haz.radius,
      haz.delay > 0 and COLORS.bone or COLORS.brimstone
    )
    if haz.delay <= 0 and haz.kind ~= 'lightning' then
      self:object(self.pool, haz.x, 0.018, haz.z, 0, haz.radius)
      self:object(
        self.spark,
        haz.x + math.sin(time * 3) * haz.radius * 0.5,
        0.16 + math.sin(time * 4) * 0.08,
        haz.z + math.cos(time * 2) * haz.radius * 0.5,
        0,
        1.1,
        COLORS.brimstone
      )
    end
  end
end

-- Deterministic ash stays in world space and respects depth; no screen-space
-- snow. Grey ash falls; every twelfth mote is a live cinder rising from the pit.
function R:ashPass(g, time)
  self.ashBatch:clear()
  for i = 1, ASH_COUNT do
    local x = 2.5 + (i * 7.31) % 26
    local z = 2.5 + (i * 3.71) % 26
    if i % 12 == 0 then
      local y = (i * 0.53 + time * 0.55) % 4.6
      self.ashBatch:add(x + math.sin(time * 1.7 + i) * 0.30, y, z, 0.10 + (i % 3) * 0.04, EMBER)
    else
      local y = 4.3 - (i * 0.37 + time * 0.16) % 4.3
      self.ashBatch:add(x + math.sin(time * 0.5 + i) * 0.22, y, z, 0.12 + (i % 3) * 0.06, ASH)
    end
  end
  self.ashBatch:draw(self, g)
end

-- Painted sprites: murals, shrine, props, soul pickups, the gallery and the
-- demons themselves (alive, and dead for 25 s).
function R:spritesPass(g, time)
  local lg = love.graphics
  lg.setShader(self.spriteShader)
  if g.run then
    self:mural(1, 2.65, 0.72, 16, math.pi / 2, 2.7)
    self:mural(2, 29.35, 0.72, 16, -math.pi / 2, 2.7)
    self:mural(4, 16, 0.72, 29.35, math.pi, 2.7)
    self:shrine(g)
  end
  for _, l in ipairs(g.world.lamps) do
    self:prop(g, 1 + math.floor(time * 7 + l.phase) % 4, l.x, 0, l.z, 1.7, 1.1)
  end
  self:prop(g, 5, 10.7, 0, 3.5, 3.3, 0.95)
  self:prop(g, 5, 21.3, 0, 3.5, 3.3, 0.95)
  for _, pos in ipairs(PROP_POS) do
    self:prop(g, 6, pos[1], 0, pos[2], 0.75, 0.95)
  end
  self:prop(g, 8, 3.7, 0.62, 20.4, 0.75, g.secretFound and 0.4 or 0.9)
  if g.run then
    for _, a in ipairs(g.pickups) do
      self:pickup(g, a)
    end
  end
  if g.testField then
    Gallery.draw(self, g)
    lg.setShader(self.spriteShader)
  end
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 or (e.deathTime or 0) < 25 then
      self:enemy(g, e)
    end
  end
end

-- Surface marks, sorted effects, charges, spells, debug volumes, tracers.
function R:effectsPass(g)
  local lg = love.graphics
  SurfaceMarks.draw(self, g)
  lg.setShader(self.spriteShader)
  local effects = self.effectOrder
  local count = #g.view.effects
  for i = 1, count do
    effects[i] = g.view.effects[i]
  end
  for i = #effects, count + 1, -1 do
    effects[i] = nil
  end
  table.sort(effects, self.effectSort)
  lg.setDepthMode('less', false)
  for _, e in ipairs(effects) do
    self:effect(g, e)
  end
  RenderFX.charges(self, g, Weapon.chargeImage)
  RenderFX.spells(self, g)
  RenderFX.hitboxes(self, g)
  self:tracers(g)
end

function R:draw(g, w, h)
  WorldMesh.prepare(g.world)
  local lg = love.graphics
  local time = g.time
  self:frameCamera(g, w, h)
  self:architecturePass(g, time)
  self:projectilesPass(g)
  self:groundPass(g, time)
  self:enemyMarksPass(g)
  self:hazardsPass(g, time)
  self:ashPass(g, time)
  self:spritesPass(g, time)
  self:effectsPass(g)
  lg.setDepthMode()
  lg.setShader()
  lg.setColor(1, 1, 1)
  Weapon.draw(g, self.w, self.h, self:weaponTint(g))
  lg.setCanvas()
  self:present(g, w, h)
end
-- Below 40 HP the frame drains of colour and the edges darken with a heartbeat.
function R.lowHealth(g)
  local p = g.player
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
  Gallery.labels(self, g, x, y, vw, vh)
end
-- Damage numbers painted where the blow landed (Risk of Rain-style feedback):
-- they rise and fade in 0.7 s; heads and kills are larger and in red ochre.
function R:damageNumbers(g, x, y, vw, vh)
  return require('src.render.numbers').draw(self, g, x, y, vw, vh)
end
return R

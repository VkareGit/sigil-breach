-- The built-in world objects and how each is drawn (render/world_objects.lua):
-- the lamps, the seals, the supplies, the Ember and its murals, the echo,
-- the gates, the classic exit and secret, the decor props and the proving
-- ground's gallery. Orders keep the 0.30 frame: in the ground pass supplies,
-- the Ember's ring, the echo, gates, exit, secret; in the sprites pass
-- murals, the Ember, lamps, props, painted supplies, the gallery.
local WorldObjects = require('src.render.world_objects')
local M = require('src.render.mesh')
local Atlas = require('src.render.atlas')
local Shaders = require('src.render.shaders')
local Portals = require('src.render.portals')
local Ritual = require('src.render.ritual_art')
local Gallery = require('src.render.gallery')
local Goetic = require('src.ui.goetic_sigils')
local Skin = require('src.ui.skin')
local Queries = require('src.run.queries')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local Art = {}
local UNIT = { 1, 1 }
local SPARK = { 1, 0.5, 0.1 }
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
-- The props sheet (lamps and decor): the first effigy's hood starts above
-- the nominal half-sheet boundary; cut through the empty gutter, not through
-- the painted hood.
local function props(r)
  if r.props then
    return
  end
  r.props, r.propFeet, r.propFrames = Atlas.load(
    'assets/art/props-fresco-v12.png',
    4,
    2,
    { { 0, 425, 887 }, { 0, 443, 887 }, { 0, 443, 887 }, { 0, 443, 887 } },
    nil,
    r.resources
  )
end
function Art.prop(r, g, frame, x, y, z, scale, bright)
  local region = r.propFrames[frame]
  if frame > 4 then
    local lr, lg, lb = r.lighting:sample(x, y + 1, z)
    bright = (bright or 0.9) * (lr * 0.30 + lg * 0.59 + lb * 0.11)
  end
  r.spriteShader:send('silhouette', 0)
  r.spriteShader:send('spriteStretch', r:vec2(region.width, region.height))
  r.spriteShader:send('effectAlpha', 1)
  r.spriteShader:send('soft', 0)
  local s = r.spriteShader
  r.sprite:setTexture(r.props)
  s:send('frameRect', region.rect)
  s:send('objectPos', r:vec3(x, y - r.propFeet[frame] * scale * region.height, z))
  s:send('objectYaw', math.atan2(g.player.x - x, g.player.z - z))
  s:send('objectScale', scale)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', bright or 0.9)
  love.graphics.draw(r.sprite)
end
function Art.mural(r, frame, x, y, z, yaw, size)
  local s = r.spriteShader
  r.sprite:setTexture(r.frescoes)
  s:send('silhouette', 0)
  s:send('spriteStretch', UNIT)
  s:send('effectAlpha', 1)
  s:send('soft', 0)
  s:send('mirror', 0)
  s:send('frameRect', MURAL_RECTS[frame])
  s:send('objectPos', r:vec3(x, y, z))
  s:send('objectYaw', yaw)
  s:send('objectScale', size)
  local lr, lg, lb = r.lighting:sample(x, y + 1, z)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('brightness', lr * 0.30 + lg * 0.59 + lb * 0.11)
  love.graphics.draw(r.sprite)
end
function Art.pickup(r, g, a)
  local name = a.kind == 'health' and 'health' or (a.kind == 'ammo' and 'ammo' or 'soul')
  local icon = Skin.icons[name]
  local x, y, w, h = icon.q:getViewport()
  local iw, ih = Skin.image:getDimensions()
  local s = r.spriteShader
  r.sprite:setTexture(Skin.image)
  s:send('spriteStretch', r:vec2(w / h, 1))
  s:send('silhouette', 1)
  s:send('soft', 0)
  s:send('effectAlpha', 1)
  s:send('frameRect', { x / iw, y / ih, w / iw, h / ih })
  s:send(
    'objectPos',
    r:vec3(a.x, Ground.of(g.world, a) + 0.27 + math.sin(g.time * 3 + a.x) * 0.04, a.z)
  )
  s:send('objectYaw', math.atan2(g.player.x - a.x, g.player.z - a.z))
  s:send('objectScale', a.kind == 'soul' and 0.42 or 0.48)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', 1.15)
  s:send('paint', 1)
  love.graphics.draw(r.sprite)
  s:send('paint', 0)
end
-- The Ember's shrine sprite (view: the mode's world view; asked when absent).
function Art.shrine(r, g, view)
  view = view or Queries.world(g)
  if not view.shrine then
    return
  end
  local frame = 1 + math.floor(g.time * 5) % 4
  local data = r.shrineFrames[frame]
  local s = r.spriteShader
  local size = 3
  local active = view.shrineActive
  local spot = view.shrine
  r.sprite:setTexture(r.shrineImage)
  s:send('spriteStretch', r:vec2(0.5, 1))
  s:send('silhouette', 1)
  s:send('soft', 0)
  s:send('effectAlpha', 1)
  s:send('frameRect', data.rect)
  s:send('objectPos', r:vec3(spot.x, Ground.of(g.world, spot) - r.shrineFeet[frame] * size, spot.z))
  s:send('objectYaw', math.atan2(g.player.x - spot.x, g.player.z - spot.z))
  s:send('objectScale', size)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', active and 0.92 or 0.32)
  love.graphics.draw(r.sprite)
end

WorldObjects.register('lamp', {
  {
    pass = 'architecture',
    order = 10,
    draw = function(r, g, _, time)
      for _, l in ipairs(g.world.lamps) do
        r:object(
          r.spark,
          l.x + 0.06 * math.sin(time * 4 + l.phase),
          l.y + 0.3 + (time * 0.6 + l.phase) % 0.4,
          l.z,
          0,
          1,
          SPARK
        )
      end
    end,
  },
  {
    pass = 'sprites',
    order = 30,
    draw = function(r, g, _, time)
      for _, l in ipairs(g.world.lamps) do
        Art.prop(
          r,
          g,
          1 + math.floor(time * 7 + l.phase) % 4,
          l.x,
          Ground.of(g.world, l),
          l.z,
          1.7,
          1.1
        )
      end
    end,
  },
  init = props,
})
WorldObjects.register('seal', {
  {
    pass = 'architecture',
    order = 20,
    draw = function(r, g)
      for _, s in ipairs(g.world.seals) do
        Ritual.seal(r, g, s)
      end
    end,
  },
  init = function(r, shader)
    r.goetic = Goetic.init()
    r.goeticShader = shader(Shaders.seal, 'seal shader')
    Ritual.init(r)
    r.native:own(r.ritualArt.mesh)
    r.native:own(r.ritualArt.shader)
  end,
})
-- Supplies: painted icons in the expedition and the proving ground, the
-- classic arena's boxes otherwise (view.paintedPickups).
WorldObjects.register('supplies', {
  {
    pass = 'ground',
    order = 10,
    draw = function(r, g, view, time)
      if view.paintedPickups then
        return
      end
      for _, a in ipairs(Pools.of(g, 'pickups')) do
        r:object(
          a.kind == 'ammo' and r.ammo or r.health,
          a.x,
          Ground.of(g.world, a) + 0.15 + math.sin(time * 3 + a.x) * 0.06,
          a.z,
          time * 0.4,
          1.25
        )
      end
    end,
  },
  {
    pass = 'sprites',
    order = 50,
    draw = function(r, g, view)
      if view.paintedPickups then
        for _, a in ipairs(Pools.of(g, 'pickups')) do
          Art.pickup(r, g, a)
        end
      end
    end,
  },
  init = function(r)
    local v = {}
    M.box(v, 0, 0, 0, 0.22, 0.28, 0.15, { 0.5, 0.2, 0.09 })
    M.box(v, 0, 0.27, 0, 0.23, 0.05, 0.16, { 1, 0.65, 0.2, 0.1 })
    r.ammo = r.native:own(M.finish(v))
    v = {}
    M.box(v, 0, 0.1, 0, 0.30, 0.10, 0.10, { 0.25, 1, 0.6, 0.6 })
    M.box(v, 0, 0, 0, 0.10, 0.30, 0.10, { 0.25, 1, 0.6, 0.6 })
    r.health = r.native:own(M.finish(v))
  end,
})
-- The Ember: its ring on the floor (lit while the knight prepares) and the
-- shrine; the murals hang only where there is an Ember.
WorldObjects.register('ember', {
  {
    pass = 'ground',
    order = 20,
    draw = function(r, g, view)
      if view.shrine then
        local active = view.shrineActive
        local sx, sz = view.shrine.x, view.shrine.z
        r:object(
          r.warning,
          sx,
          Ground.height(g.world, sx, sz) + 0.035,
          sz,
          0,
          0.72,
          active and { 0.50, 0.85, 0.72 } or { 0.12, 0.13, 0.14 }
        )
      end
    end,
  },
  {
    pass = 'sprites',
    order = 20,
    draw = function(r, g, view)
      Art.shrine(r, g, view)
    end,
  },
})
WorldObjects.register('mural', {
  {
    pass = 'sprites',
    order = 10,
    draw = function(r, g, view)
      if not view.shrine then
        return
      end
      for _, mural in ipairs((g.world.decor or {}).murals or {}) do
        Art.mural(
          r,
          mural.frame,
          mural.x,
          Ground.of(g.world, mural) + mural.y,
          mural.z,
          mural.yaw,
          mural.size
        )
      end
    end,
  },
})
WorldObjects.register('echo', {
  {
    pass = 'ground',
    order = 30,
    draw = function(r, g, view, time)
      local echo = view.echo
      if not echo then
        return
      end
      r:object(
        r.sigil,
        echo.x,
        Ground.of(g.world, echo) + 1.1 + math.sin(time * 2) * 0.07,
        echo.z,
        time * 0.7,
        0.8,
        { 0.15, 0.7, 1 }
      )
      r:object(r.warning, echo.x, Ground.of(g.world, echo) + 0.03, echo.z, 0, 0.8, { 0.2, 0.7, 1 })
    end,
  },
})
WorldObjects.register('gate', {
  {
    pass = 'ground',
    order = 40,
    draw = function(r, g, view, time)
      love.graphics.setDepthMode('less', false)
      for _, gate in ipairs(view.gates) do
        Portals.draw(r, gate, time, g.world)
      end
      love.graphics.setDepthMode('less', true)
    end,
  },
  init = Portals.init,
})
-- The classic arena: its exit once the guardian fell, its hidden sigil.
WorldObjects.register('exit', {
  {
    pass = 'ground',
    order = 50,
    draw = function(r, g, view, time)
      if view.guardianDead then
        local exit = g.world.portal
        r:object(
          r.sigil,
          exit.x,
          Ground.of(g.world, exit) + 2.1,
          exit.z - 0.1,
          time * 0.3,
          2.9,
          { 0.35, 0.85, 1 }
        )
      end
    end,
  },
})
WorldObjects.register('secret', {
  {
    pass = 'ground',
    order = 60,
    draw = function(r, g, view)
      local secret = g.world.anchors and g.world.anchors.secret
      if view.classicSecret and not view.secretFound and secret then
        r:object(
          r.sigil,
          secret.x,
          Ground.of(g.world, secret) + 1.15,
          secret.z,
          0.4,
          0.34,
          { 0.38, 0.26, 0.12 }
        )
      end
    end,
  },
})
WorldObjects.register('prop', {
  {
    pass = 'sprites',
    order = 40,
    draw = function(r, g, view)
      for _, prop in ipairs((g.world.decor or {}).props or {}) do
        local brightness = prop.secret and view.secretFound and 0.4 or prop.brightness
        Art.prop(
          r,
          g,
          prop.frame,
          prop.x,
          Ground.of(g.world, prop) + (prop.y or 0),
          prop.z,
          prop.size,
          brightness
        )
      end
    end,
  },
  init = props,
})
-- The proving ground's gallery (render/gallery.lua), when the mode's tools
-- show it, and its name plates over the frame.
WorldObjects.register('gallery', {
  {
    pass = 'sprites',
    order = 60,
    draw = function(r, g)
      local tools = Queries.tools(g)
      if tools and tools.gallery then
        Gallery.draw(r, g)
        love.graphics.setShader(r.spriteShader)
      end
    end,
  },
  overlay = Gallery.labels,
  release = Gallery.release,
})
return Art

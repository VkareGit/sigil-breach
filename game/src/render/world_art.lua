local Entities = require('src.session.entities')
local Supplies = require('src.content.supplies')
local Context = require('src.session.context')
-- The built-in world objects and how each is drawn (render/world_objects.lua):
-- the lamps, the seals, the supplies, the Ember and its murals, the echo,
-- the gates, the decor props and the proving
-- ground's gallery. Ground supplies/marks precede opaque sprites. Portals
-- blend after their depth is complete, so a later distant mural cannot
-- overwrite a nearer portal with no depth writes.
local WorldObjects = require('src.render.world_objects')
local Mesh = require('src.render.mesh')
local Atlas = require('src.render.atlas')
local Shaders = require('src.render.shaders')
local Portals = require('src.render.portals')
local Ritual = require('src.render.ritual_art')
local Gallery = require('src.render.gallery')
local GoeticSigils = require('src.ui.goetic_sigils')
local Skin = require('src.ui.skin')
local Queries = require('src.session.queries')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local Art = {}
local Environment = require('src.content.art.environment')
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
  s:send('objectYaw', math.atan2(Context.viewer(g).x - x, Context.viewer(g).z - z))
  s:send('objectScale', scale)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', bright or 0.9)
  love.graphics.draw(r.sprite)
end
function Art.mural(r, frame, x, y, z, yaw, size, art, width, brightness)
  local s = r.spriteShader
  local entry = art and Environment[art]
  local repeatX = entry and entry.tileAspect and (width or size) / size / entry.tileAspect or 1
  s:send('wallRepeat', math.max(1, repeatX))
  r.sprite:setTexture(entry and r.resources:image(entry.path, entry) or r.frescoes)
  s:send('silhouette', 0)
  s:send('spriteStretch', width and r:vec2(width / size, 1) or UNIT)
  s:send('effectAlpha', 1)
  s:send('soft', 0)
  s:send('mirror', 0)
  s:send('frameRect', entry and entry.rect or MURAL_RECTS[frame])
  s:send('objectPos', r:vec3(x, y, z))
  s:send('objectYaw', yaw)
  s:send('objectScale', size)
  local lr, lg, lb = r.lighting:sample(x, y + 1, z)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('brightness', (lr * 0.30 + lg * 0.59 + lb * 0.11) * (brightness or 1))
  love.graphics.draw(r.sprite)
  s:send('wallRepeat', 1)
end
-- A supply painted on its own (supplies: image, or images by weapon), loaded once.
local packs = {}
local function pack(path)
  packs[path] = packs[path] or love.graphics.newImage(path, { mipmaps = true })
  return packs[path]
end
function Art.pickup(r, g, a)
  local supply = Supplies:get(a.kind)
  local seal = supply.seals and supply.seals[a.offer]
  if seal then
    love.graphics.push('all')
    love.graphics.setDepthMode('less', false)
    love.graphics.setColor(1, 1, 1)
    Ritual.layer(
      r,
      GoeticSigils.image(seal),
      a.x,
      Ground.of(g.world, a) + 0.028,
      a.z,
      supply.size * 2,
      0,
      nil,
      true,
      1,
      nil,
      nil,
      0.8
    )
    love.graphics.pop()
    return
  end
  local s = r.spriteShader
  -- By the gun its rounds are for, or by the offer a relic is (0.43).
  local which = a.weapon or a.offer
  local own = supply.image or (supply.images and which and supply.images[which])
  if own then
    local image = pack(own)
    local w, h = image:getDimensions()
    r.sprite:setTexture(image)
    s:send('spriteStretch', r:vec2(w / h, 1))
    s:send('frameRect', { 0, 0, 1, 1 })
  else
    local icon = Skin.icons[supply.icons and a.offer and supply.icons[a.offer] or supply.icon]
    local x, y, w, h = icon.q:getViewport()
    local iw, ih = Skin.image:getDimensions()
    r.sprite:setTexture(Skin.image)
    s:send('spriteStretch', r:vec2(w / h, 1))
    s:send('frameRect', { x / iw, y / ih, w / iw, h / ih })
  end
  s:send('silhouette', 1)
  s:send('soft', 0)
  s:send('effectAlpha', 1)
  local floor = Ground.of(g.world, a)
  -- A painted pack lies on the floor in the chapel's own light, like the rest of the fresco
  -- (owner: no glare); an atlas supply keeps its old hover and glow.
  local lift = own and supply.size * 0.5 or 0.27 + math.sin(g.time * 3 + a.x) * 0.04
  local foot = own and supply.footInset and supply.footInset[which]
  if foot then
    lift = -supply.size * foot
  end
  s:send('objectPos', r:vec3(a.x, floor + lift, a.z))
  s:send('objectYaw', math.atan2(Context.viewer(g).x - a.x, Context.viewer(g).z - a.z))
  s:send('objectScale', supply.size)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  local brightness = 1.15
  if own then
    local lr, lg, lb = r.lighting:sample(a.x, floor + 0.5, a.z)
    brightness = (lr * 0.30 + lg * 0.59 + lb * 0.11) * supply.light
  end
  s:send('brightness', brightness)
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
  s:send('objectYaw', math.atan2(Context.viewer(g).x - spot.x, Context.viewer(g).z - spot.z))
  s:send('objectScale', size)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('mirror', 0)
  s:send('brightness', active and 0.92 or 0.32)
  love.graphics.draw(r.sprite)
end

-- Things of the world draw themselves (session/entities.lua).
WorldObjects.register('entities', {
  {
    pass = 'sprites',
    order = 60,
    draw = function(r, g)
      for _, e in ipairs(Pools.of(g, 'entities')) do
        local def = Entities.kinds:find(e.entity)
        if def and def.draw then
          def.draw(r, g, e)
        end
      end
    end,
  },
})
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
          0.3,
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
          l.scale or 1.7,
          l.brightness or 1.1
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
    draw = function(r, g, view)
      for _, s in ipairs(g.world.seals) do
        Ritual.seal(r, g, s, view)
      end
    end,
  },
  init = function(r, shader)
    r.goetic = GoeticSigils.init()
    r.goeticShader = shader(Shaders.seal, 'seal shader')
    Ritual.init(r)
    r.native:own(r.ritualArt.mesh)
    r.native:own(r.ritualArt.shader)
  end,
})
WorldObjects.register('arena_fire', {
  { pass = 'sprites', order = 35, draw = require('src.render.arena_fire').draw },
  init = props,
})
WorldObjects.register('floor_art', {
  { pass = 'ground', order = 5, draw = require('src.render.floor_art').draw },
  init = require('src.render.floor_art').init,
})
WorldObjects.register('inscription', {
  { pass = 'sprites', order = 15, draw = require('src.render.inscriptions').draw },
  init = require('src.render.inscriptions').init,
})
-- Supplies: painted icons.
WorldObjects.register('supplies', {
  {
    pass = 'sprites',
    order = 50,
    draw = function(r, g)
      for _, a in ipairs(Pools.of(g, 'pickups')) do
        Art.pickup(r, g, a)
      end
    end,
  },
})
-- The fires of the way beyond the first one, and its doors.
local doorSize = require('src.content.pilgrimage').doorSize
WorldObjects.register('fires', {
  {
    pass = 'sprites',
    order = 61,
    draw = function(r, g)
      local view = Queries.world(g)
      for _, fire in ipairs(view.fires or {}) do
        Art.shrine(r, g, { shrine = fire, shrineActive = true })
      end
      for _, door in ipairs(view.doors or {}) do
        local floor = Ground.of(g.world, door)
        Art.mural(r, nil, door.x, floor, door.z, door.yaw, doorSize, door.art)
      end
    end,
  },
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
        if not mural.surfaceOnly then
          Art.mural(
            r,
            mural.frame,
            mural.x,
            Ground.of(g.world, mural) + mural.y,
            mural.z,
            mural.yaw,
            mural.size,
            mural.art,
            mural.width,
            mural.brightness
          )
        end
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
    pass = 'translucent',
    order = 40,
    draw = function(r, g, view, time)
      Portals.scene(r, g, view.gates, time)
    end,
  },
  init = Portals.init,
})
WorldObjects.register('prop', {
  {
    pass = 'sprites',
    order = 40,
    draw = function(r, g, view)
      for _, prop in ipairs((g.world.decor or {}).props or {}) do
        local brightness = prop.brightness
        if prop.art then
          local viewer = Context.viewer(g)
          local yaw = prop.yaw or math.atan2(viewer.x - prop.x, viewer.z - prop.z)
          local entry = Environment[prop.art]
          Art.mural(
            r,
            nil,
            prop.x,
            Ground.of(g.world, prop) + (prop.y or 0),
            prop.z,
            yaw,
            prop.size,
            prop.art,
            prop.size * (entry.aspect or 1),
            brightness
          )
        else
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
})
return Art

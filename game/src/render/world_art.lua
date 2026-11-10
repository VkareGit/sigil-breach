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
local WorldLook = require('src.content.art.world_look')
local UNIT = { 1, 1 }
local SPARK = WorldLook.lamp.spark
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
local MURAL_RECTS = rects(2, 2, WorldLook.muralPad, WorldLook.muralPad)
-- The props sheet (lamps and decor): the first effigy's hood starts above
-- the nominal half-sheet boundary; cut through the empty gutter, not through
-- the painted hood.
local function props(r)
  if r.props then
    return
  end
  local sheet = WorldLook.propSheet
  r.props, r.propFeet, r.propFrames =
    Atlas.load(sheet.path, sheet.cols, sheet.rows, sheet.cuts, nil, r.resources)
end
function Art.prop(r, g, frame, x, y, z, scale, bright)
  local region = r.propFrames[frame]
  if frame > 4 then
    local lr, lg, lb = r.lighting:sample(x, y + 1, z)
    bright = (bright or WorldLook.propBright) * (lr * 0.30 + lg * 0.59 + lb * 0.11) -- constant: luma (BT.601)
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
  s:send('brightness', bright or WorldLook.propBright)
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
  s:send('brightness', (lr * 0.30 + lg * 0.59 + lb * 0.11) * (brightness or 1)) -- constant: luma (BT.601)
  love.graphics.draw(r.sprite)
  s:send('wallRepeat', 1)
end
-- A supply painted on its own (supplies: image, or images by weapon), loaded once.
local packs = {}
local function pack(path)
  packs[path] = packs[path] or love.graphics.newImage(path, { mipmaps = true })
  return packs[path]
end
-- Every painted supply, behind the loading page (PLAN Z8): the first frame that showed a
-- pack loaded it.
function Art.prepareSupplies(checkpoint)
  for id, supply in Supplies:each() do
    if supply.image then
      pack(supply.image)
    end
    for _, path in pairs(supply.images or {}) do
      pack(path)
    end
    if checkpoint then
      checkpoint(id)
    end
  end
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
      Ground.of(g.world, a) + WorldLook.seal.lift,
      a.z,
      supply.size * 2,
      0,
      nil,
      true,
      1,
      nil,
      nil,
      WorldLook.seal.alpha
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
  local hover = WorldLook.hover
  local lift = own and supply.size * 0.5
    or hover.lift + math.sin(g.time * hover.rate + a.x) * hover.bob
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
  local brightness = WorldLook.supplyGlow
  if own then
    local lr, lg, lb = r.lighting:sample(a.x, floor + 0.5, a.z)
    brightness = (lr * 0.30 + lg * 0.59 + lb * 0.11) * supply.light -- constant: luma (BT.601)
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
  local look = WorldLook.shrine
  local frame = 1 + math.floor(g.time * look.rate) % 4
  local data = r.shrineFrames[frame]
  local s = r.spriteShader
  local size = look.size
  local active = view.shrineActive
  local spot = view.shrine
  r.sprite:setTexture(r.shrineImage)
  s:send('spriteStretch', r:vec2(look.width, 1))
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
  s:send('brightness', active and look.lit or look.dark)
  love.graphics.draw(r.sprite)
end

-- Things of the world draw themselves (session/entities.lua).
WorldObjects.register('entities', {
  {
    pass = 'sprites',
    order = 60, -- constant: draw order within its pass
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
    order = 10, -- constant: draw order within its pass
    draw = function(r, g, _, time)
      for _, l in ipairs(g.world.lamps) do
        local L = WorldLook.lamp
        r:object(
          r.spark,
          l.x + L.sway * math.sin(time * L.swayRate + l.phase),
          l.y + L.rise + (time * L.flicker + l.phase) % L.flickerSpan,
          l.z,
          0,
          L.sparkSize,
          SPARK
        )
      end
    end,
  },
  {
    pass = 'sprites',
    order = 30, -- constant: draw order within its pass
    draw = function(r, g, _, time)
      for _, l in ipairs(g.world.lamps) do
        local L = WorldLook.lamp
        Art.prop(
          r,
          g,
          1 + math.floor(time * L.rate + l.phase) % 4,
          l.x,
          Ground.of(g.world, l),
          l.z,
          l.scale or L.scale,
          l.brightness or L.bright
        )
      end
    end,
  },
  init = props,
})
WorldObjects.register('seal', {
  {
    pass = 'architecture',
    order = 20, -- constant: draw order within its pass
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
  { pass = 'sprites', order = 35, draw = require('src.render.arena_fire').draw }, -- constant: draw order
  init = props,
})
WorldObjects.register('floor_art', {
  { pass = 'ground', order = 5, draw = require('src.render.floor_art').draw }, -- constant: draw order
  init = require('src.render.floor_art').init,
})
WorldObjects.register('inscription', {
  { pass = 'sprites', order = 15, draw = require('src.render.inscriptions').draw }, -- constant: draw order
  init = require('src.render.inscriptions').init,
})
-- Supplies: painted icons.
WorldObjects.register('supplies', {
  {
    pass = 'sprites',
    order = 50, -- constant: draw order within its pass
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
    order = 61, -- constant: draw order within its pass
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
    order = 20, -- constant: draw order within its pass
    draw = function(r, g, view)
      if view.shrine then
        local active = view.shrineActive
        local sx, sz = view.shrine.x, view.shrine.z
        local ring = WorldLook.ring
        r:object(
          r.warning,
          sx,
          Ground.height(g.world, sx, sz) + ring.lift,
          sz,
          0,
          ring.size,
          active and ring.lit or ring.dark
        )
      end
    end,
  },
  {
    pass = 'sprites',
    order = 20, -- constant: draw order within its pass
    draw = function(r, g, view)
      Art.shrine(r, g, view)
    end,
  },
})
WorldObjects.register('mural', {
  {
    pass = 'sprites',
    order = 10, -- constant: draw order within its pass
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
    order = 30, -- constant: draw order within its pass
    draw = function(r, g, view, time)
      local echo = view.echo
      if not echo then
        return
      end
      local E = WorldLook.echo
      local floor = Ground.of(g.world, echo)
      r:object(
        r.sigil,
        echo.x,
        floor + E.height + math.sin(time * E.bobRate) * E.bob,
        echo.z,
        time * E.turn,
        E.size,
        E.color
      )
      r:object(r.warning, echo.x, floor + E.ringLift, echo.z, 0, E.size, E.ringColor)
    end,
  },
})
WorldObjects.register('gate', {
  {
    pass = 'translucent',
    order = 40, -- constant: draw order within its pass
    draw = function(r, g, view, time)
      Portals.scene(r, g, view.gates, time)
    end,
  },
  init = Portals.init,
})
WorldObjects.register('prop', {
  {
    pass = 'sprites',
    order = 40, -- constant: draw order within its pass
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
    order = 60, -- constant: draw order within its pass
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

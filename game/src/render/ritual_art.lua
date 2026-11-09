-- Matte, world-anchored fresco. No gameplay radii, actors or clocks live here.
-- The new medallion and historical seals remain their original PNG bytes.
local FieldData = require('src.content.field')
local Weapons = require('src.content.weapons')
local Ground = require('src.physics.ground')
local SealMotion = require('src.render.seal_motion')
local Shaders = require('src.render.shaders')
local Weapon = require('src.render.weapon')
local Context = require('src.session.context')
local Queries = require('src.session.queries')
local GoeticSigils = require('src.ui.goetic_sigils')
local Skin = require('src.ui.skin')
local Archetypes = require('src.content.enemies')
local RitualLook = require('src.content.art.ritual_look')
local Ritual = { path = RitualLook.path }
local UV, WHITE, INK = { 0, 0, 1, 1 }, { 1, 1, 1 }, RitualLook.ink
-- In the game's camera basis, looking north puts +X at screen left. These
-- UVs preserve source orientation from the south; yaw rotates the whole slab.
Ritual.vertices = {
  { 0.5, 0, -0.5, 0, 0 },
  { -0.5, 0, -0.5, 1, 0 },
  { -0.5, 0, 0.5, 1, 1 },
  { 0.5, 0, -0.5, 0, 0 },
  { -0.5, 0, 0.5, 1, 1 },
  { 0.5, 0, 0.5, 0, 1 },
}
function Ritual.init(r)
  GoeticSigils.init()
  local image =
    r.resources:image(Ritual.path, { mipmaps = true, filter = 'linear', mipmapFilter = 'linear' })
  r.ritualArt = {
    image = image,
    mesh = love.graphics.newMesh(
      { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } },
      Ritual.vertices,
      'triangles',
      'static'
    ),
    shader = love.graphics.newShader(Shaders.texture),
    light = { 1, 1, 1 },
  }
  r.ritualArt.upright = r.native:own(
    love.graphics.newMesh({ { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } }, {
      { 0.5, 0, 0, 0, 1 },
      { -0.5, 0, 0, 1, 1 },
      { -0.5, 1, 0, 1, 0 },
      { 0.5, 0, 0, 0, 1 },
      { -0.5, 1, 0, 1, 0 },
      { 0.5, 1, 0, 0, 0 },
    }, 'triangles', 'static')
  )
end
function Ritual.layer(
  r,
  image,
  x,
  y,
  z,
  diameter,
  yaw,
  uv,
  ink,
  alpha,
  tint,
  mesh,
  lightFloor,
  reveal
)
  local art = r.ritualArt
  local shader = art.shader
  local red, green, blue = r.lighting:sample(x, y, z)
  art.light[1], art.light[2], art.light[3] = red, green, blue
  if lightFloor then
    for i = 1, 3 do
      art.light[i] = math.max(art.light[i], lightFloor)
    end
  end
  r:cameraUniforms(shader)
  shader:send('objectPos', r:vec3(x, y, z))
  shader:send('objectYaw', yaw or 0)
  shader:send('objectScale', diameter)
  shader:send('frameRect', uv or UV)
  shader:send('light', art.light)
  shader:send('tint', tint or (ink and INK or WHITE))
  shader:send('inkMask', ink and 1 or 0)
  shader:send('inkReveal', reveal or 1)
  shader:send('objectAlpha', alpha or 1)
  mesh = mesh or art.mesh
  mesh:setTexture(image)
  love.graphics.setShader(shader)
  love.graphics.draw(mesh)
end
-- At most one source illustration belongs to a pad. Uncatalogued demons keep
-- the ornament empty: a decorative medallion is never an invented Goetic seal.
function Ritual.symbol(pad)
  if pad.spawn then
    local creature = Archetypes.get(pad.spawn)
    local name = creature and creature.appearance.seal
    return name and GoeticSigils.image(name), nil, name ~= nil
  elseif pad.weapon then
    local def = Weapons.get(pad.weapon)
    local id = def.art or def.id
    local image, quad = Weapon.images[id], Weapon.quads[id][1]
    local x, y, w, h = quad:getViewport()
    return image,
      { x / image:getWidth(), y / image:getHeight(), w / image:getWidth(), h / image:getHeight() },
      false
  elseif pad.refill then
    local q = Skin.icons.health.q
    local x, y, w, h = q:getViewport()
    return Skin.image,
      {
        x / Skin.image:getWidth(),
        y / Skin.image:getHeight(),
        w / Skin.image:getWidth(),
        h / Skin.image:getHeight(),
      },
      false
  end
end
function Ritual.draw(r, x, y, z, diameter, yaw, image, uv, ink, alpha, dim)
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  Ritual.layer(
    r,
    r.ritualArt.image,
    x,
    y,
    z,
    diameter,
    yaw,
    nil,
    false,
    alpha,
    dim and RitualLook.dim
  )
  if image then
    Ritual.layer(
      r,
      image,
      x,
      y + RitualLook.symbol.lift,
      z,
      diameter * RitualLook.symbol.share,
      yaw,
      uv,
      ink,
      alpha,
      dim and RitualLook.dimSymbol
    )
  end
  love.graphics.pop()
end
function Ritual.pad(r, pad, floor)
  local image, uv, ink = Ritual.symbol(pad)
  local axis, look = RitualLook.axisX, RitualLook.pad
  local yaw = pad.z > RitualLook.southZ and math.pi
    or (pad.x < axis and math.pi / 2 or -math.pi / 2)
  Ritual.draw(r, pad.x, (floor or 0) + look.lift, pad.z, look.diameter, yaw, image, uv, ink)
end
function Ritual.seal(r, g, seal, view)
  local image = GoeticSigils.image(seal.id)
  if not image then
    return
  end
  local axis = RitualLook.axisX
  local yaw = seal.x < axis and math.pi / 2 or (seal.x > axis and -math.pi / 2 or 0)
  local y = Ground.of(g.world, seal) + FieldData.altar.top
  local diameter = RitualLook.seal.diameter
  Ritual.draw(r, seal.x, y, seal.z, diameter, yaw, image, nil, true, 1, seal.active)
  if seal.summoning then
    local glow, reveal, lift, complete =
      SealMotion.sample(view or Queries.world(g), seal.id, g.elapsed)
    local viewer = Context.viewer(g)
    local facing = math.atan2(viewer.x - seal.x, viewer.z - seal.z)
    love.graphics.push('all')
    -- Ink is a cutout, not a translucent screen overlay: it must occlude a
    -- mural behind it and be occluded by a brazier/actor in front of it.
    love.graphics.setDepthMode('less', true)
    love.graphics.setColor(1, 1, 1)
    local U, T, G = RitualLook.upright, RitualLook.trace, RitualLook.glow
    Ritual.layer(
      r,
      image,
      seal.x,
      y + U.lift + lift,
      seal.z,
      U.size,
      facing,
      nil,
      true,
      1,
      complete and U.complete or U.drawing,
      r.ritualArt.upright,
      U.soft
    )
    if glow > 0 then
      -- Trace the original historical ink, never invent or rotate its strokes.
      -- Move toward the viewer by 3 mm to avoid a coplanar depth fight.
      love.graphics.setDepthMode('less', false)
      Ritual.layer(
        r,
        image,
        seal.x + math.sin(facing) * T.toward,
        y + U.lift + lift,
        seal.z + math.cos(facing) * T.toward,
        U.size,
        facing,
        nil,
        true,
        glow,
        T.tint,
        r.ritualArt.upright,
        T.soft,
        reveal
      )
      Ritual.layer(
        r,
        r.ritualArt.image,
        seal.x,
        y + G.lift,
        seal.z,
        diameter + glow * G.grow,
        yaw,
        nil,
        false,
        glow * G.alpha,
        G.tint,
        nil,
        G.soft
      )
    end
    love.graphics.pop()
  end
end
return Ritual

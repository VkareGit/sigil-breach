local Ballistics = require('src.combat.ballistics')
local AbilityFeedback = require('src.feedback.ability_feedback')
local Weapon = require('src.render.weapon')
local HazardKinds = require('src.render.hazard_kinds')
local Painters = require('src.render.painters')
local Context = require('src.session.context')
local Action = require('src.content.defs.action')
local Rites = require('src.content.art.rites')
local HazardArt = require('src.render.hazard_art')
local CastAccents = require('src.render.cast_accents')
-- Visual interpretation of authoritative attack clocks. No gameplay timers,
-- extra hit regions, or hidden randomness are introduced by the renderer.
local Archetypes = require('src.content.enemies')
local Geometry = require('src.enemies.geometry')
local Surface = require('src.enemies.surface')
local Corpse = require('src.enemies.corpse')
local AttackDebug = require('src.render.attack_debug')
local Rules = require('src.combat.rules')
local Ground = require('src.physics.ground')
local Queries = require('src.session.queries')
local Pools = require('src.session.world')
local EffectLook = require('src.content.art.effect_look')
local E = {}
E.colors = EffectLook.colors
local unit = { 1, 1 }
-- The colour of a damage zone in every hit diagnostic (E.hitColors below).
function E.zoneColor(name)
  return E.hitColors[name] or E.hitColors.torso
end
function E.init(r)
  r.groundSprite = love.graphics.newMesh(
    { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } },
    {
      { -0.5, 0, -0.5, 0, 1 },
      { 0.5, 0, -0.5, 1, 1 },
      { 0.5, 0, 0.5, 1, 0 },
      { -0.5, 0, -0.5, 0, 1 },
      {
        0.5,
        0,
        0.5,
        1,
        0,
      },
      {
        -0.5,
        0,
        0.5,
        0,
        0,
      },
    },
    'triangles',
    'static'
  )
end
function E.spell(r, g, row, phase, x, y, z, size, alpha, ground)
  local frame = row * 4 + 1 + math.min(3, math.max(0, math.floor(phase * 4)))
  local data = r.spellFrames[frame]
  local shader = r.spriteShader
  local mesh = ground and r.groundSprite or r.sprite
  mesh:setTexture(r.spells)
  love.graphics.setShader(shader)
  shader:send('silhouette', 0)
  shader:send('spriteStretch', ground and unit or r:vec2(data.width, data.height))
  shader:send('effectAlpha', alpha)
  shader:send('soft', 0)
  shader:send('mirror', 0)
  shader:send('frameRect', data.rect)
  shader:send('objectPos', r:vec3(x, ground and y or y - size * data.height * 0.5, z))
  shader:send(
    'objectYaw',
    ground and 0 or math.atan2(Context.viewer(g).x - x, Context.viewer(g).z - z)
  )
  shader:send('objectScale', size)
  shader:send('lean', 0)
  shader:send('pain', 0)
  shader:send('brightness', 1)
  love.graphics.draw(mesh)
end
-- The cut a wide blow leaves in the air, while it can land and a moment after.
local cutSurface = {}
local function cut(r, g, e, spec, look)
  local active = spec.active
  local age = e.phase - active[1]
  local span = active[2] - active[1] + Rites.cut
  if age < 0 or age > span then
    return
  end
  local name = look.cuts and look.cuts[spec.id] or look.cut
  local style = name and Rites.cuts[name]
  if style and style.ground then
    HazardArt.ribbon(
      r,
      g,
      e,
      HazardArt.sequence(style.frames, age / span),
      'ring',
      spec.reach,
      style.width,
      style.height,
      0,
      1 - age / span
    )
    return
  end
  local size = spec.reach * Rites.cutSize * (style and style.scale or 1)
  local x, z =
    e.x + e.lungeX * spec.reach * Rites.cutForward, e.z + e.lungeZ * spec.reach * Rites.cutForward
  local anchorY
  if style and style.anchor then
    local ax, ay, az = Surface.centre(Surface.prepare(g, e, cutSurface), style.anchor)
    if ax then
      x, anchorY, z = ax, ay, az
    end
  end
  local viewer = Context.viewer(g)
  local yaw = math.atan2(viewer.x - x, viewer.z - z)
    + (
      spec.trace and (spec.trace[1].angle * (e.swingSide or 1) > 0 and math.pi or 0)
      or e.attackCount % 2 * math.pi
    )
  local y = (anchorY or (Ground.of(g.world, e) + (e.leapY or 0) + Rites.cutHeight)) - size * 0.5
  local cell = style and HazardArt.sequence(style.frames, age / span) or 'cut'
  local look = EffectLook.cut
  HazardArt.upright(r, x, y, z, cell, size, yaw, age < span * look.whole and 1 or look.fading)
end
function E.spells(r, g)
  love.graphics.setDepthMode('less', false)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    local look = Archetypes.look(e)
    local casts = look.casts
    local spec = e.attackSpec
    if e.hp > 0 and e.ai == 'strike' and spec and Action.trait(spec, 'cuts') then
      cut(r, g, e, spec, look)
    end
    local accented = CastAccents.draw(r, g, e, E)
    if
      not accented
      and e.hp > 0
      and e.ai == 'windup'
      and casts
      and (casts.all or casts[e.attackKind])
    then
      local progress = 1 - e.windup / math.max(1e-2, e.windupDuration or 1)
      local yaw = math.atan2(Context.viewer(g).x - e.x, Context.viewer(g).z - e.z)
      local size = look.cast.size
      E.spell(
        r,
        g,
        0,
        progress,
        e.x + math.sin(yaw) * EffectLook.cast.ahead,
        Ground.of(g.world, e) + (e.leapY or 0) + look.cast.height,
        e.z + math.cos(yaw) * EffectLook.cast.ahead,
        size,
        EffectLook.cast.alpha,
        false
      )
    end
  end
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    local art = HazardKinds.of(h)
    if art.air then
      art.air(r, g, h, E)
    end
  end
  for _, burst in ipairs(g.view.poolBursts or {}) do
    Painters.residue('poolBursts')(r, g, burst, g.elapsed - burst.starts)
  end
  for _, burst in ipairs(g.view.impactBursts or {}) do
    require('src.render.impact_art').draw(r, g, burst, g.elapsed - burst.starts)
  end
  for _, burst in ipairs(g.view.riteBursts or {}) do
    HazardKinds.rayAfterimage(r, g, burst, g.elapsed - burst.starts)
  end
  for _, burst in ipairs(g.view.lightningBursts or {}) do
    Painters.residue('lightningBursts')(r, g, burst, g.elapsed - burst.starts)
  end
  for _, burst in ipairs(g.view.blinkBursts or {}) do
    local age = g.elapsed - burst.starts
    if age >= 0 and age < Rites.blink.duration then
      local frames = burst.arriving and Rites.blink.arrival or Rites.blink.departure
      local frame = HazardArt.sequence(frames, age / Rites.blink.duration)
      local viewer = Context.viewer(g)
      HazardArt.upright(
        r,
        burst.x,
        Ground.of(g.world, burst),
        burst.z,
        frame,
        Rites.blink.size,
        math.atan2(viewer.x - burst.x, viewer.z - burst.z),
        1
      )
    end
  end
end
-- During the hand-off only, avoid magnifying a world sprite placed centimetres
-- from the eye. A returning/older charge remains opaque and visibly dangerous.
function E.chargeAlpha(g, c)
  local age = math.max(0, (c.maxFuse or c.fuse or 0) - (c.fuse or 0))
  local H = EffectLook.handoff
  local duration = math.min(H.longest, (c.maxFuse or 1) * H.share)
  if duration <= 0 or age >= duration or not AbilityFeedback.frame(g) then
    return 1
  end
  local x, y, z = Ballistics.origin(g)
  local dx, dy, dz = c.x - x, c.y - y, c.z - z
  if dx * (c.vx or 0) + dy * (c.vy or 0) + dz * (c.vz or 0) <= 0 then
    return 1
  end
  local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
  local progress = math.max(age / duration, (distance - H.from) / H.over)
  progress = math.max(0, math.min(1, progress))
  return progress * progress * (3 - 2 * progress)
end
function E.charges(r, g, image, frames)
  if not image or #Pools.of(g, 'charges') == 0 then
    return
  end
  frames = frames or Weapon.chargeWorldFrames
  local s = r.spriteShader
  love.graphics.setShader(s)
  love.graphics.setDepthMode('less', true)
  r.sprite:setTexture(image)
  s:send('silhouette', 1)
  s:send('effectAlpha', 1)
  s:send('soft', 0)
  s:send('mirror', 0)
  s:send('lean', 0)
  s:send('pain', 0)
  local look = EffectLook.charge
  s:send('brightness', look.brightness)
  s:send('objectScale', look.size)
  for _, c in ipairs(Pools.of(g, 'charges')) do
    local alpha = E.chargeAlpha(g, c)
    s:send('effectAlpha', alpha)
    love.graphics.setDepthMode('less', alpha >= 1)
    local frame = 1 + math.floor((c.spin or g.time * 5) * 2) % 4
    local region = frames[frame]
    s:send('spriteStretch', r:vec2(region.width, region.height))
    s:send('frameRect', region.rect)
    s:send('objectPos', r:vec3(c.x, c.y - look.drop, c.z))
    s:send('objectYaw', math.atan2(Context.viewer(g).x - c.x, Context.viewer(g).z - c.z))
    if alpha > 0 then
      love.graphics.draw(r.sprite)
    end
  end
  love.graphics.setDepthMode('less', true)
end
-- The last shot as the game resolved it: every ray as a dotted line from
-- the eye to its contact, the contact coloured by what it struck.
local RAYS = EffectLook.rays
local STONE = RAYS.stone
-- A ray's colour: the zone it wounded, a surface that stopped it without a
-- wound (blocks), a falling body that shielded (shield), or stone.
local function rayColor(ray)
  if not ray.target then
    return STONE
  elseif ray.corpse then
    return E.hitColors.shield
  elseif ray.part == false then
    return E.hitColors.blocks
  end
  return E.zoneColor(ray.part)
end
local function shotRays(r, g)
  local report = g.view.shotReport
  if not report or not report.origin or (g.view.shotAge or math.huge) > RAYS.shown then
    return
  end
  local ox, oy, oz = report.origin[1], report.origin[2], report.origin[3]
  for _, ray in ipairs(report.rays) do
    local color = rayColor(ray)
    local length = math.min(ray.distance or 0, RAYS.longest)
    for t = RAYS.start, length - RAYS.gap, RAYS.every do
      local x, y, z = ox + ray.dx * t, oy + ray.dy * t, oz + ray.dz * t
      r:object(r.spark, x, y, z, 0, RAYS.dot, color, RAYS.dotAlpha)
    end
    if ray.kind ~= 'range' then
      local size = ray.target and RAYS.hit or RAYS.miss
      r:object(r.spark, ray.x, ray.y, ray.z, 0, size, color, RAYS.hitAlpha)
    end
  end
end
-- HITBOXES (proving ground): what the game actually uses, drawn from the very
-- data it decides with, never a separate approximation.
--   * the surface a shot meets: the baked pigment mask and the authored
--     regions of the current frame (enemies/surface.lua), tinted by damage
--     zone (head gold, torso red, legs orange), patterned by material (horn
--     stripes, membrane dots, metal cross-hatch); a surface that stops a shot
--     without a wound (a held cleaver) cyan; painted decoration that takes no
--     shot (a flame, loose cloth) violet; a falling body that shields grey;
--   * the motion body (white floor ring: the circle bodies collide with);
--   * the attack's contact while it can land (red points: the painted hand's
--     reach samples in its active window, a charge's front, a leap's landing
--     ring), dim outside the window;
--   * the last shot's rays, each ending where it struck.
-- A body using explicit volumes (enemies/geometry.lua) shows its cylinders.
E.hitColors = EffectLook.hitColors
local patterns = {
  horn = function(i, j)
    return (i + j) % 8 < 2
  end,
  membrane = function(i, j)
    return i % 4 == 0 and j % 4 == 0
  end,
  metal = function(i, j)
    return (i + j) % 6 == 0 or (i - j) % 6 == 0
  end,
}
-- The overlay of one frame's surface: one texel per mask cell (the sprite
-- shader's 320 grid), built once per frame, annotation and life (two
-- creatures may annotate one painting differently: appearance.regions).
local function overlay(r, p)
  r.hitOverlays = r.hitOverlays or {}
  local key = tostring(p.mask) .. tostring(p.parts) .. (p.alive and ':live' or ':dead')
  local image = r.hitOverlays[key]
  if image then
    return image
  end
  local n = #p.mask
  local data = love.image.newImageData(n, n)
  for j = 0, n - 1 do
    for i = 0, n - 1 do
      local u, v = (i + 0.5) / n, (j + 0.5) / n
      if Surface.painted(p.mask, u, v, p.alive) then
        local part = Surface.part(p.parts, u, v)
        local O = EffectLook.overlay
        local color, alpha = E.hitColors.decorative, O.decorative
        if not p.alive then
          color, alpha = E.hitColors.shield, O.dead
        elseif part and part.hittable ~= false then
          color, alpha = part.zone and E.hitColors[part.zone] or E.hitColors.blocks, O.part
        end
        local mark = part and patterns[part.material]
        local k = mark and mark(i, j) and O.pattern or 1
        data:setPixel(
          i,
          j,
          math.min(1, color[1] * k),
          math.min(1, color[2] * k),
          math.min(1, color[3] * k),
          alpha
        )
      end
    end
  end
  image = r.native:own(love.graphics.newImage(data))
  image:setFilter('nearest', 'nearest')
  data:release()
  r.hitOverlays[key] = image
  return image
end
local FULL = { 0, 0, 1, 1 }
local function surfaceOverlay(r, g, e)
  local p = Surface.prepare(g, e, r.hitSurface, Context.viewer(g))
  r.hitSurface = p
  local place = r:enemyPlacement(g, e)
  local s = r.spriteShader
  love.graphics.setShader(s)
  r.sprite:setTexture(overlay(r, p))
  s:send('silhouette', 0)
  s:send('spriteStretch', r:vec2(place.sx, place.sy))
  s:send('effectAlpha', 1)
  s:send('soft', 1)
  s:send('mirror', place.mirror)
  s:send('frameRect', FULL)
  local yaw, shift = place.yaw, place.shift
  s:send('objectPos', r:vec3(e.x + math.cos(yaw) * shift, place.baseY, e.z - math.sin(yaw) * shift))
  s:send('objectYaw', yaw)
  s:send('objectScale', place.size)
  s:send('lean', place.lean)
  s:send('pain', 0)
  s:send('brightness', 1)
  love.graphics.draw(r.sprite)
end
local function volumes(r, g, e)
  for _, v in ipairs(Geometry.volumes(g, e, Context.viewer(g))) do
    local color = E.hitColors[v.zone] or E.hitColors.blocks
    local look = EffectLook.volume
    r:object(r.warning, v.x, v.bottom + look.lift, v.z, 0, v.radius, color, look.alpha)
    r:object(r.warning, v.x, v.top, v.z, 0, v.radius, color, look.alpha)
  end
end
function E.hitboxes(r, g)
  local tools = Queries.tools(g)
  if not (tools and tools.hitboxes) then
    return
  end
  love.graphics.setDepthMode('lequal', false)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 or Corpse.shields(e) then
      if Geometry.uses(e) then
        love.graphics.setShader(r.shader)
        volumes(r, g, e)
      else
        surfaceOverlay(r, g, e)
      end
    end
  end
  love.graphics.setShader(r.shader)
  love.graphics.setDepthMode('less', false)
  shotRays(r, g)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      r:object(
        r.warning,
        e.x,
        Ground.of(g.world, e) + EffectLook.bodyRing.lift,
        e.z,
        0,
        Rules.radius(e),
        E.hitColors.body,
        EffectLook.bodyRing.alpha
      )
      AttackDebug.draw(r, g, e, E.hitColors)
    end
  end
end
return E

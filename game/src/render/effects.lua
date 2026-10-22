-- Visual interpretation of authoritative attack clocks. No gameplay timers,
-- extra hit regions, or hidden randomness are introduced by the renderer.
local Archetypes = require('src.content.enemies')
local Geometry = require('src.enemies.geometry')
local Surface = require('src.enemies.surface')
local Corpse = require('src.enemies.corpse')
local Melee = require('src.combat.melee')
local Rules = require('src.combat.rules')
local E = {}
E.colors = {
  coal = { 0.018, 0.016, 0.014 },
  bone = { 0.82, 0.73, 0.52 },
  ember = { 0.83, 0.39, 0.10 },
  brimstone = { 0.49, 0.41, 0.16 },
  blood = { 0.29, 0.018, 0.012 },
}
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
  shader:send('soft', 1)
  shader:send('mirror', 0)
  shader:send('frameRect', data.rect)
  shader:send('objectPos', r:vec3(x, ground and y or y - size * data.height * 0.5, z))
  shader:send('objectYaw', ground and 0 or math.atan2(g.player.x - x, g.player.z - z))
  shader:send('objectScale', size)
  shader:send('lean', 0)
  shader:send('pain', 0)
  shader:send('brightness', 1.12)
  love.graphics.draw(mesh)
end
function E.spells(r, g)
  love.graphics.setDepthMode('less', false)
  for _, e in ipairs(g.enemies) do
    local look = Archetypes.look(e)
    local casts = look.casts
    if e.hp > 0 and e.ai == 'windup' and casts and (casts.all or casts[e.attackKind]) then
      local progress = 1 - e.windup / math.max(0.01, e.windupDuration or 1)
      local yaw = math.atan2(g.player.x - e.x, g.player.z - e.z)
      local size = look.cast.size
      E.spell(
        r,
        g,
        0,
        progress,
        e.x + math.sin(yaw) * 0.4,
        look.cast.height,
        e.z + math.cos(yaw) * 0.4,
        size,
        0.72,
        false
      )
    end
  end
  for _, b in ipairs(g.bullets) do
    E.spell(r, g, 1, (g.time * 9) % 1, b.x, b.y, b.z, b.big and 0.82 or 0.52, 0.9, false)
  end
  for _, h in ipairs(g.hazards) do
    local preparing = h.delay > 0
    local progress = preparing and (1 - h.delay / math.max(0.01, h.maxDelay or 1))
      or (1 - (h.life or 0) / 0.22)
    if preparing then
      E.spell(r, g, 2, progress, h.x, 0.045, h.z, h.radius * 2, 0.68, true)
    elseif h.kind == 'lightning' then
      -- A short narrow strike leaves the enemy silhouette visible. The ground ring
      -- is still the exact authoritative damage radius, not this ornamental width.
      E.spell(r, g, 3, progress, h.x, 1.5, h.z, 2.8, 0.9, false)
    end
  end
end
function E.charges(r, g, image, frames)
  if not image or not g.charges or #g.charges == 0 then
    return
  end
  frames = frames or require('src.render.weapon').chargeWorldFrames
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
  s:send('brightness', 1.1)
  s:send('objectScale', 0.4)
  for _, c in ipairs(g.charges or {}) do
    local frame = 1 + math.floor((c.spin or g.time * 5) * 2) % 4
    local region = frames[frame]
    s:send('spriteStretch', r:vec2(region.width, region.height))
    s:send('frameRect', region.rect)
    s:send('objectPos', r:vec3(c.x, c.y - 0.16, c.z))
    s:send('objectYaw', math.atan2(g.player.x - c.x, g.player.z - c.z))
    love.graphics.draw(r.sprite)
  end
end
-- The last shot as the game resolved it: every ray as a dotted line from
-- the eye to its contact, the contact coloured by what it struck.
local STONE = { 0.62, 0.62, 0.60 }
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
  if not report or not report.origin or (g.view.shotAge or 99) > 3 then
    return
  end
  local ox, oy, oz = report.origin[1], report.origin[2], report.origin[3]
  for _, ray in ipairs(report.rays) do
    local color = rayColor(ray)
    local length = math.min(ray.distance or 0, 24)
    for t = 0.8, length - 0.2, 0.45 do
      r:object(r.spark, ox + ray.dx * t, oy + ray.dy * t, oz + ray.dz * t, 0, 0.18, color, 0.55)
    end
    if ray.kind ~= 'range' then
      r:object(r.spark, ray.x, ray.y, ray.z, 0, ray.target and 0.9 or 0.55, color, 0.95)
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
E.hitColors = {
  head = { 1, 0.84, 0.25 },
  torso = { 0.92, 0.25, 0.16 },
  lower = { 1, 0.58, 0.12 },
  blocks = { 0.35, 0.85, 0.95 },
  decorative = { 0.55, 0.42, 0.80 },
  shield = { 0.55, 0.55, 0.55 },
  body = { 1, 1, 1 },
  attack = { 1, 0.15, 0.10 },
  idle = { 0.45, 0.30, 0.28 },
}
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
        local color, alpha = E.hitColors.decorative, 0.45
        if not p.alive then
          color, alpha = E.hitColors.shield, 0.6
        elseif part and part.hittable ~= false then
          color, alpha = part.zone and E.hitColors[part.zone] or E.hitColors.blocks, 0.62
        end
        local mark = part and patterns[part.material]
        local k = mark and mark(i, j) and 1.45 or 1
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
  image = love.graphics.newImage(data)
  image:setFilter('nearest', 'nearest')
  data:release()
  r.hitOverlays[key] = image
  return image
end
local FULL = { 0, 0, 1, 1 }
local function surfaceOverlay(r, g, e)
  local p = Surface.prepare(g, e, r.hitSurface)
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
  for _, v in ipairs(Geometry.volumes(g, e)) do
    local color = E.hitColors[v.zone] or E.hitColors.blocks
    r:object(r.warning, v.x, v.bottom + 0.025, v.z, 0, v.radius, color, 0.85)
    r:object(r.warning, v.x, v.top, v.z, 0, v.radius, color, 0.85)
  end
end
-- The attack's contact as the simulation evaluates it now.
local function attackContact(r, g, e)
  local atk = e.attackSpec
  if not atk or e.ai ~= 'strike' then
    return
  end
  local color = E.hitColors.attack
  if atk.kind == 'lunge' then
    local from, to = Melee.window(atk)
    local live = e.phase >= from and e.phase <= to and not e.didHit
    local x, y, z, dx, dz = Melee.reach(g, e, e.phase, e.x, e.z, atk)
    for _, depth in ipairs(Melee.depths(atk)) do
      r:object(
        r.spark,
        x + dx * depth,
        y,
        z + dz * depth,
        0,
        live and 1.1 or 0.6,
        live and color or E.hitColors.idle
      )
    end
  elseif atk.kind == 'charge' and e.lungeX then
    r:object(
      r.spark,
      e.x + e.lungeX * atk.reach,
      atk.contactY,
      e.z + e.lungeZ * atk.reach,
      0,
      e.didHit and 0.6 or 1.1,
      e.didHit and E.hitColors.idle or color
    )
  elseif atk.kind == 'leap' and e.leaping then
    r:object(r.warning, e.x, 0.03, e.z, 0, atk.landRadius, color, 0.85)
  end
end
function E.hitboxes(r, g)
  if not (g.testField and g.testField.hitboxes) then
    return
  end
  love.graphics.setDepthMode('lequal', false)
  for _, e in ipairs(g.enemies) do
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
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      r:object(r.warning, e.x, 0.03, e.z, 0, Rules.radius(e), E.hitColors.body, 0.7)
      attackContact(r, g, e)
    end
  end
end
return E

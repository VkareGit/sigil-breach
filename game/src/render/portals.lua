-- Painted summoning art follows existing spawner clocks; never advances them.
local Atlas = require('src.render.atlas')
local Ritual = require('src.render.ritual_art')
local Ground = require('src.physics.ground')
local P = {}
local Archetypes = require('src.content.enemies')
P.colors = require('src.run.spawner').colors
P.fallback = Archetypes.neutralLook.portal
P.path = 'assets/art/portal-fresco-v23.png'
-- The portal colour of a creature id (its appearance), or the fallback.
function P.color(kind)
  local def = Archetypes.get(kind)
  return def and def.appearance.portal or P.fallback
end
function P.progress(gate)
  local total = gate.maxDelay
  if type(total) ~= 'number' or total ~= total or total <= 0 or total == math.huge then
    total = 1.2
  end
  local delay = gate.delay
  if type(delay) ~= 'number' or delay ~= delay then
    delay = total
  end
  return 1 - math.max(0, math.min(1, delay / total))
end
function P.frame(gate)
  local t = P.progress(gate)
  if t < 0.15 then
    return 1
  end
  if t < 0.35 then
    return 2
  end
  if t < 0.60 then
    return 3
  end
  if t >= 0.90 then
    return 6
  end
  return 4 + math.floor(t * 18) % 3
end
function P.arrivalFrame(age)
  if type(age) ~= 'number' or age ~= age or age < 0 or age >= 0.6 then
    return nil
  end
  return age < 0.16 and 6 or (age < 0.38 and 7 or 8)
end
function P.init(r)
  local image, feet, frames = Atlas.load(P.path, 4, 2, nil, nil, r.resources)
  local width, height = image:getDimensions()
  for _, region in ipairs(frames) do
    region.width = region.width * (width / 4) / (height / 2)
  end
  r.portalArt = { image = image, feet = feet, frames = frames }
  r.portalTint = { 1, 1, 1 }
end
local function paint(r, x, z, kind, frame, alpha, brightness, ground)
  local art, shader = r.portalArt, r.spriteShader
  local region = art.frames[frame]
  local color, tint = P.color(kind), r.portalTint
  for i = 1, 3 do
    tint[i] = 0.72 + 0.28 * color[i]
  end
  local def = Archetypes.get(kind)
  local size = (def and def.appearance.stature == 'large') and 3.6 or 2.75
  love.graphics.setShader(shader)
  r.sprite:setTexture(art.image)
  shader:send('spriteStretch', r:vec2(region.width, region.height))
  shader:send('effectAlpha', alpha)
  shader:send('effectTint', tint)
  shader:send('soft', 1)
  shader:send('silhouette', 0)
  shader:send('mirror', 0)
  shader:send('frameRect', region.rect)
  shader:send(
    'objectPos',
    r:vec3(x, (ground or 0) + 0.018 - art.feet[frame] * size * region.height, z)
  )
  shader:send('objectYaw', math.atan2(r.camera[1] - x, r.camera[3] - z))
  shader:send('objectScale', size)
  shader:send('lean', 0)
  shader:send('pain', 0)
  shader:send('brightness', brightness)
  shader:send('keyLight', r:vec2(0, 0))
  love.graphics.draw(r.sprite)
  shader:send('effectTint', r:vec3(1, 1, 1))
end
function P.draw(r, gate, _, world)
  local ground = Ground.height(world, gate.x, gate.z)
  local t, color = P.progress(gate), P.color(gate.kind)
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setShader(r.shader)
  r:object(r.shadow, gate.x, ground + 0.014, gate.z, 0, 0.9 + 0.8 * t, nil, 0.25 + 0.35 * t)
  Ritual.draw(
    r,
    gate.x,
    ground + 0.033,
    gate.z,
    (1.55 - 0.65 * t) * 2,
    0,
    nil,
    nil,
    false,
    0.55 + 0.4 * t
  )
  paint(r, gate.x, gate.z, gate.kind, P.frame(gate), 0.9 + 0.1 * t, 0.85 + 0.22 * t, ground)
  love.graphics.pop()
end
function P.arrival(r, g, e)
  local ground = Ground.height(g.world, e.x, e.z)
  local age, frame = e.spawnAge, P.arrivalFrame(e.spawnAge)
  if not frame then
    return
  end
  local def = Archetypes.of(e)
  local kind = def and def.id or e.kind
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setShader(r.shader)
  Ritual.draw(
    r,
    e.x,
    ground + 0.028,
    e.z,
    (1.4 - age) * 2,
    0,
    nil,
    nil,
    false,
    (1 - age / 0.6) * 0.75
  )
  paint(r, e.x, e.z, kind, frame, 1 - (age / 0.6) ^ 2, 1.05 - age * 0.25, ground)
  love.graphics.pop()
end
return P

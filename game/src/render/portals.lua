-- Painted summoning art follows existing spawner clocks; never advances them.
local Atlas = require('src.render.atlas')
local Ritual = require('src.render.ritual_art')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local PortalLook = require('src.content.art.portal_look')
local P = {}
local Archetypes = require('src.content.enemies')
P.colors = require('src.run.gates').colors
P.fallback = Archetypes.neutralLook.portal
P.path = PortalLook.path
-- The portal colour of a creature id (its appearance), or the fallback.
function P.color(kind)
  local def = Archetypes.get(kind)
  return def and def.appearance.portal or P.fallback
end
function P.progress(gate)
  local total = gate.maxDelay
  if type(total) ~= 'number' or total ~= total or total <= 0 or total == math.huge then
    total = PortalLook.delay
  end
  local delay = gate.delay
  if type(delay) ~= 'number' or delay ~= delay then
    delay = total
  end
  return 1 - math.max(0, math.min(1, delay / total))
end
function P.frame(gate)
  local t = P.progress(gate)
  for frame, ends in ipairs(PortalLook.opening) do
    if t < ends then
      return frame
    end
  end
  if t >= PortalLook.done then
    return 6
  end
  return 4 + math.floor(t * PortalLook.cycle) % 3
end
function P.arrivalFrame(age)
  if type(age) ~= 'number' or age ~= age or age < 0 or age >= PortalLook.arrival then
    return nil
  end
  local ends = PortalLook.arrivalFrames
  return age < ends[1] and 6 or (age < ends[2] and 7 or 8)
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
    tint[i] = PortalLook.tint.base + PortalLook.tint.share * color[i]
  end
  local def = Archetypes.get(kind)
  local size = (def and def.appearance.stature == 'large') and PortalLook.largeSize
    or PortalLook.size
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
    r:vec3(x, (ground or 0) + PortalLook.lift - art.feet[frame] * size * region.height, z)
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
  local ground = Ground.of(world, gate)
  local t, color = P.progress(gate), P.color(gate.kind)
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setShader(r.shader)
  local G = PortalLook.gate
  r:object(
    r.shadow,
    gate.x,
    ground + G.shadowLift,
    gate.z,
    0,
    G.shadow + G.shadowGrow * t,
    nil,
    G.shadowAlpha + G.shadowAlphaGrow * t
  )
  Ritual.draw(
    r,
    gate.x,
    ground + G.medallionLift,
    gate.z,
    (G.medallion - G.medallionShrink * t) * 2,
    0,
    nil,
    nil,
    false,
    G.medallionAlpha + G.medallionAlphaGrow * t
  )
  local alpha, bright = G.alpha + G.alphaGrow * t, G.bright + G.brightGrow * t
  paint(r, gate.x, gate.z, gate.kind, P.frame(gate), alpha, bright, ground)
  love.graphics.pop()
end
function P.arrival(r, g, e)
  local ground = Ground.of(g.world, e)
  local age, frame = e.spawnAge, P.arrivalFrame(e.spawnAge)
  if not frame then
    return
  end
  local def = Archetypes.of(e)
  local kind = def and def.id or e.kind
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setShader(r.shader)
  local A, span = PortalLook.arriving, PortalLook.arrival
  Ritual.draw(
    r,
    e.x,
    ground + A.lift,
    e.z,
    (A.medallion - age) * 2,
    0,
    nil,
    nil,
    false,
    (1 - age / span) * A.alpha
  )
  paint(r, e.x, e.z, kind, frame, 1 - (age / span) ^ 2, A.bright - age * A.dim, ground)
  love.graphics.pop()
end
-- Pending and arriving portals share a stable back-to-front order. The list
-- borrows bodies only for this draw; no session survives in renderer scratch.
local function backToFront(a, b)
  if a.depth == b.depth then
    return a.order < b.order
  end
  return a.depth > b.depth
end
function P.scene(r, g, gates, time)
  local queue, count = r.portalOrder or {}, 0
  r.portalOrder = queue
  local function add(body, arriving)
    count = count + 1
    local entry = queue[count] or {}
    queue[count] = entry
    entry.body, entry.arriving, entry.order = body, arriving, count
    entry.depth = (body.x - r.camera[1]) * r.forward[1] + (body.z - r.camera[3]) * r.forward[3]
  end
  for _, gate in ipairs(gates or {}) do
    add(gate, false)
  end
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 and P.arrivalFrame(e.spawnAge) then
      add(e, true)
    end
  end
  for i = #queue, count + 1, -1 do
    queue[i] = nil
  end
  table.sort(queue, backToFront)
  for _, entry in ipairs(queue) do
    if entry.arriving then
      P.arrival(r, g, entry.body)
    else
      P.draw(r, entry.body, time, g.world)
    end
    entry.body = nil
  end
end
return P

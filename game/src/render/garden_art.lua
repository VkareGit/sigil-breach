-- Bodily pigment follows the same mouth, flight, ground and eruption clocks as contact.
local GardenPaint = require('src.content.art.garden')
local HazardArt = require('src.render.hazard_art')
local Stream = require('src.combat.stream')
local Anchor = require('src.enemies.contact_anchor')
local Ground = require('src.physics.ground')
local Context = require('src.session.context')
local G = {}
local function resources(r)
  if not r.gardenArt then
    local vertices = {}
    for _ = 1, GardenPaint.segments * 6 do
      vertices[#vertices + 1] = { 0, 0, 0, 0, 0 }
    end
    r.gardenArt = {
      vertices = vertices,
      mesh = r.native:own(
        love.graphics.newMesh(
          { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } },
          vertices,
          'triangles',
          'dynamic'
        )
      ),
    }
  end
  return r.gardenArt
end
local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } }
function G.stream(r, g, e, a)
  local viewer = Context.viewer(g)
  local s = Stream.shape(g, e, a, viewer)
  local mesh, count = resources(r), 0
  local flow = (e.phase or 0) * GardenPaint.flow
  -- Discrete clots travel inside the contact volume. A sheet through the camera
  -- would become a screen-sized carpet instead of a readable bodily discharge.
  for index = GardenPaint.segments - 1, 0, -1 do
    local t = (index + flow % 1) / GardenPaint.segments
    local width = s.startWidth + (s.endWidth - s.startWidth) * t
    local half = s.startHeight + (s.endHeight - s.startHeight) * t
    local x, z = s.x + s.dx * t * s.reach, s.z + s.dz * t * s.reach
    local yaw = math.atan2(viewer.x - x, viewer.z - z)
    local near = math.min(1, math.sqrt((viewer.x - x) ^ 2 + (viewer.z - z) ^ 2) / GardenPaint.near)
    for _, corner in ipairs(corners) do
      count = count + 1
      local v = mesh.vertices[count]
      v[1], v[2], v[3] =
        x - s.x + math.cos(yaw) * corner[1] * width * near,
        -s.fall * t + corner[2] * half * near,
        z - s.z - math.sin(yaw) * corner[1] * width * near
      v[4], v[5] = (corner[1] + 1) * 0.5, (1 - corner[2]) * 0.5
    end
  end
  mesh.mesh:setVertices(mesh.vertices)
  local frame =
    GardenPaint.stream[1 + math.floor((e.phase or 0) * GardenPaint.rate) % #GardenPaint.stream]
  HazardArt.mesh(r, s, frame, mesh.mesh, s.y, 1)
end
function G.cast(r, g, e)
  local a = e.attackSpec
  if not a or not a.art or (a.kind ~= 'stream' and a.kind ~= 'sow' and a.kind ~= 'harvest') then
    return false
  end
  if e.ai == 'strike' and a.kind == 'stream' and e.phase <= a.duration then
    G.stream(r, g, e, a)
  elseif e.ai == 'windup' and a.kind == 'sow' then
    local x, y, z = Anchor.point(g, e, e.phase, e.x, e.z, a.anchor, Context.viewer(g))
    if x then
      local size = GardenPaint.castSize * math.min(1, (e.phase or 0) / a.windup)
      local viewer = Context.viewer(g)
      HazardArt.upright(
        r,
        x,
        Ground.of(g.world, e) + y - size * 0.5,
        z,
        GardenPaint.seed[1],
        size,
        math.atan2(viewer.x - x, viewer.z - z),
        1
      )
    end
  end
  return true
end
function G.pool(r, g, h)
  local radius = h.harvest and h.harvest.radius or h.radius
  local frame = h.delay > 0 and GardenPaint.planted or GardenPaint.mature
  if h.erupting then
    frame = GardenPaint.spent
  end
  HazardArt.circle(r, g, h, frame, radius / GardenPaint.poolRim, 1)
end
function G.eruption(r, g, h)
  if not h.harvest and not h.erupting then
    return
  end
  local viewer = Context.viewer(g)
  local size = h.harvest and h.harvest.radius * 2 or h.radius * 2
  local frame = GardenPaint.harvest[1]
  if h.erupting then
    frame = h.life > h.interval * 0.5 and GardenPaint.harvest[2] or GardenPaint.harvest[3]
  end
  HazardArt.upright(
    r,
    h.x,
    Ground.of(g.world, h),
    h.z,
    frame,
    size,
    math.atan2(viewer.x - h.x, viewer.z - h.z),
    1
  )
end
function G.projectile(r, g, b)
  if b.art ~= 'rot-spit' and b.art ~= 'rot-seed' then
    return false
  end
  local frame = GardenPaint.seed[1 + math.floor(g.time * GardenPaint.rate) % #GardenPaint.seed]
  local size = b.radius * 2 / GardenPaint.seedCore
  local viewer = Context.viewer(g)
  HazardArt.upright(
    r,
    b.x,
    b.y - size * 0.5,
    b.z,
    frame,
    size,
    math.atan2(viewer.x - b.x, viewer.z - b.z),
    1
  )
  return true
end
return G

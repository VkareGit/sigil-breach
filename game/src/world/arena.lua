-- A world built from a map's data (content/maps): the cell grid (0 floor,
-- 1 wall, 2 round pillar), its seals, portal, spawn, braziers, Ember, gates
-- and zones. The map's numbers live in its data file; this only builds.
local Collision = require('src.physics.collision')
local Maps = require('src.content.maps.index')
local Schema = require('src.core.schema')
local Ground = require('src.physics.ground')
local Terrain = require('src.content.tuning').terrain
local SphereCast = require('src.physics.sphere_cast')
local MathX = require('src.core.mathx')
local SupportPath = require('src.physics.support_path')
local Grid = require('src.physics.grid')
local W = {}
local function room(map, x1, z1, x2, z2)
  for z = z1, z2 do
    for x = x1, x2 do
      map[z][x] = 0
    end
  end
end
local function copy(t)
  return Schema.copy(t)
end
-- mode: the session kind (an expedition hides the braziers by the Ember);
-- mapId: the map (default content/maps Maps.default).
function W.new(mode, mapId)
  local data = Maps:get(mapId or Maps.default)
  local width, depth = data.width or data.size, data.depth or data.size
  local w = {
    -- width x depth cells (physics/grid.lua); size only for a square world.
    width = width,
    depth = depth,
    size = width == depth and width or nil,
    mode = mode,
    mapId = data.id,
    map = {},
    seals = {},
    lamps = {},
    decor = copy(data.decor or {}),
    anchors = copy(data.anchors or {}),
    gates = copy(data.gates or {}),
    zones = copy(data.zones),
    -- Height of the walkable floor (physics/ground.lua).
    floor = data.floor or 0,
    stepHeight = data.stepHeight or Terrain.stepHeight,
  }
  for z = 1, Grid.depth(w) do
    w.map[z] = {}
    for x = 1, Grid.width(w) do
      w.map[z][x] = 1
    end
  end
  for _, r in ipairs(data.rooms) do
    room(w.map, r[1], r[2], r[3], r[4])
  end
  for _, p in ipairs(data.pillars or {}) do
    w.map[p[2]][p[1]] = 2
  end
  if data.elevations and #data.elevations > 0 then
    w.elevations = {}
    for _, area in ipairs(data.elevations) do
      for z = area.z1, area.z2 do
        w.elevations[z] = w.elevations[z] or {}
        for x = area.x1, area.x2 do
          w.elevations[z][x] = area.height
        end
      end
    end
  end
  for i, s in ipairs(data.seals or {}) do
    local seal = copy(s)
    seal.active = false
    w.seals[i] = seal
  end
  w.portal = copy(data.portal)
  w.spawn = copy(data.spawn)
  w.ember = copy(data.ember)
  return W.rebuild(w)
end
-- Call after editing map cells. Geometry is rebuilt lazily by the renderer.
function W.rebuild(w)
  local data = Maps:get(w.mapId or Maps.default)
  w.geometryRevision = (w.geometryRevision or 0) + 1
  w.lamps = {}
  for _, p in ipairs(data.lamps or {}) do
    -- The animated pixel brazier is rendered at this existing light anchor.
    w.lamps[#w.lamps + 1] =
      { x = p[1], y = Ground.height(w, p[1], p[2]) + data.lampHeight, z = p[2], phase = #w.lamps }
  end
  if w.mode == 'descent' then
    local ember, clear = data.ember, data.emberClear or 0
    for i = #w.lamps, 1, -1 do
      local l = w.lamps[i]
      if (l.x - ember.x) ^ 2 + (l.z - ember.z) ^ 2 < clear * clear then
        table.remove(w.lamps, i)
      end
    end
  end
  return w
end
-- The zone of a point, by the map's zone rules (the first that holds).
function W.zone(w, x, z)
  local zones = (w and w.zones) or Maps:get(Maps.default).zones
  for _, zone in ipairs(zones) do
    if
      (not zone.xBelow or x < zone.xBelow)
      and (not zone.xAbove or x > zone.xAbove)
      and (not zone.zBelow or z < zone.zBelow)
      and (not zone.zAbove or z > zone.zAbove)
    then
      return zone.name
    end
  end
end
function W.solid(w, x, z, r)
  return Collision.solid(w, x, z, r)
end
function W.move(w, o, dx, dz, r, velocity)
  if not w.elevations then
    return Collision.move(w, o, dx, dz, r, velocity)
  end
  if
    not MathX.finite(dx)
    or not MathX.finite(dz)
    or not MathX.finite(o.x)
    or not MathX.finite(o.z)
  then
    return Collision.move(w, o, dx, dz, r, velocity)
  end
  -- Re-evaluate support at cell crossings. Horizontal contacts still use the
  -- swept solver; subdivision only updates which riser the feet can step onto.
  local offset = o.jump ~= nil and 'jump' or ((o.hp or 1) <= 0 and 'fallY' or 'leapY')
  local sx, sz, collided, lift, progress, dropAt = 0, 0, false, 0, 0, nil
  local length = math.max(math.abs(dx), math.abs(dz))
  repeat
    local span = length > 0 and math.min(1 - progress, Terrain.segment / length) or 1
    local change = SupportPath.firstChange(w, o.x, o.z, dx * span, dz * span)
    if change then
      span = span * change
    end
    local before = Ground.height(w, o.x, o.z)
    local air = o[offset] or 0
    local feet = before + air
    local vx, vz, hit =
      Collision.move(w, o, dx * span, dz * span, r, velocity, feet, air <= 0 and w.stepHeight or 0)
    sx, sz, collided = sx + vx, sz + vz, collided or hit
    local rise = Ground.height(w, o.x, o.z) - before
    progress = progress + span
    if rise < 0 and air == 0 and not dropAt then
      dropAt = progress
    end
    lift = lift + math.max(0, rise - air)
    if rise < 0 or air > 0 then
      o[offset] = math.max(0, air - rise)
      if offset == 'leapY' and o.leapVY == nil then
        o.leapVY = 0
      end
    end
    if hit and span > 0 then
      -- Keep the solver's tangent for the remaining path. Repeatedly asking
      -- for a rejected inward segment near a support boundary could otherwise
      -- create arbitrarily many zero-progress subdivisions.
      dx, dz = vx / span, vz / span
      length = math.max(math.abs(dx), math.abs(dz))
      if length == 0 then
        break
      end
    end
  until progress >= 1
  return sx, sz, collided, lift, dropAt
end
-- Line of sight from (x, z) to (tx, tz). On a heightfield the ray runs
-- between world heights y and ty: a body's own eyes (Rules.eye), or for a
-- place with no body a standing observer's sight plane (terrain.eye).
function W.visible(w, x, z, tx, tz, y, ty)
  if w.elevations then
    y, ty = y or Ground.height(w, x, z) + Terrain.eye, ty or Ground.height(w, tx, tz) + Terrain.eye
    local dx, dy, dz = tx - x, ty - y, tz - z
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length == 0 then
      return true
    end
    local distance =
      SphereCast.world(w, x, y, z, dx / length, dy / length, dz / length, length, 0, 0)
    return distance >= length
  end
  return Collision.visible(w, x, z, tx, tz)
end
-- A body of radius r can travel in a straight line from (x, z) to (tx, tz).
function W.clear(w, x, z, tx, tz, r)
  if w.elevations then
    local probe = { x = x, z = z, jump = 0 }
    local _, _, blocked = W.move(w, probe, tx - x, tz - z, r)
    return not blocked
  end
  return not Collision.solid(w, tx, tz, r) and Collision.cast(w, x, z, tx - x, tz - z, r) == nil
end
-- Breadth-first distance field gives every demon a path around pillars and through doors.
-- Fields are shared (plan v5 G2): one per goal cell and clearance class while
-- the map is unchanged (its geometry revision), at most flowCacheSize of them,
-- the least recently used giving way. A field is read-only.
-- Plan v10 V3: a field covers the window of navigation.window cells around
-- its goal (a map no larger than the window is covered whole, as before);
-- beyond it world/navigation.lua leads a body region by region.
local neighbours = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local Navigation = require('src.content.tuning').navigation
W.flowCacheSize = require('src.content.tuning').flowFields
-- Cells visited by every field built so far (tests read the growth).
W.stats = { visited = 0 }
-- Whether a body of clearance class k fits cell (x, z): class 0 needs the
-- cell to be floor; class k the whole square of k cells around it.
function W.open(w, x, z, k)
  if k == nil or k == 0 then
    return w.map[z] and w.map[z][x] == 0 or false
  end
  for oz = -k, k do
    local row = w.map[z + oz]
    for ox = -k, k do
      if not (row and row[x + ox] == 0) then
        return false
      end
    end
  end
  return true
end
-- The clearance class of a body of radius r (content/tuning.lua: navigation).
function W.class(r)
  local k = 0
  for i, limit in ipairs(Navigation.classes) do
    if r > limit then
      k = i
    end
  end
  return k
end
local function flowField(w, sx, sz, class)
  local qx, qz, head, tail = { sx }, { sz }, 1, 1
  local dist = {}
  local window = Navigation.window
  dist[Grid.key(w, sx, sz)] = 0
  while head <= tail do
    local px, pz = qx[head], qz[head]
    head = head + 1
    W.stats.visited = W.stats.visited + 1
    local d = dist[Grid.key(w, px, pz)]
    for i = 1, #neighbours do
      local a = neighbours[i]
      local nx, nz = px + a[1], pz + a[2]
      local id = Grid.key(w, nx, nz)
      -- Search runs backwards from the goal: a neighbour must be able to
      -- climb from its own floor to this cell, not the other way round.
      local climb = Ground.cell(w, px, pz) - Ground.cell(w, nx, nz)
      if
        math.abs(nx - sx) <= window
        and math.abs(nz - sz) <= window
        and W.open(w, nx, nz, class)
        and dist[id] == nil
        and climb <= (w.stepHeight or Terrain.stepHeight)
      then
        dist[id] = d + 1
        tail = tail + 1
        qx[tail], qz[tail] = nx, nz
      end
    end
  end
  return dist
end
-- class (optional): the clearance class of the bodies following it (W.class).
function W.flow(w, x, z, class)
  class = class or 0
  local sx, sz = math.floor(x + 0.5), math.floor(z + 0.5)
  local cache = w.flows
  if not cache or cache.revision ~= w.geometryRevision then
    cache = { revision = w.geometryRevision, count = 0, clock = 0, fields = {} }
    w.flows = cache
  end
  cache.clock = cache.clock + 1
  local byClass = cache.fields[class]
  if not byClass then
    byClass = {}
    cache.fields[class] = byClass
  end
  local goal = Grid.key(w, sx, sz)
  local entry = byClass[goal]
  if not entry then
    if cache.count >= W.flowCacheSize then
      -- The least recently used field gives way (ties: lowest class, goal).
      local oldClass, oldGoal, oldest
      for k, fields in pairs(cache.fields) do
        for id, item in pairs(fields) do
          if
            not oldest
            or item.used < oldest
            or (item.used == oldest and (k < oldClass or (k == oldClass and id < oldGoal)))
          then
            oldClass, oldGoal, oldest = k, id, item.used
          end
        end
      end
      cache.fields[oldClass][oldGoal] = nil
      cache.count = cache.count - 1
    end
    entry = { field = flowField(w, sx, sz, class) }
    byClass[goal], cache.count = entry, cache.count + 1
  end
  entry.used = cache.clock
  return entry.field
end
return W

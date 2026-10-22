-- A world built from a map's data (content/maps): the cell grid (0 floor,
-- 1 wall, 2 round pillar), its seals, portal, spawn, braziers, Ember, gates
-- and zones. The map's numbers live in its data file; this only builds.
local Collision = require('src.physics.collision')
local Maps = require('src.content.maps.index')
local W = {}
local function room(map, x1, z1, x2, z2)
  for z = z1, z2 do
    for x = x1, x2 do
      map[z][x] = 0
    end
  end
end
local function copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end
-- mode: the session kind (an expedition hides the braziers by the Ember);
-- mapId: the map (default content/maps Maps.default).
function W.new(mode, mapId)
  local data = Maps:get(mapId or Maps.default)
  local w = {
    size = data.size,
    mode = mode,
    mapId = data.id,
    map = {},
    seals = {},
    lamps = {},
    decor = {},
    gates = data.gates or {},
    zones = data.zones,
    -- Height of the walkable floor (physics/ground.lua).
    floor = data.floor or 0,
  }
  for z = 1, w.size do
    w.map[z] = {}
    for x = 1, w.size do
      w.map[z][x] = 1
    end
  end
  for _, r in ipairs(data.rooms) do
    room(w.map, r[1], r[2], r[3], r[4])
  end
  for _, p in ipairs(data.pillars or {}) do
    w.map[p[2]][p[1]] = 2
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
    w.lamps[#w.lamps + 1] = { x = p[1], y = data.lampHeight, z = p[2], phase = #w.lamps }
  end
  if w.mode == 'descent' then
    local ember, clear = data.ember, data.emberClear
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
    then
      return zone.name
    end
  end
end
function W.solid(w, x, z, r)
  return Collision.solid(w, x, z, r)
end
function W.move(w, o, dx, dz, r, velocity)
  return Collision.move(w, o, dx, dz, r, velocity)
end
function W.visible(w, x, z, tx, tz)
  return Collision.visible(w, x, z, tx, tz)
end
-- A body of radius r can travel in a straight line from (x, z) to (tx, tz).
function W.clear(w, x, z, tx, tz, r)
  return not Collision.solid(w, tx, tz, r) and Collision.cast(w, x, z, tx - x, tz - z, r) == nil
end
-- Breadth-first distance field gives every demon a path around pillars and through doors.
-- Fields are shared (plan v5 G2): one per goal cell while the map is unchanged
-- (its geometry revision), at most flowCacheSize of them. A field is read-only.
local neighbours = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
W.flowCacheSize = require('src.content.tuning').flowFields
local function flowField(w, sx, sz)
  local qx, qz, head, tail = { sx }, { sz }, 1, 1
  local dist = {}
  dist[sz * w.size + sx] = 0
  while head <= tail do
    local px, pz = qx[head], qz[head]
    head = head + 1
    local d = dist[pz * w.size + px]
    for i = 1, #neighbours do
      local a = neighbours[i]
      local nx, nz = px + a[1], pz + a[2]
      local id = nz * w.size + nx
      if w.map[nz] and w.map[nz][nx] == 0 and dist[id] == nil then
        dist[id] = d + 1
        tail = tail + 1
        qx[tail], qz[tail] = nx, nz
      end
    end
  end
  return dist
end
function W.flow(w, x, z)
  local sx, sz = math.floor(x + 0.5), math.floor(z + 0.5)
  local cache = w.flows
  if not cache or cache.revision ~= w.geometryRevision then
    cache = { revision = w.geometryRevision, count = 0, fields = {} }
    w.flows = cache
  end
  local goal = sz * w.size + sx
  local field = cache.fields[goal]
  if not field then
    if cache.count >= W.flowCacheSize then
      cache.fields, cache.count = {}, 0
    end
    field = flowField(w, sx, sz)
    cache.fields[goal], cache.count = field, cache.count + 1
  end
  return field
end
return W

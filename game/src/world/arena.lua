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
local Save = require('src.storage.save')
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
-- The seals of a world that are broken (active): the count every mode and
-- screen reads, never a counter of its own (plan v11 E2).
function W.activeSeals(w)
  local count = 0
  for _, seal in ipairs(w.seals or {}) do
    if seal.active then
      count = count + 1
    end
  end
  return count
end
-- The first count seals broken, the rest whole (a checkpoint's progress).
function W.breakSeals(w, count)
  for i, seal in ipairs(w.seals or {}) do
    seal.active = i <= count
  end
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
    -- The map's hidden sigil was found (plan v11 E2: the world's, not a
    -- mode's; the classic arena finds it, the expedition saves it).
    secretFound = false,
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
  -- Decks (plan v10 V3): slabs above the floor, { bottom, top } over the
  -- datum, shared by the cells of one deck. A world with decks keeps a
  -- heightfield (flat where none is authored), so every height-aware path
  -- of movement, sight and shots runs on it.
  if data.decks and #data.decks > 0 then
    w.elevations = w.elevations or {}
    w.decks = {}
    local merged = {}
    for _, area in ipairs(data.decks) do
      local slab = { area.top - area.thickness, area.top, area.bottoms and copy(area.bottoms) }
      local alone = { slab }
      for z = area.z1, area.z2 do
        w.decks[z] = w.decks[z] or {}
        for x = area.x1, area.x2 do
          local below = w.decks[z][x]
          if not below then
            w.decks[z][x] = alone
          else
            local key = tostring(below) .. '+' .. tostring(slab)
            if not merged[key] then
              local list = { unpack(below) }
              list[#list + 1] = slab
              table.sort(list, function(a, b)
                return a[1] < b[1]
              end)
              merged[key] = list
            end
            w.decks[z][x] = merged[key]
          end
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
    -- The animated pixel brazier is rendered at this existing light anchor;
    -- p[3] (optional): it stands on the surface under that height (a deck).
    local stand = p[3] and Ground.height(w, p[1], p[2], (w.floor or 0) + p[3])
      or Ground.height(w, p[1], p[2])
    local height = p.lightHeight or data.lampHeight
    w.lamps[#w.lamps + 1] = {
      x = p[1],
      y = stand + height,
      z = p[2],
      phase = #w.lamps,
      level = p[3] and stand,
      color = p.color and copy(p.color),
      scale = p.scale,
      brightness = p.brightness,
    }
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
-- height (optional): the body's height over its feet; a deck it would
-- strike with its head stops it (plan v10 V3). On a world with decks the
-- body keeps the surface it stands on in o.level.
function W.move(w, o, dx, dz, r, velocity, height)
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
    local before = Ground.of(w, o)
    local air = o[offset] or 0
    local feet = before + air
    local climb = air <= 0 and w.stepHeight or 0
    local vx, vz, hit =
      Collision.move(w, o, dx * span, dz * span, r, velocity, feet, climb, height and feet + height)
    sx, sz, collided = sx + vx, sz + vz, collided or hit
    local after = Ground.height(w, o.x, o.z, feet + climb)
    if w.decks then
      o.level = after
    end
    local rise = after - before
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
-- place with no body a standing observer's sight plane (terrain.eye) over
-- the floor, or over the surface under level / tlevel (a deck, plan v10 V3).
function W.visible(w, x, z, tx, tz, y, ty, level, tlevel)
  if w.elevations then
    y = y or Ground.height(w, x, z, level) + Terrain.eye
    ty = ty or Ground.height(w, tx, tz, tlevel) + Terrain.eye
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
-- A body of radius r can travel in a straight line from (x, z) to (tx, tz)
-- (level, height: the surface it stands on and its height; goal: the surface
-- it must arrive on, on a world with decks; plan v10 V3).
function W.clear(w, x, z, tx, tz, r, level, height, goal)
  if w.elevations then
    local probe = { x = x, z = z, jump = 0, level = level }
    local _, _, blocked = W.move(w, probe, tx - x, tz - z, r, nil, height)
    if w.decks and goal and not blocked then
      return math.abs(Ground.of(w, probe) - Ground.height(w, tx, tz, goal)) < Terrain.stepHeight
    end
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
-- cell to be floor; class k the whole square of k cells around it (only
-- the class's width counts here: k % 4, W.class).
function W.open(w, x, z, k)
  k = k and k % 4 or 0
  if k == 0 then
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
-- The clearance class of a body of radius r (content/tuning.lua: navigation)
-- and, on a world with decks, of height tall (Rules.tall): a body taller
-- than heights[t] needs more room under a deck; the class counts it in fours.
function W.class(r, tall)
  local k = 0
  for i, limit in ipairs(Navigation.classes) do
    if r > limit then
      k = i
    end
  end
  local t = 0
  for i, limit in ipairs(Navigation.heights) do
    if tall and tall > limit then
      t = i
    end
  end
  return k + 4 * t
end
-- The room a body of class k needs under a deck (m).
function W.headroom(k)
  return Navigation.heights[math.floor(k / 4) + 1] or math.huge
end
-- Nodes of the walk graph (plan v10 V3): the floor of a cell (layer 0) or,
-- on a world with decks, the top of its n-th deck (layer n). A node's key is
-- its cell's key, past every cell once per layer below it.
local function stride(w)
  return Grid.key(w, Grid.width(w) + 1, Grid.depth(w) + 1) + 1
end
function W.node(w, x, z, layer)
  return Grid.key(w, x, z) + (layer or 0) * stride(w)
end
-- The layer of the surface at height h (over the datum) in cell (x, z).
function W.layer(w, x, z, h)
  local decks = Ground.decks(w, x, z)
  local layer = 0
  if decks and h then
    for i, deck in ipairs(decks) do
      if deck[2] <= h then
        layer = i
      end
    end
  end
  return layer
end
-- The surface (height over the datum) of layer n of cell (x, z).
function W.level(w, x, z, layer)
  if layer and layer > 0 then
    return Ground.decks(w, x, z)[layer][2]
  end
  return Ground.cell(w, x, z)
end
-- Whether a body of class k can stand on the surface h of cell (x, z):
-- its room under the next deck above.
local function roomy(w, x, z, h, k)
  local top = Ground.ceiling(w, x, z, (w.floor or 0) + h)
  return not top or top - (w.floor or 0) - h >= W.headroom(k)
end
-- The layer a body standing on surface h of one cell lands on stepping into
-- cell (x, z) (nil: it cannot: a riser too high or a deck in its way).
function W.step(w, x, z, h, k)
  local step = w.stepHeight or Terrain.stepHeight
  if not w.decks then
    return Ground.cell(w, x, z) - h <= step and 0 or nil
  end
  local landing = Ground.surface(w, x, z, h + step)
  if landing - h > step or not roomy(w, x, z, landing, k) then
    return nil
  end
  local top = Ground.ceiling(w, x, z, (w.floor or 0) + landing)
  if top and top - (w.floor or 0) - h < W.headroom(k) then
    return nil
  end
  return W.layer(w, x, z, landing)
end
local none = {}
local function flowField(w, sx, sz, class, layer)
  local qx, qz, ql, head, tail = { sx }, { sz }, { layer }, 1, 1
  local dist = {}
  local window = Navigation.window
  dist[W.node(w, sx, sz, layer)] = 0
  while head <= tail do
    local px, pz, pl = qx[head], qz[head], ql[head]
    head = head + 1
    W.stats.visited = W.stats.visited + 1
    local d = dist[W.node(w, px, pz, pl)]
    local here = W.level(w, px, pz, pl)
    for i = 1, #neighbours do
      local a = neighbours[i]
      local nx, nz = px + a[1], pz + a[2]
      -- Search runs backwards from the goal: a neighbour must be able to
      -- climb from its own floor to this cell, not the other way round.
      -- Every surface of the neighbour is a node (its floor, its decks).
      local decks = w.decks and Ground.decks(w, nx, nz) or none
      for nl = 0, #decks do
        local id = W.node(w, nx, nz, nl)
        local there = W.level(w, nx, nz, nl)
        local climb = here - there
        if
          math.abs(nx - sx) <= window
          and math.abs(nz - sz) <= window
          and W.open(w, nx, nz, class)
          and dist[id] == nil
          and climb <= (w.stepHeight or Terrain.stepHeight)
          and (
            not w.decks
            or (roomy(w, nx, nz, there, class) and W.step(w, px, pz, there, class) == pl)
          )
        then
          dist[id] = d + 1
          tail = tail + 1
          qx[tail], qz[tail], ql[tail] = nx, nz, nl
        end
      end
    end
  end
  return dist
end
-- class (optional): the clearance class of the bodies following it (W.class);
-- level (optional): the goal's surface (world height) on a world with decks.
function W.flow(w, x, z, class, level)
  class = class or 0
  local sx, sz = math.floor(x + 0.5), math.floor(z + 0.5)
  local layer = 0
  if w.decks and level then
    layer = W.layer(w, sx, sz, Ground.surface(w, sx, sz, level - (w.floor or 0)))
  end
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
  local goal = W.node(w, sx, sz, layer)
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
    entry = { field = flowField(w, sx, sz, class, layer) }
    byClass[goal], cache.count = entry, cache.count + 1
  end
  entry.used = cache.clock
  return entry.field
end
-- The session save's section of the world (plan v10 V4): which map, in
-- which mode, every cell as it is now (edits included) and the seals lit.
-- The rest (elevations, decks, lamps, places) is the map's own data.
local Tiles, zero = '^[012]*$', ('0'):byte()
Save.declare({
  name = 'map',
  file = 'session',
  version = 1,
  schema = Schema:new('map', {
    id = { type = 'string', required = true },
    mode = { type = 'string', required = true },
    rows = { type = 'table', required = true },
    seals = { type = 'table', required = true },
  }),
  pack = function(g)
    local w, rows, seals = g.world, {}, {}
    for z = 1, Grid.depth(w) do
      rows[z] = table.concat(w.map[z])
    end
    for i, seal in ipairs(w.seals) do
      seals[i] = seal.active == true
    end
    return { id = w.mapId, mode = w.mode, rows = rows, seals = seals }
  end,
  unpack = function(t)
    assert(Maps:has(t.id), 'unknown map ' .. tostring(t.id))
    local data = Maps:get(t.id)
    local width, depth = data.width or data.size, data.depth or data.size
    assert(#t.rows == depth, 'map rows')
    for z = 1, depth do
      local row = t.rows[z]
      assert(type(row) == 'string' and #row == width and row:match(Tiles), 'map row ' .. z)
    end
    assert(#t.seals == #(data.seals or {}), 'map seals')
    for _, active in ipairs(t.seals) do
      assert(type(active) == 'boolean', 'map seal')
    end
    return t
  end,
  restore = function(g, t)
    if not g.world or g.world.mapId ~= t.id or g.world.mode ~= t.mode then
      g.world = W.new(t.mode, t.id)
    end
    local w = g.world
    for z, row in ipairs(t.rows) do
      for x = 1, #row do
        w.map[z][x] = row:byte(x) - zero
      end
    end
    for i, active in ipairs(t.seals) do
      w.seals[i].active = active
    end
    W.rebuild(w)
  end,
})
return W

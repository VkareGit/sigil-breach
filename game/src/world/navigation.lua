-- Navigation beyond the exact field (plan v10 V3). The map is cut into
-- sectors of navigation.sector cells; each sector into regions (its nodes a
-- body of a clearance class can walk between without leaving the sector).
-- A node is a cell's floor or, on a world with decks, one of its decks
-- (world/arena.lua: W.node). Regions are linked where a body can step from
-- one into a neighbouring sector's region. A body farther from its goal than
-- the field's window crosses region by region: it walks to the border of its
-- region facing the next region on the way (a breadth-first search over
-- regions from the goal, run backwards like the fine field), then on. Inside
-- the window the exact field of world/arena.lua leads it as before. Built
-- per geometry revision and class, outside the session's data (a cache of
-- the world's shape).
local Grid = require('src.physics.grid')
local Ground = require('src.physics.ground')
local Tuning = require('src.content.tuning').navigation
local World = require('src.world.arena')
local Navigation = {}
local cache = setmetatable({}, { __mode = 'k' })
local neighbours = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local none = {}
-- Nodes visited building regions and crossings (tests read the growth).
Navigation.stats = { visited = 0 }
-- The layers of cell (x, z): 0 (its floor) and one per deck.
local function layers(w, x, z)
  return #(w.decks and Ground.decks(w, x, z) or none)
end
-- Whether a body of class k may step from node a to node b: b open for the
-- class and the step from a's surface landing on b's (climbing at most a
-- step, dropping any height, no deck in the way).
local function passes(w, ax, az, al, bx, bz, bl, class)
  return World.open(w, bx, bz, class)
    and World.step(w, bx, bz, World.level(w, ax, az, al), class) == bl
end
-- Whether a body of class k can stand on node (x, z, l).
local function stands(w, x, z, l, class)
  if not World.open(w, x, z, class) then
    return false
  end
  return l == 0 and not w.decks or World.step(w, x, z, World.level(w, x, z, l), class) == l
end
local function sectorOf(x, z)
  local s = Tuning.sector
  return math.floor((x - 1) / s), math.floor((z - 1) / s)
end
-- Regions of one class: region id per node key, regions as lists of keys,
-- and links { [from] = { [to] = { border nodes of from facing to } } }.
local function build(w, class)
  local nav = { region = {}, cells = {}, links = {} }
  local width, depth = Grid.width(w), Grid.depth(w)
  local count = 0
  for z = 1, depth do
    for x = 1, width do
      for l = 0, layers(w, x, z) do
        local key = World.node(w, x, z, l)
        if nav.region[key] == nil and stands(w, x, z, l, class) then
          count = count + 1
          local id, sx, sz = count, sectorOf(x, z)
          local cells, qx, qz, ql, head = { key }, { x }, { z }, { l }, 1
          nav.region[key] = id
          while head <= #qx do
            local px, pz, pl = qx[head], qz[head], ql[head]
            head = head + 1
            Navigation.stats.visited = Navigation.stats.visited + 1
            for _, a in ipairs(neighbours) do
              local nx, nz = px + a[1], pz + a[2]
              local tx, tz = sectorOf(nx, nz)
              for nl = 0, layers(w, nx, nz) do
                local nk = World.node(w, nx, nz, nl)
                -- Within the sector, both ways: a region is mutually walkable.
                if
                  tx == sx
                  and tz == sz
                  and nav.region[nk] == nil
                  and passes(w, px, pz, pl, nx, nz, nl, class)
                  and passes(w, nx, nz, nl, px, pz, pl, class)
                then
                  nav.region[nk] = id
                  cells[#cells + 1] = nk
                  qx[#qx + 1], qz[#qz + 1], ql[#ql + 1] = nx, nz, nl
                end
              end
            end
          end
          nav.cells[id] = cells
        end
      end
    end
  end
  -- Links: a step from a node of one region into a node of another.
  for z = 1, depth do
    for x = 1, width do
      for l = 0, layers(w, x, z) do
        local from = nav.region[World.node(w, x, z, l)]
        if from then
          for _, a in ipairs(neighbours) do
            local nx, nz = x + a[1], z + a[2]
            for nl = 0, layers(w, nx, nz) do
              local to = nav.region[World.node(w, nx, nz, nl)]
              if to and to ~= from and passes(w, x, z, l, nx, nz, nl, class) then
                nav.links[from] = nav.links[from] or {}
                local border = nav.links[from][to]
                if not border then
                  border = {}
                  nav.links[from][to] = border
                end
                border[#border + 1] = { x, z, l, nx, nz, nl }
              end
            end
          end
        end
      end
    end
  end
  nav.count = count
  nav.class = class
  nav.toward = {}
  nav.crossings = {}
  return nav
end
local function regions(w, class)
  local byWorld = cache[w]
  if not byWorld or byWorld.revision ~= w.geometryRevision then
    byWorld = { revision = w.geometryRevision }
    cache[w] = byWorld
  end
  local nav = byWorld[class]
  if not nav then
    nav = build(w, class)
    byWorld[class] = nav
  end
  return nav
end
-- Region steps to the goal's region from every region that reaches it.
local function toward(nav, goal)
  local dist = nav.toward[goal]
  if dist then
    return dist
  end
  -- Backwards: who can step into a region already reached.
  local into = {}
  for from, targets in pairs(nav.links) do
    for to in pairs(targets) do
      into[to] = into[to] or {}
      into[to][#into[to] + 1] = from
    end
  end
  for _, list in pairs(into) do
    table.sort(list)
  end
  dist = { [goal] = 0 }
  local queue, head = { goal }, 1
  while head <= #queue do
    local r = queue[head]
    head = head + 1
    for _, from in ipairs(into[r] or {}) do
      if dist[from] == nil then
        dist[from] = dist[r] + 1
        queue[#queue + 1] = from
      end
    end
  end
  -- A field per goal, kept for the next to ask: a long session asks for many.
  nav.fields = (nav.fields or 0) + 1
  if nav.fields > Tuning.fieldsKept then
    nav.toward, nav.fields = {}, 1
  end
  nav.toward[goal] = dist
  return dist
end
-- The cell and layer of a point at (x, z) on the surface under level.
local function nodeAt(w, x, z, level)
  local cx, cz = math.floor(x + 0.5), math.floor(z + 0.5)
  local l = 0
  if w.decks and level then
    l = World.layer(w, cx, cz, Ground.surface(w, cx, cz, level - (w.floor or 0)))
  end
  return cx, cz, l
end
local function regionAt(w, nav, x, z, level)
  local cx, cz, l = nodeAt(w, x, z, level)
  return nav.region[World.node(w, cx, cz, l)]
end
-- Whether (x, z) is beyond the exact field around a goal at (gx, gz).
function Navigation.beyond(x, z, gx, gz)
  local window = Tuning.window
  return math.abs(math.floor(x + 0.5) - math.floor(gx + 0.5)) > window
    or math.abs(math.floor(z + 0.5) - math.floor(gz + 0.5)) > window
end
-- The next region on the way and its distance in regions (nil: no way).
local function nextRegion(nav, from, dist)
  local best, bestD
  for to in pairs(nav.links[from] or {}) do
    local d = dist[to]
    if d and (not bestD or d < bestD or (d == bestD and to < best)) then
      best, bestD = to, d
    end
  end
  return best, bestD
end
-- Distances inside a region to its border nodes facing the next region.
local function crossing(w, nav, from, to)
  local key = from .. '>' .. to
  local field = nav.crossings[key]
  if field then
    return field
  end
  field = {}
  local qx, qz, ql = {}, {}, {}
  for _, b in ipairs(nav.links[from][to]) do
    local k = World.node(w, b[1], b[2], b[3])
    if field[k] == nil then
      field[k] = 0
      qx[#qx + 1], qz[#qz + 1], ql[#ql + 1] = b[1], b[2], b[3]
    end
  end
  local head = 1
  while head <= #qx do
    local px, pz, pl = qx[head], qz[head], ql[head]
    head = head + 1
    Navigation.stats.visited = Navigation.stats.visited + 1
    local d = field[World.node(w, px, pz, pl)]
    for _, a in ipairs(neighbours) do
      local nx, nz = px + a[1], pz + a[2]
      for nl = 0, layers(w, nx, nz) do
        local nk = World.node(w, nx, nz, nl)
        if
          nav.region[nk] == from
          and field[nk] == nil
          and passes(w, nx, nz, nl, px, pz, pl, nav.class)
        then
          field[nk] = d + 1
          qx[#qx + 1], qz[#qz + 1], ql[#ql + 1] = nx, nz, nl
        end
      end
    end
  end
  nav.crossings[key] = field
  return field
end
-- Where a body at (x, z) of clearance class walks next to reach (gx, gz)
-- from beyond the exact field: a cell centre (nil when there is no way).
-- level, goalLevel (optional): the surfaces of the body and of the goal on a
-- world with decks.
function Navigation.waypoint(w, x, z, gx, gz, class, level, goalLevel)
  local nav = regions(w, class or 0)
  local from, goal = regionAt(w, nav, x, z, level), regionAt(w, nav, gx, gz, goalLevel)
  if not from or not goal then
    return nil
  end
  if from == goal then
    return gx, gz
  end
  local to = nextRegion(nav, from, toward(nav, goal))
  if not to then
    return nil
  end
  local field = crossing(w, nav, from, to)
  local cx, cz, cl = nodeAt(w, x, z, level)
  local here = field[World.node(w, cx, cz, cl)]
  if here == 0 then
    -- On the border: step into the next region.
    for _, b in ipairs(nav.links[from][to]) do
      if b[1] == cx and b[2] == cz and b[3] == cl then
        return b[4], b[5]
      end
    end
  end
  local best, bx, bz = here or math.huge, nil, nil
  local surface = World.level(w, cx, cz, cl)
  for _, a in ipairs(neighbours) do
    local nx, nz = cx + a[1], cz + a[2]
    local nl = World.step(w, nx, nz, surface, nav.class)
    local d = nl and field[World.node(w, nx, nz, nl)]
    if d and d < best then
      best, bx, bz = d, nx, nz
    end
  end
  return bx, bz
end
-- The walking distance from (x, z) to (gx, gz) in cells: exact inside the
-- field's window, else the region crossings times the sector size; nil when
-- (x, z) cannot reach the goal. level, goalLevel as for waypoint.
function Navigation.distance(w, x, z, gx, gz, class, level, goalLevel)
  local field = World.flow(w, gx, gz, class, goalLevel)
  local cx, cz, cl = nodeAt(w, x, z, level)
  local exact = field[World.node(w, cx, cz, cl)]
  if exact or not Navigation.beyond(x, z, gx, gz) then
    return exact
  end
  local nav = regions(w, class or 0)
  local from, goal = regionAt(w, nav, x, z, level), regionAt(w, nav, gx, gz, goalLevel)
  local steps = from and goal and toward(nav, goal)[from]
  return steps and steps * Tuning.sector or nil
end
return Navigation

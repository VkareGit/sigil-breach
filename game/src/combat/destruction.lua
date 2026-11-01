-- What can be broken in a world. Blows come from resolved shots and blasts, so
-- a wall or a body before a thing still protects it; the state lives in the
-- world and rendering only reads it. No simulation random stream is used.
local Ballistics = require('src.combat.ballistics')
local Damage = require('src.combat.damage')
local Hit = require('src.combat.hit')
local Kinds = require('src.content.breakables')
local Ruin = require('src.content.maps.breakables')
local Copy = require('src.core.schema').copy
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local Signal = require('src.session.signal')
local Save = require('src.storage.save')
local World = require('src.world.arena')
local Tuning = require('src.content.tuning').scenery
local Bodies = require('src.combat.bodies')
local D = {}
local sqrt, floor, min, max = math.sqrt, math.floor, math.min, math.max
local NONE = {}
local indexes = setmetatable({}, { __mode = 'k' })
function D.list(world)
  return (world.decor or NONE).breakables or NONE
end
local function index(world)
  local found = indexes[world]
  if not found then
    found = { byId = {}, cells = {} }
    for _, def in ipairs(D.list(world)) do
      found.byId[def.id] = def
      if Kinds[def.kind].walk then
        local x, z = floor(def.from[1] + 0.5), floor(def.from[3] + 0.5)
        local x2, z2 = floor(def.to[1] + 0.5), floor(def.to[3] + 0.5)
        for cz = min(z, z2), max(z, z2) do
          found.cells[cz] = found.cells[cz] or {}
          for cx = min(x, x2), max(x, x2) do
            found.cells[cz][cx] = found.cells[cz][cx] or {}
            table.insert(found.cells[cz][cx], def)
          end
        end
      end
    end
    indexes[world] = found
  end
  return found
end
-- 0 whole, 1 wounded, 2 broken, and the time it broke.
function D.stage(world, id)
  local state = world.destruction and world.destruction[id]
  if not state then
    return 0
  end
  if state.at then
    return 2, state.at
  end
  local def = index(world).byId[id]
  local kind = Kinds[def.kind]
  return state.damage >= kind.health * (kind.cracked or 2) and 1 or 0
end
function D.broken(world, id)
  local state = world.destruction and world.destruction[id]
  return state ~= nil and state.at ~= nil
end
-- What a ruin replaces is kept, so a reset or a load can put it back.
local function keep(world, name, x, z, value)
  world.ruinKept = world.ruinKept or {}
  local kept = world.ruinKept
  kept[name] = kept[name] or {}
  local key = z .. ':' .. x
  if kept[name][key] == nil then
    kept[name][key] = { x = x, z = z, value = value == nil and false or value }
  end
end
local function raise(world, x, z, height)
  keep(
    world,
    'elevations',
    x,
    z,
    world.elevations and world.elevations[z] and world.elevations[z][x]
  )
  world.elevations = world.elevations or {}
  world.elevations[z] = world.elevations[z] or {}
  world.elevations[z][x] = max(world.elevations[z][x] or 0, height)
end
local function collapse(world, def)
  local x, z = def.cell[1], def.cell[2]
  keep(world, 'tiles', x, z, world.map[z][x])
  world.map[z][x] = 0
  local hole = def.hole
  local reach = Ruin.holeReach(hole)
  for cz = floor(hole.z) - reach, floor(hole.z) + reach + 1 do
    local row = world.decks and world.decks[cz]
    for cx = floor(hole.x) - reach, floor(hole.x) + reach + 1 do
      if row and row[cx] and Ruin.inHole(hole, cx, cz) then
        keep(world, 'decks', cx, cz, row[cx])
        row[cx] = nil
      end
    end
  end
  for _, cell in ipairs(def.rubble) do
    raise(world, cell[1], cell[2], cell[3])
  end
  local tear = def.tear
  if tear then
    world.solidTop.cells = world.solidTop.cells or {}
    local cells = world.solidTop.cells
    for cz = floor(tear.z - tear.half), floor(tear.z + tear.half) + 1 do
      local top = Ruin.tearHeight(tear, cz)
      if top < math.huge then
        cells[cz] = cells[cz] or {}
        for _, cx in ipairs(tear.columns) do
          cells[cz][cx] = max(top, 0.5)
        end
      end
    end
  end
end
local function repair(world)
  local kept = world.ruinKept
  if not kept then
    return false
  end
  for _, entry in pairs(kept.tiles or NONE) do
    world.map[entry.z][entry.x] = entry.value
  end
  for _, entry in pairs(kept.decks or NONE) do
    world.decks[entry.z][entry.x] = entry.value
  end
  for _, entry in pairs(kept.elevations or NONE) do
    world.elevations[entry.z][entry.x] = entry.value or nil
  end
  if world.solidTop then
    world.solidTop.cells = nil
  end
  world.ruinKept = nil
  return true
end
local function middle(def)
  local a, b = def.from, def.to
  return (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2
end
local blow
local function smash(g, def, owner)
  local world, kind = g.world, Kinds[def.kind]
  local state = world.destruction[def.id]
  state.at = g.elapsed or 0
  state.damage = kind.health
  local x, y, z = middle(def)
  if kind.collapses then
    collapse(world, def)
    World.opened(world)
    require('src.combat.observation').invalidate(g)
    local crush = kind.crush
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      local dx, dz = e.x - def.cell[1], e.z - def.cell[2]
      if e.hp > 0 and dx * dx + dz * dz < crush.radius * crush.radius then
        Hit.wound(g, e, crush.damage, 'collapse', nil, owner)
      end
    end
    Signal(g, 'StructureCollapsed', { id = def.id, thing = def.kind, x = x, y = y, z = z })
    -- What stood on it or under it goes with it.
    for _, other in ipairs(D.list(world)) do
      if not D.broken(world, other.id) then
        local ox, oz = other.from[1] - def.cell[1], other.from[3] - def.cell[2]
        local near = Kinds[other.kind].walk and ox * ox + oz * oz < crush.radius * crush.radius
        if other.supports == def.id or near then
          blow(g, other, math.huge, owner)
        end
      end
    end
  else
    Signal(g, 'SceneryBroken', { id = def.id, thing = def.kind, x = x, y = y, z = z })
  end
end
blow = function(g, def, amount, owner, point)
  local world, kind = g.world, Kinds[def.kind]
  world.destruction = world.destruction or {}
  local state = world.destruction[def.id]
  if not state then
    state = { damage = 0 }
    world.destruction[def.id] = state
  end
  if state.at then
    return
  end
  state.damage = min(kind.health, state.damage + amount)
  if state.damage >= kind.health then
    smash(g, def, owner)
  else
    local x, y, z = middle(def)
    if point then
      x, y, z = point[1], point[2], point[3]
    end
    Signal(g, 'SceneryStruck', {
      id = def.id,
      thing = def.kind,
      x = x,
      y = y,
      z = z,
      share = state.damage / kind.health,
    })
  end
end
-- Closest approach of a resolved ray to a thing's segment: the distance along
-- the ray, the distance between them, and the point on the ray.
local function approach(ox, oy, oz, dx, dy, dz, length, a, b)
  local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local wx, wy, wz = ox - a[1], oy - a[2], oz - a[3]
  local uu = ux * ux + uy * uy + uz * uz
  local du = dx * ux + dy * uy + dz * uz
  local dw = dx * wx + dy * wy + dz * wz
  local uw = ux * wx + uy * wy + uz * wz
  local det = uu - du * du
  local t = det > 1e-9 and (du * uw - uu * dw) / det or 0
  t = max(0, min(length, t))
  local s = uu > 1e-9 and max(0, min(1, (t * du + uw) / uu)) or 0
  t = max(0, min(length, s * du - dw))
  local px, py, pz = ox + dx * t, oy + dy * t, oz + dz * t
  local qx, qy, qz = a[1] + ux * s, a[2] + uy * s, a[3] + uz * s
  local ex, ey, ez = px - qx, py - qy, pz - qz
  return t, sqrt(ex * ex + ey * ey + ez * ez), px, py, pz
end
-- VolleyResolved: every ray has already stopped at its first solid contact.
function D.volley(g, event)
  local report, attack = event.report, event.attack
  local list = D.list(g.world)
  if #list == 0 or not report or not report.origin or not attack or not report.rays then
    return
  end
  local origin = report.origin
  for _, def in ipairs(list) do
    if not D.broken(g.world, def.id) then
      local damage, point = 0, nil
      for _, ray in ipairs(report.rays) do
        local t, gap, px, py, pz = approach(
          origin[1],
          origin[2],
          origin[3],
          ray.dx,
          ray.dy,
          ray.dz,
          ray.distance,
          def.from,
          def.to
        )
        if gap <= def.radius + Tuning.rayGrace then
          local reach = Kinds[def.kind].mass and 0 or t
          damage = damage + Damage.resolve(attack, def, reach, 'body')
          point = point or { px, py, pz }
        end
      end
      if damage > 0 then
        blow(g, def, damage, report.actor, point)
      end
    end
  end
end
-- A charge's blast: shielded by whatever stands between it and the thing.
function D.blast(g, charge)
  local list = D.list(g.world)
  local action = charge.action
  if #list == 0 or not action then
    return
  end
  for _, def in ipairs(list) do
    if not D.broken(g.world, def.id) then
      local a, b = def.from, def.to
      local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
      local uu = max(1e-9, ux * ux + uy * uy + uz * uz)
      local s = ((charge.x - a[1]) * ux + (charge.y - a[2]) * uy + (charge.z - a[3]) * uz) / uu
      s = max(0, min(1, s))
      local dx, dy, dz =
        a[1] + ux * s - charge.x, a[2] + uy * s - charge.y, a[3] + uz * s - charge.z
      local d = sqrt(dx * dx + dy * dy + dz * dz)
      if d - def.radius < action.radius then
        local reach = max(0, d - def.radius)
        local open = reach < 1e-3
        if not open then
          local hit, _, kind =
            Ballistics.world(g.world, charge.x, charge.y, charge.z, dx / d, dy / d, dz / d, reach)
          open = kind == 'range' or hit >= reach - 1e-5
        end
        if open then
          local dealt = Damage.resolve(action.blast, def, reach)
          blow(g, def, dealt * Kinds[def.kind].blast, charge.owner)
        end
      end
    end
  end
end
local function walkThrough(g, cells, x, z, high, owner)
  local row = cells[floor(z + 0.5)]
  local list = row and row[floor(x + 0.5)]
  if not list or high then
    return
  end
  for _, def in ipairs(list) do
    if not D.broken(g.world, def.id) then
      local t, gap = approach(x, def.from[2], z, 0, 1, 0, 0, def.from, def.to)
      if t and gap <= def.radius + Tuning.bodyGrace then
        blow(g, def, math.huge, owner)
      end
    end
  end
end
function D.step(g)
  if #D.list(g.world) == 0 then
    return
  end
  local cells = index(g.world).cells
  for _, p in ipairs(Bodies.knights(g)) do
    walkThrough(g, cells, p.x, p.z, (p.jump or 0) > Tuning.clearance, p.id)
  end
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      walkThrough(g, cells, e.x, e.z, (e.leapY or 0) > Tuning.clearance, nil)
    end
  end
end
function D.restore(world, state)
  repair(world)
  world.destruction = state and next(state) and Copy(state) or nil
  for id, entry in pairs(world.destruction or NONE) do
    local def = index(world).byId[id]
    if entry.at and Kinds[def.kind].collapses then
      collapse(world, def)
    end
  end
  World.opened(world)
end
-- A rest: what collapsed stays down, every small thing stands again.
function D.settle(world)
  local kept = {}
  for id, entry in pairs(world.destruction or NONE) do
    if entry.at and Kinds[index(world).byId[id].kind].collapses then
      kept[id] = entry
    end
  end
  D.restore(world, kept)
end
function D.reset(world)
  if world.destruction then
    D.restore(world, nil)
  end
end
Save.declare({
  name = 'destruction',
  file = 'session',
  version = 1,
  pack = function(g)
    return { [g.world.mapId] = Copy(g.world.destruction or {}) }
  end,
  default = function()
    return {}
  end,
  unpack = function(t)
    assert(type(t) == 'table', 'invalid destruction state')
    for mapId, states in pairs(t) do
      local map = require('src.content.maps.index'):get(mapId)
      assert(type(states) == 'table', 'invalid destruction states')
      local valid = {}
      for _, def in ipairs((map.decor or NONE).breakables or NONE) do
        valid[def.id] = def
      end
      for id, s in pairs(states) do
        local def = valid[id]
        assert(def and type(s) == 'table', 'unknown breakable')
        local health = Kinds[def.kind].health
        assert(
          type(s.damage) == 'number' and s.damage >= 0 and s.damage <= health,
          'invalid breakable damage'
        )
        assert(s.at == nil or (type(s.at) == 'number' and s.at >= 0), 'invalid breaking time')
      end
    end
    return Copy(t)
  end,
  restore = function(g, t)
    D.restore(g.world, t[g.world.mapId])
  end,
})
return D

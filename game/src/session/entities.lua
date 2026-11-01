-- Things of the world that are neither knights nor creatures: a turret, a barrel,
-- a person to talk to, a lever. One declaration:
--   id
--   health               it can be destroyed (absent: it cannot)
--   radius, height       its body (default a post)
--   hittable             shots and blasts meet it
--   collides             a knight stops at it
--   system = { after, step(g, e, dt) }   its place in the step, by a named neighbour
--   interact = { prompt(g, e), act(g, e, actor), reach }   the use key
--   hit(g, e, damage, owner), die(g, e, owner)   what follows a blow
--   draw(r, g, e)        how it looks (render/world_art.lua draws the pool)
-- Its live record is a member of the pool 'entities': place, health and state, a
-- plain table the save keeps as it is.
local Pools = require('src.session.world')
local Registry = require('src.core.registry')
local Roles = require('src.core.roles')
local Entities = {}
local Tuning = require('src.content.tuning').entities
Entities.kinds = Registry:new('entity kinds', function(def, id)
  assert(type(def) == 'table', 'entity ' .. id .. ': expected a definition')
  assert(not def.system or def.system.after, 'entity ' .. id .. ': system needs after')
  assert(not def.interact or def.interact.act, 'entity ' .. id .. ': interact needs act')
end)
-- After which system of the step each kind runs (systems/index.lua order).
Entities.hooks = {}
local function hook(after)
  return function(g, dt)
    for i = #Pools.of(g, 'entities'), 1, -1 do
      local e = Pools.of(g, 'entities')[i]
      local def = e and Entities.kinds:find(e.entity)
      if def and def.system and def.system.after == after then
        def.system.step(g, e, dt)
      end
    end
  end
end
function Entities.define(def)
  Entities.kinds:register(def.id, def)
  if def.system then
    Entities.hooks[def.system.after] = hook(def.system.after)
  end
  return def
end
function Entities.undefine(id)
  local def = Entities.kinds:unregister(id)
  if def and def.system then
    local used = false
    for _, other in Entities.kinds:each() do
      used = used or (other.system and other.system.after == def.system.after)
    end
    if not used then
      Entities.hooks[def.system.after] = nil
    end
  end
end
function Entities.spawn(g, id, x, z, state)
  local def = Entities.kinds:get(id)
  return g.ecs:create('entity', {
    entity = id,
    x = x,
    z = z,
    hp = def.health,
    maxHp = def.health,
    state = state or {},
  })
end
local function bodyOf(def)
  return def.radius or Tuning.radius, def.height or Tuning.height
end
-- The nearest thing a ray meets before limit: its record and the distance.
function Entities.ray(g, x, y, z, dx, dy, dz, limit)
  local list = Pools.of(g, 'entities')
  if #list == 0 then
    return
  end
  local best, at = nil, limit
  for _, e in ipairs(list) do
    local def = Entities.kinds:find(e.entity)
    if def and def.hittable then
      local radius, height = bodyOf(def)
      local ox, oz = e.x - x, e.z - z
      local along = (ox * dx + oz * dz) / math.max(1e-6, dx * dx + dz * dz)
      local px, pz = x + dx * along, z + dz * along
      local d = along - math.sqrt(math.max(0, radius * radius - (e.x - px) ^ 2 - (e.z - pz) ^ 2))
      local near = (e.x - px) ^ 2 + (e.z - pz) ^ 2 <= radius * radius
      local h = y + dy * d
      if near and d > 0 and d < at and h >= 0 and h <= height then
        best, at = e, d
      end
    end
  end
  return best, at
end
function Entities.hurt(g, e, damage, owner)
  local def = Entities.kinds:get(e.entity)
  if def.hit then
    def.hit(g, e, damage, owner)
  end
  if not e.hp then
    return
  end
  e.hp = e.hp - damage
  if e.hp <= 0 then
    Pools.remove(g, 'entities', e)
    if def.die then
      def.die(g, e, owner)
    end
  end
end
-- Things a blast from (x, z) reaches: visit(e, distance).
function Entities.within(g, x, z, radius, visit)
  local list = Pools.of(g, 'entities')
  for i = #list, 1, -1 do
    local e = list[i]
    local def = Entities.kinds:find(e.entity)
    if def and def.hittable then
      local d = math.sqrt((e.x - x) ^ 2 + (e.z - z) ^ 2)
      if d < radius then
        visit(e, d)
      end
    end
  end
end
-- A knight stops at what stands in its way.
function Entities.block(g, knight, radius)
  for _, e in ipairs(Pools.of(g, 'entities')) do
    local def = Entities.kinds:find(e.entity)
    if def and def.collides then
      local reach = radius + bodyOf(def)
      local dx, dz = knight.x - e.x, knight.z - e.z
      local d = math.sqrt(dx * dx + dz * dz)
      if d < reach and d > 1e-6 then
        knight.x, knight.z = e.x + dx / d * reach, e.z + dz / d * reach
      end
    end
  end
end
local function usable(g)
  local p = Roles.controlled(g)
  local list = Pools.of(g, 'entities')
  for i = 1, #list do
    local e = list[i]
    local def = Entities.kinds:find(e.entity)
    if def and def.interact then
      local reach = def.interact.reach or Tuning.reach
      if (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2 <= reach * reach then
        return e, def, p
      end
    end
  end
end
function Entities.interact(g)
  local e, def, p = usable(g)
  if e then
    def.interact.act(g, e, p)
    return true
  end
end
function Entities.prompt(g)
  local e, def = usable(g)
  return e and def.interact.prompt and def.interact.prompt(g, e) or nil
end
return Entities

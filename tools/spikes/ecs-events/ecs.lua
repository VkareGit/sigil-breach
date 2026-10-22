-- Spike: ECS on flat entities (components = declared field sets on the
-- entity table, as in tiny-ecs). Deterministic: entities kept in creation
-- order, structural changes deferred to the end of each system.
local ECS = {}
ECS.__index = ECS

function ECS.new()
  return setmetatable({
    components = {}, -- name -> { fields = {k = default} }
    entities = {}, -- ordered list
    nextId = 0,
    queries = {}, -- key -> { all = {...}, list = {...}, dirty = true }
    pending = {},
    systems = {},
  }, ECS)
end

function ECS:component(name, fields)
  self.components[name] = { fields = fields }
end

local function copy(v)
  if type(v) ~= 'table' then
    return v
  end
  local t = {}
  for k, x in pairs(v) do
    t[k] = copy(x)
  end
  return t
end

-- Prefab: list of component names + overrides. Fields of every component
-- are filled from its defaults (Type Object data comes in overrides).
function ECS:spawn(prefab, overrides)
  self.nextId = self.nextId + 1
  local e = { id = self.nextId, has = {} }
  for _, name in ipairs(prefab) do
    local c = assert(self.components[name], 'unknown component ' .. name)
    e.has[name] = true
    for k, v in pairs(c.fields) do
      e[k] = copy(v)
    end
  end
  for k, v in pairs(overrides or {}) do
    e[k] = v
  end
  self.pending[#self.pending + 1] = { op = 'add', e = e }
  return e
end
function ECS:destroy(e)
  self.pending[#self.pending + 1] = { op = 'remove', e = e }
end
function ECS:flush()
  if #self.pending == 0 then
    return
  end
  for _, p in ipairs(self.pending) do
    if p.op == 'add' then
      self.entities[#self.entities + 1] = p.e
    else
      p.e.dead = true
    end
  end
  self.pending = {}
  local alive = {}
  for _, e in ipairs(self.entities) do
    if not e.dead then
      alive[#alive + 1] = e
    end
  end
  self.entities = alive
  for _, q in pairs(self.queries) do
    q.dirty = true
  end
end
function ECS:query(...)
  local all = { ... }
  local key = table.concat(all, '+')
  local q = self.queries[key]
  if not q then
    q = { all = all, list = {}, dirty = true }
    self.queries[key] = q
  end
  if q.dirty then
    local list = {}
    for _, e in ipairs(self.entities) do
      local ok = true
      for _, c in ipairs(all) do
        if not e.has[c] then
          ok = false
          break
        end
      end
      if ok then
        list[#list + 1] = e
      end
    end
    q.list, q.dirty = list, false
  end
  return q.list
end
-- Systems run in the declared order; structural changes apply after each.
function ECS:system(name, fn)
  self.systems[#self.systems + 1] = { name = name, fn = fn }
end
function ECS:step(ctx, dt)
  for _, s in ipairs(self.systems) do
    s.fn(self, ctx, dt)
    self:flush()
  end
end
return ECS

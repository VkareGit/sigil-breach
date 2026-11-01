local SurfaceMarks = require('src.feedback.surface_marks')
local E = { limits = { effects = 48, decals = 40, smoke = 8 } }
local Art = require('src.content.effect_art')
function E.emit(g, kind, x, y, z, size, options)
  g.view.effects = g.view.effects or {}
  local sequence = Art:get(kind)
  local life = sequence.duration
  local effects = g.view.effects
  local recycle
  if sequence.limit then
    local count, oldest = 0
    for i, e in ipairs(effects) do
      if e.kind == kind then
        count = count + 1
        oldest = oldest or i
      end
    end
    if count >= sequence.limit then
      recycle = table.remove(effects, oldest)
    end
  end
  if not recycle and #effects >= E.limits.effects then
    recycle = table.remove(effects, 1)
  end
  g.view.effectPool = g.view.effectPool or {}
  local pool = g.view.effectPool
  local e = recycle or table.remove(pool) or {}
  e.kind, e.x, e.y, e.z, e.size, e.age, e.duration = kind, x, y, z, size or 0.65, 0, life
  -- Reused impact records must not tint or propel the next muzzle-smoke puff.
  e.tint = options and options.tint or nil
  e.material = options and options.material or nil
  e.energy = options and options.energy or 0
  e.incidence = options and options.incidence or 0
  e.vx = options and options.vx or 0
  e.vy = options and options.vy or 0
  e.vz = options and options.vz or 0
  if options and options.duration then
    e.duration = options.duration
  end
  effects[#effects + 1] = e
  return e
end
function E.stain(g, x, z, size, kind)
  g.view.decals = g.view.decals or {}
  g.view.decalPool = g.view.decalPool or {}
  local d = (#g.view.decals >= E.limits.decals and table.remove(g.view.decals, 1))
    or table.remove(g.view.decalPool)
    or {}
  d.x, d.z, d.size, d.kind, d.age, d.rotation = x, z, size, kind, 0, (x * 13 + z * 17) % 6.28
  g.view.decals[#g.view.decals + 1] = d
  return d
end
function E.update(g, dt)
  SurfaceMarks.update(g, dt)
  g.view.effectPool = g.view.effectPool or {}
  g.view.decalPool = g.view.decalPool or {}
  local write = 1
  local count = #g.view.effects
  for i = 1, count do
    local e = g.view.effects[i]
    e.age = e.age + dt
    e.x = e.x + (e.vx or 0) * dt
    e.y = e.y + (e.vy or 0) * dt
    e.z = e.z + (e.vz or 0) * dt
    e.y = e.y + dt * (Art:get(e.kind).rise or 0)
    if e.age < e.duration then
      g.view.effects[write] = e
      write = write + 1
    elseif #g.view.effectPool < E.limits.effects then
      g.view.effectPool[#g.view.effectPool + 1] = e
    end
  end
  for i = count, write, -1 do
    g.view.effects[i] = nil
  end
  write = 1
  count = #g.view.decals
  for i = 1, count do
    local d = g.view.decals[i]
    d.age = d.age + dt
    if d.age < 24 then
      g.view.decals[write] = d
      write = write + 1
    elseif #g.view.decalPool < E.limits.decals then
      g.view.decalPool[#g.view.decalPool + 1] = d
    end
  end
  for i = count, write, -1 do
    g.view.decals[i] = nil
  end
end
function E.frame(e)
  local frames = Art:get(e.kind).frames
  return frames[1 + math.min(#frames - 1, math.max(0, math.floor(e.age / e.duration * #frames)))]
end
E.profile = function(e)
  return Art:get(e.kind)
end
return E

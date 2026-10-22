-- A short powder-coloured exposure of a resolved shot, never a second bullet.
-- Endpoints stay on the ballistic ray. Aging belongs to simulation, not draw.
local MathX = require('src.core.mathx')
local S = { limit = 64 }
local clamp = MathX.clamp
function S.emit(g, origin, dx, dy, dz, distance, strong)
  if distance <= 0.02 then
    return
  end
  local start = math.min(0.30, distance * 0.5)
  g.view.traces = g.view.traces or {}
  g.view.tracePool = g.view.tracePool or {}
  local t = (#g.view.traces >= S.limit and table.remove(g.view.traces, 1))
    or table.remove(g.view.tracePool)
    or {}
  t.x1, t.y1, t.z1 = origin[1] + dx * start, origin[2] + dy * start, origin[3] + dz * start
  t.x2, t.y2, t.z2 = origin[1] + dx * distance, origin[2] + dy * distance, origin[3] + dz * distance
  -- Short close hits must not leave a luminous rod in front of the muzzle.
  t.maxLife = 0.038 + math.min(distance, 24) * 0.0011
  t.life = t.maxLife
  t.color = strong and { 0.68, 0.53, 0.32 } or { 0.76, 0.61, 0.39 }
  t.width = strong and 0.55 or 0.78
  t.swept = true
  g.view.traces[#g.view.traces + 1] = t
  return t
end
function S.bounds(t)
  if not t.swept then
    return 0, 1
  end
  local age = clamp(1 - t.life / t.maxLife, 0, 1)
  -- The brief exposure travels outwards; it does not persist as a laser.
  return age * age, math.min(1, 0.55 + age * 2.1)
end
function S.update(g, dt)
  local list = g.view.traces or {}
  g.view.tracePool = g.view.tracePool or {}
  local write = 1
  for i = 1, #list do
    local t = list[i]
    t.life = t.life - dt
    if t.life > 0 then
      list[write] = t
      write = write + 1
    elseif #g.view.tracePool < S.limit then
      g.view.tracePool[#g.view.tracePool + 1] = t
    end
  end
  for i = #list, write, -1 do
    list[i] = nil
  end
end
return S

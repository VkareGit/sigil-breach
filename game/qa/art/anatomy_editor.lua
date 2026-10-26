-- The anatomy region editor's model (plan v10 V7): an annotation open for
-- editing, frame by frame (tools/art/anatomy_editor draws it and turns the
-- mouse and keys into these calls; tests drive it directly). Every change
-- keeps a copy for undo; the result is exported as data
-- (qa/art/anatomy_export.lua) and baked like any annotation.
local Anatomy = require('src.content.art.anatomy_regions')
local Export = require('qa.art.anatomy_export')
local Editor = {}
Editor.__index = Editor
local ZONES = { 'head', 'torso', 'lower', false }
local function copy(value)
  if type(value) ~= 'table' then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = copy(v)
  end
  return out
end
-- id: the annotation id; annotation: the frames to edit (copied).
function Editor.new(id, annotation)
  return setmetatable({
    id = id,
    annotation = copy(annotation),
    index = 1,
    selected = 1,
    vertex = nil,
    history = {},
  }, Editor)
end
function Editor:frame()
  return self.annotation.frames[self.index]
end
function Editor:part()
  return self:frame().parts[self.selected]
end
local function remember(self)
  self.history[#self.history + 1] = { copy(self.annotation), self.index, self.selected }
end
function Editor:undo()
  local last = table.remove(self.history)
  if last then
    self.annotation, self.index, self.selected = last[1], last[2], last[3]
    self.vertex = nil
  end
  return last ~= nil
end
function Editor:show(index)
  self.index = math.max(1, math.min(#self.annotation.frames, index))
  self.selected = math.min(self.selected, #self:frame().parts)
  self.vertex = nil
end
function Editor:step(delta)
  self:show(self.index + delta)
end
function Editor:cycle(delta)
  local count = #self:frame().parts
  self.selected = (self.selected - 1 + delta) % count + 1
  self.vertex = nil
end
-- The vertex nearest (u, v) within radius, the selected part first; selects
-- its part. Returns the part and vertex index, or nil.
function Editor:pick(u, v, radius)
  local best, bestPart, bestVertex = radius * radius, nil, nil
  local parts = self:frame().parts
  local order = { self.selected }
  for i = #parts, 1, -1 do
    if i ~= self.selected then
      order[#order + 1] = i
    end
  end
  for _, p in ipairs(order) do
    local poly = parts[p].polygon
    for i = 1, #poly, 2 do
      local d = (poly[i] - u) ^ 2 + (poly[i + 1] - v) ^ 2
      if d < best then
        best, bestPart, bestVertex = d, p, (i + 1) / 2
      end
    end
    if bestPart then
      break
    end
  end
  if bestPart then
    self.selected, self.vertex = bestPart, bestVertex
  end
  return bestPart, bestVertex
end
-- A drag begins (one undo step for the whole drag), moves, ends.
function Editor:grab()
  remember(self)
end
function Editor:move(u, v)
  if not self.vertex then
    return false
  end
  local poly = self:part().polygon
  local i = self.vertex * 2 - 1
  poly[i] = math.max(-0.25, math.min(1.25, u))
  poly[i + 1] = math.max(-0.25, math.min(1.25, v))
  return true
end
-- A new vertex halfway to the next one, selected.
function Editor:insert()
  if not self.vertex then
    return false
  end
  remember(self)
  local poly = self:part().polygon
  local n = #poly / 2
  local a, b = self.vertex, self.vertex % n + 1
  local u = (poly[a * 2 - 1] + poly[b * 2 - 1]) / 2
  local v = (poly[a * 2] + poly[b * 2]) / 2
  table.insert(poly, a * 2 + 1, v)
  table.insert(poly, a * 2 + 1, u)
  self.vertex = a + 1
  return true
end
function Editor:remove()
  local poly = self.vertex and self:part().polygon
  if not poly or #poly <= 6 then
    return false
  end
  remember(self)
  table.remove(poly, self.vertex * 2)
  table.remove(poly, self.vertex * 2 - 1)
  self.vertex = nil
  return true
end
-- A new part: a small box in the middle of the frame, selected.
function Editor:add(id, zone, material)
  remember(self)
  local parts = self:frame().parts
  parts[#parts + 1] = {
    id = id,
    zone = zone,
    material = material,
    polygon = { 0.4, 0.4, 0.6, 0.4, 0.6, 0.6, 0.4, 0.6 },
  }
  self.selected, self.vertex = #parts, nil
end
-- Removes the selected part (never the frame-wide fallback, the first).
function Editor:drop()
  if self.selected == 1 then
    return false
  end
  remember(self)
  table.remove(self:frame().parts, self.selected)
  self.selected, self.vertex = self.selected - 1, nil
  return true
end
function Editor:zone()
  remember(self)
  local part, next = self:part(), 1
  for i, zone in ipairs(ZONES) do
    if zone == part.zone then
      next = i % #ZONES + 1
    end
  end
  part.zone = ZONES[next]
end
function Editor:material(name)
  remember(self)
  self:part().material = name
end
-- Moves a named anchor of the frame (anchors: { name = { u, v } }).
function Editor:anchor(name, u, v)
  remember(self)
  local frame = self:frame()
  frame.anchors = frame.anchors or {}
  frame.anchors[name] = { math.max(0, math.min(1, u)), math.max(0, math.min(1, v)) }
end
-- What is wrong with the edited annotation (Anatomy.problems, every frame).
function Editor:problems()
  local out = {}
  for index, frame in ipairs(self.annotation.frames) do
    for _, problem in ipairs(Anatomy.problems(frame, self.id .. '/' .. index)) do
      out[#out + 1] = problem
    end
  end
  return out
end
-- The annotation as a data file (content/art/anatomy/<id>.lua).
function Editor:text()
  return Export.text(self.id, self.annotation)
end
return Editor

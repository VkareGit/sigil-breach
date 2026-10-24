-- CPU-only contract for painted hand atlases. Rectangles and anchors are
-- authored pixels; neither simulation geometry nor GPU handles belong here.
local Id = require('src.core.id')
local Atlas = {}
function Atlas.number(value, label, minimum)
  assert(
    type(value) == 'number'
      and value == value
      and math.abs(value) < math.huge
      and (minimum == nil or value >= minimum),
    label .. ': invalid number'
  )
  return value
end
local function integer(value, label, minimum)
  Atlas.number(value, label, minimum)
  assert(value % 1 == 0, label .. ': expected integer')
end
function Atlas.point(point, rect, label)
  assert(type(point) == 'table' and #point == 2, label .. ': missing point')
  for axis = 1, 2 do
    Atlas.number(point[axis], label, 0)
    assert(point[axis] <= rect[axis + 2], label .. ': outside rectangle')
  end
end
function Atlas.validate(entry, label, anchors)
  assert(type(entry.path) == 'string' and entry.path ~= '', label .. ': missing path')
  integer(entry.width, label .. '.width', 1)
  integer(entry.height, label .. '.height', 1)
  assert(type(entry.frames) == 'table' and #entry.frames > 0, label .. ': missing frames')
  local names = {}
  for index, frame in ipairs(entry.frames) do
    local where = label .. '.frames[' .. index .. ']'
    Id.check(frame.id, where .. '.id')
    assert(not names[frame.id], where .. ': duplicate frame id ' .. frame.id)
    names[frame.id] = index
    local rect = frame.rect
    assert(type(rect) == 'table' and #rect == 4, where .. ': missing rectangle')
    for i, value in ipairs(rect) do
      integer(value, where .. '.rect[' .. i .. ']', i > 2 and 1 or 0)
    end
    assert(
      rect[1] + rect[3] <= entry.width and rect[2] + rect[4] <= entry.height,
      where .. ': rectangle outside atlas'
    )
    for _, name in ipairs(anchors) do
      Atlas.point(frame[name], rect, where .. '.' .. name)
    end
  end
  return names
end
function Atlas.frame(names, name, where)
  assert(type(name) == 'string' and names[name], where .. ': unknown frame ' .. tostring(name))
  return names[name]
end
function Atlas.sequence(phases, names, where)
  assert(type(phases) == 'table' and #phases > 0, where .. ': missing phases')
  local last, compiled = 0, {}
  for index, phase in ipairs(phases) do
    Atlas.number(phase.finish, where .. '[' .. index .. '].finish', 0)
    assert(phase.finish > last, where .. ': phase times must increase')
    compiled[index] = { phase.finish, Atlas.frame(names, phase.frame, where) }
    last = phase.finish
  end
  return compiled
end
return Atlas

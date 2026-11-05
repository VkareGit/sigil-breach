-- The sheet tool (plan v10 V7): writes an atlas sheet
-- (content/art/sheet.lua) from the painted images.
--   measure(sheet)  the sheet re-measured from its PNGs: each source's size
--                   and each frame's feet (the opaque bottom row: three
--                   pixels above alpha 0.65, the rule the atlas always
--                   used). Cuts, order and anchors are the sheet's.
--   propose(spec)   a sheet for a new atlas: cuts found in its transparent
--                   gutters, frames in cell order, feet measured, a head
--                   anchor on the top of each silhouette (to be checked
--                   by eye, like every anchor).
--   text(sheet)     the sheet as a Lua data file.
-- PNG access happens only here (QA, EXPORT-SHEET.ps1), never in play.
local Sheet = require('src.content.art.sheet')
local Templates = require('qa.art.pose_templates')
local Tool = {}
local OPAQUE, FEET_PIXELS = 0.65, 3
local function image(path, cache)
  cache[path] = cache[path] or love.image.newImageData(path)
  return cache[path]
end
local function release(cache)
  for _, data in pairs(cache) do
    data:release()
  end
end
-- Transparent rows under the opaque feet of a cell.
function Tool.feet(data, x0, x1, y0, y1)
  for y = y1, y0, -1 do
    local count = 0
    for x = x0, x1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > OPAQUE then
        count = count + 1
      end
    end
    if count >= FEET_PIXELS then
      return y1 - y
    end
  end
  return 0
end
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
function Tool.measure(sheet)
  local out, cache = copy(sheet), {}
  for _, source in ipairs(out.sources) do
    local data = image(source.path, cache)
    source.size = { data:getDimensions() }
  end
  for _, frame in ipairs(out.frames) do
    local source = out.sources[frame.source]
    local x0, x1, y0, y1 = Sheet.cut(source, frame.cell)
    frame.feet = Tool.feet(image(source.path, cache), x0, x1, y0, y1)
  end
  release(cache)
  return out
end
-- The clear line nearest each nominal cut, searched within 45% of a cell.
local function clear(data, horizontal, at, from, to)
  for t = from, to do
    local x, y = horizontal and t or at, horizontal and at or t
    local _, _, _, a = data:getPixel(x, y)
    if a > 0.06 then
      return false
    end
  end
  return true
end
local function gutters(data, count, length, along, from, to)
  local cuts = { 0 }
  for k = 1, count - 1 do
    local guess, reach = math.floor(k * length / count), math.floor(length / count * 0.45)
    local best, distance
    for at = math.max(0, guess - reach), math.min(length - 1, guess + reach) do
      if clear(data, along, at, from, to) then
        local d = math.abs(at - guess)
        if not distance or d < distance then
          best, distance = at, d
        end
      end
    end
    cuts[#cuts + 1] = best or guess
  end
  cuts[#cuts + 1] = length
  return cuts
end
-- The head anchor of a cell: the middle of the top tenth of its opaque
-- silhouette, from the cell's centre (widths) and up from its base (heights).
function Tool.head(data, x0, x1, y0, y1)
  local top
  for y = y0, y1 do
    for x = x0, x1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > OPAQUE then
        top = y
        break
      end
    end
    if top then
      break
    end
  end
  if not top then
    return { 0, 0.85 }
  end
  local band = math.max(1, math.floor((y1 - top) * 0.1))
  local sx, sy, n = 0, 0, 0
  for y = top, math.min(y1, top + band) do
    for x = x0, x1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > OPAQUE then
        sx, sy, n = sx + x, sy + y, n + 1
      end
    end
  end
  local cw, ch = x1 - x0 + 1, y1 - y0 + 1
  return { (sx / n + 0.5 - x0 - cw / 2) / cw, (y1 + 1 - (sy / n + 0.5)) / ch }
end
-- spec: { id, size, idle = { period, weights }?,
--   sources = { { path, columns, rows, scale?, idle? }... },
--   poses = { ... } | template = 'extended' | 'compact' }: every cell of
-- every source is a frame, in order. Without poses or a template the
-- action atlas's columns choose the template (6: extended, else compact).
function Tool.propose(spec)
  local cache = {}
  local template = spec.template or (spec.sources[1].columns == 6 and 'extended' or 'compact')
  local sheet = {
    id = spec.id,
    size = spec.size,
    idle = spec.idle or { period = 3.5, weights = { 0.34, 0.18, 0.17, 0.31 } },
    sources = {},
    frames = {},
    poses = spec.poses or Templates.copy(template),
  }
  for index, s in ipairs(spec.sources) do
    local data = image(s.path, cache)
    local w, h = data:getDimensions()
    local source = {
      path = s.path,
      size = { w, h },
      columns = s.columns,
      rows = s.rows,
      scale = s.scale,
      idle = s.idle,
      filter = s.filter,
      mipmaps = s.mipmaps,
      bands = {},
      columnBands = {},
    }
    for col = 0, s.columns - 1 do
      local x0, x1 = math.ceil(col * w / s.columns), math.floor((col + 1) * w / s.columns) - 1
      source.bands[col + 1] = gutters(data, s.rows, h, true, x0, x1)
    end
    for row = 0, s.rows - 1 do
      local y0, y1 = math.ceil(row * h / s.rows), math.floor((row + 1) * h / s.rows) - 1
      source.columnBands[row + 1] = gutters(data, s.columns, w, false, y0, y1)
    end
    sheet.sources[index] = source
    for cell = 1, s.columns * s.rows do
      local x0, x1, y0, y1 = Sheet.cut(source, cell)
      sheet.frames[#sheet.frames + 1] = {
        source = index,
        cell = cell,
        feet = Tool.feet(data, x0, x1, y0, y1),
        anchors = { head = Tool.head(data, x0, x1, y0, y1) },
      }
    end
  end
  release(cache)
  return sheet
end
-- The shortest decimal that reads back as the same number.
local function number(value)
  if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
    return string.format('%d', value)
  end
  for digits = 1, 17 do
    local text = string.format('%.' .. digits .. 'g', value)
    if tonumber(text) == value then
      return text
    end
  end
end
local function list(values)
  local out = {}
  for i, v in ipairs(values) do
    out[i] = type(v) == 'table' and list(v) or number(v)
  end
  return '{ ' .. table.concat(out, ', ') .. ' }'
end
local SOURCE_FIELDS = {
  'path',
  'size',
  'columns',
  'rows',
  'scale',
  'idle',
  'filter',
  'mipmaps',
  'bands',
  'columnBands',
  'crops',
}
local POSE_FIELDS =
  { 'clock', 'frames', 'bounds', 'rate', 'step', 'ends', 'offset', 'fallback', 'footsteps' }
local function scalar(value)
  return type(value) == 'string' and string.format('%q', value)
    or (type(value) == 'boolean' and tostring(value))
    or (type(value) == 'table' and list(value))
    or number(value)
end
-- The poses of a sheet as Lua, by name.
local function poses(sheet, out)
  local names = {}
  for name in pairs(sheet.poses or {}) do
    names[#names + 1] = name
  end
  table.sort(names)
  out[#out + 1] = '  poses = {'
  for _, name in ipairs(names) do
    local pose, fields = sheet.poses[name], {}
    for _, field in ipairs(POSE_FIELDS) do
      if pose[field] ~= nil then
        fields[#fields + 1] = field .. ' = ' .. scalar(pose[field])
      end
    end
    local key = name:match('^[%a_][%w_]*$') and name or ('[' .. string.format('%q', name) .. ']')
    out[#out + 1] = '    ' .. key .. ' = { ' .. table.concat(fields, ', ') .. ' },'
  end
  out[#out + 1] = '  },'
end
function Tool.text(sheet)
  local out = {
    '-- The ' .. sheet.id .. ' atlas sheet (content/art/sheet.lua): written by the sheet',
    '-- tool (qa/art/sheet_tool.lua, EXPORT-SHEET.ps1 ' .. sheet.id .. '). Cuts, order and anchors',
    '-- are authored here; feet and sizes are measured from the images.',
    'return {',
    '  id = ' .. string.format('%q', sheet.id) .. ',',
    '  size = ' .. number(sheet.size) .. ',',
    '  idle = { period = ' .. number(sheet.idle.period) .. ', weights = ' .. list(
      sheet.idle.weights
    ) .. ' },',
    '  sources = {',
  }
  for _, source in ipairs(sheet.sources) do
    out[#out + 1] = '    {'
    for _, field in ipairs(SOURCE_FIELDS) do
      local value = source[field]
      if value ~= nil then
        local text = type(value) == 'string' and string.format('%q', value)
          or (type(value) == 'boolean' and tostring(value))
          or (type(value) == 'table' and list(value))
          or number(value)
        out[#out + 1] = '      ' .. field .. ' = ' .. text .. ','
      end
    end
    out[#out + 1] = '    },'
  end
  out[#out + 1] = '  },'
  out[#out + 1] = '  frames = {'
  for _, frame in ipairs(sheet.frames) do
    local names = {}
    for name in pairs(frame.anchors) do
      names[#names + 1] = name
    end
    table.sort(names)
    local anchors = {}
    for i, name in ipairs(names) do
      anchors[i] = name .. ' = ' .. list(frame.anchors[name])
    end
    out[#out + 1] = string.format(
      '    { source = %d, cell = %d, feet = %d, anchors = { %s } },',
      frame.source,
      frame.cell,
      frame.feet,
      table.concat(anchors, ', ')
    )
  end
  out[#out + 1] = '  },'
  poses(sheet, out)
  out[#out + 1] = '}'
  return table.concat(out, '\n') .. '\n'
end
return Tool

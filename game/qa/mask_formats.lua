-- Mask storage formats compared (0.29), all decoding to the same in-memory
-- masks (hex rows, content/art/mask_codec.lua), so a shot's lookup cost is
-- the same for every format; what differs is the stored size, the time to
-- read, parse and decode it once, and the memory held after loading.
--   hex      320 rows of 160 hex digits per frame (the 0.28 format)
--   cropped  hex rows cut to the frame's painted bounding box
--   packed   4 cells per byte, base64 text (no Lua escapes)
--   rle      run-length rows (mask_codec: the chosen format, if it wins)
-- Writes mask-format-*.lua beside mask-formats.txt in the selected QA directory; every variant is
-- decoded and compared with the current masks cell by cell.
local Codec = require('src.content.art.mask_codec')
local Tooling = require('qa.tooling')
local M = {}
local clock = love.timer.getTime
local function each(masks, fn)
  for _, group in ipairs({ 'layouts', 'abilities' }) do
    local ids = {}
    for id in pairs(masks[group]) do
      ids[#ids + 1] = id
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
      fn(group, id, masks[group][id])
    end
  end
end
local function lua(value)
  return string.format('%q', value)
end
local b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64(bytes)
  local out = {}
  for i = 1, #bytes, 3 do
    local a, b, c = bytes:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    for k = 3, 0, -1 do
      local index = math.floor(n / 64 ^ k) % 64 + 1
      out[#out + 1] = b64:sub(index, index)
    end
  end
  return table.concat(out)
end
local b64index = {}
for i = 1, #b64 do
  b64index[b64:byte(i)] = i - 1
end
local function unbase64(text)
  local out = {}
  for i = 1, #text, 4 do
    local n = 0
    for k = 0, 3 do
      n = n * 64 + b64index[text:byte(i + k)]
    end
    out[#out + 1] = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
  end
  return table.concat(out)
end
local hexDigits = '0123456789abcdef'
local writers, readers = {}, {}
function writers.hex(rows)
  local parts = {}
  for i, row in ipairs(rows) do
    parts[i] = lua(row)
  end
  return '{' .. table.concat(parts, ',') .. '}'
end
function readers.hex(stored)
  return stored
end
function writers.cropped(rows, grid)
  local top, bottom, left, right = nil, nil, grid, -1
  local blank = string.rep('0', grid / 2)
  for y, row in ipairs(rows) do
    if row ~= blank then
      top, bottom = top or y, y
      local first = row:find('[^0]')
      local last = #row - row:reverse():find('[^0]') + 1
      left, right = math.min(left, first), math.max(right, last)
    end
  end
  if not top then
    return '{0,0,0,{}}'
  end
  local parts = {}
  for y = top, bottom do
    parts[#parts + 1] = lua(rows[y]:sub(left, right))
  end
  return string.format('{%d,%d,%d,{%s}}', top, left, right, table.concat(parts, ','))
end
function readers.cropped(stored, grid)
  local top, left, right, cut = stored[1], stored[2], stored[3], stored[4]
  local width = grid / 2
  local blank = string.rep('0', width)
  local rows = {}
  for y = 1, grid do
    local piece = top > 0 and cut[y - top + 1]
    rows[y] = piece and (string.rep('0', left - 1) .. piece .. string.rep('0', width - right))
      or blank
  end
  return rows
end
function writers.packed(rows)
  local bytes = {}
  for _, row in ipairs(rows) do
    for i = 1, #row, 2 do
      bytes[#bytes + 1] = string.char(tonumber(row:sub(i, i + 1), 16))
    end
  end
  return lua(base64(table.concat(bytes)))
end
function readers.packed(stored, grid)
  local bytes = unbase64(stored)
  local per = grid / 4
  local rows = {}
  for y = 1, grid do
    local digits = {}
    for i = 1, per do
      local b = bytes:byte((y - 1) * per + i)
      local hi, lo = math.floor(b / 16), b % 16
      digits[#digits + 1] = hexDigits:sub(hi + 1, hi + 1) .. hexDigits:sub(lo + 1, lo + 1)
    end
    rows[y] = table.concat(digits)
  end
  return rows
end
function writers.rle(rows, grid)
  return lua(Codec.encode(rows, grid))
end
function readers.rle(stored, grid)
  return Codec.decode(stored, grid)
end
function M.run(output)
  local masks = require('src.content.art.hit_masks')
  local grid = masks.grid
  local lines =
    Tooling.header('MASK STORAGE FORMATS (same in-memory masks; one decode at load)', false)
  lines[#lines + 1] =
    'The decoded masks are the same strings in every format (memory: core-measure).'
  lines[#lines + 1] = string.format('%d x %d cells per frame', grid, grid)
  for _, format in ipairs({ 'hex', 'cropped', 'packed', 'rle' }) do
    local parts = { 'return {' }
    each(masks, function(group, id, frames)
      local list = {}
      for index, rows in ipairs(frames) do
        list[index] = writers[format](rows, grid)
      end
      parts[#parts + 1] =
        string.format('%s_%s = {%s},', group, id:gsub('%W', '_'), table.concat(list, ','))
    end)
    parts[#parts + 1] = '}'
    local text = table.concat(parts, '\n')
    local path = output .. '/mask-format-' .. format .. '.lua'
    local f = assert(io.open(path, 'wb'))
    f:write(text)
    f:close()
    local start = clock()
    local f2 = assert(io.open(path, 'rb'))
    local source = f2:read('*a')
    f2:close()
    -- This source was generated above from quoted, trusted production masks;
    -- measuring Lua asset loading is intentional, not a replay import path.
    local stored = assert(loadstring(source))()
    local parsed = clock()
    local decoded, same, frames = {}, true, 0
    each(masks, function(group, id, list)
      for index, rows in ipairs(list) do
        frames = frames + 1
        local key = group .. '_' .. id:gsub('%W', '_')
        local got = readers[format](stored[key][index], grid)
        decoded[#decoded + 1] = got
        for y = 1, grid do
          same = same and got[y] == rows[y]
        end
      end
    end)
    local done = clock()
    lines[#lines + 1] = string.format(
      '%-8s file %6.0f KiB  read+parse %6.1f ms  decode %6.1f ms  %d frames %s',
      format,
      #text / 1024,
      (parsed - start) * 1000,
      (done - parsed) * 1000,
      frames,
      same and 'identical to the current masks' or 'DIFFERENT'
    )
    assert(same, 'mask format changed collision data: ' .. format)
  end
  Tooling.write(output, 'mask-formats.txt', lines, false)
  for _, line in ipairs(lines) do
    print(line)
  end
end
return M

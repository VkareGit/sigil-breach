-- Baked pigment masks (enemies/surface.lua reads them): one 2-bit code per
-- cell of the sprite shader's 320 x 320 grid — 0 air, 1 painted body, 2 the
-- sinopia contour drawn only around living bodies (3 is unused). In memory a
-- frame is 320 rows of 160 hex digits (two cells per digit), decoded ONCE
-- when the masks load; a shot reads one digit (Surface.painted), never a
-- stored format.
-- Stored format (content/art/hit_masks.lua, written by qa/bake_hit_masks.lua;
-- chosen by measurement, qa/mask_formats.lua): run-length tokens of exactly
-- three characters, read in one pass —
--   '.' '#' '+' '*' then a two-digit base-64 count: a run of code 0..3 cells
--   '~' then a two-digit base-64 count: the previous row, that many more times
-- Rows follow each other without separators (a row ends after grid cells).
local Codec = {}
local symbols = { [0] = '.', '#', '+', '*' }
local codes = { [('.'):byte()] = 0, [('#'):byte()] = 1, [('+'):byte()] = 2, [('*'):byte()] = 3 }
local REPEAT = ('~'):byte()
local base = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_@'
local value = {}
for n = 1, #base do
  value[base:byte(n)] = n - 1
end
local function count2(n)
  assert(n >= 1 and n < 64 * 64, 'mask run out of range')
  local hi, lo = math.floor(n / 64), n % 64
  return base:sub(hi + 1, hi + 1) .. base:sub(lo + 1, lo + 1)
end
local hex = '0123456789abcdef'
local digit = {}
for n = 1, #hex do
  digit[hex:byte(n)] = n - 1
end
-- Cell codes of one hex row (grid cells, left to right).
local function cells(row, grid, out)
  for x = 0, grid - 1 do
    local d = digit[row:byte(math.floor(x / 2) + 1)]
    out[x + 1] = math.floor(d / 4 ^ (1 - x % 2)) % 4
  end
  return out
end
-- One frame: hex rows -> stored tokens.
function Codec.encode(rows, grid)
  local out, previous, repeats, buffer = {}, nil, 0, {}
  local function flushRepeats()
    if repeats > 0 then
      out[#out + 1] = '~' .. count2(repeats)
      repeats = 0
    end
  end
  for _, row in ipairs(rows) do
    if row == previous then
      repeats = repeats + 1
    else
      flushRepeats()
      cells(row, grid, buffer)
      local code, count = buffer[1], 0
      for x = 1, grid do
        if buffer[x] == code then
          count = count + 1
        else
          out[#out + 1] = symbols[code] .. count2(count)
          code, count = buffer[x], 1
        end
      end
      out[#out + 1] = symbols[code] .. count2(count)
      previous = row
    end
  end
  flushRepeats()
  return table.concat(out)
end
-- The hex digit of a pair of cells (left code, right code).
local pairDigit = {}
for left = 0, 3 do
  pairDigit[left] = {}
  for right = 0, 3 do
    local v = left * 4 + right
    pairDigit[left][right] = hex:sub(v + 1, v + 1)
  end
end
-- One frame: stored tokens -> hex rows (identical rows are one string).
-- Run by run: a run fills whole digits with one repeated character; a run
-- that ends on half a digit pairs its code with the next run's first cell.
function Codec.decode(text, grid)
  local rows, previous, pieces = {}, nil, {}
  local n, done, pending = 0, 0, nil
  local byte = string.byte
  for i = 1, #text, 3 do
    local symbol, hi, lo = byte(text, i, i + 2)
    local count = value[hi] * 64 + value[lo]
    if symbol == REPEAT then
      for _ = 1, count do
        rows[#rows + 1] = previous
      end
    else
      local code = codes[symbol]
      done = done + count
      if pending then
        n = n + 1
        pieces[n] = pairDigit[pending][code]
        pending, count = nil, count - 1
      end
      local whole = math.floor(count / 2)
      if whole > 0 then
        n = n + 1
        pieces[n] = string.rep(pairDigit[code][code], whole)
      end
      if count % 2 == 1 then
        pending = code
      end
      if done == grid then
        assert(not pending, 'mask row ends on half a digit')
        previous = table.concat(pieces, '', 1, n)
        rows[#rows + 1] = previous
        n, done = 0, 0
      end
    end
  end
  assert(#rows == grid and done == 0, 'mask of ' .. #rows .. ' rows, expected ' .. grid)
  return rows
end
-- The stored masks -> the in-memory masks Surface reads.
function Codec.load(stored)
  local grid = stored.grid
  local out = { grid = grid, sources = stored.sources }
  for _, group in ipairs({ 'layouts', 'abilities' }) do
    out[group] = {}
    for id, frames in pairs(stored[group]) do
      local list = {}
      for index, text in ipairs(frames) do
        list[index] = Codec.decode(text, grid)
      end
      out[group][id] = list
    end
  end
  return out
end
return Codec

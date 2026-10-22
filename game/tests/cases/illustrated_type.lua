-- Verify glyph shapes against the authored image sheets, independently of the
-- importer. A summed-area integral checks source coverage rather than trusting
-- the catalog's claim of provenance or comparing a fixed screenshot.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(fonts)
  local lines = {}
  local check = Fixtures.checker(lines, 'illustrated type ', '')
  local mapPath = fonts[16].meta.sourceMap or 'assets/fonts/painted/source-map.lua'
  local sourceMap = require((mapPath:gsub('%.lua$', ''):gsub('/', '.')))
  local cache = {}
  local function image(path)
    if not cache[path] then
      cache[path] = love.image.newImageData(path)
    end
    return cache[path]
  end
  local upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZĄĆĘŁŃÓŚŹŻ'
  local lower = 'abcdefghijklmnopqrstuvwxyząćęłńóśźż'
  local utf8 = require('utf8')
  local mapped, count = true, 0
  for _, entry in ipairs({ { upper, 'upper' }, { lower, 'lower' } }) do
    for _, cp in utf8.codes(entry[1]) do
      local source = sourceMap[cp]
      count = count + 1
      local version = fonts[16].meta.version == 16 and 'v16' or 'v11'
      mapped = mapped
        and source
        and source.file == 'assets/art/alphabet-' .. entry[2] .. '-' .. version .. '.png'
        and (source.selector == cp or source.selection == 'inspected isolated cell')
        and source.kind == 'letter'
    end
  end
  check(
    'all seventy Latin and Polish letter shapes map to their generated upper and lower illustrations',
    mapped and count == 70
  )
  local sizes = { 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 36, 42, 48, 64, 94 }
  local results = {}
  local outputs = {}
  for _, size in ipairs(sizes) do
    results[size] = { valid = true, pixels = 0, ink = 0 }
    outputs[size] = image(fonts[size].meta.image)
  end
  local cropsValid = true
  for cp, source in pairs(sourceMap) do
    local original = image(source.file)
    local mask = source.maskFile and image(source.maskFile)
    local sw, sh = original:getDimensions()
    local valid = source.x >= 0
      and source.y >= 0
      and source.w > 0
      and source.h > 0
      and source.x + source.w <= sw
      and source.y + source.h <= sh
    if mask then
      valid = valid and mask:getWidth() == sw and mask:getHeight() == sh
    end
    cropsValid = cropsValid and valid
    assert(valid, 'invalid illustrated source crop ' .. cp)
    local width, height = source.w, source.h
    local stride = width + 1
    local sums = {}
    for x = 0, width do
      sums[x + 1] = 0
    end
    for y = 0, height - 1 do
      local row = 0
      sums[(y + 1) * stride + 1] = 0
      for x = 0, width - 1 do
        local _, _, _, alpha = original:getPixel(source.x + x, source.y + y)
        local selected = true
        if mask then
          local r, g = mask:getPixel(source.x + x, source.y + y)
          selected = math.floor(r * 255 + 0.5) + 256 * math.floor(g * 255 + 0.5) == source.selector
        end
        if alpha > 0.55 and selected then
          row = row + 1
        end
        sums[(y + 1) * stride + x + 2] = sums[y * stride + x + 2] + row
      end
    end
    local function integral(x, y)
      x = math.max(0, math.min(width, x))
      y = math.max(0, math.min(height, y))
      local ix, iy = math.min(width - 1, math.floor(x)), math.min(height - 1, math.floor(y))
      local fx, fy = x - ix, y - iy
      local index = iy * stride + ix + 1
      return sums[index] * (1 - fx) * (1 - fy)
        + sums[index + 1] * fx * (1 - fy)
        + sums[index + stride] * (1 - fx) * fy
        + sums[index + stride + 1] * fx * fy
    end
    for _, size in ipairs(sizes) do
      local glyph = fonts[size].glyphs[cp]
      local result = results[size]
      if not glyph or not glyph.sourceCp or glyph.sourceCp ~= cp then
        result.valid = false
      else
        local dw, dh = glyph.sampleW, glyph.sampleH
        local tx, ty = glyph.trimX, glyph.trimY
        result.valid = result.valid
          and dw > 0
          and dh > 0
          and tx >= 0
          and ty >= 0
          and tx + glyph.w <= dw
          and ty + glyph.h <= dh
        -- Small glyphs include every output pixel so detached accents and tiny
        -- punctuation cannot disappear unnoticed. Large versions use a dense grid.
        local step = size <= 18 and 1 or math.max(1, math.floor(math.min(dw, dh) / 6))
        for y = 0, dh - 1, step do
          for x = 0, dw - 1, step do
            local l, r, t, b =
              x * width / dw, (x + 1) * width / dw, y * height / dh, (y + 1) * height / dh
            local coverage = (integral(r, b) - integral(l, b) - integral(r, t) + integral(l, t))
              / ((r - l) * (b - t))
            local expected = coverage > 0.23
            local alpha = 0
            if x >= tx and x < tx + glyph.w and y >= ty and y < ty + glyph.h then
              local _, _, _, a = outputs[size]:getPixel(glyph.x + x - tx, glyph.y + y - ty)
              alpha = a
            end
            if (alpha > 0.5) ~= expected and not result.first then
              result.first =
                string.format('U+%04X at %d,%d coverage %.6f alpha %.3f', cp, x, y, coverage, alpha)
            end
            result.valid = result.valid and ((alpha > 0.5) == expected)
            result.pixels = result.pixels + 1
            if expected then
              result.ink = result.ink + 1
            end
          end
        end
      end
    end
  end
  check(
    'all illustrated source crops and component masks stay within their original PNG sheets',
    cropsValid
  )
  for _, size in ipairs(sizes) do
    local result = results[size]
    check(
      'size '
        .. size
        .. ' preserves the actual illustrated source silhouettes and detached accents ('
        .. result.pixels
        .. ' samples)'
        .. (result.first and ' ' .. result.first or ''),
      result.valid and result.pixels > 1000 and result.ink > 200
    )
  end
  for _, data in pairs(cache) do
    data:release()
  end
  return lines
end
return Tests

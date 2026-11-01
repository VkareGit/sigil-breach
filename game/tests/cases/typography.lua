-- Geometry and coverage checks for the new image-authored Roman / humanist hand.
local T = {}
function T.run(check)
  local Bitmap = require('src.ui.fonts.bitmap_font')
  local Numbers = require('src.ui.fonts.painted_numbers').init()
  local Titles = require('src.ui.fonts.painted_titles').init()
  local utf8 = require('utf8')
  local corpus =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz ĄĆĘŁŃÓŚŹŻ ąćęłńóśźż 0123456789%/ +−°∞=× []'
  local fonts = {}
  for _, size in ipairs({ 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 36, 42, 48, 64, 94 }) do
    local font = Bitmap.load(size)
    fonts[size] = font
    check(
      'v16 illustrated Latin, Polish, numerals and punctuation at size ' .. size,
      font:hasGlyphs(corpus)
    )
    local valid = font.meta.version == 16 and font.meta.image:find('painted%-v16') ~= nil
    for _, cp in utf8.codes(corpus) do
      local g = font.glyphs[cp]
      if g.w then
        valid = valid
          and g.w > 0
          and g.h > 0
          and g.advance >= g.dx + g.w
          and g.dy >= 0
          and g.dy + g.h <= font.meta.height
      end
    end
    check('v16 glyphs preserve visible ink and fit line advances at size ' .. size, valid)
  end
  local slash = require('assets.fonts.painted-v16.numerals').glyphs['/']
  check('v16 slash crop excludes the generator detached dot', slash.x + slash.w <= 1401)
  check(
    'v16 exact large number remains a finite graphic without exponent',
    Numbers.measure('1000000', 30) > 0 and Numbers.measure('1000000', 30) < 180
  )
  local titleCount = 0
  local titlesValid = true
  for _, name in ipairs(Titles.names) do
    local e = Titles.entries[name]
    titleCount = titleCount + 1
    titlesValid = titlesValid and e.w > 0 and e.h > 0 and e.w < 1024 and e.h < 256
  end
  check(
    'v16 literal titles use measured whole-ink crops',
    titlesValid and titleCount == #Titles.names
  )
  local sample = 'SHIFT / DODGE'
  local b = fonts[16]:getInk(sample)
  check(
    'v16 actual ink agrees with traversal bounds',
    b.w > 0 and b.w <= fonts[16]:getWidth(sample)
  )
  local two = fonts[16]:getInk('LIMBO\nWAVE 3 / 4')
  check('v16 multiline drawing preserves line separation', two.h > fonts[16]:getHeight())
  local covered, missing = fonts[16]:hasGlyphs('Test ' .. utf8.char(0x2603))
  check(
    'missing painted glyph reports its codepoint before release',
    not covered and missing == 0x2603
  )
  check(
    'unsupported glyph retains the compatible question-mark fallback',
    fonts[16]:getWidth(utf8.char(0x2603)) == fonts[16]:getWidth('?')
  )
  -- Two long runs of changing clock/counter labels must retain only a working
  -- set. Check real bounds after eviction and retained heap, not just metadata.
  local font = fonts[16]
  for i = 1, 10000 do
    font:getInk(string.format('%d:%02d / SOULS %d', math.floor(i / 60), i % 60, i * 17))
  end
  collectgarbage('collect')
  local firstHeap = collectgarbage('count')
  for i = 10001, 20000 do
    font:getInk(string.format('%d:%02d / SOULS %d', math.floor(i / 60), i % 60, i * 17))
  end
  collectgarbage('collect')
  local heapGrowth = collectgarbage('count') - firstHeap
  local retained = 0
  for _ in pairs(font.inkCache) do
    retained = retained + 1
  end
  check(
    '20000 dynamic bitmap strings retain at most 256 entries and no growing heap ('
      .. string.format('%.2f KiB', heapGrowth)
      .. ')',
    retained <= 256 and #font.inkCacheKeys <= 256 and heapGrowth < 32
  )
  local measured = font:getInk(sample)
  check(
    'evicted bitmap text recomputes identical ink and then reuses it',
    measured.x == b.x
      and measured.y == b.y
      and measured.w == b.w
      and measured.h == b.h
      and font:getInk(sample) == measured
  )
  local long = string.rep('LIMBO ', 100)
  local longInk = font:getInk(long)
  check(
    'oversized captions are measured without being retained',
    longInk.w > 0 and font.inkCache[long] == nil
  )
  for _, font in pairs(fonts) do
    font:release()
  end
end
return T

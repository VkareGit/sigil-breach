-- Small reproducible visual review using the actual PNG font render path.
local R = {}
function R.run(output)
  local lg = love.graphics
  local Bitmap = require('src.ui.fonts.bitmap_font')
  local ink = require('src.ui.ink')
  local Numbers = require('src.ui.fonts.painted_numbers')
  local Titles = require('src.ui.fonts.painted_titles')
  local old = require('assets.fonts.painted.catalog')
  local fonts, oldFonts = {}, {}
  for _, size in ipairs({ 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 36, 42, 48, 64, 94 }) do
    fonts[size] = Bitmap.load(size)
    local m = old.sizes[size]
    oldFonts[size] = Bitmap.new(m, lg.newImage(m.image))
  end
  local ivory = { 0.94, 0.89, 0.76 }
  local red = { 0.88, 0.31, 0.24 }
  local blue = { 0.46, 0.63, 0.65 }
  local function text(fonts, t, x, y, size, color, light)
    local f = fonts[size]
    lg.setShader(ink.ink(light))
    f:draw(t, x, y - f.meta.top, color or ivory)
    lg.setShader()
  end
  local function specimen(w, h, name)
    local canvas = lg.newCanvas(w, h)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    lg.scale(w / 1280, h / 800)
    lg.clear(0.065, 0.054, 0.043, 1)
    lg.setColor(0.72, 0.64, 0.50)
    lg.rectangle('fill', 24, 24, 1232, 752)
    text(fonts, 'PAINTED FRESCO LETTERING / B', 54, 46, 28, ivory, true)
    text(oldFonts, 'BEFORE / 0.15', 54, 100, 18, ivory, true)
    text(fonts, 'AFTER / 0.16', 670, 100, 18, ivory, true)
    local rows = {
      { 'I / LIMBO / FIELD OF TRIALS', 24 },
      { 'Preparation / WAVE 3 / 4', 22 },
      { 'EXORCIST / JUDGE / Q CHARGE', 18 },
      { '[E] EMBER / REST AND TRADE', 16 },
      { 'WASD move / SHIFT dodge / SPACE jump', 14 },
      { 'RELOAD / RESERVE 72 / 1000000 SOULS', 12 },
      { 'Zażółć gęślą jaźń. ĄĆĘŁŃÓŚŹŻ ąćęłńóśźż', 16 },
    }
    local y = 140
    for _, row in ipairs(rows) do
      text(oldFonts, row[1], 54, y, row[2], ivory, true)
      text(fonts, row[1], 670, y, row[2], ivory, true)
      y = y + 44
    end
    lg.setColor(0.13, 0.105, 0.08)
    lg.rectangle('fill', 54, 468, 1172, 94)
    text(fonts, 'DARK FIELD / WAVE 3 / 4', 76, 484, 18, ivory, false)
    text(fonts, 'PRECISE HIT / RESERVE 72 / 1000000 SOULS', 76, 520, 16, ivory, false)
    Numbers.draw('100%', 800, 480, 150, 35, red, false)
    Numbers.draw('40%', 1080, 480, 125, 35, blue, false)
    Titles.draw('sigil', 54, 596, 180, 48, 1, true)
    Titles.draw('breach', 260, 596, 240, 48, 1, true)
    Titles.draw('merchant', 540, 596, 280, 48, 1, true)
    Titles.draw('settings', 860, 596, 330, 48, 1, true)
    for i, v in ipairs({ '2', '100%', '40%', '184', '1000000' }) do
      Numbers.draw(
        v,
        162 + (i - 1) * 235,
        684,
        190,
        48,
        i == 2 and red or i == 3 and blue or ivory,
        true
      )
    end
    lg.pop()
    local data = canvas:newImageData()
    local f = assert(io.open(output .. '/' .. name, 'wb'))
    f:write(data:encode('png'):getString())
    f:close()
    data:release()
    canvas:release()
  end
  specimen(1280, 800, 'type-comparison-1280.png')
  specimen(960, 600, 'type-comparison-960.png')
  local lines = require('tests.cases.illustrated_type').run(fonts)
  require('tests.cases.typography').run(function(label, value)
    assert(value, label)
    lines[#lines + 1] = 'PASS ' .. label
  end)
  local f = assert(io.open(output .. '/type-tests.txt', 'wb'))
  f:write(table.concat(lines, '\n') .. '\nTOTAL ' .. #lines .. ' PASS\n')
  f:close()
  for _, font in pairs(fonts) do
    font.image:release()
  end
  for _, font in pairs(oldFonts) do
    font.image:release()
  end
  return #lines
end
return R

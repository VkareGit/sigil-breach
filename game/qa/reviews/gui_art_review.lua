-- Optional offscreen review of the shipped art at its real HUD placement.
-- This creates review artifacts only; it never opens a gameplay save.
local T = {}
local states = {
  { name = 'steady', time = 0, hp = 100, shotAge = 10, hurt = 0 },
  { name = 'left', time = 3 / 0.65, hp = 100, shotAge = 10, hurt = 0 },
  { name = 'right', time = 5 / 0.65, hp = 100, shotAge = 10, hurt = 0 },
  { name = 'impact', time = 0, hp = 100, shotAge = 10, hurt = 0.8 },
  { name = 'critical', time = 0, hp = 18, shotAge = 10, hurt = 0 },
  { name = 'braced', time = 0, hp = 100, shotAge = 0.01, hurt = 0 },
}
local function save(canvas, path)
  local data = canvas:newImageData()
  local encoded = data:encode('png')
  local file = assert(io.open(path, 'wb'))
  file:write(encoded:getString())
  file:close()
  data:release()
  encoded:release()
end
function T.run(output)
  local lg = love.graphics
  local P = require('src.ui.portrait')
  local S = require('src.ui.reliquary')
  S.init()
  if not P.image then
    P.init()
  end
  local report = {}
  local function check(label, value)
    report[#report + 1] = (value and 'PASS ' or 'FAIL ') .. label
    assert(value, label)
  end
  check(
    'active framed atlas is the versioned ash fresco',
    S.path == 'assets/art/reliquary-ash-v16.png'
  )
  check(
    'active six-state knight uses the versioned matte iron atlas',
    P.path == 'assets/art/nosiciel-iron-v16.png'
  )
  local frameData = love.image.newImageData(S.path)
  local faceData = love.image.newImageData(P.path)
  check(
    'both atlases preserve their authored 1536 by 1024 geometry',
    frameData:getWidth() == 1536
      and frameData:getHeight() == 1024
      and faceData:getWidth() == 1536
      and faceData:getHeight() == 1024
  )
  local light, total = 0, 0
  for y = 500, 825, 3 do
    for x = 200, 1299, 3 do
      local r, g, b = frameData:getPixel(x, y)
      if 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.55 then
        light = light + 1
      end
      total = total + 1
    end
  end
  check(
    'quiet menu writing ground remains over 98 percent high-value plaster',
    light / total > 0.98
  )
  local sheet = lg.newCanvas(1280, 840)
  lg.push('all')
  lg.setCanvas(sheet)
  lg.clear(0.10, 0.085, 0.075)
  lg.pop()
  local unique = {}
  for i, state in ipairs(states) do
    local g = {
      time = state.time,
      player = { hp = state.hp },
      view = { hurt = state.hurt, shotAge = state.shotAge },
    }
    check('portrait response ' .. state.name .. ' selects its own authored pose', P.frame(g) == i)
    local canvas = lg.newCanvas(1280, 720)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    lg.setScissor()
    lg.setDepthMode()
    lg.setShader()
    lg.setBlendMode('alpha')
    lg.clear(0, 0, 0, 0)
    P.draw(g, 565, 584, 150)
    lg.pop()
    local pixels = canvas:newImageData()
    local leaks, interior, crown, signature = 0, 0, 0, 0
    local b = P.bounds
    for y = 580, 719 do
      for x = 560, 719 do
        local r, green, blue, a = pixels:getPixel(x, y)
        if x < b.x or x >= b.x + b.w or y < b.y or y >= b.y + b.h then
          if a > 0.009 then
            leaks = leaks + 1
          end
        elseif a > 0.25 then
          interior = interior + 1
          signature = signature + r * 3 + green * 7 + blue * 11
        end
        if
          x >= 631
          and x <= 649
          and y >= 605
          and y <= 619
          and a > 0.7
          and r + green + blue < 1.5
        then
          crown = crown + 1
        end
      end
    end
    check(
      'portrait ' .. state.name .. ' has no pixels outside the fixed arched window',
      leaks == 0 and interior > 9000
    )
    check('portrait ' .. state.name .. ' keeps the helmet crown under the arch', crown > 15)
    check('portrait ' .. state.name .. ' is visually distinct', not unique[signature])
    unique[signature] = true
    pixels:release()
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    lg.setShader()
    lg.clear(0, 0, 0, 0)
    S.status()
    P.draw(g, 565, 584, 150)
    lg.pop()
    save(canvas, output .. '/portrait-' .. i .. '-' .. state.name .. '-hud.png')
    lg.push('all')
    lg.setCanvas(sheet)
    lg.origin()
    lg.setShader()
    lg.setColor(1, 1, 1)
    local x, y = (i - 1) % 3 * 426, math.floor((i - 1) / 3) * 420
    local q = lg.newQuad(550, 584, 180, 136, 1280, 720)
    lg.draw(canvas, q, x + 33, y + 15, 0, 2, 2)
    lg.draw(canvas, q, x + 33, y + 291, 0, 0.75, 0.75)
    lg.setColor(0.9, 0.86, 0.75)
    lg.print(i .. ' / ' .. state.name, x + 205, y + 309)
    lg.pop()
    q:release()
    canvas:release()
  end
  save(sheet, output .. '/portrait-six-states.png')
  sheet:release()
  local panel = lg.newCanvas(1280, 720)
  local originalDraw = lg.draw
  local trims, figures, proportionate = 0, 0, true
  lg.draw = function(image, quad, x, y, angle, sx, sy, ...)
    if image == S.image and (quad == S.frames[4].q or quad == S.frames[6].q) then
      figures = figures + 1
    elseif image == S.image and quad == S.sideTrim then
      trims = trims + 1
      proportionate = proportionate and math.abs(sx - sy) < 1e-8
    end
    return originalDraw(image, quad, x, y, angle, sx, sy, ...)
  end
  lg.push('all')
  lg.setCanvas(panel)
  lg.origin()
  lg.setShader()
  lg.clear(0.08, 0.07, 0.065)
  S.panel(30, 30, 1220, 440, 32, 6)
  S.panel(30, 495, 450, 62, 12, 2)
  S.panel(520, 495, 360, 62, 12, 3)
  S.panel(920, 495, 330, 62, 12, 4)
  S.status()
  lg.pop()
  lg.draw = originalDraw
  check(
    'menu sides use proportionate painted trim while figures stay confined to HUD niches',
    figures == 0 and trims == 8 and proportionate
  )
  save(panel, output .. '/panels-and-status.png')
  panel:release()
  frameData:release()
  faceData:release()
  local file = assert(io.open(output .. '/art-checks.txt', 'w'))
  file:write(table.concat(report, '\n') .. '\n' .. #report .. ' PASS\n')
  file:close()
  return #report
end
return T

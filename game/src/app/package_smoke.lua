-- A small installed-runtime health check: real art, fonts, map, both weapons,
-- simulation and rendering. No tests/qa module or developer file is needed.
local S = {}
function S.run(Game, renderer, getGame, settings, output)
  local UI = require('src.ui.interface')
  local Gallery = require('src.render.gallery')
  local lg = love.graphics
  local tickRate = 120
  local fingerprint = assert(love.filesystem.read('build-fingerprint.txt')):match('^%x+')
  assert(fingerprint and #fingerprint == 64, 'package fingerprint missing')
  assert(not love.filesystem.getInfo('qa'), 'player package contains developer diagnostics')
  assert(not love.filesystem.getInfo('tests'), 'player package contains developer tests')
  assert(not love.filesystem.getInfo('docs'), 'player archive contains developer documentation')
  local w, h = lg.getDimensions()
  local canvas = lg.newCanvas(w, h)
  local function draw(g)
    renderer:draw(g, w, h)
    lg.setCanvas(canvas)
    lg.clear()
    renderer:present(g, w, h)
    UI.draw(g, w, h, settings)
    lg.setCanvas()
  end
  draw(getGame())
  local field = Game.new('field')
  field:act('catalog', 'field_skirmish')
  while Gallery.pending(renderer) > 0 do
    Gallery.preloadStep(renderer)
  end
  for _ = 1, 8 do
    field:update(1 / tickRate, {})
  end
  for index in ipairs(field.player.loadout) do
    field:switchWeapon(index)
    for _ = 1, tickRate do
      field:update(1 / tickRate, {})
    end
    draw(field)
  end
  local pixels = canvas:newImageData()
  local visible = false
  for y = 0, h - 1, math.max(1, math.floor(h / 8)) do
    for x = 0, w - 1, math.max(1, math.floor(w / 8)) do
      local red, green, blue = pixels:getPixel(x, y)
      visible = visible or red + green + blue > 1
    end
  end
  assert(visible, 'package smoke capture is blank')
  local bytes = pixels:encode('png')
  assert(output, 'package smoke requires an output directory')
  local screenshot = assert(io.open(output .. '/package-smoke.png', 'wb'))
  screenshot:write(bytes:getString())
  screenshot:close()
  bytes:release()
  pixels:release()
  canvas:release()
  local report = assert(io.open(output .. '/package-smoke.txt', 'wb'))
  report:write('PACKAGE SMOKE: PASSED\nSource fingerprint: ' .. fingerprint .. '\n')
  report:write(
    'Loaded player archive without qa/tests/docs; rendered menu and test field; simulated movement clock and drew equipped weapons.\n'
  )
  report:close()
  print('PACKAGE SMOKE: PASSED')
end
return S

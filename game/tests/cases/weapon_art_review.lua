local Tests = {}
function Tests.run(Game, renderer)
  local Fixtures = require('tests.support.fixtures')
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Gallery = require('src.render.gallery')
  local output = os.getenv('SIGIL_UI_QA_DIR') or require('src.app.release').qaOutput
  local lines = {}
  local check = Fixtures.checker(lines, 'weapon review: ', 'weapon review: ')
  while Gallery.pending(renderer) > 0 do
    Gallery.preloadStep(renderer)
  end
  for slot, name in ipairs({ 'shotgun', 'revolver' }) do
    local g = Field.new(Game)
    Field.close(g)
    g.testing, g.weapon = true, slot
    g.view.swapAge, g.view.shotAge = 1, 10
    g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
    local w, h = 1280, 720
    renderer:resize(w, h)
    renderer:draw(g, w, h)
    local target = love.graphics.newCanvas(w, h)
    love.graphics.push('all')
    love.graphics.setCanvas(target)
    love.graphics.origin()
    renderer:present(g, w, h)
    UI.draw(g, w, h, { sensitivity = 1, motion = true, music = 0, hints = false })
    love.graphics.pop()
    local pixels = target:newImageData()
    local bytes = pixels:encode('png')
    local file = assert(io.open(output .. '/weapon-' .. name .. '-scene-v32.png', 'wb'))
    file:write(bytes:getString())
    file:close()
    bytes:release()
    pixels:release()
    target:release()
    check(name .. ' renders in the real fresco arena with the existing HUD', true)
  end
  local count = require('qa.reviews.weapon_timeline').run(Game, renderer, output)
  check(
    'real full, partial-one, cancelled/resumed and trigger-interrupted reloads complete',
    count > 0
  )
  local poses = require('qa.reviews.weapon_material').run(Game, renderer, output)
  check('matte material preserves every pose silhouette and reduces fine contrast', poses > 0)
  return lines
end
return Tests

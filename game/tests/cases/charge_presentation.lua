local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Effects = require('src.render.effects')
  local Integrity = require('src.session.integrity')
  local UI = require('src.ui.interface')
  local lines = {}
  local check = Fixtures.checker(lines, 'charge handoff: ', 'charge handoff: ')
  local function capture(g, name)
    local before = Integrity.capture(g)
    renderer:resize(1280, 720)
    renderer:draw(g, 1280, 720)
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    renderer:present(g, 1280, 720)
    UI.draw(g, 1280, 720)
    love.graphics.pop()
    local data = canvas:newImageData()
    local png = data:encode('png')
    local file = assert(io.open(require('qa.output').path(name .. '.png'), 'wb'))
    file:write(png:getString())
    file:close()
    png:release()
    data:release()
    canvas:release()
    check(
      name .. ' leaves flight, fuse and simulation untouched',
      not Integrity.difference(before, Integrity.capture(g))
    )
  end
  for _, motion in ipairs({ true, false }) do
    local previous = 0
    for _, time in ipairs({ 0, 1 / 120, 1 / 60, 0.05, 0.1 }) do
      local g = Fixtures.arena(G)
      g.view.motion, g.view.messageTimer = motion, 0
      assert(g:cast(1))
      for _ = 1, math.floor(time * 120 + 0.5) do
        g:update(1 / 120, {})
      end
      local c = assert(g.charges[1])
      local alpha = Effects.chargeAlpha(g, c)
      check(
        'outgoing fade is bounded and increases with real flight at ' .. time,
        alpha >= previous and alpha >= 0 and alpha <= 1
      )
      if time == 0 then
        check('hand replaces the oversized release sprite', alpha == 0)
      end
      if time == 0.1 then
        check('released charge is fully visible after handoff', alpha == 1)
      end
      previous = alpha
      capture(
        g,
        'charge-handoff-' .. (motion and 'on' or 'off') .. '-' .. math.floor(time * 1000 + 0.5)
      )
      if time == 1 / 60 then
        c.vx, c.vy, c.vz = -c.vx, -c.vy, -c.vz
        check('an early return toward the player stays opaque', Effects.chargeAlpha(g, c) == 1)
        capture(g, 'charge-return-' .. (motion and 'on' or 'off'))
      end
    end
  end
  local g = Fixtures.arena(G)
  assert(g:cast(1))
  local c = g.charges[1]
  c.fuse = c.maxFuse - 0.2
  check('an older charge near the eye remains visible', Effects.chargeAlpha(g, c) == 1)
  c.fuse = c.maxFuse
  g.view.abilityCast = nil
  check('a throw without a displayed hand gesture never fades away', Effects.chargeAlpha(g, c) == 1)
  return lines
end
return Tests

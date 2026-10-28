local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(get, settings, settle)
  local U = require('src.ui.interface')
  local Intent = require('src.player.intent')
  local lines = {}
  local check = Fixtures.checker(lines, '', '')
  local function key(value, repeatKey)
    love.keypressed(value, value, repeatKey)
    if settle then
      settle()
    end
  end
  local function click(id)
    for _, button in ipairs(U.controls(get(), settings)) do
      if button.id == id then
        local w, h = love.graphics.getDimensions()
        local scale = math.min(w / 1280, h / 720)
        love.mousepressed(
          (w - 1280 * scale) * 0.5 + (button.x + button.w * 0.5) * scale,
          (h - 720 * scale) * 0.5 + (button.y + button.h * 0.5) * scale,
          1
        )
        if settle then
          settle()
        end
        return
      end
    end
    error('Missing controller fixture ' .. id)
  end
  click('field_skirmish')
  local g = get()
  g.testField.frozen = true
  key('space')
  check('real Space callback queues a short jump tap', g.player.jumpBuffer == Intent.window)
  Intent.clear(g)
  key('space', true)
  check('operating-system key repeat does not create extra jump taps', g.player.jumpBuffer == 0)
  key('space')
  Intent.queue(g, 'fire')
  key('escape')
  check(
    'pause immediately clears both pending actions',
    g.state == 'paused' and g.player.fireBuffer == 0 and g.player.jumpBuffer == 0
  )
  click('resume')
  local shots = g.player.shots
  g:update(1 / 120, {})
  check(
    'resume cannot replay a shot or jump queued before pause',
    g.player.shots == shots and g.player.jump == 0
  )
  key('space')
  Intent.queue(g, 'fire')
  key('tab')
  check(
    'map entry immediately cancels pending actions',
    g.map and g.player.fireBuffer == 0 and g.player.jumpBuffer == 0
  )
  key('tab')
  key('space')
  Intent.queue(g, 'fire')
  love.focus(false)
  check(
    'focus loss clears pending actions and releases gameplay',
    g.state == 'paused'
      and g.player.fireBuffer == 0
      and g.player.jumpBuffer == 0
      and not love.mouse.getRelativeMode()
  )
  if not settings.motion then
    key('c')
  end
  g.view.viewPunch = 0.04
  g.view.kickBack = 1.5
  g.view.weaponImpactY = 4
  g.view.recoil = 2
  g.view.recoilV = 5
  g.view.bank = 0.02
  local mag, reload = g.player.arsenal.exorcist.mag, g.player.reload
  key('c')
  key('c')
  check(
    'motion toggle in pause discards body spring residue without spending ammunition',
    settings.motion
      and g.view.motion
      and g.view.viewPunch == 0
      and g.view.kickBack == 0
      and g.view.weaponImpactY == 0
      and g.view.recoil == 0
      and g.view.recoilV == 0
      and g.view.bank == 0
      and g.player.arsenal.exorcist.mag == mag
      and g.player.reload == reload
  )
  click('resume')
  key('f2')
  click('field_leave')
  check('input lifecycle trial returns to its original menu', get().state == 'menu' and get() ~= g)
  return lines
end
return Tests

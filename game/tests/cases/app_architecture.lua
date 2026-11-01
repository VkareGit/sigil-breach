local Tests = {}

function Tests.run(check)
  local Application = require('src.app.application')
  local Presentation = require('src.render.presentation')
  local Preferences = require('src.storage.preferences')
  local held, mouseDown = {}, false
  local originalKeyboard, originalMouse = love.keyboard.isDown, love.mouse.isDown
  local originalCapture, originalSave = Presentation.capture, Preferences.save
  local ok, err = pcall(function()
    love.keyboard.isDown = function(...)
      for index = 1, select('#', ...) do
        if held[select(index, ...)] then
          return true
        end
      end
      return false
    end
    love.mouse.isDown = function()
      return mouseDown
    end
    local app, other = Application.new(), Application.new()
    app.settings.motion = not other.settings.motion
    app.input.pendingDash = true
    check(
      'application instances own independent settings and physical input',
      app.settings ~= other.settings
        and app.settings.motion ~= other.settings.motion
        and app.input ~= other.input
        and not other.input.pendingDash
    )

    local steps, captures, capturedAt = {}, 0, nil
    app.qa = {
      isolated = true,
      has = function()
        return false
      end,
    }
    app.game = {
      state = 'playing',
      player = {},
      time = 0,
      mode = 'floor',
      act = require('src.session.game').act,
    }
    app.game.update = function(game, dt, input)
      steps[#steps + 1] = {
        dt = dt,
        dash = input.dash,
        slide = input.slide,
        forward = input.forward,
        shoot = input.shoot,
      }
      game.time = game.time + dt
    end
    Presentation.capture = function(game)
      check('application captures the current session before simulating it', game == app.game)
      captures = captures + 1
      capturedAt = game.time
    end
    app.input.pendingSlide = true
    held.w, mouseDown = true, true
    app:update(1 / 240)
    check(
      'sub-tick render frames retain dash and slide edges',
      #steps == 0 and app.input.pendingDash and app.input.pendingSlide
    )
    app:update(1 / 60)
    check(
      'multiple simulation ticks consume physical edges exactly once',
      #steps == 2
        and steps[1].dash
        and steps[1].slide
        and not steps[2].dash
        and not steps[2].slide
        and not app.input.pendingDash
        and not app.input.pendingSlide
    )
    check(
      'held movement and fire remain active on every fixed tick',
      steps[1].forward == 1
        and steps[2].forward == 1
        and steps[1].shoot
        and steps[2].shoot
        and steps[1].dt == 1 / 120
        and steps[2].dt == 1 / 120
    )
    check(
      'catch-up frames keep only the final tick starting pose for interpolation',
      captures == 1 and capturedAt == 1 / 120
    )
    check(
      'fixed tick interpolation retains the remaining partial frame',
      math.abs(app.accumulator - 1 / 240) < 1e-10
    )
    app:update(1 / 120)
    check(
      'a single due tick captures its starting pose as before',
      captures == 2 and capturedAt == 2 / 120 and #steps == 3
    )

    app.input:reset(true)
    check('held menu click stays suppressed after entering play', not app.input:sample().shoot)
    mouseDown = false
    app.input:sample()
    mouseDown = true
    check('releasing the menu click enables the next deliberate shot', app.input:sample().shoot)
    held.s = true
    check(
      'opposing held movement keys cancel without event-order dependence',
      app.input:sample().forward == 0
    )

    local saves = 0
    Preferences.save = function(settings)
      check(
        'settings persistence receives the owning application settings',
        settings == app.settings
      )
      saves = saves + 1
    end
    app.game.player.fireBuffer, app.game.player.jumpBuffer = 0.12, 0.12
    local previousHints = app.settings.hints
    app:action('hints')
    check(
      'immediate settings commands keep gameplay intentions and skip isolated writes',
      app.settings.hints ~= previousHints
        and app.game.player.fireBuffer == 0.12
        and app.game.player.jumpBuffer == 0.12
        and saves == 0
    )
    app:action('settings')
    check(
      'screen commands cancel both buffered gameplay intentions',
      app.game.state == 'settings'
        and app.game.player.fireBuffer == 0
        and app.game.player.jumpBuffer == 0
    )
    app.qa.isolated = false
    app:saveSettings()
    check('normal application settings use the persistence boundary once', saves == 1)
  end)
  love.keyboard.isDown, love.mouse.isDown = originalKeyboard, originalMouse
  Presentation.capture, Preferences.save = originalCapture, originalSave
  if not ok then
    error(err, 0)
  end
  require('tests.support.presentation_catchup').run(check)
end

return Tests

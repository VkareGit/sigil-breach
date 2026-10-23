-- LÖVE is the platform adapter. Application state and routing live in src.app.
local Application = require('src.app.application')
local app = Application.new()

function love.load(arguments)
  app:load(arguments)
end
function love.update(dt)
  app:update(dt)
end
function love.draw()
  app:draw()
end
function love.resize(w, h)
  app:resize(w, h)
end
function love.mousemoved(x, y, dx, dy)
  if app.loading then
    return
  end
  app.input:mousemoved(app, x, y, dx, dy)
end
function love.keypressed(key, scancode, isrepeat)
  if app.loading then
    if key == 'escape' then
      app:action('loading_cancel')
    end
    return
  end
  app.input:keypressed(app, key, scancode, isrepeat)
end
function love.mousepressed(x, y, button)
  if app.loading then
    return
  end
  app.input:mousepressed(app, x, y, button)
end
function love.wheelmoved(x, y)
  if app.loading then
    return
  end
  app.input:wheelmoved(app, x, y)
end
function love.focus(focused)
  if app.loading then
    app.loading.focused = focused
    app.input:forget(app.game)
    app.input:reset(true)
    return
  end
  app.input:focus(app, focused)
end
function love.quit()
  app:quit()
end
function love.errorhandler(message)
  return app:errorhandler(message)
end

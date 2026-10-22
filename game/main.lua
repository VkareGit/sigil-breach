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
  app.input:mousemoved(app, x, y, dx, dy)
end
function love.keypressed(key, scancode, isrepeat)
  app.input:keypressed(app, key, scancode, isrepeat)
end
function love.mousepressed(x, y, button)
  app.input:mousepressed(app, x, y, button)
end
function love.wheelmoved(x, y)
  app.input:wheelmoved(app, x, y)
end
function love.focus(focused)
  app.input:focus(app, focused)
end
function love.quit()
  app:quit()
end
function love.errorhandler(message)
  return app:errorhandler(message)
end

-- LÖVE is the platform adapter. Application state and routing live in src.app.
-- LuaJIT's default limits suit a script. This game outgrows them: compiled code is thrown away
-- and compiled again without end, and every key waits for it. With room for all of it a frame
-- costs half as much and one in ten no longer misses the display (qa/reviews/frame_watch.lua).
require('jit.opt').start(
  'maxtrace=20000',
  'maxrecord=8000',
  'maxmcode=131072',
  'sizemcode=1024',
  'maxsnap=1000',
  'maxside=200'
)
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
    elseif key == 'return' then
      app:action('loading_retry')
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

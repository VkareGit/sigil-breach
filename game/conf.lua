function love.conf(t)
  t.identity = 'sigil-breach-prototype'
  t.version = '11.5'
  t.console = false
  t.window.title = require('src.app.release').title
  t.window.width, t.window.height = 1280, 720
  t.window.resizable = true
  t.window.minwidth, t.window.minheight = 960, 540
  t.window.vsync = 1
  t.window.msaa = 0
  -- LOVE 11.5 has no window.visible flag. Automated canvas captures use an
  -- off-screen window; normal launches retain the centered desktop window.
  for _, value in pairs(arg or {}) do
    if require('qa.runtime').captureFlag(value) then
      t.window.centered = false
      t.window.x = -16000
      t.window.y = -16000
    end
  end
  t.modules.physics = false
  t.modules.joystick = false
end

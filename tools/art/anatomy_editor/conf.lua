function love.conf(t)
  t.identity = 'sigil-breach-anatomy-editor'
  t.window.title = 'SIGIL: BREACH - anatomy region editor'
  t.window.width, t.window.height = 1280, 900
  t.window.resizable = true
  t.console = true
  t.modules.audio, t.modules.joystick, t.modules.physics = false, false, false
end
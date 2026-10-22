local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run()
  local A = require('src.audio.audio')
  local oldMuted = A.muted
  local lines = {}
  local check = Fixtures.checker(lines, '', '')
  A.muted = false
  local spatial = A.playAt('revolver', 5, 0, { x = 0, z = 0, yaw = 0 }, 0.1)
  check('physical revolver has a playable spatial audio voice', spatial and spatial:isPlaying())
  spatial:stop()
  A.update(0)
  local reused = A.play('revolver', 0.1)
  local x, y, z = reused:getPosition()
  check(
    'finished Source is reused and its spatial position resets',
    reused == spatial and x == 0 and y == 0 and z == 0
  )
  local keys = { 'shot', 'revolver', 'blast', 'thunder', 'cast', 'antler', 'step' }
  for i = 1, 180 do
    A.play(keys[(i - 1) % #keys + 1], 0.01)
  end
  check('audio overload keeps at most28active and28cached voices', #A.live <= 28 and A.pooled <= 28)
  for _, s in ipairs(A.live) do
    s:stop()
  end
  A.update(0)
  check('stopped audio voices retire without a live Source leak', #A.live == 0 and A.pooled <= 28)
  local total = 0
  for _, pool in pairs(A.pool) do
    total = total + #pool
  end
  check('cached Source count matches the bounded idle pools', total == A.pooled)
  A.muted = oldMuted
  return lines
end
return Tests

local R = {}
function R.run(G, renderer, output)
  local Field = require('src.run.test_field')
  local U = require('src.ui.interface')
  local Shadows = require('src.render.shadows')
  local lg = love.graphics
  local count = 0
  local report = {}
  local function capture(g, name)
    g.view.messageTimer, g.view.feedbackTimer, g.zoneTimer = 0, 0, 0
    g.elapsed = 70
    renderer:draw(g, 1280, 720)
    local canvas = lg.newCanvas(1280, 720)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    lg.setShader()
    lg.setDepthMode()
    renderer:present(g, 1280, 720)
    U.draw(g, 1280, 720, { sensitivity = 1, motion = true, music = 0, hints = true })
    lg.pop()
    local data = canvas:newImageData()
    local f = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    f:write(data:encode('png'):getString())
    f:close()
    canvas:release()
    count = count + 1
    return data
  end
  local g = Field.new(G)
  g.testing = true
  Field.close(g)
  g.enemies = {}
  g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27.5, math.pi, 0.035
  for _, entry in ipairs({
    { 'imp', 13.5, 22 },
    { 'armored', 15.5, 21 },
    { 'stolas', 18.5, 21 },
    {
      'furfur',
      16,
      18,
    },
  }) do
    local e = g:spawn(entry[1], entry[2], entry[3])
    e.awake = true
    e.memory = 60
    e.facing = 0
    e.ai = 'idle'
    e.walkSpeed = 0
  end
  g.time = 3
  capture(g, 'lighting-01-nave'):release()
  g.enemies = {}
  g.player.x, g.player.z, g.player.yaw, g.player.pitch = 7, 17, -math.pi / 2, 0.03
  capture(g, 'lighting-02-west-fresco'):release()
  g.player.x, g.player.z, g.player.yaw, g.player.pitch = 24, 17, math.pi / 2, 0.03
  capture(g, 'lighting-03-east-fresco'):release()
  g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 28, math.atan2(-2, -3), -0.36
  g.player.jump = 1.3
  local e = g:spawn('armored', 14.4, 24)
  e.awake = true
  e.memory = 60
  e.facing = 0
  e.ai = 'idle'
  e.walkSpeed = 0
  local cast = capture(g, 'lighting-04-cast-shadow')
  local draw = Shadows.draw
  Shadows.draw = function() end
  local uncast = capture(g, 'lighting-05-without-cast-shadow')
  Shadows.draw = draw
  local changed, wrong, largest = 0, 0, 0
  for y = 120, 590 do
    for x = 0, 1279 do
      local r1, g1, b1 = cast:getPixel(x, y)
      local r0, g0, b0 = uncast:getPixel(x, y)
      local difference = (r0 - r1) * 0.30 + (g0 - g1) * 0.59 + (b0 - b1) * 0.11
      if difference > 0.002 then
        changed = changed + 1
        largest = math.max(largest, difference)
      end
      if difference < -0.005 then
        wrong = wrong + 1
      end
    end
  end
  assert(changed > 30 and wrong == 0, 'Projected enemy shadow must darken visible floor only')
  report[#report + 1] = ('Projected pose shadow: %d darker pixels; %d brighter pixels; maximum luminance reduction %.4f.'):format(
    changed,
    wrong,
    largest
  )
  cast:release()
  uncast:release()
  g.player.jump = 0
  g.enemies = {}
  g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27, math.pi, 0
  for _, pair in ipairs({ { 13.5, 25 }, { 16, 21 }, { 16, 14 } }) do
    local e = g:spawn('imp', pair[1], pair[2])
    e.awake = true
    e.memory = 60
    e.facing = 0
    e.ai = 'windup'
    e.windupDuration = 0.7
    e.windup = 0.25
    e.walkSpeed = 0
  end
  capture(g, 'lighting-06-telegraphs'):release()
  g.player.hp = 20
  capture(g, 'lighting-07-critical-visibility'):release()
  g.player.hp = 100
  g:shoot()
  capture(g, 'lighting-08-muzzle'):release()
  g = G.new('descent')
  g.testing = true
  g:start()
  g.time = 2
  g.player.yaw = math.atan2(
    require('src.run.descent').shrine.x - g.player.x,
    require('src.run.descent').shrine.z - g.player.z
  )
  capture(g, 'lighting-09-shrine'):release()
  g.run.phase = 'wave'
  capture(g, 'lighting-10-shrine-during-wave'):release()
  local f = assert(io.open(output .. '/lighting-review.txt', 'w'))
  f:write(
    table.concat(report, '\n')
      .. '\n'
      .. count
      .. ' actual 1280x720 captures; one arena; UI and crosshair retained.\n'
  )
  f:close()
  return count
end
return R

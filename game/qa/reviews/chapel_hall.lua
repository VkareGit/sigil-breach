-- Native acceptance frames of a painted hall: real session, real weapon, real
-- HUD, the demon in place. A walk writes numbered frames for a moving review.
local Review = {}
local SHOTS = {
  { 'A-target-camera', 10, 25, 10, 3.0, 10 },
  { 'B-vault', 10, 26, 10, 9.0, 13 },
  { 'C-niche-close', 7.5, 16.5, 2.5, 2.5, 16 },
  { 'D-diagonal', 14, 24.5, 6.5, 2.6, 15 },
  { 'E-altar-steps', 10, 13.5, 10, 2.2, 6 },
  { 'F-reverse', 10, 13, 10, 3.0, 28 },
  { 'G-door-from-hall', 12, 24, 18, 2, 27.5 },
  { 'I-sarcophagus', 7.2, 17.6, 4, 0.6, 15.5 },
  { 'J-apse-from-altar', 10, 8.5, 5.5, 3, 7 },
  { 'K-apse-breach', 10, 12, 10, 8, 5.5 },
  { 'L-south-wall', 10, 19, 10, 3.5, 29.5 },
  { 'M-storm-hall', 38, 25, 38, 3.0, 10 },
  { 'N-storm-diagonal', 34, 24.5, 41.5, 2.6, 15 },
  { 'O-narthex-start', 24, 37, 24, 3.2, 20 },
  { 'P-nave-from-south', 24, 31, 24, 4.5, 10 },
  { 'Q-nave-from-north', 24, 13, 24, 4.5, 34 },
  { 'R-nave-door', 22.5, 24, 19.5, 2.2, 27.5 },
  { 'S-sanctuary', 24, 11, 24, 2.0, 3 },
  { 'T-sanctuary-inside', 24, 7, 24, 1.8, 2 },
  { 'U-crypt-west', 20, 4, 15, 1.5, 3.5 },
  { 'V-gallery', 16, 4, 14, 1.4, 3.5 },
  { 'W-threshold', 19, 27.5, 13, 2, 26 },
  { 'X-narthex-side', 19, 37, 29, 2, 36 },
}
function Review.run(Game, renderer, output, walk)
  local UI = require('src.ui.interface')
  local Ballistics = require('src.combat.ballistics')
  local lg = love.graphics
  UI.useMouse = false
  local height = tonumber(os.getenv('SIGIL_HALL_HEIGHT'))
  if height then
    require('src.content.tuning').renderHeight = height
  end
  local release = require('src.app.release')
  local g = Game.new('field', release.sessionMaps.field, release.sessionOptions.field)
  g.ephemeral, g.state, g.elapsed, g.view.messageTimer = true, 'playing', 70, 0
  g.view.motion = false
  g.time = 12
  local function capture(name, x, z, targetX, targetY, targetZ, w, h)
    w, h = w or 1920, h or 1080
    local p = g.player
    p.x, p.z = x, z
    local dx, dz = targetX - x, targetZ - z
    p.yaw = math.atan2(dx, dz)
    local _, eye = Ballistics.origin(g)
    p.pitch = math.atan2(targetY - eye, math.sqrt(dx * dx + dz * dz))
    g.view.presentationPrevious = nil
    local canvas = lg.newCanvas(w, h)
    renderer:resize(w, h)
    renderer:draw(g, w, h)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    renderer:present(g, w, h)
    UI.draw(g, w, h, { motion = false, hints = true })
    lg.pop()
    local data = canvas:newImageData()
    local png = data:encode('png')
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(png:getString())
    file:close()
    png:release()
    data:release()
    canvas:release()
  end
  g:spawn('boss', 10, 15)
  for _, s in ipairs(SHOTS) do
    capture(s[1], s[2], s[3], s[4], s[5], s[6])
  end
  -- GPU cost of one view: every frame is read back, so the time is real.
  local function cost(label, x, z, yaw)
    renderer:resize(1920, 1080)
    local probe = lg.newCanvas(4, 4)
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = x, z, yaw, 0.1
    local times = {}
    for i = 1, 90 do
      local started = love.timer.getTime()
      renderer:draw(g, 1920, 1080)
      lg.setCanvas(probe)
      lg.setShader()
      lg.setColor(1, 1, 1)
      lg.draw(renderer.canvas, 0, 0, 0, 4 / renderer.w, 4 / renderer.h)
      lg.setCanvas()
      probe:newImageData(0, 1, 0, 0, 1, 1):release()
      times[i] = (love.timer.getTime() - started) * 1000
    end
    table.sort(times)
    probe:release()
    return string.format('%s: median %.2f ms, p95 %.2f ms', label, times[45], times[85])
  end
  local report = assert(io.open(output .. '/hall-measure.txt', 'w'))
  report:write(cost('painted hall', 10, 25, math.pi), '\n')
  report:write(cost('nave', 24, 33, math.pi), '\n')
  report:close()
  if walk then
    local keys = {
      { 24, 37.5, 24, 3.4, 20 },
      { 24, 30, 24, 4.2, 12 },
      { 23, 24, 19, 2.4, 27.5 },
      { 20.6, 27.5, 12, 2.2, 26 },
      { 16.8, 26, 10, 2.6, 19 },
      { 13, 24.4, 10, 3.2, 12 },
      { 8, 21.6, 8, 3.5, 11 },
      { 7.2, 18.2, 3, 3.2, 16.5 },
      { 7.2, 14, 9, 4, 7 },
      { 8.6, 11.8, 10, 4.5, 6 },
      { 10.6, 9.8, 7, 7, 6 },
      { 13, 12.6, 10, 3, 25 },
      { 24, 22, 24, 7, 10 },
      { 24, 12, 24, 2.4, 3 },
      { 24, 7, 24, 2, 2 },
    }
    local frame = 0
    for i = 1, #keys - 1 do
      local a, b = keys[i], keys[i + 1]
      for step = 0, 39 do
        local t = step / 40
        t = t * t * (3 - 2 * t)
        local function mix(n)
          return a[n] + (b[n] - a[n]) * t
        end
        frame = frame + 1
        capture(
          string.format('walk-%04d', frame),
          mix(1),
          mix(2),
          mix(3),
          mix(4),
          mix(5),
          1280,
          720
        )
      end
    end
  end
end
return Review

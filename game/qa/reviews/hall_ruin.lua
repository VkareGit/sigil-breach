-- Real frames of things breaking: every shot goes down the real weapon path, so
-- a ruin here is what a player gets. Numbered frames make a moving review.
local Review = {}
function Review.run(Game, renderer, output)
  local UI = require('src.ui.interface')
  local Ballistics = require('src.combat.ballistics')
  local lg = love.graphics
  UI.useMouse = false
  local release = require('src.app.release')
  local g = Game.new('field', release.sessionMaps.field, release.sessionOptions.field)
  g.ephemeral, g.state, g.elapsed, g.view.messageTimer = true, 'playing', 70, 0
  g.time = 12
  g.enemies = {}
  local function aim(x, z, tx, ty, tz)
    local p = g.player
    p.x, p.z = x, z
    local dx, dz = tx - x, tz - z
    p.yaw = math.atan2(dx, dz)
    local _, eye = Ballistics.origin(g)
    p.pitch = math.atan2(ty - eye, math.sqrt(dx * dx + dz * dz))
  end
  local function capture(name, w, h)
    w, h = w or 1920, h or 1080
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
  local frame = 0
  local function roll(count, x, z, tx, ty, tz)
    for _ = 1, count do
      aim(x, z, tx, ty, tz)
      for _ = 1, 5 do
        g:update(1 / 120, {})
      end
      g.time = g.time + 1 / 24
      frame = frame + 1
      capture(string.format('ruin-%04d', frame), 960, 540)
    end
  end
  -- The trigger held as a player holds it: the weapon keeps its own rate of
  -- fire and reloads by its own rules. Nothing is forced, so waiting is filmed.
  local function fire(x, z, tx, ty, tz)
    for step = 1, 960 do
      aim(x, z, tx, ty, tz)
      if g:shoot() then
        return
      end
      g:update(1 / 120, {})
      if step % 5 == 0 then
        g.time = g.time + 1 / 24
        frame = frame + 1
        capture(string.format('ruin-%04d', frame), 960, 540)
      end
    end
    error('the weapon never fired')
  end
  local x, z = 11, 23.5
  aim(x, z, 5, 3.4, 20)
  capture('A-before')
  roll(12, x, z, 5, 3.4, 20)
  for i = 1, 3 do
    fire(x, z, 5, 3.4, 20)
    roll(10, x, z, 5, 3.4, 20)
    if i == 1 then
      capture('B-wounded')
    end
  end
  capture('C-standing-wounded')
  while not require('src.combat.destruction').broken(g.world, 'ash-pier-3') do
    fire(x, z, 5, 3.4, 20)
    roll(10, x, z, 5, 3.4, 20)
  end
  capture('D-falling')
  roll(84, x, z, 5, 4.5, 20)
  capture('E-fallen')
  aim(x, z, 2.5, 7, 20)
  capture('F-the-tear')
  aim(9, 21, 6.5, 13, 20)
  capture('G-the-hole')
  aim(5.5, 24, 2.5, 8, 20)
  capture('H-through-the-wall')
  aim(10, 25, 10, 3.0, 10)
  capture('I-hall-after')
  -- The small things, one after another.
  x, z = 13, 23
  aim(x, z, 16.4, 0.4, 24.8)
  capture('J-urn-before')
  fire(x, z, 16.4, 0.4, 24.8)
  roll(14, x, z, 16.4, 0.4, 24.8)
  capture('K-urn-after')
  aim(13, 18, 15, 4, 13.7)
  capture('L-banner-before')
  fire(13, 18, 15, 5, 13.7)
  roll(30, 13, 18, 15, 3, 13.7)
  capture('M-banner-fallen')
  fire(10, 12.5, 6.4, 4, 9.6)
  roll(10, 10, 12.5, 6.4, 4, 9.6)
  capture('N-chain-swinging')
  roll(18, 10, 12.5, 6.4, 4, 9.6)
  aim(24, 20.5, 21, 0.5, 20.5)
  capture('O-bench-before')
  fire(24, 20.5, 21, 0.6, 20.5)
  roll(14, 24, 20.5, 21, 0.5, 20.5)
  capture('P-bench-after')
end
return Review

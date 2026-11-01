-- --movement-review: the knight's moves in the proving ground through the
-- ordinary simulation, each captured at three moments (1280x720 frames and a
-- filmstrip): the pigment flecks, the gilded dodge, the stilled perfect
-- dodge, a slide's sparks, a landing's dust, a powder charge's embers.
local Review = {}
function Review.run(Game, renderer, output)
  local lg = love.graphics
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Audio = require('src.audio.audio')
  local Signal = require('src.session.signal')
  local oldMuted, oldMouse = Audio.muted, UI.useMouse
  Audio.muted = true
  UI.useMouse = false
  local step = 1 / 120
  local function run(g, seconds, input)
    for _ = 1, math.floor(seconds / step + 0.5) do
      g:update(step, input or {})
    end
  end
  -- Each scene: a start (x, z, yaw, pitch), what leads up to the move, the
  -- move, and the three moments (s after it) to capture.
  local scenes = {
    {
      name = 'dash-side',
      x = 16,
      z = 25,
      yaw = math.pi,
      move = function(g)
        g:update(step, { strafe = 1, dash = true })
      end,
      at = { 0.03, 0.1, 0.3 },
    },
    {
      name = 'dash-forward',
      x = 16,
      z = 27,
      yaw = math.pi,
      move = function(g)
        g:update(step, { forward = 1, dash = true })
      end,
      at = { 0.02, 0.08, 0.3 },
    },
    {
      name = 'dash-back',
      x = 16,
      z = 24,
      yaw = math.pi,
      move = function(g)
        g:update(step, { forward = -1, dash = true })
      end,
      at = { 0.05, 0.15, 0.4 },
    },
    {
      name = 'perfect-dodge',
      x = 16,
      z = 25,
      yaw = math.pi,
      move = function(g)
        g:update(step, { strafe = -1, dash = true })
        Signal(g, 'PerfectDodge', { packet = {}, source = {} })
      end,
      at = { 0.02, 0.15, 0.4 },
    },
    {
      name = 'slide',
      x = 16,
      z = 28,
      yaw = math.pi,
      pitch = -0.12,
      before = function(g)
        run(g, 0.5, { forward = 1 })
      end,
      move = function(g)
        g:update(step, { forward = 1, slide = true })
      end,
      input = { forward = 1 },
      at = { 0.1, 0.25, 0.45 },
    },
    {
      name = 'landing',
      x = 16,
      z = 25,
      yaw = math.pi,
      pitch = -0.35,
      move = function(g)
        g.player.jump, g.player.jumpV = 2, 0
        for _ = 1, 240 do
          g:update(step, {})
          if g.player.jump == 0 then
            break
          end
        end
      end,
      at = { 0.03, 0.15, 0.35 },
    },
    {
      name = 'charge',
      x = 16,
      z = 27,
      yaw = math.pi,
      pitch = 0.05,
      -- A frozen ground holds charges too; this one must fly.
      live = true,
      move = function(g)
        g:cast(1)
      end,
      at = { 0.15, 0.35, 0.7 },
    },
  }
  local scale = 0.25
  local cellW, cellH = 1280 * scale, 720 * scale + 22
  local sheet = lg.newCanvas(cellW * 3, cellH * #scenes)
  lg.push('all')
  lg.setCanvas(sheet)
  lg.clear(0.08, 0.065, 0.05)
  lg.pop()
  local function save(canvas, name)
    local data = canvas:newImageData()
    local png = data:encode('png')
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(png:getString())
    file:close()
    png:release()
    data:release()
  end
  local notes = { 'scene,moment_s,particles,surge,still' }
  for row, scene in ipairs(scenes) do
    local g = Field.new(Game)
    g.ephemeral = true
    Field.close(g)
    g.testField.frozen = not scene.live
    g.enemies, g.pickups = {}, {}
    g.view.motion, g.view.fov = true, 100
    local p = g.player
    p.x, p.z, p.yaw, p.pitch = scene.x, scene.z, scene.yaw, scene.pitch or 0
    run(g, 0.2)
    if scene.before then
      scene.before(g)
    end
    scene.move(g)
    local elapsed = 0
    for column, moment in ipairs(scene.at) do
      run(g, moment - elapsed, scene.input)
      elapsed = moment
      g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
      renderer:resize(1280, 720)
      renderer:draw(g, 1280, 720)
      local frame = lg.newCanvas(1280, 720)
      lg.push('all')
      lg.setCanvas(frame)
      lg.origin()
      lg.setDepthMode()
      lg.setShader()
      renderer:present(g, 1280, 720)
      UI.draw(g, 1280, 720, { sensitivity = 1, motion = true, music = 0, hints = false })
      lg.setCanvas()
      lg.pop()
      save(frame, string.format('movement-marks-%s-%d', scene.name, column))
      notes[#notes + 1] = string.format(
        '%s,%.2f,%d,%.3f,%.3f',
        scene.name,
        moment,
        #g.view.particles,
        g.view.surge or 0,
        g.view.perfectDodge or 0
      )
      lg.push('all')
      lg.setCanvas(sheet)
      lg.origin()
      lg.setColor(0.85, 0.75, 0.56)
      lg.print(
        string.format('%s +%.2f s', scene.name, moment),
        (column - 1) * cellW + 6,
        (row - 1) * cellH + 4
      )
      lg.setColor(1, 1, 1)
      lg.draw(frame, (column - 1) * cellW, (row - 1) * cellH + 22, 0, scale, scale)
      lg.setCanvas()
      lg.pop()
      frame:release()
    end
  end
  save(sheet, 'movement-marks-filmstrip')
  sheet:release()
  local file = assert(io.open(output .. '/movement-marks.csv', 'w'))
  file:write(table.concat(notes, '\n'), '\n')
  file:close()
  Audio.muted, UI.useMouse = oldMuted, oldMouse
  renderer:resize(1280, 720)
end
return Review

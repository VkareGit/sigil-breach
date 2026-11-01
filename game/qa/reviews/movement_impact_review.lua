-- Review real contacts in the original arena, using the ordinary simulation.
local Review = {}
function Review.run(Game, renderer, output)
  local lg = love.graphics
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Audio = require('src.audio.audio')
  local Weapon = require('src.render.weapon')
  local Motion = require('src.feedback.weapon_motion')
  local oldMuted, oldMouse = Audio.muted, UI.useMouse
  Audio.muted = true
  UI.useMouse = false
  local specs = {
    { name = 'wall-front', kind = 'wall', x = 16, z = 28, yaw = 0 },
    { name = 'wall-graze', kind = 'wall', x = 15, z = 28.8, yaw = math.atan2(5, 2) },
    { name = 'normal-jump', kind = 'landing', jump = true },
    { name = 'higher-drop', kind = 'landing', drop = 2 },
  }
  local sheet = lg.newCanvas(1280, 896)
  local mask = lg.newCanvas(800, 450)
  lg.push('all')
  lg.setCanvas(sheet)
  lg.clear(0.08, 0.065, 0.05)
  lg.pop()
  local records = {
    'scenario,capture,impulse,energy_lost,mean_force,cushion_seconds,weapon_x,weapon_y,weapon_roll,central_occlusion,dust',
  }
  local function save(c, name)
    local d = c:newImageData()
    local png = d:encode('png')
    local f = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    f:write(png:getString())
    f:close()
    d:release()
    png:release()
  end
  for row, spec in ipairs(specs) do
    local g = Field.new(Game)
    g.ephemeral = true
    Field.close(g)
    g.testField.frozen = true
    g.player.weapon = 1
    g.view.motion = true
    g.view.fov = 100
    g.enemies = {}
    g.pickups = {}
    if spec.x then
      g.player.x, g.player.z, g.player.yaw = spec.x, spec.z, spec.yaw
    else
      g.player.pitch = -0.80
    end
    local input = spec.kind == 'wall' and { forward = 1 } or {}
    if spec.jump then
      g:update(1 / 120, { jump = true })
    end
    if spec.drop then
      g.player.jump = spec.drop
      g.player.jumpV = 0
    end
    for _ = 1, 12 do
      g:update(1 / 120, input)
    end
    local event
    for column = 1, 4 do
      if column == 2 then
        for _ = 1, 360 do
          g:update(1 / 120, input)
          event = spec.kind == 'wall' and g.view.lastWallImpact or g.view.lastLandingImpact
          if event then
            break
          end
        end
        assert(event, 'Contact review did not reach ' .. spec.name)
      elseif column > 2 then
        for _ = 1, column == 3 and 9 or 21 do
          g:update(1 / 120, {})
        end
      end
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
      local name = string.format('movement-impact-%s-%02d', spec.name, column)
      save(frame, name)
      lg.push('all')
      lg.setCanvas(mask)
      lg.origin()
      lg.setDepthMode()
      lg.setShader()
      lg.clear(0, 0, 0, 0)
      Weapon.draw(g, 800, 450)
      lg.setCanvas()
      lg.pop()
      local pixels = mask:newImageData()
      local covered = 0
      for y = 213, 236 do
        for x = 388, 411 do
          local _, _, _, a = pixels:getPixel(x, y)
          if a > 0.1 then
            covered = covered + 1
          end
        end
      end
      pixels:release()
      assert(covered == 0, 'Contact obscures the centre: ' .. name)
      local x, y, roll = Motion.pose(g)
      records[#records + 1] = string.format(
        '%s,%d,%.6f,%.6f,%.6f,%.3f,%.6f,%.6f,%.7f,%d,%d',
        spec.name,
        column,
        event and event.impulse or 0,
        event and event.energyLost or 0,
        event and event.meanForce or 0,
        event and event.cushionTime or 0,
        x,
        y,
        roll,
        covered,
        event and event.dust or 0
      )
      local px, py = (column - 1) * 320, (row - 1) * 224
      lg.push('all')
      lg.setCanvas(sheet)
      lg.origin()
      lg.setDepthMode()
      lg.setShader()
      lg.setColor(0.85, 0.75, 0.56)
      lg.print(
        spec.name .. ' / ' .. ({ 'approach', 'contact', '+0.075 s', '+0.250 s' })[column],
        px + 8,
        py + 5
      )
      lg.setColor(1, 1, 1)
      lg.draw(frame, px, py + 25, 0, 0.25, 0.25)
      lg.setColor(0.85, 0.75, 0.56)
      lg.print(
        string.format(
          'J %.2f  E %.2f  hands %.1f / %.1f',
          event and event.impulse or 0,
          event and event.energyLost or 0,
          x,
          y
        ),
        px + 8,
        py + 207
      )
      lg.setCanvas()
      lg.pop()
      frame:release()
    end
  end
  save(sheet, 'movement-impact-filmstrip')
  sheet:release()
  mask:release()
  local f = assert(io.open(output .. '/movement-impact-clocks.csv', 'w'))
  f:write(table.concat(records, '\n'))
  f:close()
  Audio.muted, UI.useMouse = oldMuted, oldMouse
  renderer:resize(1280, 720)
  return #records - 1
end
return Review

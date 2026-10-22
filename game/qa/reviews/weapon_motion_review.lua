-- Actual 120 Hz movement and weapon clocks, captured through the normal renderer.
-- The scene uses only the existing test arena. No desktop input or cursor grab.
local Review = {}
function Review.run(Game, renderer, output)
  local lg = love.graphics
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Audio = require('src.audio.audio')
  local Weapon = require('src.render.weapon')
  local Motion = require('src.feedback.weapon_motion')
  local Reload = require('src.combat.reload')
  local previousMuted, previousMouse = Audio.muted, UI.useMouse
  Audio.muted = true
  UI.useMouse = false
  local captures =
    { 0, 0.50, 0.75, 1.15, 1.50, 1.80, 2.0, 2.1, 2.30, 2.60, 2.90, 3.20, 3.41, 3.70, 4.20, 5.80 }
  local names = {
    'spoczynek',
    'pierwszy krok',
    'marsz',
    'zmiana kierunku',
    'hamowanie',
    'zatrzymanie',
    'obrot',
    'powrot celowania',
    'odbicie',
    'lot',
    'ladowanie',
    'po ladowaniu',
    'strzal',
    'przeladowanie',
    'przeladowanie',
    'spoczynek',
  }
  local records = {
    'weapon,time,label,position_x,position_z,jump,carry,phase,offset_x,offset_y,roll,frame,ammo,reserve,shot_age,reload_age',
  }
  local readability = {
    'A 24 x 24 px target around the crosshair at 800 x 450 scene resolution must remain free of the weapon, including muzzle smoke.',
  }
  local mask = lg.newCanvas(800, 450)
  local function save(c, name)
    local data = c:newImageData()
    local encoded = data:encode('png')
    local f = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    f:write(encoded:getString())
    f:close()
    data:release()
    encoded:release()
  end
  for slot = 1, 2 do
    local g = Field.new(Game)
    g.testing = true
    Field.close(g)
    g.testField.frozen = true
    g.weapon = slot
    g.view.motion = true
    g.view.fov = 100
    g.enemies = {}
    g.pickups = {}
    g.player.pitch = 0
    local target = g:spawn('armored', 16, 18.5)
    target.previewFrame = 1
    target.facing = 0
    g:spawn('stolas', 12.8, 19).previewFrame = 1
    local sheet = lg.newCanvas(1280, 896)
    lg.push('all')
    lg.setCanvas(sheet)
    lg.clear(0.10, 0.08, 0.06)
    lg.pop()
    local clock, fired, reloaded = 0, false, false
    local name = slot == 1 and 'shotgun' or 'revolver'
    for index, at in ipairs(captures) do
      while clock < at - 1e-8 do
        local dt = math.min(1 / 120, at - clock)
        local forward = clock >= 0.4 - 1e-8 and clock < 1.1 - 1e-8 and 1 or 0
        local strafe = clock >= 1.1 - 1e-8 and clock < 1.45 - 1e-8 and 1 or 0
        local turn = clock >= 1.8 - 1e-8 and clock < 2.05 - 1e-8 and 0.8 or 0
        local jump = clock >= 2.25 - 1e-8 and clock < 2.25 + 1 / 120 - 1e-8
        if clock >= 3.4 - 1e-8 and not fired then
          assert(g:shoot(), 'Carry review needs an actual shot')
          fired = true
        end
        if slot == 2 and clock >= 3.7 - 1e-8 and not reloaded then
          assert(g:reloadGun(), 'Carry review needs an actual reload')
          reloaded = true
        end
        g:update(dt, { forward = forward, strafe = strafe, turn = turn, jump = jump })
        clock = clock + dt
      end
      g.view.messageTimer, g.view.feedbackTimer, g.zoneTimer = 0, 0, 0
      renderer:resize(1280, 720)
      renderer:draw(g, 1280, 720)
      local canvas = lg.newCanvas(1280, 720)
      lg.push('all')
      lg.setCanvas(canvas)
      lg.origin()
      lg.setShader()
      lg.setDepthMode()
      renderer:present(g, 1280, 720)
      UI.draw(g, 1280, 720, { sensitivity = 1, motion = true, music = 0, hints = false })
      lg.setCanvas()
      lg.pop()
      local filename = string.format('weapon-carry-%s-%02d', name, index)
      save(canvas, filename)
      lg.push('all')
      lg.setCanvas(mask)
      lg.origin()
      lg.setShader()
      lg.setDepthMode()
      lg.clear(0, 0, 0, 0)
      Weapon.draw(g, 800, 450)
      lg.setCanvas()
      lg.pop()
      local pixels = mask:newImageData()
      local covered = 0
      for py = 213, 236 do
        for px = 388, 411 do
          local _, _, _, a = pixels:getPixel(px, py)
          if a > 0.1 then
            covered = covered + 1
          end
        end
      end
      pixels:release()
      readability[#readability + 1] = filename
        .. ' central target occlusion='
        .. covered
        .. '/576 pixels'
      assert(covered == 0, filename .. ' obscures the central aiming area')
      local x, y, roll = Motion.pose(g)
      local mag = slot == 1 and g.player.arsenal.exorcist.mag or g.player.arsenal.judge.mag
      local reserve = slot == 1 and g.player.arsenal.exorcist.reserve
        or g.player.arsenal.judge.reserve
      records[#records + 1] = string.format(
        '%s,%.5f,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.7f,%d,%d,%d,%.6f,%.6f',
        name,
        clock,
        names[index],
        g.player.x,
        g.player.z,
        g.player.jump,
        g.view.weaponCarry,
        g.view.weaponStride,
        x,
        y,
        roll,
        Weapon.frame(g),
        mag,
        reserve,
        g.view.shotAge,
        Reload.age(g)
      )
      local px, py = ((index - 1) % 4) * 320, math.floor((index - 1) / 4) * 224
      lg.push('all')
      lg.setCanvas(sheet)
      lg.origin()
      lg.setShader()
      lg.setDepthMode()
      lg.setColor(0.85, 0.75, 0.56)
      lg.print(string.format('%.2fs  %s', clock, names[index]), px + 8, py + 5)
      lg.setColor(1, 1, 1)
      lg.draw(canvas, px, py + 25, 0, 0.25, 0.25)
      lg.setColor(0.85, 0.75, 0.56)
      lg.print(string.format('x %.1f  y %.1f  roll %.2f', x, y, roll), px + 8, py + 207)
      lg.setCanvas()
      lg.pop()
      canvas:release()
    end
    save(sheet, 'weapon-carry-' .. name .. '-filmstrip')
    sheet:release()
  end
  local file = assert(io.open(output .. '/weapon-carry-clocks.csv', 'w'))
  file:write(table.concat(records, '\n'))
  file:close()
  file = assert(io.open(output .. '/weapon-carry-readability.txt', 'w'))
  file:write(table.concat(readability, '\n'))
  file:close()
  mask:release()
  Audio.muted, UI.useMouse = previousMuted, previousMouse
  renderer:resize(1280, 720)
  return #records - 1
end
return Review

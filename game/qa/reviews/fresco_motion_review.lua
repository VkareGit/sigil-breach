-- Visual evidence sampled from real shot/reload clocks in the current arena.
-- Targets are the test field's normal frozen specimens; weapon simulation runs.
local S = {}
function S.run(Game, renderer, output)
  local lg = love.graphics
  local Audio = require('src.audio.audio')
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Weapon = require('src.render.weapon')
  local Reload = require('src.combat.reload')
  local priorMuted, priorMouse = Audio.muted, UI.useMouse
  Audio.muted = true
  UI.useMouse = false
  if love.audio then
    love.audio.stop()
  end
  local records = {}
  local function save(canvas, name)
    local pixels = canvas:newImageData()
    local encoded = pixels:encode('png')
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(encoded:getString())
    file:close()
    pixels:release()
    encoded:release()
  end
  local times = {
    { 0, 1 / 60, 1 / 15, 7 / 60, 0.36, 0.53, 0.75, 0.99 },
    {
      0,
      1 / 60,
      1 / 15,
      7 / 60,
      0.60,
      0.95,
      1.65,
      2.28,
    },
  }
  for slot = 1, 2 do
    local g = Field.new(Game)
    g.testing = true
    Field.close(g)
    g.testField.frozen = true
    g.player.weapon = slot
    g.view.motion = true
    g.view.fov = 100
    g.elapsed = 70
    g.time = 70
    g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
    g.player.pitch = 0
    local targets = assert(Field.spawn(g, 'armored', 1))
    local target = targets[1]
    target.x, target.z = 16, 21.5
    target.facing = 0
    target.previewFrame = 1
    g:spawn('stolas', 13.6, 20.5)
    g.view.messageTimer = 0
    local name = slot == 1 and 'shotgun' or 'revolver'
    local sheet = lg.newCanvas(1280, 720)
    lg.push('all')
    lg.setCanvas(sheet)
    lg.clear(0.10, 0.065, 0.04)
    lg.pop()
    local time, started, manualReload = 0, false, false
    for index, at in ipairs(times[slot]) do
      if index == 2 then
        assert(g:shoot(), 'Visual review requires a live shot')
        started = true
      end
      while time < at - 1e-7 do
        if slot == 2 and time >= 0.40 - 1e-7 and not manualReload then
          assert(g:reloadGun(), 'Visual review requires the live reload')
          manualReload = true
        end
        local dt = math.min(1 / 240, at - time)
        if slot == 2 and not manualReload and time < 0.40 then
          dt = math.min(dt, 0.40 - time)
        end
        g:update(dt, {})
        time = time + dt
      end
      renderer:resize(1280, 720)
      renderer:draw(g, 1280, 720)
      local canvas = lg.newCanvas(1280, 720)
      lg.push('all')
      lg.setCanvas(canvas)
      lg.origin()
      lg.setDepthMode()
      renderer:present(g, 1280, 720)
      UI.draw(g, 1280, 720, { sensitivity = 1, motion = true, music = 0, hints = false })
      lg.setCanvas()
      lg.pop()
      local label = string.format('fresco-motion-%s-%02d', name, index)
      save(canvas, label)
      lg.push('all')
      lg.setCanvas(sheet)
      lg.origin()
      lg.setShader()
      lg.setDepthMode()
      lg.setColor(1, 1, 1)
      local x, y = ((index - 1) % 4) * 320, math.floor((index - 1) / 4) * 360
      lg.draw(canvas, x, y + 32, 0, 0.25, 0.25)
      lg.setColor(0.86, 0.75, 0.56)
      lg.print(string.format('%s  %.3fs  pose %02d', name, at, Weapon.frame(g)), x + 8, y + 8)
      lg.print(
        g.player.reload > 0 and Reload.label(g) or (started and 'strzal / powrot' or 'gotowa'),
        x + 8,
        y + 222
      )
      lg.pop()
      canvas:release()
      local muzzlePhase = Weapon.muzzlePhase(g)
      records[#records + 1] = string.format(
        '%s t=%.4f shotAge=%.4f reloadAge=%.4f logicalPose=%02d bodyPose=%02d muzzle=%s targetHP=%.2f',
        label,
        time,
        g.view.shotAge,
        Reload.age(g),
        Weapon.frame(g),
        Weapon.sourceFrame(g),
        tostring(muzzlePhase),
        target.hp
      )
    end
    save(sheet, 'fresco-motion-' .. name .. '-filmstrip')
    sheet:release()
  end
  local file = assert(io.open(output .. '/fresco-motion-clocks.txt', 'w'))
  file:write(table.concat(records, '\n'))
  file:close()
  Audio.muted, UI.useMouse = priorMuted, priorMouse
  renderer:resize(1280, 720)
  return #records
end
return S

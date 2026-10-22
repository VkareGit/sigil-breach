-- Sample actual shot clocks in the unchanged test arena, with full frames and
-- a centre crop to judge contact scale, outward motion and material colour.
local R = {}
function R.run(Game, renderer, output)
  local lg = love.graphics
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local A = require('src.audio.audio')
  local previousMuted = A.muted
  A.muted = true
  local cases = {
    { name = 'plaster-near', slot = 2, x = 16, z = 5, yaw = math.pi, pitch = 0 },
    { name = 'plaster-far', slot = 2, x = 16, z = 27.5, yaw = math.pi, pitch = 0 },
    { name = 'plaster-glancing', slot = 2, x = 11.2, z = 27, yaw = -math.pi + 0.20, pitch = 0 },
    { name = 'stone-floor', slot = 2, x = 16, z = 27, yaw = math.pi, pitch = -0.55 },
    {
      name = 'metal-armor',
      slot = 2,
      x = 16,
      z = 27.5,
      yaw = math.pi,
      pitch = 0,
      enemy = 'armored',
    },
    { name = 'flesh', slot = 2, x = 16, z = 27.5, yaw = math.pi, pitch = 0, enemy = 'imp' },
    { name = 'shotgun-plaster', slot = 1, x = 16, z = 5, yaw = math.pi, pitch = 0 },
  }
  local function save(canvas, name)
    local data = canvas:newImageData()
    local encoded = data:encode('png')
    local f = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    f:write(encoded:getString())
    f:close()
    data:release()
    encoded:release()
  end
  local records = {}
  for _, case in ipairs(cases) do
    local g = Field.new(Game)
    g.testing = true
    Field.close(g)
    g.testField.frozen = true
    g.weapon = case.slot
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = case.x, case.z, case.yaw, case.pitch
    g.view.motion = true
    g.view.fov = 100
    g.time = 30
    g.elapsed = 30
    g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
    if case.enemy then
      local e = g:spawn(case.enemy, 16, 24)
      e.hp = 1000
      e.maxHp = 1000
      e.facing = math.pi
    end
    assert(g:shoot())
    local time = 0
    local sheet = lg.newCanvas(1280, 720)
    lg.push('all')
    lg.setCanvas(sheet)
    lg.clear(0.10, 0.075, 0.05)
    lg.pop()
    for i, at in ipairs({ 0.02, 0.07, 0.14, 0.24 }) do
      while time < at - 1e-8 do
        local dt = math.min(1 / 240, at - time)
        g:update(dt, {})
        time = time + dt
      end
      g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
      renderer:resize(1280, 720)
      renderer:draw(g, 1280, 720)
      local canvas = lg.newCanvas(1280, 720)
      lg.push('all')
      lg.setCanvas(canvas)
      lg.origin()
      lg.setDepthMode()
      renderer:present(g, 1280, 720)
      UI.draw(g, 1280, 720, { sensitivity = 1, motion = true, music = 0, hints = false })
      lg.pop()
      save(canvas, string.format('impact-%s-%02d', case.name, i))
      lg.push('all')
      lg.setCanvas(sheet)
      lg.origin()
      lg.setDepthMode()
      lg.setShader()
      lg.setColor(1, 1, 1)
      local dx, dy = (i - 1) % 2 * 640, math.floor((i - 1) / 2) * 360
      local crop = lg.newQuad(384, 180, 512, 320, 1280, 720)
      lg.draw(canvas, crop, dx + 64, dy + 30)
      lg.setColor(0.86, 0.76, 0.58)
      lg.print(string.format('%s  %.2f s', case.name, at), dx + 64, dy + 8)
      lg.pop()
      crop:release()
      canvas:release()
      local ray = g.view.shotReport.rays[1]
      local response = ray.response
      records[#records + 1] = string.format(
        '%s t=%.3f kind=%s distance=%.4f target=%s energy=%s normal=%s tangential=%s particles=%d effects=%d',
        case.name,
        time,
        ray.kind,
        ray.distance,
        tostring(ray.target),
        response and string.format('%.4f', response.energy) or 'body',
        response and string.format('%.4f', response.normalEnergy) or 'body',
        response and string.format('%.4f', response.tangentialEnergy) or 'body',
        #g.view.particles,
        #g.view.effects
      )
    end
    save(sheet, 'impact-' .. case.name .. '-sequence')
    sheet:release()
  end
  local f = assert(io.open(output .. '/impact-review-clocks.txt', 'w'))
  f:write(table.concat(records, '\n'))
  f:close()
  A.muted = previousMuted
  return #records
end
return R

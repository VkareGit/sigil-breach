-- Dense, offscreen evidence for shot details and carried mass. Every state is
-- reached through the real simulation; drawing must not advance any clock.
local Review = {}
function Review.run(output, Game, renderer)
  local lg = love.graphics
  Game = Game or require('src.session.game')
  local Audio = require('src.audio.audio')
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Weapon = require('src.render.weapon')
  local Reload = require('src.combat.reload')
  local previousMuted, previousMouse = Audio.muted, UI.useMouse
  local previousRelative, previousGetRelative =
    love.mouse.setRelativeMode, love.mouse.getRelativeMode
  -- Also safe when invoked outside the application's QA adapter: no native
  -- cursor capture, no desktop input, no persisted chapel, and no sound.
  local relative = false
  love.mouse.setRelativeMode = function(value)
    relative = not not value
  end
  love.mouse.getRelativeMode = function()
    return relative
  end
  Audio.muted = true
  UI.useMouse = false
  local frames, occlusions = 0, 0
  local records = {
    'name,time,weapon,shot_age,reload_age,source_pose,mag,reserve,traces,marks,effects,draw_x,draw_y,draw_roll,center_pixels',
  }
  local contacts = { 'name,time,kind,distance,x,y,z,normal_x,normal_y,normal_z,traces,marks' }
  local summary = {
    'Live shot, surface and carry review. Silent/offscreen, current test arena.',
    'Shot phases: .02/.06/.12/.23/.42 seconds. No art clocks are set by hand.',
    'Surface triplets: actual impact, changed viewpoint, then final fade.',
    'Aiming mask: central 24 x 24 pixels in an 800 x 450 weapon canvas.',
  }
  local mask, canvas
  local function save(target, name)
    local data = target:newImageData()
    local encoded = data:encode('png')
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(encoded:getString())
    file:close()
    encoded:release()
    data:release()
  end
  local function write(name, lines)
    local file = assert(io.open(output .. '/' .. name, 'w'))
    file:write(table.concat(lines, '\n') .. '\n')
    file:close()
  end
  local function fresh(slot, x, z, yaw, pitch, motion)
    local g = Field.new(Game)
    g.ephemeral = true
    Field.close(g)
    g.testField.frozen = true
    g.player.weapon = slot
    g.view.motion = motion ~= false
    g.view.fov = 100
    g.enemies = {}
    g.pickups = {}
    g.player.x, g.player.z, g.player.yaw, g.player.pitch =
      x or 16, z or 27.5, yaw or math.pi, pitch or 0
    g.time, g.elapsed = 30, 30
    g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
    return g
  end
  local function advance(g, from, to, input)
    while from < to - 1e-9 do
      local dt = math.min(1 / 120, to - from)
      g:update(dt, type(input) == 'function' and input(from) or input or {})
      from = from + dt
    end
    return to
  end
  local function sheet(columns, rows)
    local c = lg.newCanvas(columns * 320, rows * 216)
    lg.push('all')
    lg.setCanvas(c)
    lg.clear(0.085, 0.068, 0.052, 1)
    lg.pop()
    return c
  end
  local function clockReceipt(g)
    local traceAge, markAge = 0, 0
    for _, t in ipairs(g.view.traces) do
      traceAge = traceAge + (t.life or 0) + (t.age or 0)
    end
    for _, m in ipairs(g.view.surfaceMarks or {}) do
      markAge = markAge + (m.age or 0)
    end
    return table.concat({
      g.time,
      g.elapsed,
      g.view.shotAge,
      g.player.reload,
      g.player.cooldown,
      g.player.arsenal.exorcist.mag,
      g.player.arsenal.judge.mag,
      #g.view.traces,
      #(g.view.surfaceMarks or {}),
      traceAge,
      markAge,
    }, '|')
  end
  local function capture(g, name, at, strip, index, columns, label)
    g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
    local before = clockReceipt(g)
    renderer:resize(1280, 720)
    renderer:draw(g, 1280, 720)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    lg.setShader()
    lg.setDepthMode()
    lg.clear()
    renderer:present(g, 1280, 720)
    UI.draw(g, 1280, 720, { sensitivity = 1, motion = g.view.motion, music = 0, hints = false })
    lg.pop()
    save(canvas, name)
    lg.push('all')
    lg.setCanvas(mask)
    lg.origin()
    lg.setShader()
    lg.setDepthMode()
    lg.clear(0, 0, 0, 0)
    Weapon.draw(g, 800, 450)
    lg.pop()
    local data = mask:newImageData()
    local covered = 0
    for y = 213, 236 do
      for x = 388, 411 do
        local _, _, _, a = data:getPixel(x, y)
        if a > 0.10 then
          covered = covered + 1
        end
      end
    end
    data:release()
    if covered > 0 then
      occlusions = occlusions + 1
    end
    -- Log the complete draw transform, including the recoil wrist pivot and
    -- reload pose. The carry-only pose omits the visible rotation after firing.
    local x, y, roll = Weapon.transform(g, 800, 450)
    assert(
      clockReceipt(g) == before,
      name .. ': drawing changed a shot clock, ammunition or effect lifetime'
    )
    local mag = g.player.weapon == 1 and g.player.arsenal.exorcist.mag or g.player.arsenal.judge.mag
    local reserve = g.player.weapon == 1 and g.player.arsenal.exorcist.reserve
      or g.player.arsenal.judge.reserve
    records[#records + 1] = string.format(
      '%s,%.5f,%d,%.5f,%.5f,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.7f,%d',
      name,
      at,
      g.player.weapon,
      g.view.shotAge,
      Reload.age(g),
      Weapon.sourceFrame(g),
      mag,
      reserve,
      #g.view.traces,
      #(g.view.surfaceMarks or {}),
      #g.view.effects,
      x,
      y,
      roll,
      covered
    )
    local ray = g.view.shotReport and g.view.shotReport.rays[1]
    if ray then
      local n = ray.response or {}
      contacts[#contacts + 1] = string.format(
        '%s,%.5f,%s,%.7f,%.7f,%.7f,%.7f,%.7f,%.7f,%.7f,%d,%d',
        name,
        at,
        ray.kind,
        ray.distance,
        ray.x,
        ray.y,
        ray.z,
        n.nx or 0,
        n.ny or 0,
        n.nz or 0,
        #g.view.traces,
        #(g.view.surfaceMarks or {})
      )
    end
    local dx, dy = ((index - 1) % columns) * 320, math.floor((index - 1) / columns) * 216
    lg.push('all')
    lg.setCanvas(strip)
    lg.origin()
    lg.setDepthMode()
    lg.setShader()
    lg.setColor(0.82, 0.73, 0.57)
    lg.print(string.format('%s / %.2fs', label, at), dx + 7, dy + 5)
    lg.setColor(1, 1, 1)
    lg.draw(canvas, dx, dy + 24, 0, 0.25, 0.25)
    lg.setColor(0.82, 0.73, 0.57)
    lg.print(
      string.format(
        'traces %d / marks %d / pose %d',
        #g.view.traces,
        #(g.view.surfaceMarks or {}),
        Weapon.sourceFrame(g)
      ),
      dx + 7,
      dy + 199
    )
    lg.pop()
    frames = frames + 1
  end
  local ok, err = xpcall(function()
    if not renderer then
      UI.init()
      renderer = require('src.render.renderer').new()
    end
    mask = lg.newCanvas(800, 450)
    canvas = lg.newCanvas(1280, 720)
    for slot = 1, 2 do
      local name = slot == 1 and 'shotgun' or 'revolver'
      local g = fresh(slot, 21.5, 28, math.pi * 0.5, 0)
      assert(g:shoot(), 'Detail review requires a real ' .. name .. ' shot')
      local strip = sheet(5, 1)
      local clock = 0
      for index, at in ipairs({ 0.02, 0.06, 0.12, 0.23, 0.42 }) do
        clock = advance(g, clock, at)
        capture(g, string.format('detail-shot-%s-%02d', name, index), at, strip, index, 5, name)
      end
      save(strip, 'detail-shot-' .. name .. '-sequence')
      strip:release()
    end
    local surfaces = {
      {
        name = 'wall',
        x = 21.5,
        z = 28,
        yaw = math.pi * 0.5,
        pitch = 0,
        moveX = 0,
        moveZ = -0.55,
        kind = 'wall',
      },
      {
        name = 'floor',
        x = 16,
        z = 27,
        yaw = math.pi,
        pitch = -0.65,
        moveX = 0.5,
        moveZ = 0,
        kind = 'floor',
      },
      {
        name = 'pillar',
        x = 12,
        z = 27.5,
        yaw = math.pi,
        pitch = 0,
        moveX = 0.55,
        moveZ = 0,
        kind = 'wall',
      },
      {
        name = 'glancing',
        x = 9.5,
        z = 24.2,
        yaw = -0.35,
        pitch = 0,
        moveX = 0.35,
        moveZ = 0.3,
        kind = 'wall',
      },
    }
    for _, case in ipairs(surfaces) do
      local g = fresh(2, case.x, case.z, case.yaw, case.pitch)
      assert(g:shoot(), 'Surface review requires a real shot')
      local ray = g.view.shotReport.rays[1]
      assert(
        ray.kind == case.kind,
        'Surface fixture hit ' .. ray.kind .. ' instead of ' .. case.kind
      )
      local strip = sheet(3, 1)
      local clock = advance(g, 0, 0.3)
      capture(
        g,
        'detail-mark-' .. case.name .. '-contact',
        clock,
        strip,
        1,
        3,
        case.name .. ' / contact'
      )
      -- A viewpoint change is intentionally not a wall-clock or mark mutation.
      -- The perspective of a persistent scar must change with its surface.
      g.player.x, g.player.z = g.player.x + case.moveX, g.player.z + case.moveZ
      local dx, dz = ray.x - g.player.x, ray.z - g.player.z
      local _, eye = require('src.combat.ballistics').origin(g)
      g.player.yaw = math.atan2(dx, dz)
      g.player.pitch = math.atan2(ray.y - eye, math.sqrt(dx * dx + dz * dz))
      clock = advance(g, clock, 0.6)
      capture(
        g,
        'detail-mark-' .. case.name .. '-viewpoint',
        clock,
        strip,
        2,
        3,
        case.name .. ' / viewpoint'
      )
      clock = advance(g, clock, 34)
      capture(
        g,
        'detail-mark-' .. case.name .. '-fade',
        clock,
        strip,
        3,
        3,
        case.name .. ' / fading'
      )
      save(strip, 'detail-mark-' .. case.name .. '-sequence')
      strip:release()
    end
    local times = { 0, 0.12, 0.3, 0.58, 0.76, 0.96, 1.2, 1.45, 1.65, 1.9, 2.2, 2.8 }
    local names = {
      'rest',
      'start',
      'step',
      'carry',
      'strafe',
      'reverse',
      'brake',
      'turn',
      'rise',
      'air',
      'land',
      'settled',
    }
    for slot = 1, 2 do
      local g = fresh(slot)
      local name = slot == 1 and 'shotgun' or 'revolver'
      local strip = sheet(4, 3)
      local clock = 0
      local jumped = false
      local function movement(at)
        local input = {}
        if at >= 0.10 - 1e-9 and at < 0.65 - 1e-9 then
          input.forward = 1
        end
        if at >= 0.65 - 1e-9 and at < 0.95 - 1e-9 then
          input.strafe = 1
        end
        if at >= 0.95 - 1e-9 and at < 1.2 - 1e-9 then
          input.strafe = -1
        end
        if at >= 1.25 - 1e-9 and at < 1.4 - 1e-9 then
          input.turn = 0.6
        end
        if at >= 1.55 - 1e-9 and not jumped then
          input.jump = true
          jumped = true
        end
        return input
      end
      for index, at in ipairs(times) do
        clock = advance(g, clock, at, movement)
        capture(
          g,
          string.format('detail-carry-%s-%02d', name, index),
          at,
          strip,
          index,
          4,
          name .. ' / ' .. names[index]
        )
      end
      save(strip, 'detail-carry-' .. name .. '-sequence')
      strip:release()
    end
    -- Reduced motion keeps shot, mark and trail receipts while the carried body
    -- remains still. It also covers a first frame after switching the setting.
    local g = fresh(2, 21.5, 28, math.pi * 0.5, 0, false)
    local strip = sheet(2, 1)
    assert(g:shoot())
    advance(g, 0, 0.06)
    capture(g, 'detail-reduced-motion-shot', 0.06, strip, 1, 2, 'reduced motion / shot')
    require('src.player.feel').clearMotion(g)
    g.view.motion = true
    advance(g, 0.06, 0.07)
    capture(
      g,
      'detail-reduced-motion-restored',
      0.07,
      strip,
      2,
      2,
      'motion restored / no latent kick'
    )
    save(strip, 'detail-reduced-motion-sequence')
    strip:release()
    summary[#summary + 1] =
      string.format('%d complete frames; %d aiming-mask occlusions.', frames, occlusions)
    write('detail-review-v17.csv', records)
    write('detail-contacts-v17.csv', contacts)
    write('detail-review-v17.txt', summary)
    assert(
      occlusions == 0,
      'Detail review found ' .. occlusions .. ' frames covering the central aiming area'
    )
  end, debug.traceback)
  if mask then
    mask:release()
  end
  if canvas then
    canvas:release()
  end
  Audio.muted, UI.useMouse = previousMuted, previousMouse
  love.mouse.setRelativeMode, love.mouse.getRelativeMode = previousRelative, previousGetRelative
  if renderer then
    renderer:resize(1280, 720)
  end
  assert(ok, err)
  return frames
end
return Review

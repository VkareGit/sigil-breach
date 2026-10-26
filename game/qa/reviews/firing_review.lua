-- Real trigger presses and bounded simulation steps, never hand-set action
-- clocks. The receipts distinguish changing gun art from camera recoil.
local Review = {}

function Review.run(output, Game, renderer)
  local lg = love.graphics
  Game = Game or require('src.session.game')
  local Field = require('src.run.test_field')
  local Audio = require('src.audio.audio')
  local UI = require('src.ui.interface')
  local Weapon = require('src.render.weapon')
  local Art = require('src.render.weapon_art')
  local Animation = require('src.enemies.animation')
  local Ballistics = require('src.combat.ballistics')
  local Rules = require('src.combat.rules')
  local previousMuted, previousMouse = Audio.muted, UI.useMouse
  local previousRelative, previousGetRelative =
    love.mouse.setRelativeMode, love.mouse.getRelativeMode
  local relative = false
  love.mouse.setRelativeMode = function(value)
    relative = not not value
  end
  love.mouse.getRelativeMode = function()
    return relative
  end
  Audio.muted, UI.useMouse = true, false
  local resources, frames, geometryOcclusions, changedShots = {}, 0, 0, 0
  local records = {
    'scenario,phase,time,source_pose,mag,reserve,shots,hits,kills,health,armor,enemy_pose,death_age,fall_y,landing_age,landing_count,effects,particles,stains,gun_center_pixels,all_center_pixels,pose_alpha_difference,pose_color_difference,native_art_agreement',
  }
  local summary = {
    'Firing and fatal-response review: real shots, 120 Hz simulation, silent offscreen renders.',
    'Death fixtures start at 1 HP to guarantee a lethal hit. Original maximum HP, armor and mass remain intact.',
    'Death fixtures keep AI/body integration running; no preview frames or forged death/action clocks.',
    'Gun comparison draws the ready and current source poses at the SAME live grip transform.',
    'Native-art agreement compares that geometry with the actual Weapon.draw output.',
    'Aiming mask: central 24 x 24 pixels of an 800 x 450 transparent weapon canvas.',
    'Flash/smoke may cross the aiming mask during ignition; gun geometry must leave it clear.',
  }
  local function canvas(w, h)
    local c = lg.newCanvas(w, h)
    resources[#resources + 1] = c
    return c
  end
  local function paint(target, clear, draw)
    lg.push('all')
    lg.setCanvas(target)
    lg.origin()
    lg.setShader()
    lg.setDepthMode()
    lg.setColor(1, 1, 1)
    lg.clear(unpack(clear))
    draw()
    lg.pop()
  end
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
  local function fresh(slot, kind, motion)
    local g = Field.new(Game)
    g.testing = true
    Field.close(g)
    g.testField.frozen = false
    g.player.weapon, g.view.motion, g.view.fov = slot, motion ~= false, 100
    g.enemies, g.pickups = {}, {}
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27.5, math.pi, 0
    g.time, g.elapsed = 30, 30
    g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
    local e
    if kind then
      g.testField.selected = kind
      e = g:spawn(kind, 16, kind == 'boss' and 22.5 or 23.5)
      e.hp = 1 -- Explicit finishing-blow fixture, not a damage/balance claim.
      e.facing = 0
      local _, eye = Ballistics.origin(g)
      g.player.pitch = math.atan2(Rules.body(e).aimY - eye, g.player.z - e.z)
    end
    return g, e
  end
  local function advance(g, from, to)
    while from < to - 1e-9 do
      local dt = math.min(1 / 120, to - from)
      g:update(dt, {})
      from = from + dt
    end
    return to
  end
  local function receipt(g, e)
    local effects = 0
    for _, effect in ipairs(g.view.effects) do
      effects = effects + effect.age
    end
    return table.concat({
      g.time,
      g.elapsed,
      g.view.shotAge,
      g.player.reload,
      g.player.cooldown,
      g.player.arsenal.exorcist.mag,
      g.player.arsenal.judge.mag,
      g.kills,
      #g.view.effects,
      effects,
      e and e.hp or 0,
      e and e.deathTime or 0,
      e and e.x or 0,
      e and e.z or 0,
    }, '|')
  end
  local main, native, geometry, ready
  local function drawGeometry(g, frame, target)
    paint(target, { 0, 0, 0, 0 }, function()
      local x, y, roll, grow = Weapon.transform(g, 800, 450)
      local art = Art.idOf(g)
      local scale = 450 * Art[art].screenScale / Weapon.cellWidths[art] * grow
      -- The same grading as the game's hands (render/weapon.lua): only the
      -- geometry may differ between the registered pose and the drawing.
      Weapon.handsShader(nil, 450, Weapon.images[art])
      lg.draw(
        Weapon.images[art],
        Weapon.quads[art][frame],
        math.floor(x + 0.5),
        math.floor(y + 0.5),
        roll,
        scale,
        scale,
        Weapon.centers[art][frame],
        Weapon.origins[art][frame]
      )
      lg.setShader()
    end)
  end
  local function measure(g)
    paint(native, { 0, 0, 0, 0 }, function()
      Weapon.draw(g, 800, 450)
    end)
    drawGeometry(g, Weapon.sourceFrame(g), geometry)
    drawGeometry(g, 1, ready)
    local n, a, b = native:newImageData(), geometry:newImageData(), ready:newImageData()
    local center, allCenter, alphaDelta, colorDelta, matching, tested = 0, 0, 0, 0, 0, 0
    for y = 0, 449, 2 do
      for x = 0, 799, 2 do
        local ar, ag, ab, aa = a:getPixel(x, y)
        local br, bg, bb, ba = b:getPixel(x, y)
        if (aa > 0.1) ~= (ba > 0.1) then
          alphaDelta = alphaDelta + 4
        end
        if
          aa > 0.1
          and ba > 0.1
          and math.abs(ar - br) + math.abs(ag - bg) + math.abs(ab - bb) > 0.12
        then
          colorDelta = colorDelta + 4
        end
        if aa > 0.9 then
          local nr, ng, nb, na = n:getPixel(x, y)
          tested = tested + 1
          if na > 0.9 and math.abs(ar - nr) + math.abs(ag - ng) + math.abs(ab - nb) < 0.12 then
            matching = matching + 1
          end
        end
      end
    end
    for y = 213, 236 do
      for x = 388, 411 do
        local _, _, _, aa = a:getPixel(x, y)
        local _, _, _, na = n:getPixel(x, y)
        if aa > 0.1 then
          center = center + 1
        end
        if na > 0.1 then
          allCenter = allCenter + 1
        end
      end
    end
    n:release()
    a:release()
    b:release()
    assert(tested > 100, 'Weapon source has no visible registered geometry')
    return center, allCenter, alphaDelta, colorDelta, matching / tested
  end
  local function capture(g, e, scenario, phase, time, strip, index, weaponStrip)
    g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
    local before = receipt(g, e)
    renderer:resize(1280, 720)
    renderer:draw(g, 1280, 720)
    paint(main, { 0, 0, 0, 0 }, function()
      renderer:present(g, 1280, 720)
      UI.draw(g, 1280, 720, { sensitivity = 1, motion = g.view.motion, music = 0, hints = false })
    end)
    local center, allCenter, alphaDelta, colorDelta, agreement = measure(g)
    assert(receipt(g, e) == before, scenario .. ': drawing advanced simulation')
    if center > 0 then
      geometryOcclusions = geometryOcclusions + 1
    end
    assert(
      agreement > 0.85,
      scenario .. ': native gun draw differs from its registered source pose'
    )
    if phase == 'fire' then
      assert(Weapon.sourceFrame(g) ~= 1, scenario .. ': firing still uses the static ready art')
      assert(
        alphaDelta + colorDelta > 500,
        scenario .. ': firing pose is not visibly different from ready'
      )
      changedShots = changedShots + 1
    end
    local response = e and e.deathResponse or {}
    local enemyFrame = e and Animation.pose(g, e) or 0
    records[#records + 1] = string.format(
      '%s,%s,%.5f,%d,%d,%d,%d,%d,%d,%.5f,%.5f,%d,%.5f,%.5f,%.5f,%d,%d,%d,%d,%d,%d,%d,%d,%.5f',
      scenario,
      phase,
      time,
      Weapon.sourceFrame(g),
      g.player.weapon == 1 and g.player.arsenal.exorcist.mag or g.player.arsenal.judge.mag,
      g.player.weapon == 1 and g.player.arsenal.exorcist.reserve or g.player.arsenal.judge.reserve,
      g.player.shots,
      g.player.hits,
      g.kills,
      e and e.hp or -1,
      e and e.armorRating or -1,
      enemyFrame,
      e and e.deathTime or 0,
      e and e.fallY or 0,
      response.landedAt or -1,
      response.contacts or 0,
      #g.view.effects,
      #g.view.particles,
      #g.view.decals,
      center,
      allCenter,
      alphaDelta,
      colorDelta,
      agreement
    )
    save(main, string.format('firing-%s-%02d-%s', scenario, index, phase))
    local dx, dy = (index - 1) % 3 * 512, math.floor((index - 1) / 3) * 330
    lg.push('all')
    lg.setCanvas(strip)
    lg.origin()
    lg.setDepthMode()
    lg.setShader()
    lg.setColor(0.84, 0.75, 0.59)
    lg.print(string.format('%s / %s / %.3fs', scenario, phase, time), dx + 8, dy + 4)
    lg.setColor(1, 1, 1)
    lg.draw(main, dx, dy + 22, 0, 0.4, 0.4)
    lg.setColor(0.84, 0.75, 0.59)
    lg.print(
      string.format(
        'gun %d / body %d / kills %d / contact %d',
        Weapon.sourceFrame(g),
        enemyFrame,
        g.kills,
        response.contacts or 0
      ),
      dx + 8,
      dy + 314
    )
    lg.pop()
    if weaponStrip then
      save(native, string.format('firing-%s-%02d-weapon', scenario, index))
      lg.push('all')
      lg.setCanvas(weaponStrip)
      lg.origin()
      lg.setDepthMode()
      lg.setShader()
      local wx, wy = (index - 1) % 4 * 400, math.floor((index - 1) / 4) * 250
      lg.setColor(0.84, 0.75, 0.59)
      lg.print(
        string.format('%s %.3fs / source %d', phase, time, Weapon.sourceFrame(g)),
        wx + 8,
        wy + 3
      )
      lg.setColor(1, 1, 1)
      lg.draw(native, wx, wy + 24, 0, 0.5, 0.5)
      lg.pop()
    end
    frames = frames + 1
    return enemyFrame
  end
  local ok, err = xpcall(function()
    if not renderer then
      UI.init()
      renderer = require('src.render.renderer').new()
    end
    main, native, geometry, ready =
      canvas(1280, 720), canvas(800, 450), canvas(800, 450), canvas(800, 450)
    for slot = 1, 2 do
      local weapon = slot == 1 and 'exorcist' or 'judge'
      local scenarios = {
        { name = weapon .. '-empty-range', times = { 0, 0.04, 0.10, 0.18, 0.38, 0.75, 1.05 } },
        { name = weapon .. '-imp', kind = 'imp' },
        { name = weapon .. '-armored', kind = 'armored' },
        { name = weapon .. '-margrave', kind = 'boss' },
        { name = weapon .. '-reduced-motion', motion = false, times = { 0, 0.10, 0.22 } },
      }
      for _, case in ipairs(scenarios) do
        local g, e = fresh(slot, case.kind, case.motion)
        local times = case.times or { 0.025, 0.14, 0.28, 0.55, 1, 2.4 }
        local strip = canvas(1536, math.ceil((#times + 1) / 3) * 330)
        paint(strip, { 0.075, 0.058, 0.045, 1 }, function() end)
        local weaponStrip
        if not e then
          weaponStrip = canvas(1600, math.ceil((#times + 1) / 4) * 250)
          paint(weaponStrip, { 0.075, 0.058, 0.045, 1 }, function() end)
        end
        capture(g, e, case.name, 'ready', 0, strip, 1, weaponStrip)
        assert(g:shoot(), case.name .. ': trigger did not fire')
        if e then
          assert(
            e.hp == 0 and g.kills == 1,
            case.name .. ': finishing shot must kill the real target'
          )
        end
        local clock, poses, resting = 0, {}, nil
        for index, at in ipairs(times) do
          clock = advance(g, clock, at)
          local phase = index == 1 and 'fire'
            or (index == #times and at >= 1 and 'settled' or 'follow-through')
          local pose = capture(g, e, case.name, phase, at, strip, index + 1, weaponStrip)
          poses[pose] = true
          if e and at >= 1 then
            if resting then
              assert(
                math.abs(e.x - resting.x) + math.abs(e.z - resting.z) < 1e-8,
                case.name .. ': grounded corpse still drifts after coming to rest'
              )
            else
              resting = { x = e.x, z = e.z }
            end
          end
        end
        if e then
          local distinct = 0
          for _ in pairs(poses) do
            distinct = distinct + 1
          end
          assert(distinct >= 3, case.name .. ': death held a static source pose')
          assert(
            e.deathTime >= 2.39 and e.hp == 0 and g.kills == 1,
            case.name .. ': corpse or kill receipt was lost'
          )
          assert(
            e.deathResponse and e.deathResponse.contacts == 1,
            case.name .. ': corpse must land exactly once'
          )
          assert((e.fallY or 0) < 0.001, case.name .. ': corpse remains airborne')
        end
        save(strip, 'firing-' .. case.name .. '-sequence')
        if weaponStrip then
          save(weaponStrip, 'firing-' .. case.name .. '-weapon-sequence')
        end
      end
    end
    summary[#summary + 1] = string.format(
      '%d native game frames; %d visibly changed firing poses; %d gun aiming-mask occlusions.',
      frames,
      changedShots,
      geometryOcclusions
    )
    write('firing-review-v19.csv', records)
    write('firing-review-v19.txt', summary)
    assert(geometryOcclusions == 0, 'Firing review found gun geometry covering the aiming mask')
  end, debug.traceback)
  for _, resource in ipairs(resources) do
    resource:release()
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

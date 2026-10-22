-- Native offscreen review of the painted summon and the existing live skills.
-- Portal fixtures stage presentation clocks; ability poses are reached by AI.
local Review = {}

function Review.run(output, Game, renderer)
  local lg = love.graphics
  local Field = require('src.run.test_field')
  local Portals = require('src.render.portals')
  local Ability = require('src.render.ability_art')
  local Audio = require('src.audio.audio')
  local UI = require('src.ui.interface')
  local previousMute, previousMouse = Audio.muted, UI.useMouse
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
  local resources, frames = {}, 0
  local records = { 'scenario,time,source,pose,state,height,x,z,health,attacks,evades,landings' }
  local notes = {
    'Summoning art: silent native offscreen renderer, 1280 x 720, normal HUD.',
    'Portal fixtures stage the existing 1.2 s warning and 0.6 s arrival clocks.',
    'Leap and evade use real AI updates at 120 Hz. No preview frames, forged phases or altered skill definitions.',
    'Ability inspection uses a separate observation camera; the combat player and simulation are unchanged.',
    'Render receipts check gameplay state before and after every capture.',
  }
  local function canvas(w, h)
    local c = lg.newCanvas(w, h)
    resources[#resources + 1] = c
    return c
  end
  local function paint(c, draw)
    lg.push('all')
    lg.setCanvas(c)
    lg.origin()
    lg.setShader()
    lg.setDepthMode()
    lg.clear(0.065, 0.048, 0.038, 1)
    lg.setColor(1, 1, 1)
    draw()
    lg.pop()
  end
  local function save(c, name)
    local data = c:newImageData()
    local png = data:encode('png')
    local f = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    f:write(png:getString())
    f:close()
    png:release()
    data:release()
  end
  local function write(name, lines)
    local f = assert(io.open(output .. '/' .. name, 'w'))
    f:write(table.concat(lines, '\n') .. '\n')
    f:close()
  end
  local function fresh()
    local g = Field.new(Game)
    g.testing = true
    Field.close(g)
    g.testField.frozen = false
    g.enemies, g.pickups = {}, {}
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27.5, math.pi, 0
    g.time, g.elapsed = 30, 30
    g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
    return g
  end
  local function receipt(g)
    local t = {
      g.time,
      g.elapsed,
      g.player.x,
      g.player.z,
      g.player.hp,
      g.player.armor,
      g.player.arsenal.exorcist.mag,
      g.kills,
      #g.view.effects,
      #g.bullets,
      #g.hazards,
    }
    for _, e in ipairs(g.enemies) do
      for _, name in ipairs({
        'x',
        'z',
        'hp',
        'ai',
        'phase',
        'attack',
        'attackCount',
        'spawnAge',
        'leapY',
        'leapVY',
        'leaping',
        'evadeTime',
        'evadeReady',
        'landings',
      }) do
        t[#t + 1] = tostring(e[name])
      end
    end
    for _, gate in ipairs(g.run.pending or {}) do
      t[#t + 1] = gate.delay
    end
    return table.concat(t, '|')
  end
  local function observation(g, e)
    if not e then
      return g
    end
    local view, player = setmetatable({}, { __index = g }), {}
    for k, v in pairs(g) do
      view[k] = v
    end
    for k, v in pairs(g.player) do
      player[k] = v
    end
    view.player = player
    player.x, player.z = 18.5, g.player.z - 2.5
    -- Keep the complete body beside the held gun, with no pillar between
    -- camera and skill path. This is an inspection view, not a fake action.
    player.yaw = math.atan2(e.x - player.x, e.z - player.z) + 0.20
    local distance = math.sqrt((e.x - player.x) ^ 2 + (e.z - player.z) ^ 2)
    player.pitch = 0.02 + math.atan2(e.leapY or 0, distance)
    return view
  end
  local main
  local function render(g, e, hud)
    local before = receipt(g)
    local view = observation(g, e)
    renderer:resize(1280, 720)
    renderer:draw(view, 1280, 720)
    paint(main, function()
      renderer:present(view, 1280, 720)
      if hud ~= false then
        UI.draw(view, 1280, 720, { sensitivity = 1, motion = true, music = 0, hints = false })
      end
    end)
    assert(receipt(g) == before, 'summoning draw mutated gameplay')
  end
  local function capture(g, e, name, at, source, pose, strip, index, inspect)
    render(g, inspect and e or nil)
    save(main, string.format('summoning-%s-%02d', name, index))
    local x, y = (index - 1) % 3 * 512, math.floor((index - 1) / 3) * 314
    lg.push('all')
    lg.setCanvas(strip)
    lg.origin()
    lg.setShader()
    lg.setDepthMode()
    lg.setColor(0.83, 0.74, 0.56)
    lg.print(string.format('%s / %.3fs / %s %s', name, at, source, tostring(pose)), x + 8, y + 4)
    lg.setColor(1, 1, 1)
    lg.draw(main, x, y + 24, 0, 0.4, 0.4)
    lg.pop()
    records[#records + 1] = string.format(
      '%s,%.5f,%s,%s,%s,%.5f,%.5f,%.5f,%.5f,%d,%d,%d',
      name,
      at,
      source,
      tostring(pose),
      e and e.ai or 'portal',
      e and e.leapY or 0,
      e and e.x or 0,
      e and e.z or 0,
      e and e.hp or 0,
      g.attackStarts or 0,
      g.evadeCount or 0,
      e and e.landings or 0
    )
    frames = frames + 1
  end
  local function strip(rows)
    local c = canvas(1536, rows * 314)
    paint(c, function() end)
    return c
  end
  local ok, err = xpcall(function()
    if not renderer then
      UI.init()
      renderer = require('src.render.renderer').new()
    end
    main = canvas(1280, 720)
    local g, sheet = fresh(), strip(3)
    local gate = { x = 16, z = 22, kind = 'imp', index = 1, delay = 1.2, maxDelay = 1.2 }
    g.run.pending = { gate }
    local index = 0
    for _, at in ipairs({ 0, 0.25, 0.50, 0.80, 1.19 }) do
      index = index + 1
      gate.delay, g.time = 1.2 - at, 30 + at
      capture(g, nil, 'opening-arrival', at, 'portal', Portals.frame(gate, g.time), sheet, index)
    end
    g.run.pending = {}
    local summoned = g:spawn('imp', gate.x, gate.z)
    for _, age in ipairs({ 0, 0.15, 0.35, 0.59 }) do
      index = index + 1
      summoned.spawnAge, g.time = age, 31.2 + age
      capture(
        g,
        summoned,
        'opening-arrival',
        1.2 + age,
        'arrival',
        Portals.arrivalFrame(age),
        sheet,
        index
      )
    end
    save(sheet, 'summoning-opening-arrival-sequence')

    g, sheet = fresh(), strip(2)
    for i, kind in ipairs({ 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }) do
      gate = { x = 16, z = 22, kind = kind, index = 1, delay = 0.12, maxDelay = 1.2 }
      g.run.pending = { gate }
      capture(g, nil, 'cohort-colors', 1.08, kind, Portals.frame(gate, g.time), sheet, i)
    end
    save(sheet, 'summoning-cohort-colors-sequence')

    -- A portal centered inside an opaque wall must not paint over it. This
    -- catches accidental screen-space drawing or a disabled depth test.
    g = fresh()
    g.player.x, g.player.z, g.player.yaw = 12, 27.5, math.pi
    g.run.pending = {}
    render(g, nil, false)
    local hiddenBaseline = main:newImageData()
    g.run.pending = { { x = 12, z = 24.65, kind = 'imp', delay = 0.1, maxDelay = 1.2 } }
    render(g, nil, false)
    local hiddenPortal, difference = main:newImageData(), 0
    -- Only the pillar's central face: side lobes may legitimately peek around
    -- its edges, but the wall itself must remain perfectly opaque.
    for y = 235, 330 do
      for x = 610, 669 do
        local a, b, c = hiddenBaseline:getPixel(x, y)
        local d, e, f = hiddenPortal:getPixel(x, y)
        if math.abs(a - d) + math.abs(b - e) + math.abs(c - f) > 0.03 then
          difference = difference + 1
        end
      end
    end
    hiddenBaseline:release()
    hiddenPortal:release()
    save(main, 'summoning-wall-occlusion')
    notes[#notes + 1] = 'Opaque pillar face changed pixels: ' .. difference
    assert(difference == 0, 'portal painted through opaque pillar face')
    frames = frames + 1

    for _, skill in ipairs({ 'leap', 'evade' }) do
      g, sheet = fresh(), strip(3)
      local kind = skill == 'leap' and 'imp' or 'stolas'
      g.testField.tier = skill == 'evade' and 2 or 1
      -- The central crossing keeps the whole physical path clear of the
      -- sanctuary ornament that would occlude a landing at the spawn point.
      g.player.z = 23.5
      local e = g:spawn(kind, 16, 18)
      e.awake, e.memory, e.attack, e.spawnAge = true, 60, skill == 'leap' and 0 or 10, 1
      e.lastX, e.lastZ, e.facing = g.player.x, g.player.z, 0
      local seen, count, at = {}, 0, 0
      while at < 2.5 and count < 8 do
        g:update(1 / 120, {})
        at = at + 1 / 120
        local key, pose = Ability.select(g, e)
        if key == skill and not seen[pose] then
          seen[pose] = true
          count = count + 1
          capture(g, e, 'live-' .. skill, at, key, pose, sheet, count, true)
        end
      end
      assert(count == 8, skill .. ': live AI reached only ' .. count .. ' of 8 painted poses')
      if skill == 'leap' then
        assert((g.leapStarts or 0) >= 1 and (e.landings or 0) >= 1, 'leap fixture never landed')
      else
        assert((e.evades or 0) >= 1, 'evade fixture never sidestepped')
      end
      notes[#notes + 1] = skill .. ': all 8 authored frames reached through live simulation.'
      save(sheet, 'summoning-live-' .. skill .. '-sequence')
    end
    notes[#notes + 1] = frames .. ' native scenes; every render receipt unchanged.'
    write('summoning-review-v23.csv', records)
    write('summoning-review-v23.txt', notes)
  end, debug.traceback)
  for _, resource in ipairs(resources) do
    resource:release()
  end
  Audio.muted, UI.useMouse = previousMute, previousMouse
  love.mouse.setRelativeMode, love.mouse.getRelativeMode = previousRelative, previousGetRelative
  if renderer then
    renderer:resize(1280, 720)
  end
  assert(ok, err)
  return frames
end

return Review

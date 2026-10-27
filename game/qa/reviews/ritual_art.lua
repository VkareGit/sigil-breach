-- Focused native art acceptance: the real floor, depth, light and ordinary HUD.
local Review = {}
function Review.run(Game, renderer, output)
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Integrity = require('src.session.integrity')
  local lg = love.graphics
  local oldMouse = UI.useMouse
  UI.useMouse = false
  local g = Field.new(Game)
  g.testing = true
  Field.close(g)
  g.enemies, g.pickups, g.hazards, g.bullets = {}, {}, {}, {}
  g.run.queueIndex = #require('src.content.waves')[g.run.wave].queue + 1
  g.run.pending = {}
  g.view.motion = false
  g.time, g.elapsed = 12, 12
  g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 0, 0, 0
  local notes = {
    'Matte ritual medallions / 1280x720 native scene with ordinary HUD.',
    'The medallion PNG is copied without pixel edits; historical seal sources are unchanged.',
  }
  local function capture(name, x, z, targetX, targetY, targetZ, w, h)
    w, h = w or 1280, h or 720
    local p = g.player
    p.x, p.z = x, z
    local dx, dz = targetX - x, targetZ - z
    p.yaw = math.atan2(dx, dz)
    local _, eye = require('src.combat.ballistics').origin(g)
    p.pitch = math.atan2(targetY - eye, math.sqrt(dx * dx + dz * dz))
    g.view.presentationPrevious = nil
    local before = Integrity.capture(g)
    local canvas = lg.newCanvas(w, h)
    renderer:resize(w, h)
    renderer:draw(g, w, h)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    renderer:present(g, w, h)
    UI.draw(g, w, h, { motion = false, hints = true })
    lg.pop()
    assert(
      not Integrity.difference(before, Integrity.capture(g)),
      'ritual drawing mutated simulation'
    )
    local data = canvas:newImageData()
    local png = data:encode('png')
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(png:getString())
    file:close()
    png:release()
    data:release()
    canvas:release()
    notes[#notes + 1] = name
      .. ': render-only state check PASS; labels '
      .. #(renderer.galleryLabelLayout and renderer.galleryLabelLayout.taken or {})
  end
  -- Empty medallions are deliberate for demons with no catalogued historical seal.
  capture('01-gallery-pads', 16, 27.5, 10.2, 0.05, 23.1)
  capture('02-stolas-pad-near', 12.2, 25.8, 10.2, 0.05, 25.8)
  capture('02-stolas-pad-near-4by3', 12.2, 25.8, 10.2, 0.05, 25.8, 1024, 768)
  capture('02-stolas-pad-near-large', 12.2, 25.8, 10.2, 0.05, 25.8, 1920, 1080)
  capture('03-stolas-pad-far', 16, 25.8, 10.2, 0.05, 25.8)
  capture('04-buer-pad', 19.8, 20.6, 21.8, 0.05, 20.6)
  capture('05-asmoday-pad', 19.8, 23.1, 21.8, 0.05, 23.1)
  capture('06-weapon-refill-pads', 16, 25.6, 16, 0.05, 28.7)
  capture('07-west-altar-close', 9.4, 17, 7, 1.05, 17)
  capture('08-west-gallery-distance', 10.5, 18.6, 5.8, 1.5, 16)
  capture('09-focused-board', 8.4, 14.8, 6.5, 1.65, 14.8)
  g.run.pending = { { x = 16, z = 21, kind = 'stolas', delay = 0.45, maxDelay = 1.2 } }
  capture('10-spawn-portal', 16, 25.5, 16, 0.8, 21)
  g.run.pending = {}
  local release = require('src.app.release')
  g = Game.new('field', release.sessionMaps.field, release.sessionOptions.field)
  g.testing, g.state, g.elapsed, g.view.messageTimer = true, 'playing', 70, 0
  capture('11-basilica-nave', 16, 27.5, 16, 2.8, 14)
  capture('12-ash-altar', 6.8, 17, 4.1, 1.7, 17)
  capture('13-storm-altar', 25.2, 17, 27.9, 1.7, 17)
  capture('13-storm-altar-small', 25.2, 17, 27.9, 1.7, 17, 960, 540)
  for _, id in ipairs({ 'ash', 'storm' }) do
    g:act('catalog', 'field_chamber_' .. id)
    for _ = 1, 160 do
      g:update(1 / 120, {})
    end
    local x = g.player.x
    capture('14-' .. id .. '-arena', x, 20, x, 1.6, 12)
    local boss = assert(g.enemies[1])
    g:damageEnemy(boss, boss.hp, 'weapon')
    for _, pose in ipairs({ 'gather', 'rise', 'release' }) do
      for _ = 1, 42 do
        g:update(1 / 120, {})
      end
      capture('15-' .. id .. '-transition-' .. pose, x, 20, x, 1.6, 12)
    end
    -- Approach into the court before commitment; at the rear wall some
    -- offsets correctly fall outside the room. Retreat after release so
    -- the ground contacts under the knight can be inspected in these stills.
    g.player.z = 18
    local expected = id == 'ash' and 'ash-lance' or 'tempest-cross'
    local function advanceUntil(predicate)
      for _ = 1, 1800 do
        if predicate() then
          return
        end
        g:update(1 / 120, {})
      end
      error('phase review did not reach ' .. expected .. ' / ' .. boss.ai)
    end
    advanceUntil(function()
      return boss.attackKind == expected
        and boss.ai == 'windup'
        and boss.windup <= boss.windupDuration * 0.5
    end)
    capture('15-' .. id .. '-pattern-windup', x, 18, x, 1.0, 15)
    advanceUntil(function()
      return boss.ai == 'strike'
    end)
    notes[#notes + 1] = id .. ': ' .. expected .. ', released marks ' .. #g.hazards
    capture('15-' .. id .. '-pattern-warning', x, 20, x, 0.7, 16)
    for beat, ticks in ipairs({ 94, 48, 42 }) do
      for _ = 1, ticks do
        g:update(1 / 120, {})
      end
      capture('15-' .. id .. '-pattern-beat-' .. beat, x, 20, x, 0.7, 16)
    end
    g:damageEnemy(boss, boss.hp, 'weapon')
    for _ = 1, 60 do
      g:update(1 / 120, {})
    end
    assert(g.testField.roomTrial.status == 'complete', 'completion capture needs final death')
    capture('16-' .. id .. '-complete', x, 20, x, 1.6, 12)
  end
  Field.reset(g)
  capture('17-reset-nave', 16, 27.5, 16, 2.8, 14)
  local file = assert(io.open(output .. '/ritual-review.txt', 'w'))
  file:write(table.concat(notes, '\n') .. '\n')
  file:close()
  UI.useMouse = oldMouse
end
return Review

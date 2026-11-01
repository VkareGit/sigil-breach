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
  g.ephemeral = true
  Field.close(g)
  g.enemies, g.pickups, g.hazards, g.bullets = {}, {}, {}, {}
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
  g.ephemeral, g.state, g.elapsed, g.view.messageTimer = true, 'playing', 70, 0
  capture('11-basilica-nave', 24, 36, 24, 3.8, 15)
  capture('12-ash-altar', 10, 11, 10, 1.7, 7)
  capture('13-storm-altar', 38, 11, 38, 1.7, 7)
  capture('13-storm-altar-small', 38, 11, 38, 1.7, 7, 960, 540)
  capture('11-basilica-vault', 24, 36, 24, 7.0, 22)
  capture('11-basilica-aisle', 17, 25, 10, 3.8, 13)
  capture('11-basilica-presbytery', 24, 11, 24, 1.8, 3)
  capture('11-basilica-reverse', 24, 10, 24, 4.2, 32)
  capture('11-basilica-nave-small', 24, 36, 24, 3.8, 15, 960, 540)
  capture('11-catacomb-west', 18, 4, 13.58, 1.5, 3.5)
  capture('11-catacomb-east', 30, 4, 34.42, 1.5, 3.5)
  capture('11-loculi-aisle', 16, 4, 18, 1.5, 1.58)
  capture('19-ossuary', 16, 4, 13.64, 1.4, 3.5)
  capture('19-threshold', 24, 35.5, 24, 2.8, 39.34)
  capture('19-relic-shelf', 20.2, 35.5, 18.60, 1.4, 35.5)
  -- Look along both thresholds, not only down the visually flattering axis.
  -- Regression: a dado and a funerary shelf used to float in these openings.
  capture('20-west-door-from-nave', 21.5, 27.6, 13, 1.3, 27.6)
  capture('20-west-door-from-hall', 14.5, 28, 23, 1.3, 27.5)
  capture('20-east-door-from-nave', 26.5, 27.6, 35, 1.3, 27.6)
  capture('20-east-door-from-hall', 33.5, 28, 25, 1.3, 27.5)
  capture('23-ritual-entry', 24, 37.2, 24, 3.2, 24)
  capture('23-binding-west', 18.5, 28.5, 18.5, 0.75, 25.62)
  capture('23-binding-east', 29.5, 28.5, 29.5, 0.75, 25.62)
  capture('23-threshold-trace', 21.2, 27.5, 17.5, 0.15, 27.5)
  capture('23-threshold-trace-low', 21.2, 27.5, 17.5, 0.15, 27.5, 960, 540)
  capture('23-votive-entry', 20.1, 36.5, 17.6, 1.35, 35.5)
  -- Inspect ink at the edge and from the adjoining aisle, not only head-on.
  capture('24-binding-close-west', 7.2, 6.8, 7.1, 2.9, 5.66)
  capture('24-binding-oblique-west', 6.0, 7.3, 7.6, 2.85, 5.66)
  capture('24-binding-edge-west', 13.9, 6.8, 10, 3.1, 5.66)
  capture('24-binding-close-east', 35.2, 6.8, 35.1, 2.9, 5.66)
  capture('24-binding-from-altar', 10, 9, 10, 3.2, 5.66)
  capture('24-entry-panel-close', 24, 37.5, 24, 2.5, 39.34)
  capture('24-entry-panel-side', 26.8, 37, 24, 2.4, 39.34)
  capture('24-entry-gallery', 24, 37, 18, 1.8, 35.5)
  capture('24-inscription-reading', 7.8, 8.4, 7.73, 3.5, 5.624)
  capture('24-inscription-reading-small', 7.8, 8.4, 7.73, 3.5, 5.624, 960, 540)
  capture('24-inscription-reading-east', 40.2, 8.4, 40.27, 3.5, 5.624)
  capture('24-altar-walkup', 10, 8.85, 10, 3.2, 5.624)
  capture('24-altar-walkup-4by3', 10, 8.85, 10, 3.2, 5.624, 1024, 768)
  g:spawn('boss', 10, 15)
  capture('23-altar-presence', 10, 25, 10, 3.0, 10)
  require('qa.reviews.atmosphere').run(g, capture, renderer)
  Field.reset(g)
  g:act('catalog', 'field_chamber_ash')
  g.testField.invincible = true
  for index = 0, 5 do
    if index > 0 then
      for _ = 1, 24 do
        g:update(1 / 120, {})
      end
    end
    capture('19-seal-activation-' .. index, 10, 11, 10, 2.0, 7)
  end
  for _, id in ipairs({ 'ash', 'storm' }) do
    g:act('catalog', 'field_chamber_' .. id)
    g.testField.invincible = true -- art inspection only, live entry is mortal
    for _ = 1, 160 do
      g:update(1 / 120, {})
    end
    local x = g.player.x
    capture('14-' .. id .. '-arena', x, 25, x, 3.2, 10)
    capture('14-' .. id .. '-arena-4x3', x, 25, x, 3.2, 10, 1024, 768)
    capture('14-' .. id .. '-vault', x, 25, x, 7.0, 15)
    local boss = assert(g.enemies[1])
    for _ = 1, 300 do
      if boss.ai == 'strike' then
        break
      end
      g:update(1 / 120, {})
    end
    capture('15-' .. id .. '-opening', x, 25, boss.x, 1.5, boss.z)
    g:damageEnemy(boss, boss.hp, 'weapon')
    for _ = 1, 60 do
      g:update(1 / 120, {})
    end
    assert(g.testField.roomTrial.status == 'complete', 'one stock must end the trial')
    capture('16-' .. id .. '-complete', x, 25, x, 2.8, 10)
  end
  Field.reset(g)
  capture('17-reset-nave', 24, 36, 24, 3.8, 15)
  -- Focused read of each new response, with real warning/contact clocks.
  -- Directly choosing an action here is deliberate art QA; the combat suite
  -- separately requires the unassisted AI to choose/finish a live string.
  for _, sample in ipairs({
    { trial = 'ash', action = 'furnace', distance = 2.6 },
    { trial = 'ash', action = 'cinder-spear', distance = 5.5 },
    { trial = 'storm', action = 'antler-return', distance = 2.8 },
    { trial = 'stars', action = 'talon-fan', distance = 3 },
    { trial = 'resin', action = 'root-brace', distance = 2.8 },
  }) do
    g = Game.new('field', release.sessionMaps.field, release.sessionOptions.field)
    g.ephemeral, g.view.motion = true, false
    g:act('catalog', 'field_chamber_' .. sample.trial)
    g.testField.invincible = true
    for _ = 1, 160 do
      g:update(1 / 120, {})
    end
    local e = assert(g.enemies[1])
    local def = require('src.content.enemies').of(e)
    if def.phases then
      e.phaseIndex = 2
    end
    g.bullets, g.hazards = {}, {}
    local x, z = e.x, e.z + sample.distance
    g.player.x, g.player.z, g.player.yaw = x, z, math.pi
    e.target, e.recover, e.attack = g.player.id, 0, 0
    local action
    for _, a in ipairs(def.attacks) do
      if a.id == sample.action then
        action = a
      end
    end
    assert(action)
    local Actions = require('src.enemies.actions')
    Actions.begin(g, e, sample.distance, action)
    for _ = 1, math.floor(action.windup * 60) do
      g:update(1 / 120, {})
    end
    capture('18-' .. sample.action .. '-windup', x, z, e.x, 1.2, e.z)
    for _ = 1, 300 do
      if e.ai == 'strike' then
        break
      end
      g:update(1 / 120, {})
    end
    assert(e.ai == 'strike', 'new action failed to release ' .. sample.action)
    capture('18-' .. sample.action .. '-release', x, z, e.x, 0.7, e.z)
    for _ = 1, 90 do
      g:update(1 / 120, {})
    end
    capture('18-' .. sample.action .. '-contact', x, z, e.x, 0.7, e.z, 960, 540)
  end
  local file = assert(io.open(output .. '/ritual-review.txt', 'w'))
  file:write(table.concat(notes, '\n') .. '\n')
  file:close()
  UI.useMouse = oldMouse
end
return Review

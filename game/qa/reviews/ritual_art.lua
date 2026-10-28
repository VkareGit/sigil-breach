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
  capture('11-basilica-vault', 16, 27.5, 16, 5.8, 18)
  capture('11-basilica-aisle', 11, 26, 11, 2.8, 14)
  capture('11-basilica-presbytery', 16, 11, 16, 1.8, 3)
  capture('11-basilica-reverse', 16, 9, 16, 3.2, 26)
  capture('11-basilica-nave-small', 16, 27.5, 16, 2.8, 14, 960, 540)
  capture('11-catacomb-west', 7.5, 7.7, 4.6, 1.5, 4.5)
  capture('11-catacomb-east', 24.5, 7.7, 27.4, 1.5, 4.5)
  capture('11-loculi-aisle', 13.2, 22.2, 10.6, 1.5, 21.5)
  for _, id in ipairs({ 'ash', 'storm' }) do
    g:act('catalog', 'field_chamber_' .. id)
    g.testField.invincible = true -- art inspection only, live entry is mortal
    for _ = 1, 160 do
      g:update(1 / 120, {})
    end
    local x = g.player.x
    capture('14-' .. id .. '-arena', x, 20, x, 2.4, 12)
    capture('14-' .. id .. '-vault', x, 20, x, 5.0, 14)
    local boss = assert(g.enemies[1])
    for _ = 1, 300 do
      if boss.ai == 'strike' then
        break
      end
      g:update(1 / 120, {})
    end
    capture('15-' .. id .. '-opening', x, 20, boss.x, 1.5, boss.z)
    g:damageEnemy(boss, boss.hp, 'weapon')
    for _ = 1, 60 do
      g:update(1 / 120, {})
    end
    assert(g.testField.roomTrial.status == 'complete', 'one stock must end the trial')
    capture('16-' .. id .. '-complete', x, 20, x, 1.6, 12)
  end
  Field.reset(g)
  capture('17-reset-nave', 16, 27.5, 16, 2.8, 14)
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
    g.testing, g.view.motion = true, false
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

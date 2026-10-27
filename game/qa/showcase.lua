local S = {}
function S.run(G, renderer)
  local output = os.getenv('SIGIL_UI_QA_DIR') or require('src.app.release').qaOutput
  local Skin = require('src.ui.skin')
  local previousForce, previousOutput = Skin.forceAudit, Skin.auditOutput
  Skin.forceAudit = true
  Skin.auditOutput = output
  Skin.auditFailureCount = 0
  local auditFile = assert(io.open(output .. '/ui-layout-audit.txt', 'w'))
  auditFile:close()
  local U = require('src.ui.interface')
  local Run = require('src.run.descent')
  local Waves = require('src.content.waves')
  local A = require('src.audio.audio')
  A.muted = true
  U.useMouse = false
  local g = G.new('descent')
  g.testing = true
  g:start()
  g.view.messageTimer = 0
  g.zoneTimer = 0
  local reports, scenes, measured = {}, 0, 0
  local function save(name, w, h)
    w, h = w or 1280, h or 720
    renderer:resize(w, h)
    renderer:draw(g, w, h)
    local target = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(target)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1)
    renderer:present(g, w, h)
    local Skin = require('src.ui.skin')
    local beginAudit, endAudit = Skin.beginAudit, Skin.endAudit
    Skin.beginAudit = function(screen, aw, ah)
      beginAudit(screen, aw, ah)
      -- A showcase always measures the active PNG ink, even without an env flag.
      Skin.audit = Skin.audit or { name = screen .. ' ' .. aw .. 'x' .. ah, items = {}, zones = {} }
    end
    Skin.endAudit = function()
      local audit = assert(Skin.audit, 'showcase requires actual painted UI measurements')
      for _, item in ipairs(audit.items) do
        measured = measured + 1
        if item.x < 0 or item.y < 0 or item.x + item.w > 1280 or item.y + item.h > 720 then
          reports[#reports + 1] = name .. ' OUTSIDE VIEWPORT: ' .. item.kind .. ' ' .. item.label
        end
      end
      return endAudit()
    end
    U.draw(g, w, h, { sensitivity = 1, motion = true, music = 0.65, hints = true })
    Skin.beginAudit, Skin.endAudit = beginAudit, endAudit
    love.graphics.setCanvas()
    local data = target:newImageData():encode('png')
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(data:getString())
    file:close()
    target:release()
    scenes = scenes + 1
  end
  g.state = 'menu'
  save('01-menu')
  save('01-menu-4by3', 1024, 768)
  save('01-menu-large', 1920, 1080)
  g.availableSave = { phase = 'preparing', wave = 3 }
  save('02-continue')
  g.state = 'confirm_new'
  save('03-new-confirm')
  g.availableSave = nil
  g.state = 'playing'
  save('04-shrine')
  Run.openShop(g)
  save('05-shop')
  save('06-shop-small', 960, 540)
  save('07-shop-4by3', 1024, 768)
  save('08-shop-wide', 1720, 720)
  g.player.arsenal.exorcist.reserve = 71
  g.player.armor = 99.5
  g.run.wallet = 3
  U.focus = 1
  save('09-partial-stock')
  g.run.wallet = 350
  Run.buy(g, 'choke')
  Run.buy(g, 'pierce')
  save('10-glyphs')
  U.focus = 1
  Run.closeShop(g)
  g.map = true
  save('11-circles')
  g.map = false
  g.help = true
  save('12-help')
  g.help = false
  g.player.arsenal.exorcist.reserve = 28
  g.run.wallet = 150
  Run.ready(g)
  g.player.yaw = math.pi
  g.view.messageTimer = 0
  save('13-countdown')
  g.run.phase = 'wave'
  g.run.countdown = 0
  g.run.pending = { { x = 16, z = 22, delay = 0.7, kind = 'imp', rewardId = '1_1' } }
  save('14-portal')
  g.run.wave = 3
  g.run.queueIndex = #Waves[3].queue + 1
  g.run.pending = {}
  g.player.z = 25.5
  g.player.pitch = 0.03
  g.elapsed = 80
  g.zoneTimer = 0
  g.view.messageTimer = 0
  g:spawn('armored', 15.4, 21.5)
  g:spawn('stolas', 17.6, 19.5)
  g:spawn('buer', 14, 17)
  g.pickups = {
    { kind = 'soul', amount = 12, rewardId = '3_9', x = 17.5, z = 23.6 },
    { kind = 'soul', amount = 4, rewardId = '3_1', x = 15.5, z = 23.3 },
  }
  save('15-armored-combat')
  save('16-combat-small', 960, 540)
  save('17-combat-wide', 1720, 720)
  g.run.echo = { x = 16, z = 22.5, wave = 3, amount = 148 }
  save('18-echo')
  g.map = true
  save('19-echo-map')
  g.map = false
  g.player.weapon = 2
  g.player.arsenal.judge.mag = 0
  g.player.arsenal.judge.reserve = 0
  save('20-revolver-empty')
  g.player.weapon = 1
  g.player.arsenal.judge.mag = 6
  g.player.arsenal.judge.reserve = 24
  g:damagePlayer(1000, 16, 20)
  save('21-death')
  save('22-death-small', 960, 540)
  Run.retry(g)
  save('23-retry')
  g:interact()
  save('24-poor-shop')
  g.state = 'playing'
  g.player.yaw = math.pi
  g.run.phase = 'wave'
  g.run.wave = 5
  g.run.queueIndex = 2
  g.run.pending = {}
  g.enemies = {}
  g.pickups = {}
  g.run.echo = nil
  g.view.messageTimer = 0
  g.view.feedbackTimer = 0
  g.player.z = 25
  g.player.pitch = 0.1
  require('src.session.encounter').guardianArrived(g)
  g:spawn('boss', 16, 20)
  save('25-boss')
  g.enemies[1].hp = 420
  save('26-boss-fury')
  -- 0.20: the boss guard strip filling, then a broken guard (falter + exposed).
  g.enemies[1].poise = 190
  save('26b-boss-guard')
  require('src.combat.rules').react(g, g.enemies[1], 200, true, nil, 0)
  g.view.feedback, g.view.feedbackTimer = require('src.content.text').get('feedback_falter'), 1.6
  save('26c-boss-falter')
  g.view.feedbackTimer = 0
  g.state = 'won'
  g.run.phase = 'complete'
  g.run.fragment = true
  require('src.session.encounter').guardianFell(g)
  g.run.wallet = 350
  save('27-victory')
  save('28-victory-4by3', 1024, 768)
  g = G.new('descent')
  g.testing = true
  g:start()
  g.state = 'paused'
  save('29-pause')
  g.state = 'settings'
  save('30-settings')
  g.state = 'playing'
  g.player.yaw = math.pi
  g.run.phase = 'wave'
  g.run.wave = 3
  g.run.queueIndex = 11
  g.run.pending = {}
  g.player.z = 25.5
  g.elapsed = 70
  g.view.messageTimer = 0
  g.zoneTimer = 0
  g.run.wallet = 184
  g:spawn('armored', 15, 21.5)
  g:spawn('stolas', 17.8, 20)
  g:spawn('buer', 14, 18)
  save('31-cover')
  -- Readability under live states, not just a clean menu illustration.
  g.player.yaw = math.atan2(g.enemies[1].x - g.player.x, g.enemies[1].z - g.player.z)
  save('32-target-armor')
  -- 0.20: the guard strip under the target's health while blows accumulate.
  g.enemies[1].poise = 24
  save('32b-target-guard')
  g.enemies[1].poise = 0
  g.player.hp = 18
  g.player.armor = 0
  g.player.arsenal.exorcist.mag = 0
  g.player.arsenal.exorcist.reserve = 0
  g.player.abilityState.powder.uses = 0
  g.player.dash = 0.3
  save('33-low-resources')
  save('34-low-resources-small', 960, 540)
  g.player.arsenal.exorcist.mag = 2
  g.player.arsenal.exorcist.reserve = 28
  g.player.hp = 100
  g.player.armor = 40
  g.player.abilityState.powder.uses = 2
  g.player.cooldown = 0
  g:shoot()
  g.view.hitmarker = 0.12
  save('35-fire')
  g.player.arsenal.exorcist.readyAt = 0
  g.run.phaseTime = 0
  g.run.spawnTimer = 99
  for _ = 1, 43 do
    g:update(1 / 120, {})
  end
  save('36-reload')
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      e.ai = 'windup'
      e.windupDuration = 0.6
      e.windup = 0.1
    end
  end
  save('37-windup')
  g = G.new('descent')
  g.testing = true
  g:start()
  g.view.messageTimer = 0
  g.zoneTimer = 0
  g:interact()
  g.run.wallet = 0
  U.focus = 4
  save('38-no-money')
  g.run.wallet = 1000000
  g.run.owned = { choke = true, pierce = true }
  g.run.glyph = 'choke'
  U.focus = 5
  save('39-owned-glyph')
  save('40-shop-large', 1920, 1080)
  g.state = 'menu'
  g.availableSave = { phase = 'preparing', wave = 3 }
  g.saveRecovered = true
  save('41-recovered-save')
  g.state = 'playing'
  g.run.echo = { amount = 148, x = 16, z = 21, wave = 1 }
  g.run.phase = 'wave'
  g.run.wave = 1
  g.run.queueIndex = 8
  g.run.pending = {}
  g.player.x = 16
  g.player.z = 25
  g.player.yaw = math.pi
  g.hazards = { { x = 15, z = 20, radius = 1.8, delay = 0, life = 5 } }
  g.pickups = {
    { kind = 'soul', x = 17, z = 22, amount = 4, rewardId = '1_1' },
    { kind = 'health', x = 14, z = 22, amount = 20 },
    { kind = 'ammo', x = 18, z = 22, amount = 2 },
  }
  g:spawn('imp', 16, 17)
  g.bullets = { { x = 16, z = 21, y = 1.4, color = { 1, 0.2, 0.15 }, big = false } }
  save('42-pickups-and-threats')
  g.player.z = 27.5
  g.player.pitch = 0
  g.player.x = 16
  g.player.yaw = math.pi
  g.enemies = {}
  g.bullets = {}
  g.hazards = {}
  g.pickups = {}
  g.run.echo = nil
  g:spawn('imp', 16, 9)
  g:spawn('stolas', 18, 11)
  save('43-distance-visibility')
  g.enemies = {}
  g.player.z = 25.5
  g.player.yaw = math.pi
  g.elapsed = 70
  g.zoneTimer = 0
  g.run.wallet = 184
  local armor = g:spawn('armored', 16, 21.5)
  armor.walkSpeed = 2
  armor.walk = 0.5
  armor.facing = math.pi
  save('44-armored-back')
  armor.ai = 'strike'
  armor.phase = 0.06
  save('45-armored-strike')
  armor.hp = 0
  armor.deathTime = 0.45
  save('46-armored-fall')
  -- The single test field, physical weapon and every portrait state.
  g = G.new('descent')
  g.testing = true
  g:start()
  g.view.messageTimer = 0
  g.zoneTimer = 0
  g.elapsed = 30
  g.player.x = 7
  g.player.z = 16
  g.player.yaw = -math.pi / 2
  g.player.pitch = 0.10
  save('47-west-fresco')
  g.player.x = 25
  g.player.z = 16
  g.player.yaw = math.pi / 2
  save('48-east-fresco')
  g.player.x = 16
  g.player.z = 25
  g.player.yaw = 0
  save('49-entry-fresco')
  g.map = true
  save('50-single-test-field')
  g.map = false
  g = G.new('descent')
  g.testing = true
  g:start()
  g.view.messageTimer = 0
  g.zoneTimer = 0
  g.player.yaw = g.player.yaw + math.pi
  save('55-shrine-behind')
  g.player.x = 6
  g.player.z = 13
  g.player.yaw = math.pi / 2
  save('56-shrine-occluded')
  g.player.x = 16
  g.player.z = 25.5
  g.player.yaw = math.pi
  g.run.phase = 'wave'
  g.run.pending = {}
  g.run.queueIndex = 8
  g.player.weapon = 2
  g.view.shotAge = 99
  save('57-pistol')
  save('58-combat-4by3', 1024, 768)
  g:spawn('imp', 16, 19)
  g:shoot()
  save('59-pistol-fire')
  g.view.shotAge = 0.17
  save('60-pistol-cycle')
  -- 0.14 weight: typed incoming projectiles with trails, blow arcs around the
  -- reticle (fire from the left, a heavy astral blow from the right, a near
  -- miss behind) and the gold guard-break brackets.
  g.player.weapon = 1
  g.view.shotAge = 99
  g.bullets = {
    {
      x = 14.6,
      y = 1.3,
      z = 20.6,
      vx = 3.2,
      vy = 0,
      vz = 3.9,
      life = 3,
      packet = {
        base = 14,
        impact = 40,
        damageType = 'astral',
      },
    },
    {
      x = 17.9,
      y = 1.5,
      z = 19.4,
      vx = -2.6,
      vy = 0,
      vz = 4.0,
      life = 3,
      big = true,
      packet = { base = 22, impact = 60, damageType = 'fire' },
    },
    {
      x = 15.4,
      y = 1.0,
      z = 21.8,
      vx = 1.6,
      vy = 0,
      vz = 2.9,
      life = 3,
      packet = { base = 14, impact = 40, damageType = 'poison' },
    },
  }
  local p = g.player
  g.view.hurtMarks = {
    {
      angle = p.yaw + math.pi / 2,
      harm = 0.5,
      severity = 0.6,
      color = require('src.feedback.weight').typeColor('fire'),
      age = 0.1,
      life = 1.1,
    },
    {
      angle = p.yaw - math.pi / 2 + 0.4,
      harm = 1,
      severity = 1,
      color = require('src.feedback.weight').typeColor('astral'),
      age = 0.05,
      life = 1.35,
    },
    {
      angle = p.yaw + math.pi,
      harm = 0,
      severity = 0.25,
      color = require('src.feedback.weight').typeColor('poison'),
      age = 0.05,
      life = 0.45,
      miss = true,
    },
  }
  g.view.hitmarker = 0.12
  g.view.breakConfirm = 0.12
  g.view.lastKill = false
  g.view.hitWeight = 0.6
  g.view.armorHit = false
  save('61-weight')
  g.bullets = {}
  g.view.hurtMarks = nil
  g.view.breakConfirm = 0
  g.view.hitmarker = 0
  -- 0.14 weight of the hero's weapon: the same shotgun blast sampled on the
  -- real clock (shove at the eye, view rise, settle past rest).
  g.player.arsenal.exorcist.mag = 2
  g.player.arsenal.exorcist.reserve = 28
  g.player.cooldown = 0
  g.player.arsenal.exorcist.readyAt = 0
  g.player.reload = 0
  g.run.phaseTime = 0
  g.run.spawnTimer = 99
  g:spawn('imp', 16, 10).hp = 5000
  g:shoot()
  local elapsed = 0
  for _, t in ipairs({ 0, 0.03, 0.07, 0.14, 0.30 }) do
    while elapsed < t - 1e-9 do
      g:update(1 / 120, {})
      elapsed = elapsed + 1 / 120
    end
    save(string.format('62-shot-weight-%03d', math.floor(t * 1000 + 0.5)), 640, 360)
  end
  -- 0.14 proving-ground gallery: halls of textures, the statue row, the pads.
  do
    local main = g
    local Field = require('src.run.test_field')
    g = Field.new(G)
    Field.close(g)
    g.view.messageTimer = 0
    g.zoneTimer = 0
    g.elapsed = 30
    for _, v in ipairs({
      { '63-gallery-west', 12.5, 16.5, -math.pi / 2, 0.04 },
      { '64-gallery-altar', 16, 13.5, math.pi, 0.08 },
      { '65-gallery-east', 19.5, 16.5, math.pi / 2, 0.04 },
      { '66-gallery-pads', 16, 18.5, 0, -0.18 },
    }) do
      g.player.x, g.player.z, g.player.yaw, g.player.pitch = v[2], v[3], v[4], v[5]
      g.view.presentationPrevious = nil
      save(v[1])
      if v[1] == '66-gallery-pads' then
        save('66-gallery-pads-4by3', 1024, 768)
        save('66-gallery-pads-large', 1920, 1080)
      end
    end
    -- 0.22 stations: the shooting range and the physics drills.
    Field.range(g)
    g.view.messageTimer, g.zoneTimer = 0, 0
    g.player.pitch = 0.02
    g.view.presentationPrevious = nil
    save('67-station-range')
    Field.physics(g)
    g.view.messageTimer, g.zoneTimer = 0, 0
    g.player.pitch = -0.05
    g.view.presentationPrevious = nil
    save('67b-station-physics')
    -- 0.24 balance tiers side by side: a light falter (in place), a heavy
    -- stagger (thrown back, bowed) and a knockdown (dropped to the floor).
    Field.reset(g)
    Field.close(g)
    g.view.messageTimer, g.zoneTimer = 0, 0
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 26, math.pi, -0.06
    local tiers = {}
    for i, x in ipairs({ 14.2, 16, 17.8 }) do
      local e = g:spawn('imp', x, 21.5)
      e.awake, e.spawnAge, e.ai, e.phase, e.stun = true, 1, 'hurt', 0.05, 0.3
      tiers[i] = e
    end
    tiers[2].heavyStagger = true
    tiers[3].knockedDown, tiers[3].knockTime, tiers[3].stun = true, 0.45, 0.25
    g.view.presentationPrevious = nil
    save('67e-balance-tiers')
    for _, e in ipairs(tiers) do
      e.hp = 0
    end
    g.enemies = {}
    -- 0.22 portals: three telegraphs at different moments, then an arrival.
    Field.reset(g)
    Field.close(g)
    g.view.messageTimer, g.zoneTimer, g.elapsed = 0, 0, 30
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27, math.pi, -0.04
    g.run.pending = {
      { x = 13.4, z = 21.5, kind = 'imp', delay = 1.0, maxDelay = 1.2, index = 1 },
      { x = 16, z = 20.2, kind = 'stolas', delay = 0.55, maxDelay = 1.2, index = 2 },
      { x = 18.6, z = 21.5, kind = 'buer', delay = 0.1, maxDelay = 1.2, index = 3 },
    }
    g.view.presentationPrevious = nil
    save('67c-portals')
    g.run.pending = {}
    local arriving = g:spawn('imp', 16, 22.5)
    arriving.spawnAge = 0.22
    g.view.presentationPrevious = nil
    save('67d-arrival')
    g = main
  end
  g.player.weapon = 1
  g.view.shotAge = 99
  g.view.hurt = 0
  g.player.hp = 100
  for i, t in ipairs({ 0, 3 / 0.65, 5 / 0.65 }) do
    g.time = t
    save('portrait-' .. i)
  end
  g.view.hurt = 0.4
  save('portrait-4')
  g.player.hp = 20
  save('portrait-5')
  g.view.hurt = 0
  g.player.hp = 100
  g.view.shotAge = 0.08
  save('portrait-6')
  g = G.new('descent')
  g.testing = true
  g:start()
  g.view.messageTimer = 0
  g.zoneTimer = 0
  g.help = true
  save('61-help-small', 960, 540)
  save('62-help-4by3', 1024, 768)
  save('63-help-wide', 1720, 720)
  g.help = false
  g.state = 'playing'
  g.map = true
  save('64-map-small', 960, 540)
  g.map = false
  g = G.new('descent')
  g.testing = true
  g:start()
  g.view.messageTimer = 0
  g.zoneTimer = 0
  g.elapsed = 30
  g.player.pitch = 0
  g.player.yaw = math.pi
  g.player.x = 7
  g.player.z = 20
  save('65-seal-asmoday')
  g.player.x = 25
  g.player.z = 20
  save('66-seal-stolas')
  g.player.x = 16
  g.player.z = 9
  save('67-seal-buer')
  g.player.x = 16
  g.player.z = 25.5
  g.run.phase = 'wave'
  g.time = 0
  g.view.shotAge = 99
  g.view.hurt = 0
  g.player.hp = 100
  save('portrait-1-small', 960, 540)
  g.player.hp = 18
  save('portrait-5-small', 960, 540)
  -- Free testing catalog uses the very same combat, assets and GUI as the expedition.
  local Field = require('src.run.test_field')
  g = Field.new(G)
  g.testing = true
  U.focus = 1
  save('68-field-catalog')
  save('69-field-catalog-small', 960, 540)
  save('70-field-catalog-4by3', 1024, 768)
  save('71-field-catalog-wide', 1720, 720)
  save('72-field-catalog-large', 1920, 1080)
  Field.spawn(g, 'boss', 1)
  Field.close(g)
  g.elapsed = 70
  g.view.messageTimer = 0
  save('73-field-boss')
  Field.reset(g)
  Field.spawn(g, 'imp', 3)
  Field.close(g)
  g.elapsed = 70
  g.view.messageTimer = 0
  save('74-field-group')
  Field.reset(g)
  Field.spawn(g, 'stolas', 1)
  Field.pose(g, 8)
  Field.close(g)
  g.elapsed = 70
  g.view.messageTimer = 0
  save('75-field-pose')
  Field.reset(g)
  for i, seal in ipairs(Field.catalog.seals) do
    Field.visitSeal(g, seal.id)
    Field.close(g)
    g.elapsed = 70
    g.view.messageTimer = 0
    save('field-seal-' .. seal.id)
  end
  Field.shop(g)
  save('76-field-shop')
  Field.close(g)
  Field.action(g, 'field_low')
  g.view.messageTimer = 0
  save('77-field-low-resources')
  g.testField.invincible = false
  g.player.invuln = 0
  g:damagePlayer(1000)
  save('78-field-death')
  Field.reset(g)
  Field.close(g)
  g.map = true
  save('79-field-map')
  g.map = false
  Field.open(g)
  Field.action(g, 'field_archive')
  for i = 1, 6 do
    Field.action(g, 'archive_' .. i)
    U.focus = i
    save('archive-sign-' .. i)
  end
  save('archive-small', 960, 540)
  save('archive-4by3', 1024, 768)
  save('archive-wide', 1720, 720)
  save('archive-large', 1920, 1080)
  -- Physical ammunition, exact reload stages and read-only range reports.
  g = Field.new(G)
  g.testing = true
  Field.close(g)
  g.player.weapon = 2
  g.elapsed = 70
  g.view.messageTimer = 0
  g.player.pitch = 0
  g.player.yaw = math.pi
  save('revolver-ready')
  save('revolver-ready-small', 960, 540)
  g.player.arsenal.judge.mag = 0
  g.player.arsenal.judge.reserve = 0
  g.player.abilityState.powder.uses = 0
  save('revolver-dry')
  save('revolver-dry-small', 960, 540)
  g.player.arsenal.judge.reserve = 24
  g:reloadGun()
  require('src.combat.reload').update(g, 0.7)
  save('revolver-loading')
  require('src.combat.reload').update(g, 0.8)
  save('revolver-closing')
  require('src.combat.reload').update(g, 1)
  Field.shop(g)
  g.player.arsenal.judge.reserve = 71
  g.run.wallet = 3
  save('revolver-shop-partial')
  save('revolver-shop-partial-small', 960, 540)
  g.player.arsenal.judge.reserve = 72
  g.run.wallet = 1000
  g.player.abilityState.powder.uses = 3
  save('revolver-shop-full')
  Field.reset(g)
  Field.close(g)
  g.player.weapon = 1
  g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27, math.pi, 0
  g.enemies = {}
  g:spawn('imp', 15.6, 22)
  g:spawn('armored', 16.4, 22)
  g:shoot()
  Field.open(g)
  save('range-shotgun-report')
  save('range-shotgun-report-small', 960, 540)
  save('range-shotgun-report-4by3', 1024, 768)
  save('range-shotgun-report-wide', 1720, 720)
  save('range-shotgun-report-large', 1920, 1080)
  Field.reset(g)
  Field.close(g)
  g.player.weapon = 2
  g.player.yaw = 0
  g:shoot()
  Field.open(g)
  save('range-revolver-miss')
  save('range-revolver-miss-small', 960, 540)
  Field.reset(g)
  Field.spawn(g, 'furfur', 1)
  Field.close(g)
  g.elapsed = 70
  g.view.messageTimer = 0
  save('furfur-test-field')
  save('furfur-test-field-small', 960, 540)
  Field.action(g, 'field_hitboxes')
  g.view.messageTimer = 0
  save('furfur-hit-volumes')
  Field.open(g)
  save('furfur-catalog-small', 960, 540)
  Field.reset(g)
  Field.close(g)
  g.player.yaw = math.pi
  g.view.messageTimer = 0
  g.elapsed = 70
  assert(g:cast(1), 'Powder-charge QA requires a real throw')
  for _ = 1, 18 do
    g:update(1 / 120, {})
  end
  save('powder-charge-throw')
  save('powder-charge-throw-small', 960, 540)
  for _ = 1, 107 do
    g:update(1 / 120, {})
  end
  save('powder-charge-detonation-small', 960, 540)
  local weaponPoses = require('qa.reviews.weapon_timeline').run(G, renderer, output)
  require('qa.reviews.weapon_material').run(G, renderer, output)
  g = Field.new(G)
  g.testing = true
  Field.skirmish(g)
  g.elapsed = 70
  g.view.messageTimer = 0
  save('quick-combat')
  save('quick-combat-small', 960, 540)
  g.player.armor = 0
  g.player.invuln = 0
  g:damagePlayer(1000)
  save('quick-combat-retry')
  save('quick-combat-retry-small', 960, 540)
  Field.skirmish(g)
  g.player.weapon = 2
  g.elapsed = 70
  g.view.messageTimer = 0
  local e = g.enemies[1]
  e.previewFrame = 1
  local Surface = require('src.enemies.surface')
  local hx, hy, hz = Surface.locate(Surface.prepare(g, e), 'head')
  local _, eye = require('src.combat.ballistics').origin(g)
  local dx, dz = hx - g.player.x, hz - g.player.z
  g.player.yaw = math.atan2(dx, dz)
  g.player.pitch = math.atan2(hy - eye, math.sqrt(dx * dx + dz * dz))
  g:shoot()
  save('precision-hit')
  Field.open(g)
  save('precision-report-small', 960, 540)
  local attackScenes = require('qa.reviews.render').run(G, renderer, output)
  require('qa.reviews.fresco_motion_review').run(G, renderer, output)
  local lightScenes = require('qa.reviews.lighting_review').run(G, renderer, output)
  local carryScenes = require('qa.reviews.weapon_motion_review').run(G, renderer, output)
  local contactScenes = require('qa.reviews.movement_impact_review').run(G, renderer, output)
  local impactScenes = require('qa.reviews.impact_review').run(G, renderer, output)
  local clarityScenes =
    require('qa.reviews.visual_readability_review').run(G, renderer, output, true)
  require('qa.reviews.typography_review').run(output)
  require('qa.reviews.gui_art_review').run(output)
  local detailScenes = require('qa.reviews.detail_review').run(output, G, renderer)
  local firingScenes = require('qa.reviews.firing_review').run(output, G, renderer)
  local summoningScenes = require('qa.reviews.summoning_review').run(output, G, renderer)
  -- Hit volumes against what is drawn, in live states (plan v7 H0;
  -- measurement only, it changes nothing in play).
  require('qa.reviews.hit_truth').run(output, G, renderer)
  local atlas = assert(io.open(output .. '/atlas-bounds.txt', 'w'))
  for i, b in ipairs(require('src.ui.skin').bounds) do
    atlas:write(string.format('Cell %d: %d,%d %dx%d\n', i, b.x, b.y, b.w, b.h))
  end
  atlas:close()
  renderer:resize(1280, 720)
  local start = love.timer.getTime()
  for _ = 1, 120 do
    g.time = g.time + 1 / 120
    renderer:draw(g, 1280, 720)
    love.graphics.present()
  end
  local elapsed = love.timer.getTime() - start
  reports[#reports + 1] = scenes
    .. ' scenes rendered (native game renderer and actual UI), 960x540 / 1280x720 / 1024x768 / 1720x720 / 1920x1080.'
  reports[#reports + 1] = weaponPoses
    .. ' weapon poses sampled from actual shot/reload timelines in two contact sheets.'
  reports[#reports + 1] = attackScenes
    .. ' additional enemy attack scenes sampled from actual windup/strike/recovery timelines.'
  reports[#reports + 1] = string.format(
    '120 complete frames: %.3f seconds, %.1f FPS (present/vsync dependent).',
    elapsed,
    120 / elapsed
  )
  if #reports == 4 then
    table.insert(
      reports,
      1,
      measured
        .. ' actual painted text, image and indicator bounds checked; none outside the logical viewport. Frame-interior and collision results: ui-layout-audit.txt.'
    )
  end
  reports[#reports + 1] = string.format(
    'v13 additional reviews: %d light/shadow, %d weapon-carry, %d movement-contact, %d shot-impact frames.',
    lightScenes,
    carryScenes,
    contactScenes,
    impactScenes
  )
  reports[#reports + 1] = string.format(
    'v15 integrated readability: %d feedback and occlusion frames; all use the current renderer.',
    clarityScenes
  )
  reports[#reports + 1] = string.format(
    'v17 weapon details: %d shot/carry/surface-mark frames; actual simulation and persistent-contact review.',
    detailScenes
  )
  require('qa.reviews.creature_pigment').run(G, renderer, output)
  require('qa.reviews.ritual_art').run(G, renderer, output)
  -- Public release controls are a separate profile; keep legacy shop/wave
  -- captures above as regression coverage for their retained implementations.
  local archived = g
  g = G.new('field', nil, require('src.app.release').sessionOptions.field)
  g.testing = true
  g.time, g.elapsed, g.view.messageTimer = 70, 70, 0
  for _, size in ipairs({
    { 'small', 960, 540 },
    { '4by3', 1024, 768 },
    { 'normal', 1280, 720 },
    { 'wide', 1720, 720 },
    { 'large', 1920, 1080 },
  }) do
    g.state, g.help = 'field_catalog', false
    save('public-field-catalog-' .. size[1], size[2], size[3])
    g.help = true
    save('public-field-help-' .. size[1], size[2], size[3])
    g.state, g.help = 'playing', false
    save('public-field-hud-' .. size[1], size[2], size[3])
  end
  g = archived
  reports[#reports + 1] =
    'Public proving ground: 15 catalogue, help and unchanged HUD captures across five viewport sizes.'
  -- Actual phase event, existing portrait/HUD and cast art; no mock labels.
  for _, kind in ipairs({ 'boss', 'furfur' }) do
    g = G.new('field', nil, require('src.app.release').sessionOptions.field)
    g.testing, g.state = true, 'playing'
    g.player.x, g.player.z, g.player.yaw = 16, 25, math.pi
    g.elapsed = 70 -- Inspect combat after the entry tutorial, not behind its overlay.
    local enemy = assert(Field.spawn(g, kind, 1))[1]
    g.view.messageTimer = 0 -- The old summon notice has expired before a phase transition.
    enemy.x, enemy.z = 16, 17
    enemy.spawnAge, enemy.awake, enemy.target = 2, true, g.player.id
    g:damageEnemy(enemy, enemy.hp, 'weapon')
    for _ = 1, 78 do
      g:update(1 / 120, {})
    end
    for _, size in ipairs({ { 'small', 960, 540 }, { '4by3', 1024, 768 }, { 'normal', 1280, 720 } }) do
      save('encounter-' .. kind .. '-transition-' .. size[1], size[2], size[3])
    end
    local function advanceUntil(predicate)
      for _ = 1, 1200 do
        if predicate() then
          return
        end
        g:update(1 / 120, {})
      end
      error(kind .. ': phase review did not reach the expected action')
    end
    -- Actual choice, recovery, windup and release. Do not hold the hit flash
    -- from the transition over a manually posed later attack.
    advanceUntil(function()
      return enemy.ai == 'windup' and enemy.windup <= enemy.windupDuration * 0.5
    end)
    assert(enemy.attackKind == (kind == 'boss' and 'ash-lance' or 'tempest-cross'))
    save('encounter-' .. kind .. '-phase2-windup')
    advanceUntil(function()
      return enemy.ai == 'strike'
    end)
    save('encounter-' .. kind .. '-phase2-release')
    for beat, ticks in ipairs({ 94, 48, 42 }) do
      for _ = 1, ticks do
        g:update(1 / 120, {})
      end
      save('encounter-' .. kind .. '-phase2-beat-' .. beat)
    end
  end
  g = archived
  reports[#reports + 1] =
    'Encounter phases: 16 real transition/windup/release/ground-pattern captures with unchanged artwork and HUD.'
  -- Public room layout uses the same painted assets; inspect live portals,
  -- attacks, physical doorways and the existing HUD at small viewports too.
  local release = require('src.app.release')
  local function chamberSession()
    g = G.new('field', release.sessionMaps.field, release.sessionOptions.field)
    g.testing, g.state = true, 'playing'
    g.elapsed, g.view.messageTimer = 70, 0
  end
  for _, view in ipairs({
    { 'nave', 16, 27.5, math.pi },
    { 'west-door', 14, 17, -math.pi / 2 },
    { 'east-door', 18, 17, math.pi / 2 },
    { 'north-passage', 16, 13, math.pi },
    { 'chapel-door', 16, 7, -math.pi / 2 },
    { 'basilica-ribs', 16, 26, math.pi, 0.18 },
    { 'side-arcade', 10.3, 28.5, math.pi, 0.12 },
    { 'presbytery', 16, 9, math.pi, 0.08 },
    { 'ash-altar', 6.8, 17, -math.pi / 2, 0.06 },
    { 'storm-altar', 25.2, 17, math.pi / 2, 0.06 },
  }) do
    chamberSession()
    g.player.x, g.player.z, g.player.yaw = view[2], view[3], view[4]
    g.player.pitch = view[5] or 0
    save('chambers-' .. view[1])
  end
  for _, trial in
    ipairs(require('src.content.maps.index'):get(release.sessionMaps.field).proving.trials)
  do
    chamberSession()
    assert(g:act('catalog', 'field_chamber_' .. trial.id))
    for _ = 1, 70 do
      g:update(1 / 120, {})
    end
    save('chambers-' .. trial.id .. '-portal')
    for _ = 1, 900 do
      g:update(1 / 120, {})
      if g.enemies[1] and g.enemies[1].ai == 'windup' then
        break
      end
    end
    assert(g.enemies[1], 'room review requires an actual arrival')
    for _, size in ipairs({ { 'small', 960, 540 }, { '4by3', 1024, 768 }, { 'normal', 1280, 720 } }) do
      save('chambers-' .. trial.id .. '-active-' .. size[1], size[2], size[3])
    end
  end
  local enemy = g.enemies[1]
  g:damageEnemy(enemy, enemy.hp, 'weapon')
  g:update(1 / 120, {})
  assert(g.testField.roomTrial.status == 'complete')
  save('chambers-complete-small', 960, 540)
  g = archived
  reports[#reports + 1] =
    'Authored chambers: 35 basilica layout, live portal/attack and completion captures; existing art/HUD.'
  local foundationChecks = require('qa.reviews.foundation_ui').run(G, renderer, output)
  reports[#reports + 1] = 'Foundation UI / charge handoff: '
    .. foundationChecks
    .. ' passing checks; fresh slot, loading and ritual captures.'
  local f = assert(io.open(output .. '/render-results.txt', 'w'))
  reports[#reports + 1] = string.format(
    'v19 discharge and death: %d real shot/fall frames; distinct painted recoil, one landing per body, clear aiming area.',
    firingScenes
  )
  f:write(table.concat(reports, '\n'))
  f:write(
    '\nPainted portals and abilities: '
      .. summoningScenes
      .. ' native scenes, read-only render receipts and wall occlusion verified.\n'
      .. require('qa.output').receipt()
  )
  f:close()
  print(table.concat(reports, '\n'))
  love.mouse.setRelativeMode(false)
  Skin.forceAudit, Skin.auditOutput = previousForce, previousOutput
  assert(
    Skin.auditFailureCount == 0,
    'Showcase found '
      .. Skin.auditFailureCount
      .. ' UI interior/overlap issues; see '
      .. output
      .. '/ui-layout-audit.txt'
  )
end
return S

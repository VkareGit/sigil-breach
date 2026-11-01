-- Exercise the rendered UI at supported sizes, including legal save limits.
-- This is independent of the optional Skin audit and does not trust its zones.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local U = require('src.ui.interface')
  local Skin = require('src.ui.skin')
  local Sanctuary = require('src.session.sanctuary')
  local Portrait = require('src.ui.portrait')
  local Titles = require('src.ui.fonts.painted_titles').init()
  local Numbers = require('src.ui.fonts.painted_numbers').init()
  local Reliquary = require('src.ui.reliquary')
  local lg = love.graphics
  local lines = {}
  local failures = {}
  local inspected = 0
  local imagesChecked = 0
  local output = os.getenv('SIGIL_UI_QA_DIR') or require('src.app.release').qaOutput
  local preview = {
    ['maximum-wallet-and-clock'] = true,
    ['catalog-furfur'] = true,
    ['revolver-partial-ammunition-purchase'] = true,
    ['sandbox-shot-report-spread'] = true,
    ['sandbox-shot-report-miss'] = true,
    ['sandbox-hitbox-toggle'] = true,
    ['full-revolver-and-charges'] = true,
    ['revolver-loading'] = true,
    ['recovered-menu'] = true,
    ['sandbox-help'] = true,
  }
  local check = Fixtures.checker(lines, 'bitmap UI ', '')
  local function fresh()
    local g = G.new('floor')
    g.ephemeral = true
    g:start()
    g.view.messageTimer = 0
    g.zoneTimer = 0
    return g
  end
  local function active(g)
    g.player.yaw = math.pi
    g.enemies = {}
    g.view.messageTimer = 0
  end
  local function maxima(g)
    g.elapsed = 10000000
    local counted = require('src.session.stats').controlled(g)
    counted.kills = 1000000
    counted.damageTaken = 100000000
    counted.score = 1000000000
    g.run.deaths = 100000
    g.run.wallet = 1000000
    g.player.hp = 100
    g.player.armor = 100
    g.player.arsenal.exorcist.mag = 2
    g.player.arsenal.exorcist.reserve = 72
    g.player.arsenal.judge.mag = 6
    g.player.arsenal.judge.reserve = 72
    g.player.abilityState.powder.uses = 3
    g.player.dash = 2
  end
  local settings =
    { sensitivity = 3, motion = true, music = 1, fov = 115, hints = true, muted = false }
  local settingsOff =
    { sensitivity = 0.2, motion = false, music = 0, fov = 85, hints = false, muted = true }
  local polish =
    'Zażółć gęślą jaźń. ĄĆĘŁŃÓŚŹŻ ąćęłńóśźż 0123456789 +−/%° []'
  local oldNewFont = lg.newFont
  local fontCalls = 0
  lg.newFont = function(...)
    fontCalls = fontCalls + 1
    error('runtime tried to create a TTF font')
  end
  local initialized, initError = pcall(U.init)
  lg.newFont = oldNewFont
  check(
    'UI initializes exclusively from bitmap assets without constructing runtime TTF fonts',
    initialized and fontCalls == 0
  )
  -- Reproduce the old settings failure with real drawing calls. A control
  -- panel drawn after a label must count even if its own letters miss it.
  local savedAudit, savedFields, savedForce = Skin.audit, Skin.fields, Skin.forceAudit
  local probe = lg.newCanvas(256, 128)
  lg.push('all')
  lg.setCanvas(probe)
  lg.origin()
  lg.clear(0, 0, 0, 1)
  Skin.forceAudit = true
  Skin.beginAudit('panel order fixture', 256, 128)
  Skin.panel(0, 0, 256, 128)
  Skin.text('RELOAD', 20, 20, U.fonts[18])
  local backgroundIssues = Skin.auditProblems(Skin.audit)
  Skin.panel(40, 18, 180, 42)
  local coveredIssues = Skin.auditProblems(Skin.audit)
  Skin.auditLayer('new modal')
  Skin.panel(0, 0, 256, 128)
  Skin.text('READY', 20, 20, U.fonts[18])
  local modalIssues = Skin.auditProblems(Skin.audit)
  Skin.audit, Skin.fields, Skin.forceAudit = savedAudit, savedFields, savedForce
  lg.pop()
  probe:release()
  check('earlier panel remains a valid text background', #backgroundIssues == 0)
  check(
    'later opaque panel reports its covered label independently of button letters',
    #coveredIssues == 1 and coveredIssues[1]:find('COVERED BY LATER PANEL', 1, true) ~= nil
  )
  check('new modal audit discards intentionally covered previous-layer labels', #modalIssues == 0)
  local fontImages = {}
  for _, size in ipairs({ 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 36, 42, 48, 64, 94 }) do
    local font = assert(U.fonts[size])
    check(
      'bitmap text preserves Polish letters and numbers at size ' .. size,
      font:hasGlyphs(polish) and font:getWidth(polish) > 0
    )
    local image = font.image
    local meta = font.meta
    local valid = type(font) == 'table'
      and image
      and image:typeOf('Image')
      and meta
      and meta.image:match('%.png$')
    if valid then
      fontImages[image] = true
      local source = love.image.newImageData(meta.image)
      valid = image:getWidth() == source:getWidth()
        and image:getHeight() == source:getHeight()
        and image:getFilter() == 'nearest'
      for _, cp in require('utf8').codes(polish) do
        local glyph = font.glyphs[cp]
        if cp ~= 32 then
          local painted = false
          if glyph and glyph.w then
            local x, y, w, h = glyph.quad:getViewport()
            valid = valid and x == glyph.x and y == glyph.y and w == glyph.w and h == glyph.h
            for iy = 0, h - 1 do
              for ix = 0, w - 1 do
                local _, _, _, a = source:getPixel(x + ix, y + iy)
                if a > 0.05 then
                  painted = true
                  break
                end
              end
              if painted then
                break
              end
            end
          end
          valid = valid and painted
        end
      end
      source:release()
    end
    check(
      'size ' .. size .. ' reads actual painted Polish glyph pixels from its active PNG texture',
      valid
    )
  end
  for _, line in ipairs(require('tests.cases.illustrated_type').run(U.fonts)) do
    lines[#lines + 1] = line
  end
  local cases = {
    {
      'preparation',
      function(g)
        g.view.message = 'LIMBO / 4 waves and a guardian. [E] Merchant at the Ember. [ENTER] Ready.'
        g.view.messageTimer = 6
      end,
    },
    {
      'warning-and-combo',
      function(g)
        active(g)
        g.saveWarning = 'Could not verify the save. Try again at the Ember.'
        g.view.feedback = 'CLOSE EXECUTION / +5 HEALTH'
        g.view.feedbackTimer = 2
        local counted = require('src.session.stats').controlled(g)
        counted.combo = 12
        counted.comboTimer = 2
        g.view.message = 'WAVE 4 / Do not get boxed in between demons. Keep a way out.'
        g.view.messageTimer = 4
        g.zone = 'zone_nave'
        g.zoneTimer = 3
      end,
    },
    {
      'maximum-wallet-and-clock',
      function(g)
        active(g)
        maxima(g)
        g.run.echo = { amount = 1000000, x = 16, z = 23 }
        g.run.glyph = 'pierce'
      end,
    },
    {
      'empty-revolver-and-low-health',
      function(g)
        active(g)
        g.player.weapon = 2
        g.player.arsenal.judge.mag = 0
        g.player.arsenal.judge.reserve = 0
        g.player.hp = 1
        g.player.armor = 0
        g.player.abilityState.powder.uses = 0
        g.run.wallet = 1000000
        g.run.echo = { amount = 1000000, x = 16, z = 23 }
      end,
    },
    {
      'full-revolver-and-charges',
      function(g)
        active(g)
        g.player.weapon = 2
        g.player.arsenal.judge.mag = 6
        g.player.arsenal.judge.reserve = 72
        g.player.abilityState.powder.uses = 3
      end,
    },
    {
      'revolver-needs-reload',
      function(g)
        active(g)
        g.player.weapon = 2
        g.player.arsenal.judge.mag = 0
        g.player.arsenal.judge.reserve = 72
      end,
    },
    {
      'revolver-loading',
      function(g)
        active(g)
        g.player.weapon = 2
        g.player.arsenal.judge.mag = 0
        g:reloadGun()
        require('src.combat.reload').update(g, 0.7)
      end,
    },
    {
      'revolver-closing',
      function(g)
        active(g)
        g.player.weapon = 2
        g.player.arsenal.judge.mag = 0
        g:reloadGun()
        require('src.combat.reload').update(g, 1.5)
      end,
    },
    {
      'boss-and-warning',
      function(g)
        active(g)
        require('src.session.encounter').guardianArrived(g)
        local boss = g:spawn('boss', 16, 22)
        boss.hp = boss.maxHp * 0.4
        g.saveWarning = 'Could not save.'
        g.view.message = 'MARGRAVE OF ASH'
        g.view.messageTimer = 3
      end,
    },
    {
      'furfur-boss-and-charges',
      function(g)
        active(g)
        require('src.session.encounter').guardianArrived(g)
        local boss = g:spawn('furfur', 16, 22)
        boss.hp = boss.maxHp * 0.4
        g.player.abilityState.powder.uses = 1
      end,
    },
    {
      'armored-target-and-hit-marker',
      function(g)
        active(g)
        local target = g:spawn('armored', 16, 24)
        target.hp = target.maxHp * 0.6
        g.view.hitmarker = 0.1
        g.view.armorHit = true
        g.view.hitWeight = 0.5
      end,
    },
    {
      'reload-at-shrine',
      function(g)
        g.player.arsenal.exorcist.mag = 0
        g:reloadGun()
        g.view.message = 'Restock ammo before the next wave begins.'
        g.view.messageTimer = 3
      end,
    },
    {
      'paused-during-reload',
      function(g)
        active(g)
        g:shoot()
        g.state = 'paused'
      end,
    },
    {
      'settings-from-menu',
      function(g)
        g.state = 'settings'
      end,
    },
    {
      'help-during-paused-reload',
      function(g)
        active(g)
        g:shoot()
        g.state = 'paused'
        g.help = true
      end,
    },
    {
      'map-with-echo',
      function(g)
        active(g)
        g.run.echo = { amount = 1000000, x = 7, z = 17 }
        g.map = true
      end,
    },
    {
      'partial-ammunition-purchase',
      function(g)
        Sanctuary.openShop(g)
        g.player.arsenal.exorcist.reserve = 71
        g.player.armor = 99.5
        g.run.wallet = 3
        U.focus = 1
      end,
    },
    {
      'full-ammunition-after-purchase',
      function(g)
        Sanctuary.openShop(g)
        g.player.arsenal.exorcist.reserve = 71
        g.run.wallet = 3
        assert(require('src.run.economy').trade(g, 'ammo'))
        U.focus = 1
      end,
    },
    {
      'owned-engraving-with-large-wallet',
      function(g)
        Sanctuary.openShop(g)
        g.run.wallet = 1000000
        g.run.owned = { choke = true, pierce = true }
        g.run.glyph = 'pierce'
        U.focus = 4
      end,
    },
    {
      'revolver-partial-ammunition-purchase',
      function(g)
        Sanctuary.openShop(g)
        g.player.weapon = 2
        g.player.arsenal.judge.reserve = 71
        g.run.wallet = 3
        U.focus = 1
      end,
    },
    {
      'revolver-full-ammunition-and-charges',
      function(g)
        Sanctuary.openShop(g)
        g.player.weapon = 2
        g.player.arsenal.judge.reserve = 72
        g.player.abilityState.powder.uses = 3
        g.run.wallet = 1000000
        U.focus = 2
      end,
    },
    {
      'charge-purchase-empty-stock',
      function(g)
        Sanctuary.openShop(g)
        g.player.abilityState.powder.uses = 0
        g.run.wallet = 30
        U.focus = 6
      end,
    },
    {
      'death-at-save-limits',
      function(g)
        maxima(g)
        g.state = 'dead'
        g.player.hp = 0
        g.run.echo = { amount = 1000000, x = 16, z = 23 }
        g.saveWarning = 'Could not verify the save.'
      end,
    },
    {
      'new-run-confirmation',
      function(g)
        g.state = 'confirm_new'
      end,
    },
  }
  local Field = require('src.run.test_field')
  for _, entry in ipairs(Field.catalog.enemies) do
    local selected = entry.id
    cases[#cases + 1] = {
      'catalog-' .. selected,
      function()
        local g = Field.new(G)
        g.testField.selected = selected
        return g
      end,
    }
  end
  cases[#cases + 1] = {
    'sandbox-frozen-pose',
    function()
      local g = Field.new(G)
      Field.spawn(g, 'stolas', 1)
      Field.pose(g, 17)
      Field.close(g)
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-death',
    function()
      local g = Field.new(G)
      Field.close(g)
      g.testField.invincible = false
      g:damagePlayer(1000)
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-shop',
    function()
      local g = Field.new(G)
      Field.shop(g)
      g.player.arsenal.exorcist.reserve = 71
      g.run.wallet = 3
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-paused',
    function()
      local g = Field.new(G)
      Field.close(g)
      g.view.fieldReturnLabel = 'return_chapel'
      g.state = 'paused'
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-map',
    function()
      local g = Field.new(G)
      Field.spawn(g, 'imp', 3)
      Field.close(g)
      g.map = true
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-help',
    function()
      local g = Field.new(G)
      g.help = true
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-shot-report-spread',
    function()
      local g = Field.new(G)
      g.view.shotReport = {
        weapon = 1,
        distanceMin = 3.4,
        distanceMax = 27.8,
        pelletsHit = 20,
        headHits = 20,
        pellets = 20,
        targets = 12,
        healthDamage = 180.6,
        blocked = 59.1,
        impact = 240,
        overkill = 180.7,
      }
      return g
    end,
  }
  cases[#cases + 1] = {
    'quick-combat-live',
    function()
      local g = Field.new(G)
      Field.skirmish(g)
      return g
    end,
  }
  cases[#cases + 1] = {
    'quick-combat-retry',
    function()
      local g = Field.new(G)
      Field.skirmish(g)
      g:damagePlayer(1000)
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-shot-report-miss',
    function()
      local g = Field.new(G)
      g.view.shotReport = {
        weapon = 2,
        pelletsHit = 0,
        pellets = 1,
        targets = 0,
        healthDamage = 0,
        blocked = 0,
        impact = 0,
        overkill = 0,
      }
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-hitbox-toggle',
    function()
      local g = Field.new(G)
      g.testField.hitboxes = true
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-furfur-live-context',
    function()
      local g = Field.new(G)
      Field.spawn(g, 'furfur', 1)
      Field.close(g)
      return g
    end,
  }
  cases[#cases + 1] = {
    'sandbox-furfur-group-target',
    function()
      local g = Field.new(G)
      Field.spawn(g, 'furfur', 3)
      Field.close(g)
      return g
    end,
  }
  for index = 1, 6 do
    local selection = index
    cases[#cases + 1] = {
      'historical-archive-' .. selection,
      function()
        local g = Field.new(G)
        Field.action(g, 'field_archive')
        g.testField.archiveSelection = selection
        return g
      end,
    }
  end
  local protected = {}
  for _, state in ipairs({ 'settings', 'paused' }) do
    local screen = state
    cases[#cases + 1] = {
      screen .. '-motion-off',
      function(g)
        g.state = screen
      end,
      settingsOff,
    }
  end
  for name, image in pairs(U.faces) do
    protected[image] = 'bestiary ' .. name
  end
  for name, image in pairs(require('src.ui.goetic_sigils').init().images) do
    protected[image] = 'historical seal ' .. name
  end
  protected[Titles.image] = 'literal heading'
  protected[Numbers.image] = 'illustrated number'
  protected[require('src.ui.occult_plates').init().image] = 'historical source plate'
  local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
  end
  local function inside(a, b)
    return a.x >= b.x - 0.05
      and a.y >= b.y - 0.05
      and a.x + a.w <= b.x + b.w + 0.05
      and a.y + a.h <= b.y + b.h + 0.05
  end
  local function describe(rect)
    return string.format('[%.1f,%.1f %.1fx%.1f]', rect.x, rect.y, rect.w, rect.h)
  end
  -- The status bar is one painted image, so it never calls Skin.panel. These
  -- calibrated writing wells belong to the artwork, independently of UI zones.
  local hudWells = {
    { from = 0, to = 260, x = 133, w = 105 },
    { from = 260, to = 410, x = 271, w = 119 },
    { from = 410, to = 550, x = 421, w = 115 },
    { from = 730, to = 895, x = 752, w = 118 },
    { from = 895, to = 1038, x = 908, w = 113 },
    { from = 1038, to = 1280, x = 1055, w = 100, h = 76 },
  }
  local sceneCount = 0
  local seenStrings = {}
  local imageDraws = 0
  local glyphDraws = 0
  local hudChecked = 0
  local originals = {
    text = Skin.text,
    panel = Skin.panel,
    meter = Skin.meter,
    auditLayer = Skin.auditLayer,
    status = Reliquary.status,
    number = Numbers.draw,
    print = lg.print,
    printf = lg.printf,
    draw = lg.draw,
  }
  local function runScene(name, g, w, h, preferences)
    local layers = { { name = 'base', texts = {}, images = {}, panels = {} } }
    local layer = layers[1]
    Skin.auditLayer = function(label)
      originals.auditLayer(label)
      layer = { name = label, texts = {}, images = {}, panels = {} }
      layers[#layers + 1] = layer
    end
    Reliquary.status = function(...)
      layer.hud = true
      return originals.status(...)
    end
    Skin.panel = function(x, y, pw, ph, style, border)
      local b = border or 14
      if pw >= 500 and ph >= 300 then
        b = math.max(32, b)
      end
      b = math.min(math.max(10, b), math.floor(pw / 3), math.floor(ph / 3))
      layer.panels[#layer.panels + 1] = {
        x = x,
        y = y,
        w = pw,
        h = ph,
        safe = { x = x + b, y = y + b, w = pw - 2 * b, h = ph - 2 * b },
      }
      return originals.panel(x, y, pw, ph, style, border)
    end
    Skin.text = function(t, x, y, font, color)
      t = tostring(t)
      local ink = Skin.inkBounds(font, t)
      local top = Skin.fontTops and Skin.fontTops[font] or 0
      local covered, missing = font:hasGlyphs(t)
      if not covered then
        failures[#failures + 1] = name
          .. string.format(' MISSING PAINTED GLYPH U+%04X: ', missing)
          .. t
      end
      local box = {
        x = math.floor(x) + ink.x,
        y = math.floor(y) - top + ink.y,
        w = ink.w,
        h = ink.h,
        label = t,
        panelsBefore = #layer.panels,
      }
      local panel, area
      for _, p in ipairs(layer.panels) do
        if
          x >= p.x
          and x < p.x + p.w
          and y >= p.y
          and y < p.y + p.h
          and (not area or p.w * p.h < area)
        then
          panel, area = p, p.w * p.h
        end
      end
      box.panel = panel
      layer.texts[#layer.texts + 1] = box
      seenStrings[t] = true
      inspected = inspected + 1
      local before = glyphDraws
      local result = originals.text(t, x, y, font, color)
      if ink.w > 0 and glyphDraws == before then
        failures[#failures + 1] = name .. ' TEXT WAS NOT DRAWN FROM A GLYPH PNG: ' .. t
      end
      return result
    end
    Skin.meter = function(x, y, mw, ...)
      layer.images[#layer.images + 1] =
        { x = x - 1, y = y - 1, w = mw + 2, h = 8, label = 'status meter' }
      return originals.meter(x, y, mw, ...)
    end
    Numbers.draw = function(value, ...)
      seenStrings[tostring(value)] = true
      return originals.number(value, ...)
    end
    lg.draw = function(drawable, ...)
      imageDraws = imageDraws + 1
      if fontImages[drawable] then
        glyphDraws = glyphDraws + 1
      end
      if drawable == Portrait.image or protected[drawable] or drawable == Skin.image then
        local args = { ... }
        local quad = type(args[1]) == 'userdata'
            and args[1].typeOf
            and args[1]:typeOf('Quad')
            and args[1]
          or nil
        local offset = quad and 1 or 0
        local x, y, rotation = args[offset + 1] or 0, args[offset + 2] or 0, args[offset + 3] or 0
        local sx, sy = args[offset + 4] or 1, args[offset + 5] or args[offset + 4] or 1
        local ox, oy = args[offset + 6] or 0, args[offset + 7] or 0
        local qw, qh = drawable:getDimensions()
        if quad then
          local _, _, a, b = quad:getViewport()
          qw, qh = a, b
        end
        if drawable == Portrait.image then
          -- Its real shader clips the full source quad into an arched HUD window.
          local b = Portrait.bounds
          assert(b, 'portrait must expose its clipping window')
          layer.images[#layer.images + 1] =
            { x = b.x, y = b.y, w = b.w, h = b.h, label = 'portrait window' }
        elseif rotation == 0 then
          layer.images[#layer.images + 1] = {
            x = x - ox * sx,
            y = y - oy * sy,
            w = qw * sx,
            h = qh * sy,
            label = protected[drawable] or 'HUD icon',
          }
        end
      end
      return originals.draw(drawable, ...)
    end
    lg.print = function()
      error('UI attempted runtime font print')
    end
    lg.printf = function()
      error('UI attempted runtime font printf')
    end
    local target = lg.newCanvas(w, h)
    lg.push('all')
    lg.setCanvas(target)
    lg.clear(0, 0, 0, 1)
    lg.origin()
    U.useMouse = false
    U.screen = g.help and 'help' or (g.map and 'map' or g.state)
    local ok, err = pcall(U.draw, g, w, h, preferences or settings)
    lg.pop()
    local settingsPreview = name == 'settings-from-menu' or name == 'settings-motion-off'
    if
      ok
      and ((w == 960 and preview[name]) or settingsPreview)
      and os.getenv('SIGIL_UI_PREVIEW') == '1'
    then
      local data = target:newImageData()
      local suffix = settingsPreview and ('-' .. w .. 'x' .. h) or ''
      local file = assert(io.open(output .. '/audit-' .. name .. suffix .. '.png', 'wb'))
      file:write(data:encode('png'):getString())
      file:close()
      data:release()
    end
    target:release()
    Skin.text, Skin.panel, Skin.meter, Skin.auditLayer =
      originals.text, originals.panel, originals.meter, originals.auditLayer
    lg.print, lg.printf, lg.draw = originals.print, originals.printf, originals.draw
    Reliquary.status = originals.status
    Numbers.draw = originals.number
    if not ok then
      failures[#failures + 1] = name .. ' ' .. w .. 'x' .. h .. ' RENDER ERROR ' .. tostring(err)
      return
    end
    for _, l in ipairs(layers) do
      local function inspectHud(box, prefix)
        if not l.hud or box.label == 'portrait window' or box.y + box.h / 2 < 620 then
          return
        end
        local cx = box.x + box.w / 2
        for _, well in ipairs(hudWells) do
          if cx >= well.from and cx < well.to then
            hudChecked = hudChecked + 1
            local safe = { x = well.x, y = 628, w = well.w, h = well.h or 68 }
            if not inside(box, safe) then
              failures[#failures + 1] = prefix
                .. ' ON PAINTED HUD BORDER '
                .. describe(box)
                .. ' safe '
                .. describe(safe)
            end
            return
          end
        end
      end
      for i, picture in ipairs(l.images) do
        local prefix = name .. ' ' .. w .. 'x' .. h .. ' ' .. l.name .. ': ' .. picture.label
        inspectHud(picture, prefix)
        if not inside(picture, { x = 0, y = 0, w = 1280, h = 720 }) then
          failures[#failures + 1] = prefix .. ' OUTSIDE VIEWPORT ' .. describe(picture)
        end
        for j = 1, i - 1 do
          if overlap(picture, l.images[j]) then
            failures[#failures + 1] = prefix .. ' IMAGE COLLISION / ' .. l.images[j].label
          end
        end
      end
      for i, t in ipairs(l.texts) do
        local prefix = name .. ' ' .. w .. 'x' .. h .. ' ' .. l.name .. ': ' .. t.label
        inspectHud(t, prefix)
        if not inside(t, { x = 0, y = 0, w = 1280, h = 720 }) then
          failures[#failures + 1] = prefix .. ' OUTSIDE VIEWPORT ' .. describe(t)
        end
        if t.y < 100 and t.label:match('^%d+:%d+$') and t.x + t.w > 1254 then
          failures[#failures + 1] = prefix .. ' CLOCK TOUCHES OUTER FRESCO FRAME ' .. describe(t)
        end
        if t.panel and not inside(t, t.panel.safe) then
          failures[#failures + 1] = prefix
            .. ' ON FRAME BORDER '
            .. describe(t)
            .. ' safe '
            .. describe(t.panel.safe)
        end
        -- A control's plaster can cover a preceding label even when their
        -- letters do not touch. Backgrounds already drawn remain legitimate.
        for j = t.panelsBefore + 1, #l.panels do
          if overlap(t, l.panels[j]) then
            failures[#failures + 1] = prefix .. ' COVERED BY LATER PANEL ' .. describe(l.panels[j])
          end
        end
        for j = 1, i - 1 do
          if overlap(t, l.texts[j]) then
            failures[#failures + 1] = prefix .. ' TEXT COLLISION / ' .. l.texts[j].label
          end
        end
        for _, picture in ipairs(l.images) do
          imagesChecked = imagesChecked + 1
          if overlap(t, picture) then
            failures[#failures + 1] = prefix .. ' IMAGE COLLISION / ' .. picture.label
          end
        end
      end
    end
    sceneCount = sceneCount + 1
  end
  for _, case in ipairs(cases) do
    for _, size in ipairs({
      { 960, 540 },
      { 1280, 720 },
      { 1024, 768 },
      { 1720, 720 },
      { 1920, 1080 },
    }) do
      local g = fresh()
      g = case[2](g) or g
      runScene(case[1], g, size[1], size[2], case[3])
    end
  end
  -- Read actual canvas pixels outside the logical page. This catches the
  -- bright-world strips that were invisible to logical-rectangle audits.
  for _, v in ipairs({
    { name = 'wide shop', w = 1720, h = 720, x = 12, y = 360, modal = true, state = 'shop' },
    { name = 'tall help', w = 1024, h = 768, x = 512, y = 12, modal = true, help = true },
    { name = 'wide pause', w = 1720, h = 720, x = 1708, y = 360, modal = true, state = 'paused' },
    {
      name = 'wide live field',
      w = 1720,
      h = 720,
      x = 12,
      y = 360,
      modal = false,
      state = 'playing',
    },
  }) do
    local g = fresh()
    g.state = v.state or 'playing'
    g.help = v.help
    local target = lg.newCanvas(v.w, v.h)
    lg.push('all')
    lg.setCanvas(target)
    lg.origin()
    lg.setShader()
    lg.setScissor()
    lg.clear(0.2, 0.8, 0.1, 1)
    U.draw(g, v.w, v.h, settings)
    lg.pop()
    local pixels = target:newImageData()
    local r, gc, b, a = pixels:getPixel(v.x, v.y)
    check(
      v.name .. ' has correct physical viewport gutter coverage',
      v.modal and r < 0.04 and gc < 0.04 and b < 0.04 and a > 0.99
        or not v.modal and gc > 0.75 and r > 0.15 and r < 0.25
    )
    pixels:release()
    target:release()
  end
  local file = assert(io.open(output .. '/bitmap-ui-audit.txt', 'w'))
  file:write(
    'BITMAP UI INDEPENDENT RENDER AUDIT\n'
      .. sceneCount
      .. ' scenes; '
      .. inspected
      .. ' text bounds; '
      .. imagesChecked
      .. ' protected image comparisons; '
      .. hudChecked
      .. ' painted HUD interior checks; '
      .. #failures
      .. ' issues.\n'
  )
  for _, failure in ipairs(failures) do
    file:write(failure .. '\n')
  end
  file:close()
  local corpus = {}
  for value in pairs(seenStrings) do
    corpus[#corpus + 1] = value
  end
  table.sort(corpus)
  local corpusFile = assert(io.open(output .. '/gui-string-corpus.txt', 'w'))
  corpusFile:write(table.concat(corpus, '\n') .. '\n')
  corpusFile:close()
  check(
    'all ' .. #cases .. ' UI edge cases render at five sizes exclusively with bitmap draws',
    sceneCount == #cases * 5 and imageDraws > 0
  )
  check(
    'rendered text stays off frame borders, protected character images and other labels',
    #failures == 0
  )
  check(
    'painted HUD writing wells contain actual glyphs, illustrated numbers and status meters',
    hudChecked > sceneCount * 3 and #failures == 0
  )
  check(
    'partial purchase displays the exact one-round price and full-stock state',
    seenStrings['3 SOULS'] and seenStrings['RESERVE FULL']
  )
  check(
    'large wallet and separately captioned echo remain visible without corrupting exact values',
    seenStrings['1000000'] and seenStrings['ECHO']
  )
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests

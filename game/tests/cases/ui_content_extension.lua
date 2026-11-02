-- More content, long Polish captions and changing values must stay inside
-- painted interiors. All fixtures reuse production pigment and bitmap glyphs.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local Text = require('src.content.text')
  local Fit = require('src.ui.text_fit')
  local Help = require('src.ui.screens.help')
  local Descent = require('src.ui.chapel')
  local UI = require('src.ui.interface')
  local Skin = require('src.ui.skin')
  local Enemies = require('src.content.enemies')
  local Shop = require('src.content.shop')
  local Weapons = require('src.content.weapons')
  local Schema = require('src.core.schema')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local Application = require('src.app.application')
  local utf8 = require('utf8')
  local lg = love.graphics
  local lines = {}
  local check = Fixtures.checker(lines, 'UI content extension: ', 'UI content extension: ')
  local creatureCount, offerCount = #Enemies.creatures, #Shop.offers
  local saved = {
    audit = Skin.audit,
    fields = Skin.fields,
    force = Skin.forceAudit,
    finish = Skin.endAudit,
    focus = UI.focus,
    screen = UI.screen,
    useMouse = UI.useMouse,
  }
  local ids, guns = {}, {}
  local ok, problem = xpcall(function()
    Text.register('trial_polish', 'Żelazny {name}: {count} / ĄĆĘŁŃÓŚŹŻ')
    local phrase = Text.get('trial_polish', { name = 'rycerz', count = 1234567 })
    check(
      'named parameters retain exact Polish glyph content',
      phrase == 'Żelazny rycerz: 1234567 / ĄĆĘŁŃÓŚŹŻ'
    )
    check('unknown text key fails clearly', not pcall(Text.get, 'trial_missing'))
    check(
      'missing parameter cannot leak a placeholder to the player',
      not pcall(Text.get, 'trial_polish', { count = 1 })
    )
    check(
      'non-finite parameter cannot produce a broken counter',
      not pcall(Text.get, 'trial_polish', { name = 'x', count = math.huge })
    )
    check(
      'malformed template is rejected atomically',
      not pcall(Text.register, 'trial_invalid', 'Błąd {count')
    )
    local font = UI.fonts[14]
    check('all text remains assembled from painted Polish glyphs', font:hasGlyphs(phrase))
    local long = phrase .. ' ' .. phrase .. ' ' .. phrase
    local clipped = Fit.ellipsis(font, long, 180)
    check(
      'long text uses an explicit UTF-8 safe continuation mark within painted width',
      utf8.len(clipped) ~= nil and clipped:sub(-3) == '...' and font:getInk(clipped).w <= 180
    )
    for counter = 1, 1000 do
      font:getInk(Text.get('trial_polish', { name = 'rycerz', count = counter }))
    end
    check('changing counters retain a bounded bitmap measurement cache', #font.inkCacheKeys <= 256)
    local original = G.new('floor')
    -- The rules page comes before the bestiary (audit L04): back, and the two page turns.
    check('production help has its back button and two page turns', #Help.controls(original) == 3)
    for index = 1, 5 do
      local id = 'trial_caption_' .. index
      local def = Schema.copy(Enemies.imp)
      Fixtures.words({
        [id] = 'STRAŻNIK ŻELAZNYCH WRÓT I ZAPOMNIANYCH PRZYSIĄG ' .. index,
        trial_caption_text = 'Próbuje zamknąć wszystkie drogi ucieczki; śledź jego ramiona i odległość.',
        trial_caption_tip = 'Zachowaj nabój na przerwanie zamachu i odejdź w stronę wolnej przestrzeni.',
      })
      def.id, def.name = id, id
      def.catalog.bestiary = {
        order = 4 + index,
        color = 'red',
        text = 'trial_caption_text',
        tip = 'trial_caption_tip',
      }
      def.catalog.field = nil
      Enemies[id], Enemies.creatures[#Enemies.creatures + 1], ids[#ids + 1] = def, id, id
    end
    for index = 1, 7 do
      local offer = Schema.copy(Shop.offers[3])
      local id = 'trial_offer_' .. index
      Fixtures.words({
        [id] = 'PRZYWRÓCENIE OCHRONY STRAŻNIKA ŻELAZNEJ BRAMY ' .. index,
        trial_offer_description = 'Uzupełnia ochronę przed kolejnym ciosem; koszt dotyczy wyłącznie brakującej części osłony.',
      })
      offer.id, offer.name, offer.description = id, id, 'trial_offer_description'
      Shop.offers[#Shop.offers + 1] = offer
    end
    for index = 1, 5 do
      local id = 'trial_label_gun_' .. index
      Fixtures.words({
        [id] = 'SĘDZIA ZAPOMNIANYCH ŚLUBÓW ' .. index,
        [id .. '_tab'] = 'ŻELAZNY REWOLWER STRAŻNIKA ' .. index,
      })
      Weapons.define({
        extends = Weapons.get('judge'),
        id = id,
        name = id,
        hud = { tab = id .. '_tab' },
      })
      guns[#guns + 1] = id
    end
    Snapshot.invalidateDefinitions()
    local g = Fixtures.started(G)
    local app = Application.new()
    app:adopt(g)
    app:action('help')
    app.input:keypressed(app, 'tab')
    app.input:keypressed(app, 'tab')
    app.input:keypressed(app, 'return')
    check(
      'real keyboard navigation reaches the next bestiary page',
      g.help and g.view.helpPage == 2
    )
    local controls = Help.controls(g)
    local prev = controls[2]
    local scale, ox, oy = UI.viewport(lg.getDimensions())
    app.input:mousepressed(
      app,
      ox + (prev.x + prev.w / 2) * scale,
      oy + (prev.y + prev.h / 2) * scale,
      1
    )
    check('real mouse navigation reaches the previous page', g.view.helpPage == 1)
    app:action('help_next')
    app.input:keypressed(app, 'escape')
    check(
      'leaving help resets the page and closes the overlay',
      not g.help and g.view.helpPage == 1
    )
    app:action('help')
    Help.turn(g, 99)
    local _, first, last, page, pages = Help.page(g)
    check(
      'all nine bestiary entries remain reachable in bounded pages, after the rules page',
      first == 9 and last == 9 and page == 6 and pages == 6
    )
    local function capture(name, width, height)
      local canvas = lg.newCanvas(width, height)
      local before = Integrity.capture(g)
      local issues
      Skin.forceAudit = true
      Skin.endAudit = function()
        -- The extension's names are made longer than any niche on purpose, so they are cut
        -- with an ellipsis; the game's own text may never be (the showcase holds it to that).
        issues = {}
        for _, issue in ipairs((Skin.auditProblems(Skin.audit))) do
          if not issue:match('^ELIDED') then
            issues[#issues + 1] = issue
          end
        end
        if name == 'bestiary' then
          -- Nonintersection alone is insufficient: adjacent painted capitals
          -- with zero breathing room read as a fused block after downscaling.
          local previous
          for _, item in ipairs(Skin.audit.items) do
            if item.kind == 'text' and item.label:find('STRAŻNIK ŻELAZNYCH', 1, true) then
              previous = item
            elseif previous and item.kind == 'text' then
              check(
                'wrapped title retains a visible ink gap at ' .. width .. 'x' .. height,
                item.y - (previous.y + previous.h) >= 4
              )
              previous = nil
            end
          end
        end
        Skin.audit = nil
      end
      UI.useMouse = false
      lg.push('all')
      lg.setCanvas(canvas)
      lg.origin()
      lg.clear(0.015, 0.013, 0.017, 1)
      UI.draw(g, width, height, app.settings)
      lg.pop()
      check(
        name .. ' has no ink overlap or ornament overflow at ' .. width .. 'x' .. height,
        #issues == 0 or error(table.concat(issues, '\n'))
      )
      check(
        name .. ' drawing leaves authoritative state untouched',
        not Integrity.difference(before, Integrity.capture(g))
      )
      local data = canvas:newImageData()
      local file = data:encode('png')
      local target = assert(
        io.open(
          require('qa.output').path(
            'content-ui-' .. name .. '-' .. width .. 'x' .. height .. '.png'
          ),
          'wb'
        )
      )
      target:write(file:getString())
      target:close()
      file:release()
      data:release()
      canvas:release()
    end
    for _, dimensions in ipairs({
      { 960, 540 },
      { 1280, 720 },
      { 1024, 768 },
      { 1920, 1080 },
      { 1920, 810 },
    }) do
      g.help, g.state = true, 'paused'
      g.view.helpPage = 4
      capture('bestiary', dimensions[1], dimensions[2])
      g.help, g.state = false, 'shop'
      Descent.turnShop(g, 99)
      local a, b, current, total = Descent.shopPage(g)
      check(
        'extra shop offers remain reachable on page four',
        a == 13 and b == 13 and current == 4 and total == 4
      )
      Descent.turnShop(g, -1)
      capture('shop', dimensions[1], dimensions[2])
    end
    g.state, g.help, g.view.messageTimer = 'playing', false, 0
    for _, id in ipairs(guns) do
      g.player.weapon = Weapons.give(g, id)
    end
    for _, dimensions in ipairs({
      { 960, 540 },
      { 1280, 720 },
      { 1024, 768 },
      { 1920, 1080 },
      { 1920, 810 },
    }) do
      capture('arsenal', dimensions[1], dimensions[2])
    end
  end, debug.traceback)
  Skin.audit, Skin.fields, Skin.forceAudit, Skin.endAudit =
    saved.audit, saved.fields, saved.force, saved.finish
  UI.focus, UI.screen, UI.useMouse = saved.focus, saved.screen, saved.useMouse
  for _, id in ipairs(ids) do
    Enemies[id] = nil
  end
  while #Enemies.creatures > creatureCount do
    table.remove(Enemies.creatures)
  end
  while #Shop.offers > offerCount do
    table.remove(Shop.offers)
  end
  for _, id in ipairs(guns) do
    Weapons.registry:unregister(id)
  end
  Text.unregister('trial_polish')
  Text.unregister('trial_invalid')
  Snapshot.invalidateDefinitions()
  assert(ok, problem)
  return lines
end
return Tests

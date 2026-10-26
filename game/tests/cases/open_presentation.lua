-- Plan v10 V6, the open presentation: a new kind of world object is drawn by
-- its registration alone; the HUD lists four weapons and three equipment
-- slots inside its painted wells; switching the text table's language
-- changes every text the player reads, with no code change, and painted
-- inscriptions fall back to glyphs in a language without its own paintings.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
-- A pseudo language marks every template with a letter the painted glyphs
-- have; a lettered string drawn without it did not come from the table.
local MARK = 'Ż'
local function source(path)
  return (love.filesystem.read(path):gsub('%-%-[^\n]*', ''))
end
-- A new kind of world object: registered, drawn in its pass, never named
-- by the renderer.
local function worldObjects(G, renderer, check)
  local WorldObjects = require('src.render.world_objects')
  local WorldArt = require('src.render.world_art')
  -- (ember is also a pigment of the palette: the Ember is named by its shrine)
  local names = { 'seal', 'shrine', 'pickup', 'supplies', 'gallery', 'mural', 'echo', 'lamp' }
  local named = {}
  local files = { 'src/render/renderer.lua' }
  for _, file in ipairs(love.filesystem.getDirectoryItems('src/render/passes')) do
    files[#files + 1] = 'src/render/passes/' .. file
  end
  for _, file in ipairs(files) do
    local code = source(file):lower()
    for _, name in ipairs(names) do
      if code:find('%f[%w_]' .. name) then
        named[#named + 1] = file .. ': ' .. name
      end
    end
  end
  check(
    'the renderer and its passes name no kind of world object ' .. table.concat(named, ', '),
    #named == 0 and #files > 8
  )
  local g = Fixtures.arena(G)
  g.state = 'playing'
  renderer:draw(g, 1280, 720)
  local before = renderer.canvas:newImageData()
  local camera, forward = renderer.camera, renderer.forward
  local spot = { x = camera[1] + forward[1] * 4, z = camera[3] + forward[3] * 4 }
  local drawn = 0
  WorldObjects.register('trial_obelisk', {
    {
      pass = 'sprites',
      order = 45,
      draw = function(r, game)
        drawn = drawn + 1
        WorldArt.prop(r, game, 5, spot.x, 0, spot.z, 1.6, 0.9)
      end,
    },
  })
  local ok, problem = pcall(function()
    renderer:draw(g, 1280, 720)
  end)
  local after = ok and renderer.canvas:newImageData()
  WorldObjects.unregister('trial_obelisk')
  assert(ok, problem)
  local changed = 0
  local w, h = before:getDimensions()
  for y = 0, h - 1, 2 do
    for x = 0, w - 1, 2 do
      local r1, g1, b1 = before:getPixel(x, y)
      local r2, g2, b2 = after:getPixel(x, y)
      if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) > 0.02 then
        changed = changed + 1
      end
    end
  end
  before:release()
  after:release()
  check(
    'a new world object kind is drawn by its registration alone (' .. changed .. ' samples)',
    drawn == 1 and changed > 50
  )
  check('an unregistered kind leaves the frame', not WorldObjects.has('trial_obelisk'))
end
-- Audit a screen at five sizes: no ink overlap, no ornament overflow.
local function audit(g, name, check)
  local U = require('src.ui.interface')
  local Skin = require('src.ui.skin')
  local lg = love.graphics
  local saved = { Skin.audit, Skin.fields, Skin.forceAudit, Skin.endAudit, U.useMouse, U.screen }
  for _, size in ipairs({
    { 960, 540 },
    { 1280, 720 },
    { 1024, 768 },
    { 1720, 720 },
    { 1920, 1080 },
  }) do
    local issues
    Skin.forceAudit = true
    Skin.endAudit = function()
      issues = Skin.auditProblems(Skin.audit)
      Skin.audit = nil
    end
    U.useMouse, U.screen = false, g.state
    local canvas = lg.newCanvas(size[1], size[2])
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    lg.clear(0, 0, 0, 1)
    local ok, problem = pcall(U.draw, g, size[1], size[2], {
      sensitivity = 1,
      motion = true,
      music = 1,
      fov = 100,
      hints = false,
      muted = true,
    })
    lg.pop()
    local data = canvas:newImageData()
    local file = assert(
      io.open(require('qa.output').path(name .. '-' .. size[1] .. 'x' .. size[2] .. '.png'), 'wb')
    )
    file:write(data:encode('png'):getString())
    file:close()
    data:release()
    canvas:release()
    check(
      name
        .. ' at '
        .. size[1]
        .. 'x'
        .. size[2]
        .. ' has no layout problem '
        .. (ok and table.concat(issues or { 'not audited' }, '; ') or tostring(problem)),
      ok and issues and #issues == 0
    )
  end
  Skin.audit, Skin.fields, Skin.forceAudit, Skin.endAudit = saved[1], saved[2], saved[3], saved[4]
  U.useMouse, U.screen = saved[5], saved[6]
end
-- Four weapons and three equipment slots: every slot readable in its well.
local function hudSlots(G, check)
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local Schema = require('src.core.schema')
  local Snapshot = require('src.session.snapshot')
  local Slots = require('src.ui.hud_slots')
  local Text = require('src.content.text')
  local weapons, equipment = { 'trial_lance', 'trial_mortar' }, { 'trial_ash', 'trial_bell' }
  Fixtures.words({
    trial_lance = 'LANCE',
    trial_lance_tab = 'LANCE',
    trial_mortar = 'MORTAR',
    trial_mortar_tab = 'MORTAR',
    trial_ash = 'ASH POT',
    trial_ash_tag = 'ASH',
    trial_bell = 'BELL',
    trial_bell_tag = 'BELL',
  })
  local ok, problem = pcall(function()
    for _, id in ipairs(weapons) do
      Weapons.define({
        extends = Weapons.get('judge'),
        id = id,
        name = id,
        hud = { tab = id .. '_tab' },
      })
    end
    for _, id in ipairs(equipment) do
      local item = Schema.copy(Abilities:get('powder'))
      item.id, item.name, item.tag, item.action.id = id, id, id .. '_tag', id
      Abilities.define(item)
    end
    Snapshot.invalidateDefinitions()
    local g = Fixtures.expedition(G)
    require('src.run.descent').ready(g)
    g.run.phase, g.state, g.view.messageTimer, g.zoneTimer = 'wave', 'playing', 0, 0
    for _, id in ipairs(weapons) do
      g.weapon = Weapons.give(g, id)
    end
    for _, id in ipairs(equipment) do
      Abilities.give(g, id)
    end
    local shown, count = Slots.weapons(g, 2)
    local kit = Slots.equipment(g)
    check(
      'the arsenal lists four weapons, the one in hand among those shown',
      count == 4 and #shown == 2 and shown[2].selected and shown[2].slot == 4
    )
    check(
      'the equipment lists the three keyed slots Q, F and C',
      #kit == 3
        and kit[1].key == 'Q'
        and kit[2].key == 'F'
        and kit[3].key == 'C'
        and Text.get(kit[3].def.tag) == 'BELL'
    )
    audit(g, 'hud-slots-4-weapons-3-equipment', check)
    g.weapon = 2
    audit(g, 'hud-slots-second-weapon', check)
  end)
  for _, id in ipairs(weapons) do
    Weapons.registry:unregister(id)
  end
  for _, id in ipairs(equipment) do
    Abilities:unregister(id)
  end
  Snapshot.invalidateDefinitions()
  assert(ok, problem)
end
-- Every lettered string drawn on the screens below carries the mark.
local function language(G, renderer, check)
  local Text = require('src.content.text')
  local U = require('src.ui.interface')
  local Skin = require('src.ui.skin')
  local Run = require('src.run.descent')
  local Field = require('src.run.test_field')
  local Loading = require('src.ui.loading')
  local Titles = require('src.ui.fonts.painted_titles').init()
  local lg = love.graphics
  local pseudo = {}
  for id, entry in Text.each() do
    pseudo[id] = MARK .. entry.template
  end
  Text.language('pseudo', pseudo)
  local unmarked, seen, titles, corpus = {}, 0, 0, {}
  local function note(t)
    t = tostring(t)
    if t:find('%a') then
      seen = seen + 1
      corpus[t] = true
      if not t:find(MARK, 1, true) then
        unmarked[t] = true
      end
    end
  end
  local originals = { text = Skin.text, draw = lg.draw }
  local labelFont = U.fonts[14]
  local fontDraw = rawget(labelFont, 'draw')
  local settings =
    { sensitivity = 1, motion = true, music = 1, fov = 100, hints = true, muted = true }
  local function screen(g)
    U.useMouse, U.screen = false, g.help and 'help' or (g.map and 'map' or g.state)
    local canvas = lg.newCanvas(1280, 720)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    local ok, problem = pcall(U.draw, g, 1280, 720, settings)
    lg.pop()
    canvas:release()
    assert(ok, problem)
  end
  local function expedition()
    local g = G.new('descent')
    g.testing = true
    g:start()
    return g
  end
  local scenes = {
    menu = function()
      local g = expedition()
      g.state = 'menu'
      return g
    end,
    settings = function()
      local g = expedition()
      g.state = 'settings'
      return g
    end,
    confirm = function()
      local g = expedition()
      g.state = 'confirm_new'
      return g
    end,
    preparing = function()
      return expedition()
    end,
    wave = function()
      local g = expedition()
      Run.ready(g)
      g.run.phase = 'wave'
      g.elapsed = 1
      local e = g:spawn('armored', g.player.x, g.player.z - 4)
      e.hp = e.maxHp * 0.5
      return g
    end,
    guardian = function()
      local g = expedition()
      g.run.phase, g.run.wave, g.bossSpawned = 'wave', 5, true
      local boss = g:spawn('boss', 16, 22)
      boss.hp = boss.maxHp * 0.4
      return g
    end,
    reload = function()
      local g = expedition()
      g.run.phase = 'wave'
      g.weapon = 2
      g.player.arsenal.judge.mag = 0
      g:reloadGun()
      require('src.combat.reload').update(g, 0.7)
      return g
    end,
    empty = function()
      local g = expedition()
      g.run.phase = 'wave'
      for _, state in pairs(g.player.arsenal) do
        state.mag, state.reserve = 0, 0
      end
      g.player.hp = 10
      return g
    end,
    paused = function()
      local g = expedition()
      g.state = 'paused'
      return g
    end,
    help = function()
      local g = expedition()
      g.state, g.help = 'paused', true
      return g
    end,
    map = function()
      local g = expedition()
      g.run.echo = { amount = 10, x = 7, z = 17, wave = 1 }
      g.map = true
      return g
    end,
    shop = function()
      local g = expedition()
      Run.openShop(g)
      return g
    end,
    dead = function()
      local g = expedition()
      g.state, g.player.hp, g.run.phase = 'dead', 0, 'defeated'
      g.run.echo = { amount = 10, x = 16, z = 23, wave = 1 }
      return g
    end,
    won = function()
      local g = expedition()
      g.state, g.run.phase, g.run.fragment, g.run.wave = 'won', 'complete', true, 5
      return g
    end,
    classic = function()
      local g = Fixtures.arena(G)
      g.state = 'playing'
      return g
    end,
    classicDead = function()
      local g = Fixtures.arena(G)
      g.state, g.player.hp = 'dead', 0
      return g
    end,
    classicWon = function()
      local g = Fixtures.arena(G)
      g.state = 'won'
      return g
    end,
    catalogue = function()
      return Field.new(G)
    end,
    range = function()
      local g = Field.new(G)
      Field.range(g)
      Field.close(g)
      return g
    end,
    physics = function()
      local g = Field.new(G)
      Field.physics(g)
      Field.close(g)
      return g
    end,
    trial = function()
      local g = Field.new(G)
      Field.waves(g)
      Field.close(g)
      return g
    end,
    fieldShop = function()
      local g = Field.new(G)
      Field.shop(g)
      return g
    end,
    fieldPaused = function()
      local g = Field.new(G)
      Field.close(g)
      g.state = 'paused'
      return g
    end,
    fieldMap = function()
      local g = Field.new(G)
      Field.spawn(g, 'imp', 3)
      Field.close(g)
      g.map = true
      return g
    end,
    fieldHelp = function()
      local g = Field.new(G)
      g.help = true
      return g
    end,
    fieldDeath = function()
      local g = Field.new(G)
      Field.close(g)
      g.testField.invincible = false
      g:damagePlayer(1000)
      return g
    end,
    skirmish = function()
      local g = Field.new(G)
      Field.skirmish(g)
      return g
    end,
    report = function()
      local g = Field.new(G)
      g.view.shotReport = {
        weapon = 1,
        distanceMin = 3.4,
        distanceMax = 27.8,
        pelletsHit = 20,
        headHits = 2,
        pellets = 20,
        targets = 3,
        healthDamage = 180.6,
        blocked = 59.1,
        impact = 240,
        overkill = 18,
      }
      return g
    end,
    archive = function()
      local g = Field.new(G)
      Field.action(g, 'field_archive')
      Field.action(g, 'archive_4')
      return g
    end,
  }
  local order = {}
  for name in pairs(scenes) do
    order[#order + 1] = name
  end
  table.sort(order)
  local ok, problem = pcall(function()
    Text.use('pseudo')
    check(
      'the pseudo language is the active one',
      Text.active() == 'pseudo' and not Text.paintings()
    )
    Skin.text = function(t, ...)
      note(t)
      return originals.text(t, ...)
    end
    labelFont.draw = function(self, t, ...)
      note(t)
      return (fontDraw or getmetatable(self).__index.draw)(self, t, ...)
    end
    lg.draw = function(drawable, ...)
      if drawable == Titles.image then
        titles = titles + 1
      end
      return originals.draw(drawable, ...)
    end
    for _, name in ipairs(order) do
      local made, g = pcall(scenes[name])
      assert(made, name .. ': ' .. tostring(g))
      local drawn, why = pcall(screen, g)
      assert(drawn, name .. ': ' .. tostring(why))
    end
    -- The gallery's name plates over the world.
    local g = Field.new(G)
    Field.close(g)
    local pad = require('src.world.gallery').pads[1]
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = pad.x, pad.z + 1.6, math.pi, -0.2
    renderer:draw(g, 1280, 720)
    -- The loading screen and its failure.
    lg.push('all')
    Loading.draw(U, 3, 10, 1280, 720, nil, 'loading_world', true)
    Loading.draw(U, 3, 10, 1280, 720, 'failed', nil, false)
    lg.pop()
  end)
  Skin.text, lg.draw = originals.text, originals.draw
  labelFont.draw = fontDraw
  Text.use(Text.base)
  assert(ok, problem)
  -- The strings read in the pseudo language, for the GUI audit.
  local lettered = {}
  for t in pairs(corpus) do
    lettered[#lettered + 1] = t
  end
  table.sort(lettered)
  local file = assert(io.open(require('qa.output').path('language-switch-corpus.txt'), 'wb'))
  file:write(table.concat(lettered, '\n') .. '\n')
  file:close()
  local list = {}
  for t in pairs(unmarked) do
    list[#list + 1] = t
  end
  table.sort(list)
  check(
    'switching the language changes every text on '
      .. #order
      .. ' screens ('
      .. seen
      .. ' strings) '
      .. table.concat(list, ' | '),
    seen > 500 and #list == 0
  )
  check('painted inscriptions fall back to glyphs without their paintings', titles == 0)
  -- Every painting the registry names is in the atlas; an inscription
  -- without one is written in glyphs, in any language.
  local missing = {}
  for _, name in ipairs(Titles.names) do
    if not Titles.has(name) then
      missing[#missing + 1] = name
    end
  end
  check(
    'every registered painted inscription is in the atlas ' .. table.concat(missing, ', '),
    #missing == 0
  )
  Fixtures.words({ inscription_trial_banner = 'TRIAL BANNER' })
  local written, painted = {}, 0
  Skin.text = function(t, ...)
    written[#written + 1] = t
    return originals.text(t, ...)
  end
  lg.draw = function(drawable, ...)
    if drawable == Titles.image then
      painted = painted + 1
    end
    return originals.draw(drawable, ...)
  end
  local canvas = lg.newCanvas(640, 200)
  lg.push('all')
  lg.setCanvas(canvas)
  local drew, why = pcall(Skin.inscription, 'trial_banner', 20, 20, 600, 120)
  lg.pop()
  canvas:release()
  Skin.text, lg.draw = originals.text, originals.draw
  check(
    'an inscription without a painting is written in glyphs ' .. (drew and '' or tostring(why)),
    drew and painted == 0 and written[1] == 'TRIAL BANNER'
  )
  check('the base language returns', Text.get('health') == 'HEALTH')
end
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'open presentation: ', 'open presentation: ')
  worldObjects(G, renderer, check)
  hudSlots(G, check)
  language(G, renderer, check)
  return lines
end
return Tests

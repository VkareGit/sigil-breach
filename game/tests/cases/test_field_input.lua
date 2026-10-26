-- Runs only under the isolated --input-test identity, using real callbacks.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(get, settings)
  local U = require('src.ui.interface')
  local Run = require('src.run.descent')
  local Save = require('src.storage.run_save')
  local lines = {}
  local check = Fixtures.checker(lines, 'sandbox controller ', '')
  local function draw()
    local w, h = love.graphics.getDimensions()
    U.draw(get(), w, h, settings)
  end
  local function key(k)
    love.keypressed(k, k)
    draw()
  end
  local function click(id)
    local w, h = love.graphics.getDimensions()
    local scale, ox, oy = U.viewport(w, h)
    for _, b in ipairs(U.controls(get(), settings)) do
      if b.id == id then
        love.mousepressed(ox + (b.x + b.w / 2) * scale, oy + (b.y + b.h / 2) * scale, 1)
        draw()
        return
      end
    end
    error('missing sandbox controller button: ' .. id)
  end
  local function files()
    local names = {
      [Save.prefix .. '.a'] = true,
      [Save.prefix .. '.b'] = true,
      ['best-score-v03.txt'] = true,
      ['best-score.txt'] = true,
      ['settings-v03.txt'] = true,
      ['settings.txt'] = true,
    }
    for _, name in ipairs(love.filesystem.getDirectoryItems('')) do
      if
        name:match('profile')
        or name:match('^best%-score')
        or name:match('^descent')
        or name:match('^settings')
      then
        names[name] = true
      end
    end
    local result = {}
    for name in pairs(names) do
      result[name] = love.filesystem.read(name) or false
    end
    return result
  end
  local function sameFiles(a, b)
    for name, bytes in pairs(a) do
      if b[name] ~= bytes then
        return false
      end
    end
    for name, bytes in pairs(b) do
      if a[name] ~= bytes then
        return false
      end
    end
    return true
  end
  -- A catalogue summons opens portals; play on until every demon stepped out.
  local function arrive(field)
    for _ = 1, 600 do
      if #field.run.pending == 0 then
        break
      end
      love.update(1 / 120)
    end
    draw()
  end
  local original = get()
  local snapshot = Save.encode(Run.snapshot(original), 1)
  local originalBoss = require('src.session.encounter').guardianDead(original)
  local before = files()
  key('f2')
  local field = get()
  field.testing = false
  check(
    'F2 enters an independent sandbox without replacing the suspended expedition',
    field ~= original
      and field.testField
      and field.state == 'field_catalog'
      and field.run ~= original.run
  )
  click('field_spawn_imp_3')
  local opened = #field.run.pending == 3 and #field.enemies == 0
  arrive(field)
  check(
    'a scaled catalog click opens three portals, resumes free combat, and three live demons step out',
    opened
      and get() == field
      and field.state == 'playing'
      and #field.enemies == 3
      and #field.run.pending == 0
      and field.run.phase == 'wave'
  )
  key('f2')
  click('field_freeze')
  key('escape')
  check(
    'F2 and Escape toggle the catalog while preserving the selected freeze option',
    get() == field and field.state == 'playing' and field.testField.frozen
  )
  key('f2')
  click('field_weapon_2')
  check(
    'catalog weapon selection reaches the actual player weapon',
    field.state == 'playing' and field.weapon == 2
  )
  key('f2')
  click('field_low')
  local low = field.player.hp == 25 and field.player.arsenal.exorcist.reserve == 0
  key('f2')
  click('field_refill')
  check(
    'low-resource and refill buttons change only sandbox resources',
    low
      and field.player.hp == 100
      and field.player.arsenal.exorcist.reserve == 72
      and original.player.arsenal.exorcist.reserve ~= nil
      and Save.encode(Run.snapshot(original), 1) == snapshot
  )
  click('field_close')
  field.player.arsenal.judge.mag, field.player.arsenal.judge.reserve = 0, 7
  key('r')
  local reloading = field.reload > 0 and field.reloadWeapon == 2
  for _ = 1, 240 do
    love.update(1 / 120)
  end
  draw()
  check(
    'R callback reloads the selected revolver and consumes its exact reserve',
    reloading
      and field.reload == 0
      and field.player.arsenal.judge.mag == 6
      and field.player.arsenal.judge.reserve == 1
      and not field.player.arsenal.judge.open
  )
  key('q')
  check(
    'Q callback throws one physical charge in the sandbox without healing',
    field.player.abilityState.powder.uses == 2 and #field.charges == 1 and field.player.hp == 100
  )
  key('f2')
  click('field_hitboxes')
  local hitboxes = field.testField.hitboxes
  click('field_hitboxes')
  check(
    'catalog hitbox control toggles the actual debug geometry setting',
    hitboxes and not field.testField.hitboxes
  )
  click('field_refill')
  click('field_shop')
  click('shop_weapon_1')
  field.player.arsenal.exorcist.reserve = 71
  draw()
  click('buy_ammo')
  check(
    'sandbox shop uses the real controller and partial-ammunition price',
    field.state == 'shop'
      and field.player.arsenal.exorcist.reserve == 72
      and field.run.wallet == 997
  )
  key('2')
  field.player.arsenal.judge.reserve = 71
  draw()
  click('buy_ammo')
  check(
    'shop weapon shortcut redirects the real partial purchase to revolver ammunition',
    field.weapon == 2
      and field.player.arsenal.judge.reserve == 72
      and field.player.arsenal.exorcist.reserve == 72
      and field.run.wallet == 994
  )
  key('f2')
  click('field_reset')
  check(
    'catalog reset clears combat and retains a usable isolated catalog',
    field.state == 'field_catalog'
      and #field.enemies == 0
      and #field.bullets == 0
      and not require('src.session.encounter').guardianDead(field)
      and field.run.wave == 1
  )
  click('field_spawn_furfur_1')
  arrive(field)
  local furfur = field.enemies[1]
  check(
    'Furfur catalog button spawns its real boss definition without an armored-imp skin',
    field.state == 'playing'
      and #field.enemies == 1
      and furfur.kind == 'furfur'
      and furfur.boss
      and furfur.variant == nil
  )
  key('f2')
  click('field_reset')
  key('f2')
  key('tab')
  local mapOpen = field.map
  key('escape')
  check(
    'sandbox map opens and closes through the actual Tab and Escape callbacks',
    mapOpen and not field.map and field.state == 'playing' and get() == field
  )
  key('f1')
  local helpOpen = field.help
  key('f1')
  key('escape')
  check(
    'sandbox help returns to free combat without restoring or mutating the expedition',
    helpOpen
      and not field.help
      and field.state == 'playing'
      and get() == field
      and Save.encode(Run.snapshot(original), 1) == snapshot
  )
  key('f2')
  click('field_archive')
  local allPages = field.state == 'field_archive'
  for i = 1, 6 do
    click('archive_' .. i)
    allPages = allPages and field.state == 'field_archive' and field.testField.archiveSelection == i
  end
  key('escape')
  check(
    'all six historical archive pages select and return to the sandbox catalog',
    allPages and field.state == 'field_catalog' and get() == field
  )
  click('field_leave')
  check(
    -- 0.22: entered from the menu (the expedition is closed), so it returns there.
    'leaving the sandbox restores the exact session it was entered from',
    get() == original
      and (original.state == 'paused' or original.state == 'menu')
      and require('src.session.encounter').guardianDead(original) == originalBoss
      and Save.encode(Run.snapshot(original), 1) == snapshot
  )
  check(
    'sandbox entry, purchases and exit preserve both save generations and profile bytes',
    sameFiles(before, files())
  )
  key('backspace')
  local menu = get()
  local menuFiles = files()
  click('field_start')
  field = get()
  field.testing = false
  check(
    'main-menu catalog entry is available without starting or continuing an expedition',
    field.testField and field ~= menu and field.state == 'field_catalog'
  )
  click('field_spawn_boss_1')
  arrive(field)
  local boss = field.enemies[1]
  field:damageEnemy(boss, 100000, 'weapon')
  require('src.world.arena').breakSeals(field.world, 3)
  require('src.session.encounter').guardianFell(field)
  field.run.wave = 5
  field.player.x, field.player.z = field.world.portal.x, field.world.portal.z
  key('e')
  check(
    'a killed sandbox boss and exit interaction cannot complete or save a real expedition',
    field.state ~= 'won' and not field.run.fragment and sameFiles(menuFiles, files())
  )
  key('f2')
  click('field_leave')
  check(
    'leaving a menu-created sandbox restores the same menu and unchanged save files',
    get() == menu and menu.state == 'menu' and sameFiles(menuFiles, files())
  )
  click('field_skirmish')
  field = get()
  check(
    'quick-combat menu button starts three live targets with real damage',
    field ~= menu
      and field.testField.skirmish
      and not field.testField.invincible
      and #field.enemies == 3
      and field.state == 'playing'
  )
  field.player.armor = 0
  field.player.invuln = 0
  field:damagePlayer(1000)
  draw()
  click('field_skirmish')
  check(
    'quick-combat death retry uses the real callback and rebuilds three targets',
    get() == field and field.state == 'playing' and #field.enemies == 3 and field.player.hp == 100
  )
  key('f2')
  click('field_leave')
  check(
    'quick-combat entry retry and exit preserve expedition and profile bytes',
    get() == menu and sameFiles(menuFiles, files())
  )
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests

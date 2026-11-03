-- Contact sheets are sampled from real mechanical reloads and round counts.
-- Named chamber variants may extend an atlas beyond its original sixteen cells.
local Review = {}
function Review.run(Game, renderer, output)
  local lg = love.graphics
  local V = require('src.render.weapon')
  local Art = require('src.render.weapon_art')
  local Weapons = require('src.content.weapons')
  local Reload = require('src.combat.reload')
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Skin = require('src.ui.skin')
  local report = {
    'LIVE WEAPON PRESENTATION / REAL RELOAD TRANSACTIONS / 240 HZ',
    'Open chamber drawings read current magazine contents, including a reserve of one.',
    'Source-pixel grip, muzzle and placement are authored; no art clock alters ammunition.',
    'Contact sheets use neutral inspection light; full arena screenshots use actual world lighting.',
  }
  local total = 0
  local function save(canvas, name)
    local pixels = canvas:newImageData()
    local bytes = pixels:encode('png')
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(bytes:getString())
    file:close()
    bytes:release()
    pixels:release()
  end
  local function sequence(slot, name, scenario)
    local g = Field.new(Game)
    g.ephemeral = true
    Field.close(g)
    g.player.weapon, g.view.motion = slot, false
    g.view.swapAge, g.view.shotAge = 1, 10
    local state, definition = Weapons.state(g), Weapons.inHand(g)
    local entry = Art.of(g)
    local tiles, seen, last = {}, {}, nil
    local function capture(label)
      local index = V.sourceFrame(g)
      local frame = assert(entry.frames[index], 'sampled unknown weapon drawing')
      local age = g.player.reload > 0 and Reload.age(g) or 0
      local key = table.concat({ frame.id, state.mag, state.open and 1 or 0, label or '' }, ':')
      if key == last then
        return
      end
      last = key
      report[#report + 1] = string.format(
        '%s t=%.4f reload=%.4f frame=%d name=%s mag=%d reserve=%d open=%s %s',
        name,
        g.elapsed,
        age,
        index,
        frame.id,
        state.mag,
        state.reserve,
        tostring(state.open),
        label or ''
      )
      if seen[key] then
        return
      end
      seen[key] = true
      local tile = lg.newCanvas(480, 300)
      lg.push('all')
      lg.setCanvas(tile)
      lg.origin()
      lg.setDepthMode()
      lg.setShader()
      lg.clear(0.035, 0.03, 0.025, 1)
      lg.setScissor(0, 0, 480, 240)
      V.draw(g, 480, 240, { 1, 1, 1 })
      lg.setScissor()
      Skin.text(
        string.format('%02d %s', index, frame.action:upper():gsub('_', ' ')),
        12,
        250,
        UI.fonts[16],
        Skin.colors.ivory
      )
      Skin.text(
        string.format('R %.3f / AMMO %d / OPEN %d', age, state.mag, state.open and 1 or 0),
        12,
        272,
        UI.fonts[16],
        Skin.colors.ivory
      )
      lg.pop()
      tiles[#tiles + 1] = tile
    end
    local function advance(seconds)
      for _ = 1, math.ceil(seconds * 240) do
        g:update(1 / 240, {})
        capture()
      end
    end
    if scenario == 'full' then
      capture('READY')
      assert(g:shoot(), 'live weapon review requires a real shot')
      capture('FIRED')
      if not definition.fire.autoReload then
        advance(0.35)
        assert(g:reloadGun(), 'live weapon review requires a real reload')
      end
      advance(Reload.mechanism(g, slot).duration + 0.1)
      assert(
        not state.open and state.mag == definition.ammo.capacity,
        'full reload failed to latch with full magazine'
      )
    elseif scenario == 'empty' then
      state.mag, state.reserve = 0, definition.ammo.capacity
      capture('EMPTY / FULL LOADER')
      assert(g:reloadGun())
      advance(Reload.mechanism(g, slot).duration + 0.1)
      assert(
        state.mag == definition.ammo.capacity and state.reserve == 0 and not state.open,
        'full loader must transfer all available rounds at the existing transaction'
      )
    elseif scenario == 'partial' then
      state.mag, state.reserve = 0, 1
      capture('EMPTY / RESERVE ONE')
      assert(g:reloadGun())
      advance(Reload.mechanism(g, slot).duration + 0.1)
      assert(
        state.mag == 1 and state.reserve == 0 and not state.open,
        'partial reserve fabricated ammunition'
      )
    elseif scenario == 'retained' then
      state.mag, state.reserve = 3, 1
      capture('THREE RETAINED / ONE IN LOADER')
      assert(g:reloadGun())
      advance(Reload.mechanism(g, slot).duration + 0.1)
      assert(
        state.mag == 4 and state.reserve == 0 and not state.open,
        'loader must add one round to the three retained rounds'
      )
    elseif scenario == 'resume' then
      state.mag, state.reserve = 1, 1
      assert(g:reloadGun())
      local beforeLoad = definition.reload.mechanism == 'breech' and 0.4 or 0.85
      advance(beforeLoad)
      assert(
        state.open and state.mag == 1,
        'cancel fixture must be open and before its load transaction'
      )
      capture('BEFORE SWAP')
      g:switchWeapon(slot == 1 and 2 or 1)
      assert(state.open and state.mag == 1, 'switch changed open chamber contents')
      g:switchWeapon(slot)
      g.view.swapAge = 1
      capture('RESUMED')
      advance(Reload.mechanism(g, slot).duration + 0.1)
      assert(
        state.mag == 2 and state.reserve == 0 and not state.open,
        'resumed reload did not preserve exact ammo'
      )
    else
      state.mag, state.reserve = 1, 1
      assert(g:reloadGun())
      advance(0.85)
      capture('BEFORE TRIGGER INTERRUPT')
      assert(
        not g:shoot() and not state.open and state.mag == 1,
        'open cylinder trigger must close before firing'
      )
      capture('CLOSING BEFORE FIRE')
      advance(0.3)
      assert(
        g:shoot() and state.mag == 0,
        'closed cylinder must consume exactly its one remaining round'
      )
      capture('FIRED REMAINING ROUND')
      advance(0.3)
    end
    local rows = math.ceil(#tiles / 4)
    local sheet = lg.newCanvas(1920, rows * 300)
    lg.push('all')
    lg.setCanvas(sheet)
    lg.origin()
    lg.setShader()
    lg.clear(0.016, 0.014, 0.012, 1)
    lg.setColor(1, 1, 1)
    for index, tile in ipairs(tiles) do
      lg.draw(tile, (index - 1) % 4 * 480, math.floor((index - 1) / 4) * 300)
    end
    lg.pop()
    save(sheet, name)
    sheet:release()
    for _, tile in ipairs(tiles) do
      tile:release()
    end
    total = total + #tiles
    report[#report + 1] = name
      .. ': '
      .. #tiles
      .. ' distinct live pose/round/open samples; '
      .. #entry.frames
      .. ' authored rectangles.'
  end
  -- These sheets count the rounds of each reload transaction exactly; the Judge's spare rounds
  -- (0.42, tests/suites/weapons.lua holds them) would add to the count while it loads.
  local judgeAmmo = require('src.content.weapons').get('judge').ammo
  local spare = judgeAmmo.spare
  judgeAmmo.spare = 0
  -- Put back even when a sheet fails, so no later suite runs without the spare rounds.
  local ok, problem = pcall(function()
    for slot, name in ipairs({ 'shotgun', 'revolver' }) do
      sequence(slot, 'weapon-' .. name .. '-16-poses', 'full')
      sequence(slot, 'weapon-' .. name .. '-partial-one', 'partial')
      sequence(slot, 'weapon-' .. name .. '-cancel-resume', 'resume')
    end
    sequence(2, 'weapon-revolver-trigger-interrupt', 'interrupt')
    sequence(2, 'weapon-revolver-retained-three', 'retained')
    sequence(2, 'weapon-revolver-speedloader-full', 'empty')
  end)
  judgeAmmo.spare = spare
  assert(ok, problem)
  local file = assert(io.open(output .. '/weapon-timeline.txt', 'w'))
  file:write(table.concat(report, '\n') .. '\n')
  file:close()
  love.mouse.setRelativeMode(false)
  return total
end
return Review

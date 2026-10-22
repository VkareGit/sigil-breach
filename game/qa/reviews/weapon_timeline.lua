-- Contact sheets sampled from live fire/reload timelines, never forced frame ids.
local S = {}
function S.run(G, renderer, output)
  local lg = love.graphics
  local V = require('src.render.weapon')
  local Reload = require('src.combat.reload')
  local Art = require('src.render.weapon_art')
  local Weapons = require('src.content.weapons')
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Skin = require('src.ui.skin')
  local reports = {
    'LIVE WEAPON PRESENTATION / SOURCE POSES AND MECHANICAL TRANSACTIONS',
    'Sampling: 240 Hz. Source IDs come from weapon_art, not logical Reload.frame.',
    'Firing selects authored recoil/recovery poses; powder follows each registered muzzle.',
    'The historical *-16-poses filenames are retained; actual live counts are reported below.',
  }
  local width, height = 640, 300
  local totalPoses = 0
  local function save(canvas, name)
    local pixels = canvas:newImageData()
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(pixels:encode('png'):getString())
    file:close()
    pixels:release()
  end
  for slot = 1, 2 do
    local g = Field.new(G)
    g.testing = true
    Field.close(g)
    g.weapon = slot
    g.view.motion = false
    local manifest = assert(Art[Art.ids[slot]])
    local name = slot == 1 and 'shotgun' or 'revolver'
    local expected = { [1] = true }
    local expectedCount = 1
    for _, key in ipairs(manifest.fire) do
      if not expected[key[2]] then
        expected[key[2]] = true
        expectedCount = expectedCount + 1
      end
    end
    for _, key in ipairs(manifest.timeline) do
      assert(manifest.frames[key[2]], 'Weapon timeline references a missing source pose')
      if not expected[key[2]] then
        expected[key[2]] = true
        expectedCount = expectedCount + 1
      end
    end
    assert(expectedCount <= 16, 'Weapon contact sheet needs more than sixteen source cells')
    reports[#reports + 1] = '\n' .. name:upper() .. ' / ' .. manifest.path
    local seen = {}
    local count = 0
    local sheet = lg.newCanvas(1920, 1080)
    sheet:setFilter('nearest', 'nearest')
    lg.push('all')
    lg.setCanvas(sheet)
    lg.origin()
    lg.clear(0.016, 0.014, 0.012, 1)
    lg.pop()
    local lastState
    local function snapshot(frame)
      local mag, reserve = Weapons.ammo(g)
      local p = g.player
      local opened = slot == 1 and p.arsenal.exorcist.open or slot == 2 and p.arsenal.judge.open
      local loaded = slot == 1 and (g.reloadStage or 0) >= 2 or slot == 2 and p.arsenal.judge.loaded
      local age = g.reload > 0 and Reload.age(g) or 0
      local state = table.concat({
        frame,
        mag,
        reserve,
        opened and 1 or 0,
        loaded and 1 or 0,
        g.reload > 0 and 1 or 0,
        V.muzzlePhase(g) or 0,
      }, ':')
      if state ~= lastState then
        reports[#reports + 1] = string.format(
          't=%.4f source=%02d action=%s shotAge=%.4f reloadAge=%.4f remaining=%.4f mag=%d reserve=%d open=%s loadFlag=%s muzzle=%s',
          g.elapsed,
          frame,
          manifest.frames[frame].action,
          g.view.shotAge,
          age,
          g.reload,
          mag,
          reserve,
          tostring(opened == true),
          tostring(loaded == true),
          tostring(V.muzzlePhase(g) or 'none')
        )
        lastState = state
      end
      return age, mag, opened
    end
    local function capture()
      local frame = V.sourceFrame(g)
      assert(
        expected[frame],
        'Live drawing selected an unexpected source pose: ' .. name .. ' ' .. frame
      )
      local age, mag, opened = snapshot(frame)
      if seen[frame] then
        return
      end
      seen[frame] = true
      count = count + 1
      local tile = lg.newCanvas(width, height)
      tile:setFilter('nearest', 'nearest')
      lg.push('all')
      lg.setCanvas(tile)
      lg.origin()
      lg.setDepthMode()
      lg.setShader()
      lg.clear(0.035, 0.030, 0.025, 1)
      V.draw(g, width, height)
      lg.setCanvas(sheet)
      lg.origin()
      lg.setShader()
      lg.setColor(1, 1, 1)
      local x, y = (count - 1) % 4 * 480, math.floor((count - 1) / 4) * 270
      lg.draw(tile, x, y, 0, 0.75, 0.75)
      lg.setColor(0.25, 0.20, 0.13)
      lg.rectangle('fill', x + 12, y + 225, 456, 1)
      Skin.text(
        string.format('SOURCE %02d / %s', frame, manifest.frames[frame].action:upper()),
        x + 16,
        y + 230,
        UI.fonts[16],
        Skin.colors.ivory
      )
      Skin.text(
        string.format('R %.3fs / AMMO %d / OPEN %d', age, mag, opened and 1 or 0),
        x + 16,
        y + 251,
        UI.fonts[16],
        Skin.colors.ivory
      )
      lg.pop()
      tile:release()
    end
    local function advance(seconds)
      for _ = 1, math.ceil(seconds * 240) do
        g:update(1 / 240, {})
        capture()
      end
    end
    capture()
    assert(g:shoot(), 'Contact sheet requires a real shot')
    capture()
    if slot == 1 then
      advance(1.1)
    else
      advance(0.35)
      assert(g:reloadGun(), 'Contact sheet requires a real revolver reload')
      capture()
      advance(2)
    end
    local missing = {}
    for frame in pairs(expected) do
      if not seen[frame] then
        missing[#missing + 1] = frame
      end
    end
    table.sort(missing)
    assert(
      #missing == 0 and count == expectedCount,
      'Incomplete live weapon source timeline: '
        .. name
        .. ' missing '
        .. table.concat(missing, ',')
    )
    local unused = {}
    for frame in ipairs(manifest.frames) do
      if not seen[frame] then
        unused[#unused + 1] = frame
      end
    end
    reports[#reports + 1] = string.format(
      'COVERAGE %s: %d/%d required live source poses, %d authored atlas poses. Unused in the live timeline: %s.',
      name,
      count,
      expectedCount,
      #manifest.frames,
      #unused > 0 and table.concat(unused, ', ') or 'none'
    )
    if count < 16 then
      local x, y = count % 4 * 480, math.floor(count / 4) * 270
      lg.push('all')
      lg.setCanvas(sheet)
      lg.origin()
      lg.setShader()
      local summary = {
        name:upper() .. ' / LIVE CAPTURE',
        count .. ' SOURCE POSES / ' .. #manifest.frames .. ' IN ATLAS',
        '240 HZ / PHYSICAL RELOAD',
        'R = RELOAD AGE IN SECONDS',
        'FLASH AND RECOIL ARE SEPARATE',
      }
      for index, line in ipairs(summary) do
        Skin.text(line, x + 16, y + 35 + (index - 1) * 30, UI.fonts[16], Skin.colors.ivory)
      end
      lg.pop()
    end
    save(sheet, slot == 1 and 'weapon-shotgun-16-poses' or 'weapon-revolver-16-poses')
    sheet:release()
    totalPoses = totalPoses + count
  end
  local file = assert(io.open(output .. '/weapon-timeline.txt', 'w'))
  file:write(table.concat(reports, '\n'))
  file:close()
  love.mouse.setRelativeMode(false)
  return totalPoses
end
return S

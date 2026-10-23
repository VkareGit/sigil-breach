local D = {}
local lg = love.graphics
local E = require('src.run.economy')
local Run = require('src.run.descent')
local Modes = require('src.run.modes')
local Circles = require('src.content.circles')
local Skin = require('src.ui.skin')
local Weapons = require('src.content.weapons')
local Palette = require('src.ui.palette')
local ivory = Skin.colors.ivory
local muted = Skin.colors.muted
local gold = Skin.colors.gold
local blue = Skin.colors.blue
local red = Skin.colors.red
local U
function D.install(ui)
  U = ui
end
local function color(c, a)
  lg.setColor(c[1], c[2], c[3], a or 1)
end
local function text(t, x, y, size, c)
  Skin.text(t, x, y, U.fonts[size or 18], c or ivory)
end
local function center(t, y, size, c)
  local font = U.fonts[size or 18]
  Skin.text(t, (1280 - font:getWidth(t)) / 2, y, font, c or ivory)
end
local function rect(x, y, w, h, c, a)
  color(c, a)
  lg.rectangle('fill', x, y, w, h)
end
local function panel(x, y, w, h)
  Skin.panel(x, y, w, h, 1, 14)
end
local function waveName(r)
  return r.wave == Run.totalWaves + 1 and 'LIMBO GUARDIAN'
    or ('WAVE ' .. r.wave .. ' / ' .. Run.totalWaves)
end
function D.objective(g)
  local r = g.run
  if r.phase == 'complete' then
    return 'Ring fragment recovered.'
  end
  if r.phase == 'preparing' then
    return 'Preparation / ' .. waveName(r)
  end
  if r.phase == 'countdown' then
    return 'The rite begins in ' .. math.ceil(r.countdown)
  end
  return waveName(r) .. ' / Remaining: ' .. (Modes.act(g, 'remaining') or 0)
end
function D.controls(g)
  if not g.run or g.help or g.map then
    return nil
  end
  local r = g.run
  if g.state == 'shop' then
    local list = {}
    for i, o in ipairs(E.offers) do
      local _, reason = E.quote(g, o.id)
      list[#list + 1] = {
        id = 'buy_' .. o.id,
        label = E.label(g, o.id),
        x = 881,
        y = 189 + (i - 1) * 56,
        w = 270,
        h = 42,
        disabled = reason ~= nil,
      }
    end
    list[#list + 1] = {
      id = 'ready',
      label = g.testField and 'BACK TO PROVING GROUND' or 'READY / BEGIN',
      x = 824,
      y = 593,
      w = 328,
      h = 48,
    }
    list[#list + 1] =
      { id = 'shop_back', label = 'BACK TO ARENA [ ESC ]', x = 128, y = 593, w = 310, h = 48 }
    -- One button per weapon of the loadout across the shop's right half.
    local count = Weapons.count(g)
    local step = count <= 2 and 262 or math.floor(524 / count)
    for slot = 1, count do
      local mag, reserve = Weapons.ammo(g, slot)
      list[#list + 1] = {
        id = 'shop_weapon_' .. slot,
        label = slot .. ' ' .. Weapons.profile(slot, g).hud.tab .. ' ' .. mag .. ' + ' .. reserve,
        x = 640 + (slot - 1) * step,
        y = 137,
        w = step - 12,
        h = 40,
        active = g.weapon == slot,
      }
    end
    return list
  elseif g.state == 'menu' then
    -- 0.22: the expedition is closed while combat is forged; only the
    -- proving ground is open (skirmish and the full catalogue of stations).
    local list = {
      { id = 'field_skirmish', label = 'SKIRMISH [ SPACE ]', x = 72, y = 390, w = 400, h = 54 },
      { id = 'field_start', label = 'PROVING GROUND [ F2 ]', x = 72, y = 455, w = 400, h = 44 },
    }
    list[#list + 1] = { id = 'help', label = 'HELP [ F1 ]', x = 72, y = 514, w = 194, h = 44 }
    list[#list + 1] = { id = 'settings', label = 'SETTINGS', x = 270, y = 514, w = 194, h = 44 }
    list[#list + 1] = { id = 'quit', label = 'QUIT', x = 72, y = 573, w = 194, h = 40 }
    return list
  elseif g.state == 'confirm_new' then
    return {
      { id = 'new_confirm', label = 'START OVER', x = 440, y = 405, w = 400, h = 48 },
      { id = 'new_cancel', label = 'KEEP EXPEDITION [ ESC ]', x = 440, y = 470, w = 400, h = 44 },
    }
  elseif g.state == 'dead' then
    return {
      {
        id = 'retry',
        label = r.wave == Run.totalWaves + 1 and 'RETRY GUARDIAN [ ENTER ]'
          or ('RETRY WAVE ' .. r.wave .. ' [ ENTER ]'),
        x = 410,
        y = 524,
        w = 460,
        h = 50,
      },
      { id = 'menu', label = 'SAVE / MAIN MENU', x = 410, y = 591, w = 460, h = 42 },
    }
  elseif g.state == 'won' then
    return {
      { id = 'new_confirm', label = 'NEW LIMBO TRIAL', x = 410, y = 524, w = 460, h = 50 },
      { id = 'menu', label = 'MAIN MENU [ ESC ]', x = 410, y = 591, w = 460, h = 42 },
    }
  end
end
function D.heading(g)
  if g.testField then
    return require('src.ui.test_field').heading(g, U)
  end
  local r = g.run
  Skin.panel(20, 16, 378, 64, 2, 9)
  Skin.zone('objective field', 32, 26, 354, 44)
  local title = 'I / LIMBO / PROVING FIELD'
  Skin.boxText(title, 35, 27, 348, 20, U.fonts[14], gold)
  local objective = D.objective(g)
  local size = 16
  if Skin.inkBounds(U.fonts[size], objective).w > 348 then
    size = 14
  end
  Skin.boxText(objective, 35, 48, 348, 22, U.fonts[size], ivory)
  Skin.endZone()
  if r.phase == 'preparing' then
    local n = require('src.run.navigation').shrine(g)
    local cold = Palette.cold
    Skin.panel(470, 16, 340, 64, 2, 10)
    Skin.zone('shrine compass field', 482, 26, 316, 44)
    Skin.icon('ring', 486, 29, 29)
    Skin.boxText(
      'SEAL EMBER / ' .. math.max(1, math.ceil(n.distance)) .. ' M',
      526,
      27,
      268,
      23,
      U.fonts[16],
      cold
    )
    Skin.boxText(
      n.visible and n.direction or ('COVERED / ' .. n.direction),
      526,
      52,
      268,
      18,
      U.fonts[12],
      muted
    )
    Skin.endZone()
    if math.abs(n.angle) > 0.18 then
      local sign = n.angle < 0 and -1 or 1
      local x = sign < 0 and 458 or 822
      color(cold)
      lg.polygon('fill', x + sign * 6, 45, x - sign * 4, 39, x - sign * 4, 51)
    end
    Skin.panel(950, 538, 312, 44, 7, 10)
    Skin.zone('ready caption field', 960, 548, 292, 24)
    local ready = '[ENTER] BEGIN WAVE'
    local size = 16
    if Skin.inkBounds(U.fonts[size], ready).w > 288 then
      size = 14
    end
    Skin.boxText(ready, 962, 549, 288, 22, U.fonts[size], gold, true)
    Skin.endZone()
  elseif r.phase == 'countdown' then
    center(tostring(math.ceil(r.countdown)), 250, 64, gold)
  end
  if g.saveWarning then
    center('WARNING: ' .. g.saveWarning, 448, 18, red)
  end
end
function D.shop(g)
  local r, p = g.run, g.player
  rect(0, 0, 1280, 720, Palette.veilDeep, 0.9)
  Skin.panel(96, 44, 1088, 628, 5, 14)
  Skin.zone('shop writing field', 128, 78, 1024, 562)
  Skin.icon('ring', 129, 84, 36)
  Skin.inscription('merchant', 188, 82, 420, 52)
  Skin.icon('soul', 844, 84, 31)
  text('SOULS  ' .. r.wallet, 892, 84, 28, gold)
  text(
    g.testField and 'PROVING GROUND / UNSAVED SHOP' or (waveName(r) .. ' / PREPARATION'),
    130,
    150,
    20,
    gold
  )
  text(
    'BUYING FOR: ' .. Weapons.inHand(g).hud.kind .. ' / WARD ' .. math.ceil(p.armor) .. '/100',
    650,
    120,
    14,
    muted
  )
  for i, o in ipairs(E.offers) do
    local y = 183 + (i - 1) * 56
    rect(128, y, 1024, 1, gold, 0.22)
    if U.focus == i then
      rect(132, y + 3, 730, 50, Palette.highlight, 0.22)
    end
    Skin.icon(((o.id == 'fill' or o.id == 'charge') and 'ammo' or o.id), 145, y + 7, 40)
    Skin.zone('offer ' .. o.id, 208, y + 3, 650, 50)
    local name, description = E.describe(g, o.id)
    text(name, 209, y + 7, 20, gold)
    text(description, 209, y + 32, 16, muted)
    Skin.endZone()
  end
  local selected = U.controls(g, {})[U.focus]
  local price, reason
  if selected and selected.id:sub(1, 4) == 'buy_' then
    price, reason = E.quote(g, selected.id:sub(5))
  end
  text(
    reason or g.shopMessage or 'Owned engravings switch for free. One is active.',
    129,
    536,
    18,
    reason and red or ivory
  )
  if price and not reason then
    text('AFTER: ' .. (r.wallet - price) .. ' SOULS', 825, 559, 16, gold)
  end
  text('Health restored. The Ember shields you until the wave begins.', 129, 567, 16, muted)
  Skin.endZone()
  if g.saveWarning then
    center(g.saveWarning, 679, 16, red)
  end
end
function D.map(g)
  if g.testField then
    return require('src.ui.test_field').map(g, U)
  end
  rect(0, 0, 1280, 720, Palette.veilCool, 0.96)
  panel(100, 40, 1080, 640)
  Skin.zone('map writing field', 132, 76, 1016, 570)
  Skin.inscription('circles', 132, 84, 400, 40)
  text('RING  ' .. (g.run.fragment and '1' or '0') .. ' / 9', 132, 131, 20, gold)
  for i, c in ipairs(Circles) do
    local y = 163 + (i - 1) * 39
    text(c.roman .. '  ' .. c.name, 136, y, 22, i == 1 and gold or muted)
    text(i == 1 and '4 WAVES + GUARDIAN' or 'IN DEVELOPMENT', 386, y + 5, 14, muted)
  end
  text('Proving field: the Limbo arena.', 136, 535, 20, ivory)
  text('One arena. Four waves and a guardian.', 136, 565, 16, muted)
  local sz, ox, oy = 420 / g.world.size, 652, 121
  for z = 1, g.world.size do
    for x = 1, g.world.size do
      if g.world.map[z][x] == 0 then
        rect(ox + x * sz, oy + z * sz, sz - 1, sz - 1, Palette.stone)
      end
    end
  end
  for _, s in ipairs(g.world.seals) do
    color(s.color)
    lg.circle('line', ox + s.x * sz, oy + s.z * sz, 9)
  end
  local p = g.player
  color(ivory)
  lg.circle('fill', ox + p.x * sz, oy + p.z * sz, 4)
  lg.line(
    ox + p.x * sz,
    oy + p.z * sz,
    ox + p.x * sz + math.sin(p.yaw) * 15,
    oy + p.z * sz + math.cos(p.yaw) * 15
  )
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      rect(ox + e.x * sz - 2, oy + e.z * sz - 2, 4, 4, red)
    end
  end
  local cold = Palette.cold
  local sx, sy = ox + Run.shrine.x * sz, oy + Run.shrine.z * sz
  color(cold)
  lg.setLineWidth(2)
  lg.circle('line', sx, sy, 13)
  Skin.icon('ring', sx - 8, sy - 8, 16)
  text(
    g.run.phase == 'preparing' and 'EMBER / MERCHANT' or 'EMBER DORMANT',
    sx - 54,
    sy + 17,
    14,
    cold
  )
  if g.run.echo then
    local e = g.run.echo
    color(blue)
    lg.circle('line', ox + e.x * sz, oy + e.z * sz, 7)
    text('ECHO', ox + e.x * sz - 18, oy + e.z * sz - 25, 14, blue)
  end
  text('CELADON: EMBER / MERCHANT    BLUE: ECHO', 132, 622, 16, muted)
  text('WHITE: YOU    RED: DEMON', 652, 558, 14, muted)
  text('The map pauses combat.', 652, 585, 14, gold)
  Skin.endZone()
end
function D.ending(g)
  local r = g.run
  rect(0, 0, 1280, 720, Palette.veil, 0.95)
  panel(96, 42, 1088, 628)
  Skin.icon(g.state == 'won' and 'ring' or 'skull', 612, 52, 56)
  Skin.zone('ending writing field', 128, 110, 1024, 402)
  center(g.state == 'won' and 'FIRST FRAGMENT' or 'SOULS LEFT IN LIMBO', 116, 48, ivory)
  if g.state == 'won' then
    center('The Margrave has fallen. The ring seal regains its shape.', 188, 22, muted)
    center('I / IX', 250, 64, gold)
    center('FOUR WAVES AND THE GUARDIAN DEFEATED', 340, 24, ivory)
    center('Further circles are in development. Limbo remains the proving field.', 465, 20, muted)
  else
    center('Gear and completed waves are kept.', 188, 22, muted)
    center(
      r.echo and (r.echo.amount .. ' SOULS IN THE ECHO') or 'NO SOULS TO RECOVER',
      260,
      36,
      blue
    )
    center(
      'Retry '
        .. (r.wave == Run.totalWaves + 1 and 'the guardian' or ('wave ' .. r.wave))
        .. '. Recover the echo during the fight.',
      326,
      22,
      ivory
    )
    center('Dying again before recovery erases the previous echo.', 367, 18, muted)
    center('Ammo and ward return to their state at the start of the wave.', 465, 20, gold)
  end
  center(
    string.format(
      'TIME %02d:%02d   DEMONS %d   DEATHS %d   SOULS %d',
      math.floor(g.elapsed / 60),
      math.floor(g.elapsed % 60),
      g.kills,
      r.deaths,
      r.wallet
    ),
    412,
    22,
    ivory
  )
  if g.saveWarning then
    center(g.saveWarning, 490, 16, red)
  end
  Skin.endZone()
end
function D.confirm()
  rect(0, 0, 1280, 720, Palette.veil, 0.95)
  panel(250, 144, 780, 432)
  Skin.zone('confirmation writing field', 282, 176, 716, 180)
  Skin.inscription('new_run', 410, 185, 460, 54)
  center('This replaces the current expedition, its souls and gear.', 273, 22, muted)
  center('Control settings are kept.', 315, 20, gold)
  Skin.endZone()
end
return D

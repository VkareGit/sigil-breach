local UI = {}
local Field = require('src.run.test_field')
local Skin = require('src.ui.skin')
local Goetia = require('src.ui.goetic_sigils')
local Defs = require('src.content.enemy_catalog')
local lg = love.graphics
local C = Skin.colors
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local ShotReport = require('src.ui.shot_report')
local Palette = require('src.ui.palette')
local Pools = require('src.session.world')
local function box(ui, label, x, y, w, h, size, color)
  -- Step the size down if the illustrated glyphs would overrun the field.
  -- Only sizes that exist in the painted font (36 steps to 28, not 34).
  size = size or 18
  local steps = { 94, 64, 48, 42, 36, 28, 24, 22, 20, 18, 16, 14, 13, 12, 11 }
  for _, s in ipairs(steps) do
    if s <= size and (Skin.inkBounds(ui.fonts[s], label).w <= w or s == 11) then
      size = s
      break
    end
  end
  Skin.zone('field ' .. label, x, y, w, h)
  Skin.boxText(label, x, y, w, h, ui.fonts[size], color or C.ivory)
  Skin.endZone()
end
local function button(id, label, x, y, w, h)
  return { id = id, label = label, x = x, y = y, w = w, h = h or 44 }
end
function UI.controls(g)
  if not g.testField or g.help or g.map then
    return nil
  end
  local t = g.testField
  if g.state == 'dead' then
    return {
      button(
        t.skirmish and 'field_skirmish' or 'field_reset',
        t.skirmish and 'RETRY SKIRMISH' or 'RESET PROVING GROUND',
        410,
        524,
        460,
        50
      ),
      button('field_open', 'CATALOGUE [ F2 ]', 410, 586, 224, 44),
      button('field_leave', g.view.fieldReturnLabel, 650, 586, 220, 44),
    }
  end
  if g.state ~= 'field_catalog' then
    return nil
  end
  local list = {}
  for i, entry in ipairs(Field.catalog.enemies) do
    local y = 174 + (i - 1) * 48
    list[#list + 1] = button(
      'field_select_' .. entry.id,
      (t.selected == entry.id and ': ' or '') .. entry.name,
      140,
      y,
      258,
      44
    )
    list[#list + 1] = button('field_spawn_' .. entry.id .. '_1', 'ONE', 410, y, 86, 44)
    list[#list + 1] = button('field_spawn_' .. entry.id .. '_3', 'x 3', 508, y, 108, 44)
  end
  local items = {
    { 'field_refill', 'HP / ARMOUR / AMMO' },
    { 'field_reset', 'RESET FIELD' },
    { 'field_god', 'GOD MODE: ' .. (t.invincible and 'ON' or 'OFF') },
    { 'field_freeze', 'AI / SHOTS: ' .. (t.frozen and 'STOP' or 'LIVE') },
  }
  -- One button per weapon of the knight's loadout (slot order).
  for _, weapon in ipairs(Field.weapons(g)) do
    items[#items + 1] = { 'field_weapon_' .. weapon.id, weapon.id .. ' / ' .. weapon.name }
  end
  for _, item in ipairs({
    { 'field_pose_prev', 'PREVIOUS POSE' },
    { 'field_pose_next', 'NEXT POSE' },
    { 'field_shop', 'SHOP / TRIAL SOULS' },
    { 'field_low', 'LOW RESOURCES' },
  }) do
    items[#items + 1] = item
  end
  for i, item in ipairs(items) do
    list[#list + 1] =
      button(item[1], item[2], 654 + (i - 1) % 2 * 264, 174 + math.floor((i - 1) / 2) * 52, 250, 44)
  end
  -- 0.22 stations of the proving ground (seal visits remain in Field.visitSeal).
  for i, station in ipairs(Field.catalog.stations) do
    list[#list + 1] =
      button('field_station_' .. station.id, station.name, 654 + (i - 1) * 176, 511, 162, 44)
  end
  list[#list + 1] = button(
    'field_close',
    g.player.hp <= 0 and 'RETURN / CHARACTER DEAD' or 'BACK TO FIELD [ F2 / ESC ]',
    86,
    616,
    440,
    48
  )
  list[#list + 1] = button('field_archive', 'ARCHIVE OF SIGNS', 550, 616, 250, 48)
  list[#list + 1] = button('field_leave', g.view.fieldReturnLabel, 826, 616, 342, 48)
  list[#list + 1] =
    button('field_hitboxes', 'HITBOXES: ' .. (t.hitboxes and 'ON' or 'OFF'), 904, 72, 264, 40)
  -- 0.21: the wave tier of demons spawned here (1 = calibrated base).
  list[#list + 1] = button('field_tier', 'TIER ' .. (t.tier or 1) .. ' / 5', 712, 72, 180, 40)
  return list
end
function UI.heading(g, ui)
  Skin.panel(20, 16, 378, 64, 2, 9)
  box(
    ui,
    'PROVING / TARGETS ' .. require('src.run.descent').remaining(g) .. ' / F2',
    35,
    27,
    348,
    20,
    14,
    C.gold
  )
  local t = g.testField
  box(
    ui,
    (t.invincible and 'INVINCIBLE' or 'DAMAGE ON') .. ' / ' .. (t.frozen and 'AI STOP' or 'AI LIVE'),
    35,
    48,
    348,
    22,
    14,
    C.ivory
  )
end
function UI.draw(g, ui)
  lg.setColor(0.012, 0.010, 0.014, 0.97)
  lg.rectangle('fill', 0, 0, 1280, 720)
  Skin.panel(54, 36, 1172, 650, 6, 14)
  box(ui, 'PROVING GROUND / TRIAL CATALOGUE', 86, 72, 610, 42, 36, C.gold)
  box(
    ui,
    g.testField.message or 'One arena. Real combat. Separate trials that never save the expedition.',
    86,
    120,
    1082,
    26,
    18,
    C.ivory
  )
  box(ui, 'DEMONS / CHOOSE TYPE AND COUNT', 86, 148, 530, 22, 16, C.muted)
  box(ui, 'TOOLS / WEAPONS / GUI', 654, 148, 514, 22, 16, C.muted)
  for i, entry in ipairs(Field.catalog.enemies) do
    local y = 174 + (i - 1) * 48
    ui.face(entry.id, 86, y, 44, 44, 'field enemy ' .. entry.id)
  end
  local t = g.testField
  local entry = Defs[t.selected]
  local count = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      count = count + 1
    end
  end
  box(ui, 'SELECTED: ' .. entry.name, 86, 474, 530, 26, 18, C.gold)
  box(
    ui,
    'HP ' .. entry.hp .. ' / ARMOUR ' .. entry.armor .. ' / POSE ' .. t.poseIndex,
    86,
    505,
    530,
    22,
    16,
    C.ivory
  )
  box(
    ui,
    'LIVE TARGETS ' .. count .. ' / ' .. Field.limit .. ' / KILLS ' .. g.kills,
    86,
    535,
    530,
    22,
    16,
    C.muted
  )
  local arms = {}
  for slot = 1, Weapons.count(g) do
    local mag, reserve = Weapons.ammo(g, slot)
    arms[slot] = Weapons.profile(slot, g).hud.tab .. ' ' .. mag .. ' + ' .. reserve
  end
  -- The ability on Q: uses left of its capacity.
  local ability, power = Abilities.slot(g, 1)
  local quick = ability and ((power.uses or 0) .. '/' .. ability.capacity) or ''
  box(ui, table.concat(arms, ' / ') .. ' / Q ' .. quick, 654, 439, 514, 22, 14, C.ivory)
  box(ui, 'STATIONS / RANGE, PHYSICS, WAVE TRIAL (TIER)', 654, 476, 514, 22, 16, C.muted)
  ShotReport.draw(g.view.shotReport, ui)
end
function UI.ending(g, ui)
  lg.setColor(0.015, 0.013, 0.017, 0.95)
  lg.rectangle('fill', 0, 0, 1280, 720)
  Skin.panel(280, 106, 720, 560, 5, 14)
  box(ui, 'PROVING GROUND / CHARACTER FELL', 328, 173, 624, 54, 36, C.gold)
  box(ui, 'The expedition and its souls are kept.', 328, 268, 624, 34, 22)
  box(ui, 'Reset renews the field. F2 opens the trial catalogue.', 328, 320, 624, 30, 18, C.muted)
  box(
    ui,
    'KILLS '
      .. g.kills
      .. ' / DAMAGE '
      .. math.floor(g.damageTaken)
      .. ' / CONTROL '
      .. math.floor(100 * require('src.combat.telemetry').uptime(g) + 0.5)
      .. ' %',
    328,
    380,
    624,
    30,
    20,
    C.ivory
  )
end
function UI.map(g, ui)
  lg.setColor(0.015, 0.013, 0.017, 0.96)
  lg.rectangle('fill', 0, 0, 1280, 720)
  Skin.panel(100, 40, 1080, 640, 5, 14)
  box(ui, 'PROVING GROUND / TRIAL MAP', 132, 84, 1016, 46, 36, C.gold)
  box(ui, 'The original 31 x 31 arena.', 132, 163, 440, 34, 22)
  box(ui, 'F2: demons, guns, poses and seals.', 132, 208, 440, 30, 18, C.muted)
  for i, seal in ipairs(g.world.seals) do
    Goetia.draw(seal.name, 140, 278 + (i - 1) * 74, 44, Palette.sepia, 0.95)
    Skin.imageBounds('field map seal ' .. seal.name, 140, 278 + (i - 1) * 74, 44, 44)
    box(ui, seal.name, 206, 288 + (i - 1) * 74, 344, 28, 20, seal.color)
  end
  box(ui, 'WHITE: YOU / RED: TARGET', 132, 535, 440, 28, 16, C.ivory)
  box(ui, 'The map pauses combat. No wave progression.', 132, 573, 440, 26, 16, C.muted)
  local sz, ox, oy = 420 / g.world.size, 652, 121
  for z = 1, g.world.size do
    for x = 1, g.world.size do
      if g.world.map[z][x] == 0 then
        lg.setColor(0.20, 0.18, 0.16)
        lg.rectangle('fill', ox + x * sz, oy + z * sz, sz - 1, sz - 1)
      end
    end
  end
  for _, seal in ipairs(g.world.seals) do
    lg.setColor(seal.color)
    lg.circle('line', ox + seal.x * sz, oy + seal.z * sz, 9)
  end
  local p = g.player
  lg.setColor(C.ivory)
  lg.circle('fill', ox + p.x * sz, oy + p.z * sz, 4)
  lg.line(
    ox + p.x * sz,
    oy + p.z * sz,
    ox + p.x * sz + math.sin(p.yaw) * 15,
    oy + p.z * sz + math.cos(p.yaw) * 15
  )
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      lg.setColor(C.red)
      lg.rectangle('fill', ox + e.x * sz - 2, oy + e.z * sz - 2, 4, 4)
    end
  end
end
return UI

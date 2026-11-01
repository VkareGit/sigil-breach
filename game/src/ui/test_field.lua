local Tiles = require('src.core.tiles')
local Context = require('src.session.context')
local UI = {}
local Stats = require('src.session.stats')
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
local Grid = require('src.physics.grid')
local Queries = require('src.run.queries')
local FieldData = require('src.content.field')
local Text = require('src.content.text')
local Access = require('src.run.field.access')
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
  local t = Queries.field(g)
  if not t or g.help or g.map then
    return nil
  end
  if g.state == 'dead' then
    return {
      button(
        t.skirmish and 'field_skirmish' or 'field_reset',
        Text.get(t.skirmish and 'fui_retry_skirmish' or 'fui_reset'),
        410,
        524,
        460,
        50
      ),
      button('field_open', Text.get('fui_catalogue'), 410, 586, 224, 44),
      button('field_leave', Text.get(g.view.fieldReturnLabel), 650, 586, 220, 44),
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
      t.selected == entry.id and Text.get('fui_selected_mark', { name = Text.get(entry.name) })
        or Text.get(entry.name),
      140,
      y,
      258,
      44
    )
    list[#list + 1] =
      button('field_spawn_' .. entry.id .. '_1', Text.get('fui_one'), 410, y, 86, 44)
    list[#list + 1] =
      button('field_spawn_' .. entry.id .. '_3', Text.get('fui_three'), 508, y, 108, 44)
  end
  local items = {
    { 'field_refill', Text.get('fui_refill') },
    { 'field_reset', Text.get('fui_reset_field') },
    {
      'field_god',
      Text.get('fui_god', { state = Text.get(t.invincible and 'fui_on' or 'fui_off') }),
    },
    {
      'field_freeze',
      Text.get('fui_freeze', { state = Text.get(t.frozen and 'fui_stop' or 'fui_live') }),
    },
  }
  -- One button per weapon of the knight's loadout (slot order).
  for _, weapon in ipairs(Field.weapons(g)) do
    items[#items + 1] = {
      'field_weapon_' .. weapon.id,
      Text.get('fui_weapon', { slot = weapon.id, name = Text.get(weapon.name) }),
    }
  end
  for _, item in ipairs({
    { 'field_pose_prev', Text.get('fui_pose_prev') },
    { 'field_pose_next', Text.get('fui_pose_next') },
    { 'field_shop', Text.get('fui_shop'), 'trade' },
    { 'field_low', Text.get('fui_low') },
  }) do
    items[#items + 1] = item
  end
  for i, item in ipairs(items) do
    if Access.allows(t, item[3]) then
      list[#list + 1] = button(
        item[1],
        item[2],
        654 + (i - 1) % 2 * 264,
        174 + math.floor((i - 1) / 2) * 52,
        250,
        44
      )
    end
  end
  -- 0.22 stations of the proving ground (seal visits remain in Field.visitSeal).
  for i, station in ipairs(Field.catalog.stationsFor(t)) do
    list[#list + 1] = button(
      'field_station_' .. station.id,
      Text.get(station.name),
      654 + (i - 1) * 176,
      511,
      162,
      44
    )
  end
  list[#list + 1] = button(
    'field_close',
    Text.get(Context.actor(g).hp <= 0 and 'fui_close_dead' or 'fui_close'),
    86,
    616,
    440,
    48
  )
  list[#list + 1] = button('field_archive', Text.get('fui_archive'), 550, 616, 250, 48)
  list[#list + 1] = button('field_leave', Text.get(g.view.fieldReturnLabel), 826, 616, 342, 48)
  list[#list + 1] = button(
    'field_hitboxes',
    Text.get('fui_hitboxes', { state = Text.get(t.hitboxes and 'fui_on' or 'fui_off') }),
    904,
    72,
    264,
    40
  )
  return list
end
function UI.heading(g, ui)
  Skin.panel(20, 16, 378, 64, 2, 9)
  box(ui, Text.get('fui_heading', { count = Queries.remaining(g) }), 35, 27, 348, 20, 14, C.gold)
  local t = Queries.field(g)
  box(
    ui,
    Text.get('fui_heading_state', {
      damage = Text.get(t.invincible and 'fui_invincible' or 'fui_damage_on'),
      ai = Text.get(t.frozen and 'fui_ai_stop' or 'fui_ai_live'),
    }),
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
  local t = Queries.field(g)
  box(ui, Text.get('fui_title'), 86, 72, 610, 42, 36, C.gold)
  box(ui, t.message or Text.get('fui_intro'), 86, 120, 1082, 26, 18, C.ivory)
  box(ui, Text.get('fui_demons'), 86, 148, 530, 22, 16, C.muted)
  box(ui, Text.get('fui_tools'), 654, 148, 514, 22, 16, C.muted)
  for i, entry in ipairs(Field.catalog.enemies) do
    local y = 174 + (i - 1) * 48
    ui.face(entry.id, 86, y, 44, 44, 'field enemy ' .. entry.id)
  end
  local entry = Defs[t.selected]
  local count = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      count = count + 1
    end
  end
  box(ui, Text.get('fui_selected', { name = Text.get(entry.name) }), 86, 474, 530, 26, 18, C.gold)
  box(
    ui,
    Text.get('fui_entry', { hp = entry.hp, armor = entry.armor, pose = t.poseIndex }),
    86,
    505,
    530,
    22,
    16,
    C.ivory
  )
  box(
    ui,
    Text.get(
      'fui_live_targets',
      { count = count, limit = Field.limit, kills = Stats.total(g, 'kills') }
    ),
    86,
    535,
    530,
    22,
    16,
    C.muted
  )
  local arms = {}
  for slot = 1, Weapons.count(g, Context.actor(g)) do
    local mag, reserve = Weapons.meter(g, slot, Context.actor(g))
    arms[slot] = Text.get('fui_arm', {
      tab = Text.get(Weapons.profile(slot, g, Context.actor(g)).hud.tab),
      mag = mag,
      reserve = reserve,
    })
  end
  -- The ability on Q: uses left of its capacity.
  local ability, power = Abilities.slot(g, 1, Context.actor(g))
  local quick = ability
      and Text.get('fui_quick', { uses = power.uses or 0, capacity = ability.capacity })
    or ''
  box(
    ui,
    Text.get('fui_arms', { arms = table.concat(arms, ' / '), quick = quick }),
    654,
    439,
    514,
    22,
    14,
    C.ivory
  )
  local stations = Text.get('fui_stations')
  if t.features then
    local names = {}
    for _, station in ipairs(Field.catalog.stationsFor(t)) do
      names[#names + 1] = Text.get(station.name)
    end
    stations = Text.get('fui_available_stations', { names = table.concat(names, ', ') })
  end
  box(ui, stations, 654, 476, 514, 22, 16, C.muted)
  ShotReport.draw(g.view.shotReport, ui)
end
function UI.ending(g, ui)
  lg.setColor(0.015, 0.013, 0.017, 0.95)
  lg.rectangle('fill', 0, 0, 1280, 720)
  Skin.panel(280, 106, 720, 560, 5, 14)
  box(ui, Text.get('fui_fell'), 328, 173, 624, 54, 36, C.gold)
  box(ui, Text.get('fui_fell_kept'), 328, 268, 624, 34, 22)
  box(ui, Text.get('fui_fell_tip'), 328, 320, 624, 30, 18, C.muted)
  box(
    ui,
    Text.get('fui_fell_stats', {
      kills = Stats.total(g, 'kills'),
      damage = math.floor(Stats.total(g, 'damageTaken')),
      control = math.floor(100 * require('src.combat.telemetry').uptime(g) + 0.5),
    }),
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
  box(ui, Text.get('fui_map_title'), 132, 84, 1016, 46, 36, C.gold)
  box(ui, Text.get('fui_map_arena'), 132, 163, 440, 34, 22)
  box(ui, Text.get('fui_map_tip'), 132, 208, 440, 30, 18, C.muted)
  for i, seal in ipairs(g.world.seals) do
    Goetia.draw(seal.id, 140, 278 + (i - 1) * 74, 44, Palette.sepia, 0.95)
    Skin.imageBounds('field map seal ' .. Text.get(seal.name), 140, 278 + (i - 1) * 74, 44, 44)
    box(ui, Text.get(seal.name), 206, 288 + (i - 1) * 74, 344, 28, 20, seal.color)
  end
  box(ui, Text.get('fui_map_legend'), 132, 535, 440, 28, 16, C.ivory)
  box(ui, Text.get('fui_map_pause'), 132, 573, 440, 26, 16, C.muted)
  local sz, ox, oy = 420 / Grid.span(g.world), 652, 121
  for z = 1, Grid.depth(g.world) do
    for x = 1, Grid.width(g.world) do
      if Tiles.walkable[g.world.map[z][x]] then
        lg.setColor(0.20, 0.18, 0.16)
        lg.rectangle('fill', ox + x * sz, oy + z * sz, sz - 1, sz - 1)
      end
    end
  end
  for _, seal in ipairs(g.world.seals) do
    lg.setColor(seal.color)
    lg.circle('line', ox + seal.x * sz, oy + seal.z * sz, 9)
  end
  local p = Context.actor(g)
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

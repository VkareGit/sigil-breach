local Telemetry = require('src.combat.telemetry')
local Tiles = require('src.core.tiles')
local Context = require('src.session.context')
local UI = {}
local Stats = require('src.session.stats')
local Field = require('src.run.test_field')
local Skin = require('src.ui.skin')
local GoeticSigils = require('src.ui.goetic_sigils')
local Defs = require('src.content.enemy_catalog')
local lg = love.graphics
local C = Skin.colors
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local ShotReport = require('src.ui.shot_report')
local Palette = require('src.ui.palette')
local Pools = require('src.session.world')
local Grid = require('src.physics.grid')
local Queries = require('src.session.queries')
local FieldData = require('src.content.field')
local Text = require('src.content.text')
local Access = require('src.run.field.access')
local ProvingPage = require('src.content.screens.proving')
local FrameSize = require('src.content.ui_layout')
local function box(ui, label, x, y, w, h, size, color)
  -- Step the size down if the illustrated glyphs would overrun the field.
  -- Only sizes that exist in the painted font (36 steps to 28, not 34).
  size = size or ProvingPage.font
  local steps = ProvingPage.fonts
  local smallest = steps[#steps]
  for _, s in ipairs(steps) do
    if s <= size and (Skin.inkBounds(ui.fonts[s], label).w <= w or s == smallest) then
      size = s
      break
    end
  end
  Skin.zone('field ' .. label, x, y, w, h)
  Skin.boxText(label, x, y, w, h, ui.fonts[size], color or C.ivory)
  Skin.endZone()
end
local function button(id, label, x, y, w, h)
  return { id = id, label = label, x = x, y = y, w = w, h = h or ProvingPage.buttonHeight }
end
-- A text on its box (content/screens/proving.lua), dy lower.
local function put(ui, label, spec, color, dy)
  box(ui, label, spec[1], spec[2] + (dy or 0), spec[3], spec[4], spec.font, color)
end
local function at(id, label, b)
  return button(id, label, b[1], b[2], b[3], b[4])
end
local function veil(color)
  lg.setColor(color[1], color[2], color[3], color[4])
  lg.rectangle('fill', 0, 0, FrameSize.width, FrameSize.height)
end
function UI.controls(g)
  local t = Queries.field(g)
  if not t or g.help or g.map then
    return nil
  end
  if g.state == 'dead' then
    local D = ProvingPage.dead
    return {
      at(
        t.skirmish and 'field_skirmish' or 'field_reset',
        Text.get(t.skirmish and 'fui_retry_skirmish' or 'fui_reset'),
        D.retry
      ),
      at('field_open', Text.get('fui_catalogue'), D.catalogue),
      at('field_leave', Text.get(g.view.fieldReturnLabel), D.leave),
    }
  end
  if g.state ~= 'field_catalog' then
    return nil
  end
  local list = {}
  local P = ProvingPage
  for i, entry in ipairs(Field.catalog.enemies) do
    local y = P.rows.y + (i - 1) * P.rows.step
    list[#list + 1] = button(
      'field_select_' .. entry.id,
      t.selected == entry.id and Text.get('fui_selected_mark', { name = Text.get(entry.name) })
        or Text.get(entry.name),
      P.select.x,
      y,
      P.select.w
    )
    list[#list + 1] =
      button('field_spawn_' .. entry.id .. '_1', Text.get('fui_one'), P.one.x, y, P.one.w)
    list[#list + 1] =
      button('field_spawn_' .. entry.id .. '_3', Text.get('fui_three'), P.three.x, y, P.three.w)
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
      local T = P.tools
      list[#list + 1] = button(
        item[1],
        item[2],
        T.x + (i - 1) % 2 * T.column,
        T.y + math.floor((i - 1) / 2) * T.row,
        T.w
      )
    end
  end
  -- 0.22 stations of the proving ground (seal visits remain in Field.visitSeal).
  for i, station in ipairs(Field.catalog.stationsFor(t)) do
    local S = P.stations
    list[#list + 1] = button(
      'field_station_' .. station.id,
      Text.get(station.name),
      S.x + (i - 1) * S.step,
      S.y,
      S.w
    )
  end
  list[#list + 1] = at(
    'field_close',
    Text.get(Context.actor(g).hp <= 0 and 'fui_close_dead' or 'fui_close'),
    P.close
  )
  list[#list + 1] = at('field_archive', Text.get('fui_archive'), P.archive)
  list[#list + 1] = at('field_leave', Text.get(g.view.fieldReturnLabel), P.leave)
  list[#list + 1] = at(
    'field_hitboxes',
    Text.get('fui_hitboxes', { state = Text.get(t.hitboxes and 'fui_on' or 'fui_off') }),
    P.hitboxes
  )
  return list
end
function UI.heading(g, ui)
  local plate = ProvingPage.plate
  Skin.panel(plate[1], plate[2], plate[3], plate[4], 2, plate.corner)
  put(ui, Text.get('fui_heading', { count = Queries.remaining(g) }), ProvingPage.heading, C.gold)
  local t = Queries.field(g)
  put(
    ui,
    Text.get('fui_heading_state', {
      damage = Text.get(t.invincible and 'fui_invincible' or 'fui_damage_on'),
      ai = Text.get(t.frozen and 'fui_ai_stop' or 'fui_ai_live'),
    }),
    ProvingPage.state,
    C.ivory
  )
end
function UI.draw(g, ui)
  local P = ProvingPage
  veil(P.veil)
  Skin.panel(P.page[1], P.page[2], P.page[3], P.page[4], 6, P.page.corner)
  local t = Queries.field(g)
  put(ui, Text.get('fui_title'), P.title, C.gold)
  put(ui, t.message or Text.get('fui_intro'), P.intro, C.ivory)
  put(ui, Text.get('fui_demons'), P.demons, C.muted)
  put(ui, Text.get('fui_tools'), P.toolsTitle, C.muted)
  for i, entry in ipairs(Field.catalog.enemies) do
    local y = P.rows.y + (i - 1) * P.rows.step
    ui.face(entry.id, P.face.x, y, P.face.side, P.face.side, 'field enemy ' .. entry.id)
  end
  local entry = Defs[t.selected]
  local count = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      count = count + 1
    end
  end
  put(ui, Text.get('fui_selected', { name = Text.get(entry.name) }), P.selected, C.gold)
  put(
    ui,
    Text.get('fui_entry', { hp = entry.hp, armor = entry.armor, pose = t.poseIndex }),
    P.entry,
    C.ivory
  )
  put(
    ui,
    Text.get(
      'fui_live_targets',
      { count = count, limit = Field.limit, kills = Stats.total(g, 'kills') }
    ),
    P.live,
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
  put(
    ui,
    Text.get('fui_arms', { arms = table.concat(arms, ' / '), quick = quick }),
    P.arms,
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
  put(ui, stations, P.stationNames, C.muted)
  ShotReport.draw(g.view.shotReport, ui)
end
function UI.ending(g, ui)
  local E = ProvingPage.ending
  veil(E.veil)
  Skin.panel(E.page[1], E.page[2], E.page[3], E.page[4], 5, E.page.corner)
  put(ui, Text.get('fui_fell'), E.fell, C.gold)
  put(ui, Text.get('fui_fell_kept'), E.kept)
  put(ui, Text.get('fui_fell_tip'), E.tip, C.muted)
  put(
    ui,
    Text.get('fui_fell_stats', {
      kills = Stats.total(g, 'kills'),
      damage = math.floor(Stats.total(g, 'damageTaken')),
      control = math.floor(100 * Telemetry.uptime(g) + 0.5), -- constant: a percent
    }),
    E.stats,
    C.ivory
  )
end
function UI.map(g, ui)
  local M = ProvingPage.map
  veil(M.veil)
  Skin.panel(M.page[1], M.page[2], M.page[3], M.page[4], 5, M.page.corner)
  put(ui, Text.get('fui_map_title'), M.title, C.gold)
  put(ui, Text.get('fui_map_arena'), M.arena)
  put(ui, Text.get('fui_map_tip'), M.tip, C.muted)
  local S = M.seal
  for i, seal in ipairs(g.world.seals) do
    local y = S.y + (i - 1) * S.step
    GoeticSigils.draw(seal.id, S.x, y, S.side, Palette.sepia, S.alpha)
    Skin.imageBounds('field map seal ' .. Text.get(seal.name), S.x, y, S.side, S.side)
    put(ui, Text.get(seal.name), M.sealName, seal.color, (i - 1) * S.step)
  end
  put(ui, Text.get('fui_map_legend'), M.legend, C.ivory)
  put(ui, Text.get('fui_map_pause'), M.pause, C.muted)
  local sz, ox, oy = M.side / Grid.span(g.world), M.origin[1], M.origin[2]
  for z = 1, Grid.depth(g.world) do
    for x = 1, Grid.width(g.world) do
      if Tiles.walkable[g.world.map[z][x]] then
        local stone = Palette.stone
        lg.setColor(stone[1], stone[2], stone[3])
        lg.rectangle('fill', ox + x * sz, oy + z * sz, sz - 1, sz - 1)
      end
    end
  end
  for _, seal in ipairs(g.world.seals) do
    lg.setColor(seal.color)
    lg.circle('line', ox + seal.x * sz, oy + seal.z * sz, M.sealRing)
  end
  local p = Context.actor(g)
  local K = M.knight
  lg.setColor(C.ivory)
  lg.circle('fill', ox + p.x * sz, oy + p.z * sz, K.radius)
  lg.line(
    ox + p.x * sz,
    oy + p.z * sz,
    ox + p.x * sz + math.sin(p.yaw) * K.heading,
    oy + p.z * sz + math.cos(p.yaw) * K.heading
  )
  local mark = M.enemy
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      lg.setColor(C.red)
      lg.rectangle('fill', ox + e.x * sz - mark / 2, oy + e.z * sz - mark / 2, mark, mark)
    end
  end
end
return UI

local U = { focus = 1, mouseX = -1, mouseY = -1 }
local lg = love.graphics
local T = require('src.content.tuning')
local Reload = require('src.combat.reload')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Skin = require('src.ui.skin')
local Goetia = require('src.ui.goetic_sigils')
local FieldUI = require('src.ui.test_field')
local HUD = require('src.ui.hud')
local D = require('src.ui.descent')
local Palette = require('src.ui.palette')
local Camera = require('src.render.camera')
D.install(U)
local ivory = Skin.colors.ivory
local muted = Skin.colors.muted
local gold = Skin.colors.gold
local red = Skin.colors.red
local blue = Skin.colors.blue
local green = Palette.green
local Views = require('src.ui.views')
local Kit = require('src.ui.kit')
Kit.ui = U
local c = Kit.c
function U.init()
  Skin.init()
  require('src.ui.portrait').init()
  U.fonts = {}
  local Bitmap = require('src.ui.fonts.bitmap_font')
  for _, size in ipairs({ 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 36, 42, 48, 64, 94 }) do
    local font = Bitmap.load(size)
    assert(
      font:hasGlyphs('ąćęłńóśźż ĄĆĘŁŃÓŚŹŻ 0123456789'),
      'Missing painted Polish UI glyphs'
    )
    U.fonts[size] = font
    Skin.registerFont(font)
  end
  U.faces = {}
  U.faceQuads = {}
  local catalog = require('src.render.fresco_enemies')
  for _, kind in ipairs(catalog.kinds) do
    local entry = catalog.entries[kind]
    local img = lg.newImage(entry.path)
    img:setFilter('linear', 'linear')
    U.faces[kind] = img
    local w, h = img:getDimensions()
    local rows = entry.bands and (type(entry.bands[1]) == 'table' and entry.bands[1] or entry.bands)
    local columns = entry.columnBands and entry.columnBands[1]
    local left, top = columns and columns[1] or 0, rows and rows[1] or 0
    local right, bottom =
      columns and columns[2] or w / entry.columns, rows and rows[2] or h / entry.rows
    U.faceQuads[kind] = lg.newQuad(left, top, right - left, bottom - top, w, h)
  end
end
function U.face(kind, x, y, w, h, label)
  local q = U.faceQuads[kind]
  local _, _, qw, qh = q:getViewport()
  local scale = math.min(w / qw, h / qh)
  local dw, dh = qw * scale, qh * scale
  x, y = x + (w - dw) / 2, y + (h - dh) / 2
  lg.setColor(1, 1, 1)
  lg.draw(U.faces[kind], q, x, y, 0, scale, scale)
  Skin.imageBounds(label or ('bestiary ' .. kind), x, y, dw, dh)
end
local function alive(g)
  local n = 0
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      n = n + 1
    end
  end
  return n
end
function U.objective(g)
  if g.testField then
    return 'PROVING GROUND / [F2] Trial catalogue'
  end
  if g.run then
    return D.objective(g)
  end
  if g.bossDead then
    return 'Return to the gate and end the trial.'
  end
  if g.seals < 3 then
    return 'Break the court seals  ' .. g.seals .. ' / 3'
  end
  if not g.bossSpawned then
    return 'Defeat the remaining defenders: ' .. alive(g)
  end
  return 'Destroy the Margrave of Ash.'
end
-- The screens live in ui/screens/ (0.24 F7); these names stay for callers.
function U.hud(g, s)
  return require('src.ui.screens.hud').draw(g, s, U)
end
function U.map(g)
  return require('src.ui.screens.map').draw(g, nil, U)
end
function U.menu(g)
  return require('src.ui.screens.menu').draw(g, nil, U)
end
function U.pause(g, s)
  return require('src.ui.screens.pause').draw(g, s, U)
end
function U.helpPanel(g)
  return require('src.ui.screens.help').draw(g, nil, U)
end
function U.ending(g)
  return require('src.ui.screens.ending').draw(g, nil, U)
end
-- The buttons of the current screen (ui/views.lua: its providers).
function U.controls(g, s)
  return Views.controls(g, s)
end
function U.viewport(w, h)
  return require('src.ui.layout').viewport(w, h)
end
function U.toLogical(x, y, w, h)
  local scale, ox, oy = U.viewport(w, h)
  return (x - ox) / scale, (y - oy) / scale
end
function U.hover(x, y)
  U.mouseX = x
  U.mouseY = y
  U.useMouse = true
end
function U.actionAt(g, s, x, y)
  for i, b in ipairs(U.controls(g, s)) do
    if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
      U.focus = i
      return b.id
    end
  end
end
function U.navigate(g, s, delta)
  U.useMouse = false
  local n = #U.controls(g, s)
  if n > 0 then
    U.focus = (U.focus - 1 + delta) % n + 1
  end
end
function U.selected(g, s)
  local list = U.controls(g, s)
  return list[U.focus] and list[U.focus].id
end
local function buttons(g, s)
  if U.useMouse then
    U.actionAt(g, s, U.mouseX, U.mouseY)
  end
  for i, b in ipairs(U.controls(g, s)) do
    local selected = i == U.focus
    Skin.panel(b.x, b.y, b.w, b.h, b.disabled and 4 or ((selected or b.active) and 3 or 2), 8)
    if selected then
      c(gold)
      lg.polygon(
        'fill',
        b.x + 10,
        b.y + b.h / 2 - 4,
        b.x + 16,
        b.y + b.h / 2,
        b.x + 10,
        b.y + b.h / 2 + 4
      )
    end
    local size = b.w < 60 and 24 or 18
    while
      size > 12
      and (
        Skin.inkBounds(U.fonts[size], b.label).w > b.w - (b.w < 60 and 22 or 40)
        or Skin.inkBounds(U.fonts[size], b.label).h > b.h - 22
      )
    do
      size = size - 2
    end
    Skin.zone('button ' .. b.id, b.x + 10, b.y + 10, b.w - 20, b.h - 20)
    local inset = b.w < 60 and 11 or 24
    Skin.boxText(
      b.label,
      b.x + inset,
      b.y + 11,
      b.w - inset - 12,
      b.h - 22,
      U.fonts[size],
      b.disabled and Palette.disabled or (selected and ivory or (b.active and gold or muted)),
      b.w < 60
    )
    Skin.endZone()
  end
end
function U.draw(g, w, h, s)
  s = s or { sensitivity = 1, motion = true, music = 0.65 }
  U.aimX, U.aimY = nil, nil
  if g.state == 'playing' then
    U.aimX, U.aimY = Camera.reticle(g, w, h)
  end
  local screen = g.help and 'help' or (g.map and 'map' or g.state)
  if U.screen ~= screen then
    U.screen = screen
    U.focus = 1
  end
  if U.useMouse then
    U.actionAt(g, s, U.mouseX, U.mouseY)
  end
  Skin.beginAudit(screen, w, h)
  local scale, ox, oy = U.viewport(w, h)
  if g.state ~= 'playing' or g.help or g.map then
    -- The page occupies the logical 16:9 writing area. Modal gutters belong to
    -- its dark surround too; never leave bright live scenery beside the page.
    local vw, vh = 1280 * scale, 720 * scale
    lg.setColor(0.015, 0.013, 0.017, 1)
    if ox > 0 then
      lg.rectangle('fill', 0, 0, ox, h)
      lg.rectangle('fill', ox + vw, 0, w - ox - vw, h)
    end
    if oy > 0 then
      lg.rectangle('fill', ox, 0, vw, oy)
      lg.rectangle('fill', ox, oy + vh, vw, h - oy - vh)
    end
  end
  lg.push()
  lg.translate(ox, oy)
  lg.scale(scale)
  lg.setLineStyle('rough')
  lg.setLineWidth(2)
  -- The screen's own page (ui/views.lua), then the overlays.
  Views.of(g).draw(g, s, U)
  if g.map then
    Skin.auditLayer('map')
    Views.overlays.map(g, s, U)
  end
  if g.help then
    Views.overlays.help(g, s, U)
  end
  buttons(g, s)
  lg.pop()
  lg.setColor(1, 1, 1)
  Skin.endAudit()
end
return U

local FrescoEnemies = require('src.render.fresco_enemies')
local BitmapFont = require('src.ui.fonts.bitmap_font')
local PaintedNumbers = require('src.ui.fonts.painted_numbers')
local PaintedTitles = require('src.ui.fonts.painted_titles')
local GoeticSigils = require('src.ui.goetic_sigils')
local Hud = require('src.ui.hud')
local Ink = require('src.ui.ink')
local Layout = require('src.ui.layout')
local OccultPlates = require('src.ui.occult_plates')
local Portrait = require('src.ui.portrait')
local Reliquary = require('src.ui.reliquary')
local Ending = require('src.ui.screens.ending')
local Help = require('src.ui.screens.help')
local Menu = require('src.ui.screens.menu')
local Pause = require('src.ui.screens.pause')
local U = { focus = 1, mouseX = -1, mouseY = -1 }
local lg = love.graphics
local Skin = require('src.ui.skin')
local Chapel = require('src.ui.chapel')
local Palette = require('src.ui.palette')
local Resources = require('src.render.resources')
local Camera = require('src.render.camera')
local TextFit = require('src.ui.text_fit')
Chapel.install(U)
local ivory = Skin.colors.ivory
local muted = Skin.colors.muted
local gold = Skin.colors.gold
local red = Skin.colors.red
local blue = Skin.colors.blue
local green = Palette.green
local Views = require('src.ui.views')
local Kit = require('src.ui.kit')
local Queries = require('src.session.queries')
Kit.ui = U
local c = Kit.c
function U.release()
  for _, font in pairs(U.fonts or {}) do
    if Skin.fontTops then
      Skin.fontTops[font] = nil
    end
    font:release()
  end
  if U.faceResources then
    U.faceResources:release()
  end
  U.fonts, U.faces, U.faceQuads, U.faceResources = nil, nil, nil, nil
end
function U.init(checkpoint)
  U.release()
  Skin.init()
  Portrait.init(checkpoint)
  U.fonts = {}
  for _, size in ipairs({ 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 36, 42, 48, 64, 94 }) do
    local font = BitmapFont.load(size, checkpoint)
    assert(
      font:hasGlyphs('ąćęłńóśźż ĄĆĘŁŃÓŚŹŻ 0123456789'),
      'Missing painted Polish UI glyphs'
    )
    U.fonts[size] = font
    Skin.registerFont(font)
  end
  Skin.useFonts(U.fonts)
  -- HUD numerals are part of the UI load, not a surprise upload when the
  -- first catalogue closes and gameplay becomes visible.
  PaintedNumbers.init(checkpoint)
  U.faces = {}
  U.faceQuads = {}
  U.faceResources = Resources.new('UI creature portraits', checkpoint)
  for _, kind in ipairs(FrescoEnemies.kinds) do
    local entry = FrescoEnemies.entries[kind]
    local img = U.faceResources:image(entry.path, { filter = 'linear' })
    U.faces[kind] = img
    local w, h = img:getDimensions()
    local rows = entry.bands and (type(entry.bands[1]) == 'table' and entry.bands[1] or entry.bands)
    local columns = entry.columnBands and entry.columnBands[1]
    local left, top = columns and columns[1] or 0, rows and rows[1] or 0
    local right, bottom =
      columns and columns[2] or w / entry.columns, rows and rows[2] or h / entry.rows
    U.faceQuads[kind] = U.faceResources:own(lg.newQuad(left, top, right - left, bottom - top, w, h))
  end
  U.faceResources.checkpoint = nil
end
-- Application lifetime ends after renderers stop borrowing historical seals.
-- Ordinary UI reinitialization only releases its fonts and bestiary faces.
function U.shutdown()
  U.release()
  OccultPlates.release()
  Portrait.release()
  Reliquary.release()
  PaintedTitles.release()
  PaintedNumbers.release()
  Ink.release()
  GoeticSigils.release()
  Skin.release()
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
-- What the session's mode asks of the player now (session/queries.lua).
function U.objective(g)
  return Queries.objective(g)
end
-- The screens live in ui/screens/ (0.24 F7); these names stay for callers.
function U.hud(g, s)
  return Hud.draw(g, s, U, Chapel)
end
function U.map(g)
  return Chapel.map(g)
end
function U.menu(g)
  return Menu.draw(g, nil, U)
end
function U.pause(g, s)
  return Pause.draw(g, s, U)
end
function U.helpPanel(g)
  return Help.draw(g, nil, U)
end
function U.ending(g)
  return Ending.draw(g, nil, U)
end
-- The buttons of the current screen (ui/views.lua: its providers).
function U.controls(g, s)
  return Views.controls(g, s)
end
function U.viewport(w, h)
  return Layout.viewport(w, h)
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
      TextFit.ellipsis(U.fonts[size], b.label, b.w - inset - 12),
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

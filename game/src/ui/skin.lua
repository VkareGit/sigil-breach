-- Generated bitmap atlas, measured once and assembled as nine-slice frames.
-- Live prices and Polish strings are assembled from a permanently painted PNG alphabet.
local Release = require('src.app.release')
local PaintedTitles = require('src.ui.fonts.painted_titles')
local Ink = require('src.ui.ink')
local Reliquary = require('src.ui.reliquary')
local SkinLook = require('src.content.ui_look').skin
local S = {
  -- The interface palette (ui/palette.lua).
  colors = require('src.ui.palette'),
  -- The painted interface atlas the frames and icons are cut from.
  path = SkinLook.path,
}
local lg = love.graphics
local Resources = require('src.render.resources')
local Text = require('src.content.text')
local Weapons = require('src.content.weapons')
local WeaponArtwork = require('src.content.weapon_art')
-- The shop's weapon card sheet holds this many cards side by side.
local CARD_CELLS = 2
local names = {
  'health',
  'armor',
  'soul',
  'essence',
  'ammo',
  'revolver',
  'dash',
  'skull',
  'choke',
  'pierce',
  'shrine',
  'ring',
}
-- Icons painted one per file (assets/art/icons, by Codex, provenance.json beside them), loaded
-- with the skin, never on the first frame that shows one.
local PAINTED = 'assets/art/icons/'
local SEALS = 'assets/art/sigils/'
local painted = {}
function S.init()
  if S.image then
    return
  end
  local data = love.image.newImageData(S.path)
  local w, h = data:getDimensions()
  S.resources = Resources.new('UI skin')
  S.image = S.resources:image(S.path, nil, data)
  S.weaponCards = S.resources:image(SkinLook.cards)
  S.weaponCardQuads = {}
  local cw, ch = S.weaponCards:getDimensions()
  local cell = cw / CARD_CELLS
  for i = 1, CARD_CELLS do
    S.weaponCardQuads[i] = S.resources:own(lg.newQuad((i - 1) * cell, 0, cell, ch, cw, ch))
  end
  S.image:setFilter('nearest', 'nearest')
  S.frames = {}
  S.icons = {}
  S.bounds = {}
  local side, rowCuts, bandCuts = SkinLook.side, SkinLook.rowCuts, SkinLook.bands
  for index = 0, 15 do -- constant: a sheet of four by four cells
    local col, row = index % 4, math.floor(index / 4)
    local cuts = row == 2 and { 0, rowCuts[1] / side, rowCuts[2] / side, rowCuts[3] / side, 1 }
      or { 0, 1 / 4, 2 / 4, 3 / 4, 1 }
    local left, right = math.floor(cuts[col + 1] * w), math.floor(cuts[col + 2] * w) - 1
    -- Authored rows have unequal gutters. These bands exclude the next row's icon tips.
    local third = col == 3 and SkinLook.lastBand or bandCuts[3]
    local bands = { 0, bandCuts[1] / side, bandCuts[2] / side, third / side, 1 }
    local top, bottom = math.floor(bands[row + 1] * h), math.floor(bands[row + 2] * h) - 1
    local x1, y1, x2, y2 = right, bottom, left, top
    for y = top, bottom do
      for x = left, right do
        local _, _, _, a = data:getPixel(x, y)
        if a > SkinLook.painted then
          x1 = math.min(x1, x)
          y1 = math.min(y1, y)
          x2 = math.max(x2, x)
          y2 = math.max(y2, y)
        end
      end
    end
    assert(x2 > x1 and y2 > y1, 'Empty UI atlas cell ' .. index)
    local bw, bh = x2 - x1 + 1, y2 - y1 + 1
    S.bounds[index + 1] = { x = x1, y = y1, w = bw, h = bh }
    if index < 4 then
      local cut = math.floor(math.min(bw, bh) * SkinLook.corner)
      local frame = {}
      local xs = { x1, x1 + cut, x2 + 1 - cut }
      local ys = { y1, y1 + cut, y2 + 1 - cut }
      local ws = { cut, bw - 2 * cut, cut }
      local hs = { cut, bh - 2 * cut, cut }
      for iy = 1, 3 do
        for ix = 1, 3 do
          frame[#frame + 1] = {
            q = S.resources:own(lg.newQuad(xs[ix], ys[iy], ws[ix], hs[iy], w, h)),
            w = ws[ix],
            h = hs[iy],
          }
        end
      end
      S.frames[index + 1] = frame
    else
      S.icons[names[index - 3]] =
        { q = S.resources:own(lg.newQuad(x1, y1, bw, bh, w, h)), w = bw, h = bh }
    end
  end
  data:release()
  for _, file in ipairs(love.filesystem.getDirectoryItems(PAINTED)) do
    local name = file:match('^(.+)%.png$')
    if name then
      painted[name] = S.resources:image(PAINTED .. file, { mipmaps = true })
    end
  end
  -- The seals of the Goetia (assets/art/sigils, 1904 plates) are the icons of the sigils
  -- sold at a fire (0.42): stolas-1904.png is the icon sigil_stolas.
  for _, file in ipairs(love.filesystem.getDirectoryItems(SEALS)) do
    local name = file:match('^(%a+)%-.*%.png$')
    if name then
      painted['sigil_' .. name] = S.resources:image(SEALS .. file, { mipmaps = true })
    end
  end
end
function S.release()
  if S.resources then
    S.resources:release()
  end
  S.resources, S.image, S.frames, S.icons, S.bounds, S.fontTops, S.fields =
    nil, nil, nil, nil, nil, nil, nil
  painted = {}
  S.weaponCards, S.weaponCardQuads = nil, nil
end
-- A weapon's card is its art's cell on the card sheet (content/art/weapon_frames.lua).
function S.cardCell(id)
  local def = Weapons.get(id)
  local cell = WeaponArtwork.get(def.art or def.id).card
  assert(
    type(cell) == 'number' and cell >= 1 and cell <= CARD_CELLS and cell % 1 == 0,
    'weapon ' .. id .. ': its art has no cell on the shop card sheet'
  )
  return cell
end
function S.weaponCard(id, x, y, width, height)
  local w, h = S.weaponCards:getDimensions()
  lg.setColor(1, 1, 1)
  lg.draw(
    S.weaponCards,
    S.weaponCardQuads[S.cardCell(id)],
    x,
    y,
    0,
    width / (w / CARD_CELLS),
    height / h
  )
end
local function record(kind, label, x, y, w, h)
  if not S.audit then
    return
  end
  local a = S.audit
  a.items[#a.items + 1] =
    { kind = kind, label = label, x = x, y = y, w = w, h = h, zone = a.zones[#a.zones] }
end
function S.panel(x, y, w, h, style, border)
  S.lightField(x, y, w, h)
  record('panel', 'painted panel', x, y, w, h)
  return Reliquary.panel(x, y, w, h, border, style)
end
function S.lightField(x, y, w, h)
  S.fields = S.fields or {}
  S.fields[#S.fields + 1] = { x = x, y = y, w = w, h = h }
end
function S.onLightField(x, y)
  for i = #(S.fields or {}), 1, -1 do
    local r = S.fields[i]
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
      return true
    end
  end
  return false
end
function S.registerFont(font)
  -- The exporter records the visible cap position, including the painted rim.
  assert(font.image and font.meta, 'GUI requires a painted PNG font')
  S.fontTops = S.fontTops or {}
  S.fontTops[font] = font.meta.top
end
function S.beginAudit(name, w, h)
  S.fields = {}
  if not S.forceAudit and os.getenv('SIGIL_UI_AUDIT') ~= '1' then
    return
  end
  S.audit = { name = name .. ' ' .. w .. 'x' .. h, items = {}, zones = {} }
end
function S.auditLayer(name)
  -- A modal first covers the previous layer. Its dark surround must not inherit
  -- the HUD's light-field classification when choosing caption ink.
  S.fields = {}
  if S.audit then
    S.audit.items = {}
    S.audit.zones = {}
    S.audit.name = S.audit.name .. ' / ' .. name
  end
end
function S.zone(name, x, y, w, h)
  if S.audit then
    local zones = S.audit.zones
    zones[#zones + 1] = { name = name, x = x, y = y, w = w, h = h }
  end
end
function S.endZone()
  if S.audit then
    table.remove(S.audit.zones)
  end
end
local function measuredInk(font, t)
  return font:getInk(t)
end
function S.inkBounds(font, t)
  return measuredInk(font, t)
end
function S.boxText(t, x, y, w, h, font, color, centered)
  local b = measuredInk(font, t)
  local tx = x - b.x + (centered and math.floor((w - b.w) / 2) or 0)
  local ty = y + math.floor((h - b.h) / 2) - b.y + (S.fontTops[font] or 0)
  S.text(t, tx, ty, font, color)
end
function S.auditProblems(a)
  local failures = {}
  local checked = 0
  for i, v in ipairs(a.items) do
    local z = v.zone
    -- A word cut short is a word the player cannot read: no caption may need an ellipsis.
    if v.kind == 'text' and tostring(v.label):sub(-3) == '...' then
      failures[#failures + 1] = string.format('ELIDED %s: %s', z and z.name or a.name, v.label)
    end
    if z and v.kind ~= 'panel' then
      checked = checked + 1
      if v.x < z.x or v.y < z.y or v.x + v.w > z.x + z.w or v.y + v.h > z.y + z.h then
        failures[#failures + 1] = string.format(
          'INTERIOR %s: %s [%g,%g..%g,%g] safe [%g,%g..%g,%g]',
          z.name,
          v.label,
          v.x,
          v.y,
          v.x + v.w,
          v.y + v.h,
          z.x,
          z.y,
          z.x + z.w,
          z.y + z.h
        )
      end
    end
    for j = 1, i - 1 do
      local u = a.items[j]
      if
        (
          (v.kind == 'panel' and u.kind == 'text')
          or (u.kind ~= 'panel' and v.kind ~= 'panel' and (u.kind == 'text' or v.kind == 'text'))
        )
        and v.x < u.x + u.w
        and u.x < v.x + v.w
        and v.y < u.y + u.h
        and u.y < v.y + v.h
      then
        failures[#failures + 1] = string.format(
          (
            v.kind == 'panel' and 'COVERED BY LATER PANEL %s / %s (vertical %g..%g / %g..%g)'
            or 'COLLISION %s / %s (vertical %g..%g / %g..%g)'
          ),
          u.label,
          v.label,
          u.y,
          u.y + u.h,
          v.y,
          v.y + v.h
        )
      end
    end
  end
  return failures, checked
end
function S.endAudit()
  local a = S.audit
  if not a then
    return
  end
  S.audit = nil
  local failures, checked = S.auditProblems(a)
  local path = (S.auditOutput or Release.output()) .. '/ui-layout-audit.txt'
  local f = assert(io.open(path, 'a'))
  f:write(
    a.name
      .. ': '
      .. #a.items
      .. ' ink/indicator bounds, '
      .. checked
      .. ' interior checks, '
      .. #failures
      .. ' issues\n'
  )
  for _, v in ipairs(failures) do
    f:write('  ' .. v .. '\n')
  end
  f:close()
  S.auditFailureCount = (S.auditFailureCount or 0) + #failures
end
function S.text(t, x, y, font, color)
  -- No font rasterization at runtime: every visible stroke is a painted PNG quad.
  color = color or S.colors.ivory
  x = math.floor(x)
  y = math.floor(y) - (S.fontTops and S.fontTops[font] or 0)
  if S.audit then
    local b = measuredInk(font, t)
    record('text', t, x + b.x, y + b.y, b.w, b.h)
  end
  local b = measuredInk(font, t)
  local previous = lg.getShader()
  lg.setShader(Ink.ink(S.onLightField(x + b.x + b.w / 2, y + b.y + b.h / 2)))
  font:draw(t, x, y, color)
  lg.setShader(previous)
end
function S.imageBounds(label, x, y, w, h)
  record('image', label, x, y, w, h)
end
S.recordImage = S.imageBounds
-- The fonts a painted inscription falls back to (ui/interface.lua gives its
-- sizes once loaded).
function S.useFonts(fonts)
  S.fallbackFonts = fonts
end
-- The painted glyph font of this size, once the interface has loaded them
-- (nil before): the world's drawing reads it here, not from a screen.
function S.font(size)
  return S.fallbackFonts and S.fallbackFonts[size]
end
-- A painted inscription; one without a painting (none in the atlas, or a
-- language without its own: content/text.lua) is written in glyphs: the
-- largest font whose ink fits the field.
function S.inscription(name, x, y, w, h)
  local paintings = Text.paintings()
  local painted = paintings == true or (paintings and paintings[name])
  if not (painted and PaintedTitles.has(name)) then
    local font
    for _, size in ipairs(SkinLook.inscriptionSizes) do
      font = S.fallbackFonts and S.fallbackFonts[size]
      if font then
        local ink = measuredInk(font, Text.get('inscription_' .. name))
        if ink.w <= w and ink.h <= h then
          break
        end
      end
    end
    S.boxText(Text.get('inscription_' .. name), x, y, w, h, font, S.colors.gold, true)
    return x, y, w, h
  end
  local px, py, pw, ph =
    PaintedTitles.draw(name, x, y, w, h, nil, S.onLightField(x + w / 2, y + h / 2))
  S.imageBounds('painted inscription ' .. name, px, py, pw, ph)
  return px, py, pw, ph
end
-- A painted icon (loaded by S.init), drawn whole: a name the atlas does not have.
local function paintedIcon(name)
  return painted[name]
end
function S.hasIcon(name)
  return S.icons[name] ~= nil or paintedIcon(name) ~= nil
end
function S.icon(name, x, y, size, alpha)
  local image = not S.icons[name] and paintedIcon(name)
  if image then
    local w, h = image:getDimensions()
    local scale = size / math.max(w, h)
    local dw, dh = math.floor(w * scale + 0.5), math.floor(h * scale + 0.5)
    record('icon', name, x + (size - dw) / 2, y + (size - dh) / 2, dw, dh)
    local previous = lg.getShader()
    lg.setShader()
    lg.setColor(1, 1, 1, alpha or 1)
    lg.draw(image, math.floor(x + (size - dw) / 2), math.floor(y + (size - dh) / 2), 0, scale)
    lg.setShader(previous)
    lg.setColor(1, 1, 1)
    return
  end
  local icon = assert(S.icons[name], name)
  local scale = size / math.max(icon.w, icon.h)
  local dw, dh = math.floor(icon.w * scale + 0.5), math.floor(icon.h * scale + 0.5)
  record('icon', name, x + (size - dw) / 2, y + (size - dh) / 2, dw, dh)
  local previous = lg.getShader()
  lg.setShader()
  lg.setColor(1, 1, 1, alpha or 1)
  lg.draw(
    S.image,
    icon.q,
    math.floor(x + (size - dw) / 2),
    math.floor(y + (size - dh) / 2),
    0,
    dw / icon.w,
    dh / icon.h
  )
  lg.setShader(previous)
  lg.setColor(1, 1, 1)
end
function S.meter(x, y, w, value, color, segments)
  local M = SkinLook.meter
  record('meter', 'meter', x - 1, y - 1, w + 2, M.height)
  -- Pigment tally marks in the fresco margin. The empty portion is bare umber-
  -- washed plaster; no polished/enamel bevel competing with the painted frame.
  segments = segments or M.segments
  value = math.max(0, math.min(1, value))
  lg.setColor(M.plaster[1], M.plaster[2], M.plaster[3], 1)
  lg.rectangle('fill', x - 1, y - 1, w + 2, M.height)
  for i = 1, segments do
    local left = math.floor(x + (i - 1) * w / segments)
    local right = math.floor(x + i * w / segments) - 2
    local fill = math.max(0, math.min(1, value * segments - i + 1))
    lg.setColor(M.empty[1], M.empty[2], M.empty[3], 1)
    lg.rectangle('fill', left, y, right - left, M.mark)
    if fill > 0 then
      local fw = math.max(1, math.floor((right - left) * fill))
      local f, d = M.fill, M.foot
      lg.setColor(color[1] * f[1], color[2] * f[2], color[3] * f[3], 1)
      lg.rectangle('fill', left, y, fw, M.mark)
      lg.setColor(color[1] * d[1], color[2] * d[2], color[3] * d[3], 1)
      lg.rectangle('fill', left, y + M.mark - 1, fw, 1)
    end
  end
end
return S

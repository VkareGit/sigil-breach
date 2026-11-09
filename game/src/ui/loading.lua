-- An application transition, drawn from the existing bitmap skin and glyphs.
-- No world is displayed or sampled until the gallery cache is complete.
local BitmapFont = require('src.ui.fonts.bitmap_font')
local Skin = require('src.ui.skin')
local Text = require('src.content.text')
local Loading = {}
local L = require('src.content.ui_look').loading
function Loading.bootstrap(ui)
  local view = { viewport = ui.viewport, fonts = {} }
  Skin.init()
  for _, size in ipairs(L.fonts) do
    local font = BitmapFont.load(size)
    view.fonts[size] = font
    Skin.registerFont(font)
  end
  return view
end
function Loading.releaseBootstrap(view)
  if not view then
    return
  end
  for _, font in pairs(view.fonts) do
    if Skin.fontTops then
      Skin.fontTops[font] = nil
    end
    font:release()
  end
  view.fonts = {}
end
function Loading.draw(ui, remaining, total, w, h, loadError, stage, startup)
  local lg = love.graphics
  lg.push('all')
  lg.origin()
  lg.setShader()
  lg.clear(L.clear[1], L.clear[2], L.clear[3], 1)
  local scale, ox, oy = ui.viewport(w, h)
  lg.translate(ox, oy)
  lg.scale(scale)
  Skin.beginAudit('gallery loading', w, h)
  local panel, zone, title, count, back = L.panel, L.zone, L.title, L.count, L.back
  Skin.panel(panel[1], panel[2], panel[3], panel[4])
  Skin.zone('gallery loading text', zone[1], zone[2], zone[3], zone[4])
  Skin.boxText(
    Text.get(loadError and 'loading_failed' or (stage or 'loading_gallery')),
    title[1],
    title[2],
    title[3],
    title[4],
    ui.fonts[title.font],
    Skin.colors.gold,
    true
  )
  Skin.boxText(
    loadError and Text.get(startup and 'loading_enter_retry' or 'loading_return')
      or Text.get('loading_count', { done = total - remaining, total = total }),
    count[1],
    count[2],
    count[3],
    count[4],
    ui.fonts[count.font],
    Skin.colors.ivory,
    true
  )
  local meter = L.meter
  Skin.meter(
    meter[1],
    meter[2],
    meter[3],
    (total - remaining) / math.max(1, total),
    Skin.colors.gold,
    total
  )
  Skin.boxText(
    Text.get(startup and 'loading_quit' or 'loading_back'),
    back[1],
    back[2],
    back[3],
    back[4],
    ui.fonts[back.font],
    Skin.colors.muted,
    true
  )
  Skin.endZone()
  Skin.endAudit()
  lg.pop()
end
return Loading

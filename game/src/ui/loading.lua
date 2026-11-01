-- An application transition, drawn from the existing bitmap skin and glyphs.
-- No world is displayed or sampled until the gallery cache is complete.
local BitmapFont = require('src.ui.fonts.bitmap_font')
local Skin = require('src.ui.skin')
local Text = require('src.content.text')
local Loading = {}
function Loading.bootstrap(ui)
  local view = { viewport = ui.viewport, fonts = {} }
  Skin.init()
  for _, size in ipairs({ 12, 16, 22 }) do
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
  lg.clear(0.025, 0.019, 0.021, 1)
  local scale, ox, oy = ui.viewport(w, h)
  lg.translate(ox, oy)
  lg.scale(scale)
  Skin.beginAudit('gallery loading', w, h)
  Skin.panel(330, 268, 620, 184)
  Skin.zone('gallery loading text', 354, 290, 572, 142)
  Skin.boxText(
    Text.get(loadError and 'loading_failed' or (stage or 'loading_gallery')),
    362,
    296,
    556,
    32,
    ui.fonts[22],
    Skin.colors.gold,
    true
  )
  Skin.boxText(
    loadError and Text.get(startup and 'loading_enter_retry' or 'loading_return')
      or Text.get('loading_count', { done = total - remaining, total = total }),
    362,
    341,
    556,
    24,
    ui.fonts[16],
    Skin.colors.ivory,
    true
  )
  Skin.meter(374, 382, 532, (total - remaining) / math.max(1, total), Skin.colors.gold, total)
  Skin.boxText(
    Text.get(startup and 'loading_quit' or 'loading_back'),
    362,
    406,
    556,
    22,
    ui.fonts[12],
    Skin.colors.muted,
    true
  )
  Skin.endZone()
  Skin.endAudit()
  lg.pop()
end
return Loading

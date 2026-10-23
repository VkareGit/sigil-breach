-- An application transition, drawn from the existing bitmap skin and glyphs.
-- No world is displayed or sampled until the gallery cache is complete.
local Skin = require('src.ui.skin')
local Loading = {}
function Loading.draw(ui, remaining, total, w, h)
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
  Skin.boxText('PREPARING THE GALLERY', 362, 296, 556, 32, ui.fonts[22], Skin.colors.gold, true)
  Skin.boxText(
    (total - remaining) .. ' / ' .. total,
    362,
    341,
    556,
    24,
    ui.fonts[16],
    Skin.colors.ivory,
    true
  )
  Skin.meter(374, 382, 532, (total - remaining) / math.max(1, total), Skin.colors.gold, total)
  Skin.boxText('ESC TO RETURN', 362, 406, 556, 22, ui.fonts[12], Skin.colors.muted, true)
  Skin.endZone()
  Skin.endAudit()
  lg.pop()
end
return Loading

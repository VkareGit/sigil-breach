-- The map overlay (TAB): the arena, the knight, seals and objective.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Kit = require('src.ui.kit')
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local lg = love.graphics
local c, text, right, center = Kit.c, Kit.text, Kit.right, Kit.center
local rect, line, panel, key, bar = Kit.rect, Kit.line, Kit.panel, Kit.key, Kit.bar
local ivory, muted, gold = Skin.colors.ivory, Skin.colors.muted, Skin.colors.gold
local red, blue, green = Skin.colors.red, Skin.colors.blue, Palette.green
local D = require('src.ui.descent')
local Pools = require('src.session.world')
local S = {}
function S.draw(g, s, U)
  if g.run then
    return D.map(g)
  end
  rect(0, 0, 1280, 720, Palette.veilCool, 0.94)
  panel(150, 60, 980, 606)
  text('CARTOGRAPHY OF LIMBO', 181, 81, 36, ivory)
  text(U.objective(g), 182, 136, 20, gold)
  local sz, ox, oy = 14, 590, 156
  for z = 1, g.world.size do
    for x = 1, g.world.size do
      if g.world.map[z][x] == 0 then
        rect(ox + x * sz, oy + z * sz, sz - 1, sz - 1, Palette.stone)
      end
    end
  end
  for i, s in ipairs(g.world.seals) do
    local x, y = ox + s.x * sz, oy + s.z * sz
    c(s.active and muted or s.color)
    lg.setLineWidth(2)
    lg.circle('line', x, y, 9)
    text(tostring(i), x - 4, y - 10, 16, s.color)
    text('0' .. i .. '  ' .. s.name, 184, 218 + (i - 1) * 77, 24, s.color)
    text(s.active and 'SEAL BROKEN' or 'APPROACH AND PRESS E', 184, 251 + (i - 1) * 77, 16, muted)
  end
  local p = g.player
  local x, y = ox + p.x * sz, oy + p.z * sz
  c(ivory)
  lg.circle('fill', x, y, 4)
  lg.setLineWidth(3)
  lg.line(x, y, x + math.sin(p.yaw) * 17, y + math.cos(p.yaw) * 17)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 and e.awake then
      rect(ox + e.x * sz - 2, oy + e.z * sz - 2, 4, 4, red)
    end
  end
  c(g.bossDead and blue or muted)
  lg.rectangle('line', ox + 16 * sz - 10, oy + 3 * sz - 6, 20, 12)
  text('GATE', ox + 16 * sz - 28, oy + 3 * sz - 29, 16, muted)
  text('WHITE: YOU     RED: DEMON', 184, 492, 16, ivory)
  text('The map pauses combat.', 184, 619, 18, muted)
end
return S

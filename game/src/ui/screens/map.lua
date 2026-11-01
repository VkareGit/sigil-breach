local Tiles = require('src.core.tiles')
local Context = require('src.session.context')
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
local Grid = require('src.physics.grid')
local Queries = require('src.run.queries')
local Text = require('src.content.text')
local S = {}
function S.draw(g, s, U)
  if Queries.run(g) then
    return D.map(g)
  end
  rect(0, 0, 1280, 720, Palette.veilCool, 0.94)
  panel(150, 60, 980, 606)
  text(Text.get('classic_map_title'), 181, 81, 36, ivory)
  text(U.objective(g), 182, 136, 20, gold)
  local sz, ox, oy = 14, 590, 156
  for z = 1, Grid.depth(g.world) do
    for x = 1, Grid.width(g.world) do
      if Tiles.walkable[g.world.map[z][x]] then
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
    text(
      Text.get('classic_map_seal', { index = i, name = Text.get(s.name) }),
      184,
      218 + (i - 1) * 77,
      24,
      s.color
    )
    text(
      Text.get(s.active and 'classic_map_seal_broken' or 'classic_map_seal_open'),
      184,
      251 + (i - 1) * 77,
      16,
      muted
    )
  end
  local p = Context.actor(g)
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
  -- A mode's own marks (plan v11 E2): its world view's markers { x, z, done }.
  for _, m in ipairs(Queries.world(g).markers or {}) do
    rect(ox + m.x * sz - 3, oy + m.z * sz - 3, 6, 6, m.done and muted or gold)
  end
  local gate = g.world.portal
  if gate then
    c(Queries.world(g).guardianDead and blue or muted)
    lg.rectangle('line', ox + gate.x * sz - 10, oy + gate.z * sz - 6, 20, 12)
    text(Text.get('classic_map_gate'), ox + gate.x * sz - 28, oy + gate.z * sz - 29, 16, muted)
  end
  text(Text.get('classic_map_legend'), 184, 492, 16, ivory)
  text(Text.get('map_pause'), 184, 619, 18, muted)
end
return S

-- Surface marks, sorted effects, charges, spells, debug volumes, tracers.
local SurfaceMarks = require('src.render.surface_marks')
local RenderFX = require('src.render.effects')
local Weapon = require('src.render.weapon')
local Pass = {}
function Pass.draw(r, g)
  local lg = love.graphics
  SurfaceMarks.draw(r, g)
  lg.setShader(r.spriteShader)
  local effects = r.effectOrder
  local count = #g.view.effects
  for i = 1, count do
    effects[i] = g.view.effects[i]
  end
  for i = #effects, count + 1, -1 do
    effects[i] = nil
  end
  table.sort(effects, r.effectSort)
  lg.setDepthMode('less', false)
  for _, e in ipairs(effects) do
    r:effect(g, e)
  end
  RenderFX.charges(r, g, Weapon.chargeImage)
  RenderFX.spells(r, g)
  RenderFX.hitboxes(r, g)
  r:tracers(g)
end
return Pass

-- A chapel margin painted into lime plaster. The atlas supplies the material,
-- brush marks and figures; layout keeps the live text inside quiet fields.
local ReliquarySheet = require('src.content.art.reliquary_sheet')
local S = { path = ReliquarySheet.path }
local CORNER, ROWS, HEIGHTS = ReliquarySheet.corner, ReliquarySheet.rows, ReliquarySheet.heights
local PAPER, RULE = ReliquarySheet.paper, ReliquarySheet.rule
local lg = love.graphics
local Resources = require('src.render.resources')
local FrameSize = require('src.content.ui_layout')
function S.init()
  if S.image then
    return
  end
  S.resources = Resources.new('UI reliquary')
  S.image = S.resources:image(S.path, { filter = 'linear' })
  local w, h = S.image:getDimensions()
  S.bar = S.resources:own(lg.newQuad(0, 0, w, ReliquarySheet.bar, w, h))
  S.frames = {}
  local xs = { 0, CORNER, w - CORNER }
  local ys = ROWS
  local ws = { CORNER, w - 2 * CORNER, CORNER }
  local hs = HEIGHTS
  for y = 1, 3 do
    for x = 1, 3 do
      S.frames[#S.frames + 1] =
        { q = S.resources:own(lg.newQuad(xs[x], ys[y], ws[x], hs[y], w, h)), w = ws[x], h = hs[y] }
    end
  end
  -- Tall menu borders use the authored nonfigurative frieze. Narrative
  -- figures stay in the spacious HUD niches, never stretched into columns.
  S.sideTrim = S.resources:own(lg.newQuad(CORNER, ROWS[1], w - 2 * CORNER, HEIGHTS[1], w, h))
  S.paper = S.image
  S.paperQuiet = S.resources:own(lg.newQuad(PAPER.x, PAPER.y, PAPER.w, PAPER.h, w, h))
  S.rule = S.resources:own(lg.newQuad(RULE.x, 0, RULE.w, RULE.h, w, h))
end
function S.release()
  if S.resources then
    S.resources:release()
  end
  S.resources, S.image, S.paper, S.frames, S.bar, S.sideTrim, S.paperQuiet, S.rule =
    nil, nil, nil, nil, nil, nil, nil, nil
end
function S.plaster(x, y, w, h, tone)
  S.init()
  local tint = ReliquarySheet.tones[tone]
  if tint then
    lg.setColor(tint[1], tint[2], tint[3])
  else
    lg.setColor(1, 1, 1)
  end
  -- Crop the lime ground to the destination aspect, rather than elongating its
  -- pigment grains into vertical wallpaper on a tall menu.
  local cw, ch = PAPER.w, PAPER.h
  if w / h > cw / ch then
    ch = cw * h / w
  else
    cw = ch * w / h
  end
  S.paperQuiet:setViewport(
    PAPER.x + (PAPER.w - cw) / 2,
    PAPER.y + (PAPER.h - ch) / 2,
    cw,
    ch,
    S.image:getDimensions()
  )
  lg.draw(S.image, S.paperQuiet, x, y, 0, w / cw, h / ch)
  lg.setColor(1, 1, 1)
end
function S.panel(x, y, w, h, b, style)
  S.init()
  if style == 7 then
    -- Utility captions need a calm writing ground, not another large ornament.
    -- The two thin sinopia rules are cropped from the same authored fresco.
    local previous = lg.getShader()
    lg.setShader()
    S.plaster(x, y, w, h)
    lg.setColor(1, 1, 1)
    local thick = ReliquarySheet.ruleWidth
    lg.draw(S.image, S.rule, x, y, 0, w / RULE.w, thick / RULE.h)
    lg.draw(S.image, S.rule, x, y + h - thick, 0, w / RULE.w, thick / RULE.h)
    lg.setShader(previous)
    return
  end
  local large, border = ReliquarySheet.large, ReliquarySheet.border
  if w >= large.w and h >= large.h then
    b = math.max(large.border, b or 0)
  end
  b = math.min(math.max(border.least, b or border.default), math.floor(w / 3), math.floor(h / 3))
  local xs = { x, x + b, x + w - b }
  local ys = { y, y + b, y + h - b }
  local ws = { b, w - 2 * b, b }
  local hs = { b, h - 2 * b, b }
  local previous = lg.getShader()
  lg.setShader()
  lg.setColor(1, 1, 1)
  for iy = 1, 3 do
    for ix = 1, 3 do
      local p = S.frames[(iy - 1) * 3 + ix]
      if ix == 2 and iy == 2 then
        S.plaster(xs[ix], ys[iy], ws[ix], hs[iy], style == 4 and 3 or (style == 3 and 2 or 1))
      elseif iy == 2 then
        local trim = HEIGHTS[1]
        local cw = math.min(S.image:getWidth() - 2 * CORNER, hs[iy] * trim / ws[ix])
        S.sideTrim:setViewport(
          (S.image:getWidth() - cw) / 2,
          ROWS[1],
          cw,
          trim,
          S.image:getDimensions()
        )
        if ix == 1 then
          lg.draw(
            S.image,
            S.sideTrim,
            xs[ix] + ws[ix],
            ys[iy],
            math.pi / 2,
            hs[iy] / cw,
            ws[ix] / trim
          )
        else
          lg.draw(
            S.image,
            S.sideTrim,
            xs[ix],
            ys[iy] + hs[iy],
            -math.pi / 2,
            hs[iy] / cw,
            ws[ix] / trim
          )
        end
      else
        lg.draw(S.image, p.q, math.floor(xs[ix]), math.floor(ys[iy]), 0, ws[ix] / p.w, hs[iy] / p.h)
      end
    end
  end
  lg.setShader(previous)
  lg.setColor(1, 1, 1)
end
function S.status()
  S.init()
  local previous = lg.getShader()
  lg.setShader()
  lg.setColor(1, 1, 1)
  local status = ReliquarySheet.status
  lg.draw(
    S.image,
    S.bar,
    0,
    status.top,
    0,
    FrameSize.width / S.image:getWidth(),
    status.height / ReliquarySheet.bar
  )
  lg.setShader(previous)
end
return S

-- A chapel margin painted into lime plaster. The atlas supplies the material,
-- brush marks and figures; layout keeps the live text inside quiet fields.
local S = { path = 'assets/art/reliquary-ash-v16.png' }
local lg = love.graphics
local Resources = require('src.render.resources')
function S.init()
  if S.image then
    return
  end
  S.resources = Resources.new('UI reliquary')
  S.image = S.resources:image(S.path, { filter = 'linear' })
  local w, h = S.image:getDimensions()
  S.bar = S.resources:own(lg.newQuad(0, 0, w, 230, w, h))
  S.frames = {}
  local xs = { 0, 108, w - 108 }
  local ys = { 408, 482, 850 }
  local ws = { 108, w - 216, 108 }
  local hs = { 74, 368, 74 }
  for y = 1, 3 do
    for x = 1, 3 do
      S.frames[#S.frames + 1] =
        { q = S.resources:own(lg.newQuad(xs[x], ys[y], ws[x], hs[y], w, h)), w = ws[x], h = hs[y] }
    end
  end
  -- Tall menu borders use the authored nonfigurative frieze. Narrative
  -- figures stay in the spacious HUD niches, never stretched into columns.
  S.sideTrim = S.resources:own(lg.newQuad(108, 408, w - 216, 74, w, h))
  S.paper = S.image
  S.paperQuiet = S.resources:own(lg.newQuad(200, 500, 1100, 326, w, h))
  S.rule = S.resources:own(lg.newQuad(200, 0, 1100, 10, w, h))
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
  if tone == 2 then
    lg.setColor(0.98, 0.84, 0.68)
  elseif tone == 3 then
    lg.setColor(0.83, 0.84, 0.82)
  else
    lg.setColor(1, 1, 1)
  end
  -- Crop the lime ground to the destination aspect, rather than elongating its
  -- pigment grains into vertical wallpaper on a tall menu.
  local cw, ch = 1100, 326
  if w / h > cw / ch then
    ch = cw * h / w
  else
    cw = ch * w / h
  end
  S.paperQuiet:setViewport(
    200 + (1100 - cw) / 2,
    500 + (326 - ch) / 2,
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
    lg.draw(S.image, S.rule, x, y, 0, w / 1100, 2 / 10)
    lg.draw(S.image, S.rule, x, y + h - 2, 0, w / 1100, 2 / 10)
    lg.setShader(previous)
    return
  end
  if w >= 500 and h >= 300 then
    b = math.max(32, b or 0)
  end
  b = math.min(math.max(10, b or 14), math.floor(w / 3), math.floor(h / 3))
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
        local cw = math.min(S.image:getWidth() - 216, hs[iy] * 74 / ws[ix])
        S.sideTrim:setViewport((S.image:getWidth() - cw) / 2, 408, cw, 74, S.image:getDimensions())
        if ix == 1 then
          lg.draw(
            S.image,
            S.sideTrim,
            xs[ix] + ws[ix],
            ys[iy],
            math.pi / 2,
            hs[iy] / cw,
            ws[ix] / 74
          )
        else
          lg.draw(
            S.image,
            S.sideTrim,
            xs[ix],
            ys[iy] + hs[iy],
            -math.pi / 2,
            hs[iy] / cw,
            ws[ix] / 74
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
  lg.draw(S.image, S.bar, 0, 584, 0, 1280 / S.image:getWidth(), 136 / 230)
  lg.setShader(previous)
end
return S

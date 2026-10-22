-- Source and composited-arch checks for the closed-visored human portrait.
-- Optional review writes real GPU composites at HUD size, not mock-ups.
local T = {}
local states = {
  { name = 'steady', time = 0, hp = 100, shotAge = 10, hurt = 0 },
  { name = 'left', time = 3 / 0.65, hp = 100, shotAge = 10, hurt = 0 },
  { name = 'right', time = 5 / 0.65, hp = 100, shotAge = 10, hurt = 0 },
  { name = 'impact', time = 0, hp = 100, shotAge = 10, hurt = 0.8 },
  { name = 'critical', time = 0, hp = 18, shotAge = 10, hurt = 0 },
  { name = 'braced', time = 0, hp = 100, shotAge = 0.01, hurt = 0 },
}
local function game(state)
  return {
    time = state.time,
    player = { hp = state.hp },
    view = { hurt = state.hurt, shotAge = state.shotAge },
  }
end
local function save(canvas, path)
  local pixels = canvas:newImageData()
  local encoded = pixels:encode('png')
  local file = assert(io.open(path, 'wb'))
  file:write(encoded:getString())
  file:close()
  pixels:release()
  encoded:release()
end
local function compose(P, state, withFrame)
  local lg = love.graphics
  local canvas = lg.newCanvas(1280, 720)
  lg.push('all')
  lg.setCanvas(canvas)
  lg.origin()
  lg.setScissor()
  lg.setDepthMode()
  lg.setShader()
  lg.setBlendMode('alpha')
  lg.clear(0, 0, 0, 0)
  if withFrame then
    require('src.ui.reliquary').status()
  end
  P.draw(game(state), 565, 584, 150)
  lg.pop()
  return canvas
end
function T.run(check, output)
  local lg = love.graphics
  local P = require('src.ui.portrait')
  if not P.image then
    P.init()
  end
  local source = love.image.newImageData(P.path)
  local width, height = source:getDimensions()
  check(
    'knight portrait is the active six-cell iron atlas',
    P.path == 'assets/art/nosiciel-iron-v16.png' and width / 3 == height / 2 and #P.quads == 6
  )
  local signatures = {}
  local sheet = output and lg.newCanvas(1440, 840)
  if sheet then
    lg.push('all')
    lg.setCanvas(sheet)
    lg.clear(0.13, 0.10, 0.08)
    lg.pop()
  end
  for i, state in ipairs(states) do
    local x, y, w, h = P.quads[i]:getViewport()
    local opaque, signature = 0, 0
    for py = y, y + h - 1, 5 do
      for px = x, x + w - 1, 5 do
        local r, g, b, a = source:getPixel(px, py)
        if a > 0.99 then
          opaque = opaque + 1
        end
        signature = signature + r * 3 + g * 7 + b * 11
      end
    end
    check(
      'knight ' .. state.name .. ' retains an opaque painted ground and a distinct pose',
      opaque > 9000 and not signatures[signature]
    )
    signatures[signature] = true
    check('knight ' .. state.name .. ' uses its gameplay response state', P.frame(game(state)) == i)
    local canvas = compose(P, state, false)
    local pixels = canvas:newImageData()
    local b = P.bounds
    local interior, leaks, crown = 0, 0, 0
    for py = 580, 719 do
      for px = 560, 719 do
        local r, g, blue, a = pixels:getPixel(px, py)
        if px < b.x or px >= b.x + b.w or py < b.y or py >= b.y + b.h then
          if a > 0.009 then
            leaks = leaks + 1
          end
        elseif a > 0.25 then
          interior = interior + 1
        end
        -- The crown should sit visibly beneath, not be cut by, the arch apex.
        if
          px >= 631
          and px <= 649
          and py >= 605
          and py <= 619
          and a > 0.7
          and r + g + blue < 1.50
        then
          crown = crown + 1
        end
      end
    end
    check(
      'knight ' .. state.name .. ' stays inside the existing arched HUD window',
      leaks == 0 and interior > 9000
    )
    check('knight ' .. state.name .. ' keeps its helmet crown visible below the arch', crown > 15)
    pixels:release()
    canvas:release()
    if output then
      local composite = compose(P, state, true)
      save(composite, output .. '/knight-' .. i .. '-' .. state.name .. '-hud.png')
      lg.push('all')
      lg.setCanvas(sheet)
      lg.origin()
      lg.setShader()
      lg.setDepthMode()
      lg.setColor(1, 1, 1)
      local dx, dy = (i - 1) % 3 * 480, math.floor((i - 1) / 3) * 420
      local q = lg.newQuad(550, 584, 180, 136, 1280, 720)
      lg.draw(composite, q, dx + 36, dy + 32, 0, 2, 2)
      lg.draw(composite, q, dx + 36, dy + 318, 0, 0.75, 0.75)
      lg.setColor(0.87, 0.78, 0.62)
      lg.print(i .. '  ' .. state.name, dx + 220, dy + 328)
      lg.pop()
      q:release()
      composite:release()
    end
  end
  source:release()
  if output then
    save(sheet, output .. '/knight-six-states-full-and-small.png')
    sheet:release()
  end
end
return T

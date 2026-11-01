-- Identical game states and illustrated assets in both halves. The legacy
-- placement below is retained here solely as a reproducible visual baseline.
local R = {}
local function legacy(r, g, x, y, vw, vh)
  local list = g.view.damageNumbers
  if not list or #list == 0 or g.state ~= 'playing' or g.showDamageNumbers == false then
    return
  end
  local Numbers = require('src.ui.fonts.painted_numbers')
  local unit = vh / 720
  for _, n in ipairs(list) do
    local t = n.age / 0.7
    local px, py = r:project(n.x, n.y + 0.35 + t * 0.55, n.z)
    if px and t < 1 then
      local big = n.kill or n.head or n.wound or n.broke
      local size = (big and 30 or 22)
        * unit
        * (1 + (n.broke and 0.45 or 0.25) * math.max(0, 1 - n.age * 8))
      local alpha = math.min(1, (1 - t) * 2.2)
      local color = n.kill and { 1, 0.62, 0.36, alpha }
        or (
          n.wound and { 1, 0.52, 0.50, alpha }
          or (
            n.broke and { 1, 0.80, 0.30, alpha }
            or (
              n.head and { 1, 0.86, 0.52, alpha }
              or (n.armor and { 0.70, 0.78, 0.86, alpha } or { 0.96, 0.92, 0.82, alpha })
            )
          )
        )
      local drift = (n.side or 1) * (28 + t * 26) * unit
      Numbers.draw(
        tostring(n.value),
        x + px * vw / r.w + drift,
        y + py * vh / r.h - size,
        200 * unit,
        size,
        color,
        false
      )
    end
  end
end
function R.run(Game, renderer, output, afterOnly)
  local lg = love.graphics
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Numbers = require('src.render.numbers')
  local saveMethod = renderer.damageNumbers
  local function game()
    local g = Field.new(Game)
    g.ephemeral = true
    Field.close(g)
    g.testField.frozen = true
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27.5, math.pi, 0
    g.time, g.elapsed, g.view.messageTimer, g.zoneTimer, g.view.feedbackTimer = 30, 30, 0, 0, 0
    g.view.damageNumbers = {}
    g.view.motion = false
    g.view.muzzle = 0
    return g
  end
  local function number(x, y, z, value, side, age)
    return { x = x, y = y, z = z, value = value, age = age or 0.10, side = side or 1 }
  end
  local cases = {
    {
      name = 'cluster',
      w = 1280,
      h = 720,
      setup = function(g)
        g:spawn('imp', 16.2, 21.5)
        g:spawn('armored', 15.7, 21)
        g:spawn('buer', 16, 19.7)
        for i = 1, 6 do
          local n =
            number(16 + (i % 3) * 0.03, 1.2, 21, 35 + i, i % 2 == 0 and 1 or -1, 0.07 + i * 0.012)
          n.head = i == 5
          n.kill = i == 6
          g.view.damageNumbers[i] = n
        end
      end,
    },
    {
      name = 'cluster-small',
      w = 960,
      h = 540,
      setup = function(g)
        g:spawn('armored', 16, 21.5)
        for i = 1, 6 do
          g.view.damageNumbers[i] =
            number(16 + (i % 3) * 0.03, 1.2, 21, 42 + i, i % 2 == 0 and 1 or -1, 0.07 + i * 0.012)
        end
      end,
    },
    {
      name = 'pillar-occluded',
      w = 1280,
      h = 720,
      setup = function(g)
        g.player.x, g.player.z = 12, 27.5
        g:spawn('imp', 12, 22)
        g.view.damageNumbers = { number(12, 1.3, 22, 70, 1) }
      end,
    },
    {
      name = 'precision-aim',
      w = 1280,
      h = 720,
      setup = function(g)
        g:spawn('imp', 16, 22)
        local n = number(16, 1.38, 22, 120, -1)
        n.head = true
        g.view.damageNumbers = { n }
      end,
    },
    {
      name = 'buer-shoulder',
      w = 1280,
      h = 720,
      setup = function(g)
        local e = g:spawn('buer', 16, 23.5)
        e.previewFrame = 1
        g.testField.hitboxes = true
      end,
    },
  }
  local lines = {}
  local frames = 0
  local function save(canvas, path)
    local d = canvas:newImageData()
    local encoded = d:encode('png')
    local f = assert(io.open(path, 'wb'))
    f:write(encoded:getString())
    f:close()
    encoded:release()
    d:release()
  end
  for _, case in ipairs(cases) do
    local g = game()
    case.setup(g)
    for _, mode in ipairs(afterOnly and { 'after' } or { 'before', 'after' }) do
      renderer.damageNumbers = mode == 'before' and legacy or Numbers.draw
      renderer:resize(case.w, case.h)
      renderer:draw(g, case.w, case.h)
      local target = lg.newCanvas(case.w, case.h)
      lg.push('all')
      lg.setCanvas(target)
      lg.clear()
      lg.origin()
      lg.setDepthMode()
      renderer:present(g, case.w, case.h)
      UI.draw(g, case.w, case.h, { sensitivity = 1, motion = false, music = 0, hints = false })
      lg.pop()
      save(target, output .. '/numbers-' .. case.name .. '-' .. mode .. '.png')
      target:release()
      frames = frames + 1
      if mode == 'after' then
        local items = renderer.numberLayout and renderer.numberLayout.items or {}
        lines[#lines + 1] = string.format(
          '%s: %d input, %d visible, %dx%d',
          case.name,
          #g.view.damageNumbers,
          #items,
          case.w,
          case.h
        )
        for _, item in ipairs(items) do
          lines[#lines + 1] = string.format(
            '  %s %s bounds %.2f %.2f %.2f %.2f',
            item.kind,
            item.text,
            item.x,
            item.y,
            item.w,
            item.h
          )
        end
      end
    end
  end
  renderer.damageNumbers = saveMethod
  local f = assert(io.open(output .. '/visual-readability-v15.txt', 'w'))
  f:write(table.concat(lines, '\n'))
  f:close()
  return frames
end
return R

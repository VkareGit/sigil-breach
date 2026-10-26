-- Compare the same painted weapon with/without source-space pigment grading.
-- Alpha/readability checks cover every registered pose; arena pairs show the
-- actual renderer, identical scene, UI and mechanical state on both sides.
local Review = {}
function Review.run(Game, renderer, output)
  local lg = love.graphics
  local Weapon = require('src.render.weapon')
  local Art = require('src.render.weapon_art')
  local Field = require('src.run.test_field')
  local UI = require('src.ui.interface')
  local Audio = require('src.audio.audio')
  local blend, muted, mouse = Art.look.pigmentBlend, Audio.muted, UI.useMouse
  Audio.muted, UI.useMouse = true, false
  local reports = {
    'WEAPON PIGMENT / SOURCE-SPACE MATERIAL REVIEW',
    'Per-pose checks isolate pigmentBlend; arena pairs compare the previous v32 and current complete material.',
    'Alpha is the authored source alpha; grading never changes anchors or animation timing.',
    'Variation is mean absolute adjacent opaque-pixel luminance difference, not an art-quality score.',
    'Tests every registered pose; scene pairs use the actual renderer at the same state.',
  }
  local function save(canvas, name)
    local pixels = canvas:newImageData()
    local encoded = pixels:encode('png')
    local f = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    f:write(encoded:getString())
    f:close()
    encoded:release()
    pixels:release()
  end
  local function paint(target, draw)
    lg.push('all')
    lg.setCanvas(target)
    lg.origin()
    lg.setShader()
    lg.setDepthMode()
    lg.clear(0, 0, 0, 0)
    lg.setColor(1, 1, 1)
    draw()
    lg.pop()
  end
  local function luminance(data, x, y)
    local r, g, b, a = data:getPixel(x, y)
    return r * 0.30 + g * 0.59 + b * 0.11, a
  end
  local before, after
  local totalBefore, totalAfter, totalEdges, totalPoses = 0, 0, 0, 0
  for _, id in ipairs(Art.ids) do
    local image = Weapon.images[id]
    for frame, quad in ipairs(Weapon.quads[id]) do
      local _, _, width, height = quad:getViewport()
      if not before or before:getWidth() ~= width or before:getHeight() ~= height then
        if before then
          before:release()
          after:release()
        end
        before, after = lg.newCanvas(width, height), lg.newCanvas(width, height)
      end
      local function render(amount, target)
        Art.look.pigmentBlend = amount
        paint(target, function()
          Weapon.handsShader({ 0.8, 0.76, 0.70 }, height, image)
          lg.draw(image, quad)
        end)
      end
      render(0, before)
      render(blend, after)
      local a, b = before:newImageData(), after:newImageData()
      local alphaChanges, edges, oldVariation, newVariation = 0, 0, 0, 0
      for y = 0, height - 1 do
        for x = 0, width - 1 do
          local old, oa = luminance(a, x, y)
          local new, na = luminance(b, x, y)
          if oa ~= na then
            alphaChanges = alphaChanges + 1
          end
          if x < width - 1 and oa > 0.95 then
            local oldNext, oldAlpha = luminance(a, x + 1, y)
            local newNext = luminance(b, x + 1, y)
            if oldAlpha > 0.95 then
              edges = edges + 1
              oldVariation = oldVariation + math.abs(oldNext - old)
              newVariation = newVariation + math.abs(newNext - new)
            end
          end
        end
      end
      assert(alphaChanges == 0, id .. ' material grading changed the silhouette')
      assert(
        edges > 0 and newVariation < oldVariation,
        id .. ' pigment should reduce fine contrast'
      )
      reports[#reports + 1] = string.format(
        '%s pose %02d: alpha changes=%d, opaque edges=%d, adjacent variation %.6f -> %.6f',
        id,
        frame,
        alphaChanges,
        edges,
        oldVariation / edges,
        newVariation / edges
      )
      totalBefore, totalAfter, totalEdges =
        totalBefore + oldVariation, totalAfter + newVariation, totalEdges + edges
      totalPoses = totalPoses + 1
      a:release()
      b:release()
    end
  end
  before:release()
  after:release()
  local canvas = lg.newCanvas(1280, 720)
  local comparisons = lg.newCanvas(1280, 720)
  local current = {}
  for key, value in pairs(Art.look) do
    current[key] = value
  end
  local previous = {
    saturation = 0.80,
    contrast = 0.84,
    exposure = 1,
    haze = 0.07,
    mist = { 0.24, 0.17, 0.12 },
    shade = 0.28,
    pigmentRadius = 1.35,
    pigmentBlend = 0.65,
  }
  local g = Field.new(Game)
  g.testing = true
  Field.close(g)
  g.testField.frozen = true
  g.enemies, g.pickups = {}, {}
  g:spawn('armored', 16, 18.5).previewFrame = 1
  g:spawn('stolas', 12.8, 19).previewFrame = 1
  g.view.messageTimer, g.view.feedbackTimer, g.zoneTimer = 0, 0, 0
  for slot, id in ipairs({ 'exorcist', 'judge' }) do
    g.player.weapon = slot
    for index, material in ipairs({ previous, current }) do
      for key, value in pairs(material) do
        Art.look[key] = value
      end
      renderer:resize(1280, 720)
      renderer:draw(g, 1280, 720)
      paint(canvas, function()
        renderer:present(g, 1280, 720)
        UI.draw(g, 1280, 720, { sensitivity = 1, motion = true, music = 0, hints = false })
      end)
      save(canvas, 'weapon-material-' .. id .. (index == 1 and '-before' or '-after'))
      lg.push('all')
      lg.setCanvas(comparisons)
      lg.origin()
      lg.setShader()
      lg.setDepthMode()
      lg.setColor(1, 1, 1)
      lg.draw(canvas, (index - 1) * 640, (slot - 1) * 360, 0, 0.5, 0.5)
      lg.pop()
    end
  end
  save(comparisons, 'weapon-material-comparison')
  canvas:release()
  comparisons:release()
  reports[#reports + 1] = string.format(
    'All %d poses: silhouette unchanged; adjacent opaque variation %.6f -> %.6f (%.1f%% reduction).',
    totalPoses,
    totalBefore / totalEdges,
    totalAfter / totalEdges,
    (1 - totalAfter / totalBefore) * 100
  )
  Art.look.pigmentBlend, Audio.muted, UI.useMouse = blend, muted, mouse
  local f = assert(io.open(output .. '/weapon-material.txt', 'w'))
  f:write(table.concat(reports, '\n'))
  f:close()
  return totalPoses
end
return Review

-- Real GPU/source comparisons: a floor plane must not mirror historic ink.
local Tests = {}
function Tests.run(_, r)
  local Ritual = require('src.render.ritual_art')
  local Sigils = require('src.ui.goetic_sigils').init()
  local lg = love.graphics
  local lines = {}
  local check = require('tests.support.fixtures').checker(lines, 'ritual art: ', 'ritual art: ')
  local source = love.image.newImageData(Ritual.path)
  local sw, sh = source:getDimensions()
  local _, _, _, corner = source:getPixel(0, 0)
  local _, _, _, center = source:getPixel(math.floor(sw / 2), math.floor(sh / 2))
  check(
    'selected generated PNG remains byte-for-byte unchanged',
    love.data.encode(
      'string',
      'hex',
      love.data.hash('sha256', assert(love.filesystem.read(Ritual.path)))
    ) == '58894b3dfb843722b11e840942283fa2ff893db311423d307fe58b6aa8047123'
  )
  check(
    'substrate has a transparent outer margin and painted center',
    corner == 0 and center > 0.98
  )
  source:release()
  for _, pair in ipairs({
    { 'stolas', 'stolas' },
    { 'buer', 'buer' },
    { 'boss', 'asmoday' },
    { 'furfur', 'furfur' },
  }) do
    local image, _, ink = Ritual.symbol({ spawn = pair[1] })
    check(pair[1] .. ' uses its actual historical source', image == Sigils.image(pair[2]) and ink)
  end
  for _, name in ipairs({ 'imp', 'armored', 'unknown' }) do
    check(name .. ' has no invented Goetic alias', Ritual.symbol({ spawn = name }) == nil)
  end
  local saved = {}
  local keys = { 'camera', 'right', 'up', 'forward', 'w', 'h', 'projection', 'lighting' }
  for _, key in ipairs(keys) do
    saved[key] = r[key]
  end
  local previousTexture = r.ritualArt.mesh:getTexture()
  local light = 1
  r.lighting = {
    sample = function()
      return light, light, light
    end,
  }
  local size, projected = 512, 384
  local inset, distance = (size - projected) / 2, size / projected
  local function camera(yaw)
    local sy, cy = math.sin(yaw), math.cos(yaw)
    r.w, r.h, r.projection = size, size, 2
    r.camera, r.forward = { 0, distance, 0 }, { 0, -1, 0 }
    r.right, r.up = { -cy, 0, sy }, { -sy, 0, -cy }
  end
  local function render(image, yaw, ink, occlude, reveal)
    camera(yaw)
    local canvas = lg.newCanvas(size, size)
    lg.push('all')
    lg.setCanvas({ canvas, depth = true })
    lg.origin()
    lg.setScissor()
    lg.setMeshCullMode('none')
    lg.setBlendMode('replace', 'premultiplied')
    lg.setColor(1, 1, 1)
    lg.clear(0, 0, 0, 0, 0, 1)
    if occlude then
      lg.setDepthMode('less', true)
      Ritual.layer(r, r.blank, 0, 0.1, 0, 1, yaw, nil, false, 1, { 0.15, 0.12, 0.1 })
    end
    lg.setDepthMode('less', false)
    Ritual.layer(r, image, 0, 0, 0, 1, yaw, nil, ink, nil, nil, nil, nil, reveal)
    lg.pop()
    local pixels = canvas:newImageData()
    canvas:release()
    return pixels
  end
  for _, name in ipairs({ 'asmoday', 'stolas', 'buer', 'furfur', 'paimon' }) do
    source = love.image.newImageData('assets/art/sigils/' .. Sigils.entries[name].file)
    sw, sh = source:getDimensions()
    local function inkAt(x, y)
      local red, green, blue, alpha = source:getPixel(x, y)
      local ink = (1 - math.min(red, green, blue)) * alpha
      return ink >= 0.02 and ink or 0
    end
    for index, yaw in ipairs({ 0, math.pi / 2, 2.37 }) do
      local pixels = render(Sigils.image(name), yaw, true)
      local error, mirrored, samples, opaque, outside = 0, 0, 0, 0, true
      for y = 0, size - 1, 3 do
        for x = 0, size - 1, 3 do
          local _, _, _, alpha = pixels:getPixel(x, y)
          if x < inset or x >= inset + projected or y < inset or y >= inset + projected then
            outside = outside and alpha < 0.009
          else
            local sx = math.floor((x + 0.5 - inset) / projected * sw)
            local ty = math.floor((y + 0.5 - inset) / projected * sh)
            error = error + math.abs(alpha - inkAt(sx, ty))
            mirrored = mirrored + math.abs(alpha - inkAt(sw - 1 - sx, ty))
            samples = samples + 1
            if alpha > 0.5 then
              opaque = opaque + 1
            end
          end
        end
      end
      error, mirrored = error / samples, mirrored / samples
      pixels:release()
      check(
        string.format(
          '%s floor yaw %d matches original source UV [error %.4f, mirror %.4f]',
          name,
          index,
          error,
          mirrored
        ),
        outside and opaque > 100 and error < 0.012 and mirrored > error * 4 + 0.01
      )
    end
    source:release()
  end
  local function inkCount(reveal)
    local pixels = render(Sigils.image('asmoday'), 0, true, false, reveal)
    local amount = 0
    for y = 64, 447, 3 do
      for x = 64, 447, 3 do
        local _, _, _, alpha = pixels:getPixel(x, y)
        amount = amount + alpha
      end
    end
    pixels:release()
    return amount
  end
  local initial, middle, full = inkCount(0), inkCount(0.5), inkCount(1)
  check(
    'activation reveals original ink progressively on the real GPU',
    initial == 0 and middle > full * 0.2 and middle < full * 0.8 and full > 100
  )
  local function brightness(pixels)
    local sum = 0
    for y = 128, 383, 7 do
      for x = 128, 383, 7 do
        local red, green, blue = pixels:getPixel(x, y)
        sum = sum + red + green + blue
      end
    end
    pixels:release()
    return sum
  end
  light = 1
  local lit = brightness(render(r.ritualArt.image, 0, false))
  light = 0.2
  local dark = brightness(render(r.ritualArt.image, 0, false))
  check('painted substrate follows scene light rather than emitting glow', lit > dark * 2)
  light = 1
  local hidden = render(Sigils.image('stolas'), 0, true, true)
  local clear = true
  local red0, green0, blue0, alpha0 = hidden:getPixel(256, 256)
  for y = 140, 371, 11 do
    for x = 140, 371, 11 do
      local red, green, blue, alpha = hidden:getPixel(x, y)
      clear = clear
        and math.abs(red - red0) < 0.009
        and math.abs(green - green0) < 0.009
        and math.abs(blue - blue0) < 0.009
        and alpha == alpha0
    end
  end
  hidden:release()
  check('a nearer opaque plane occludes historic ink through real GPU depth', clear and alpha0 == 1)
  camera(0)
  lg.push('all')
  lg.setShader()
  lg.setColor(0.2, 0.3, 0.4, 0.5)
  lg.setDepthMode('always', true)
  Ritual.draw(r, 0, 0, 0, 1, 0, Sigils.image('stolas'), nil, true)
  local red, green, blue, alpha = lg.getColor()
  local mode, writes = lg.getDepthMode()
  check(
    'complete medallion restores caller shader, color and depth',
    lg.getShader() == nil
      and math.abs(red - 0.2) < 0.001
      and math.abs(green - 0.3) < 0.001
      and math.abs(blue - 0.4) < 0.001
      and math.abs(alpha - 0.5) < 0.001
      and mode == 'always'
      and writes
  )
  lg.pop()
  r.ritualArt.mesh:setTexture(previousTexture)
  for _, key in ipairs(keys) do
    r[key] = saved[key]
  end
  return lines
end
return Tests

local T = {}
function T.run(check, r)
  local function checkAtlas(name, path, frames, feet)
    local data = love.image.newImageData(path)
    local w, h = data:getDimensions()
    for i, region in ipairs(frames) do
      local q = region.rect
      local x0, y0 = math.floor(q[1] * w + 0.5), math.floor(q[2] * h + 0.5)
      local cw, ch = math.floor(q[3] * w + 0.5), math.floor(q[4] * h + 0.5)
      local ink, edges, lowest = 0, 0, 0
      for y = y0, y0 + ch - 1 do
        for x = x0, x0 + cw - 1 do
          local _, _, _, a = data:getPixel(x, y)
          if a > 0.3 then
            ink = ink + 1
            lowest = math.max(lowest, y)
            if x == x0 or x == x0 + cw - 1 or y == y0 or y == y0 + ch - 1 then
              edges = edges + 1
            end
          end
        end
      end
      check(
        name
          .. ' frame '
          .. i
          .. ' retains an isolated complete painted silhouette (edge pixels '
          .. edges
          .. ')',
        ink > 500 and edges == 0
      )
      check(
        name .. ' frame ' .. i .. ' rests at its measured painted baseline',
        feet[i] >= 0 and math.abs(feet[i] - (y0 + ch - 1 - lowest) / ch) < 0.03
      )
    end
    data:release()
  end
  checkAtlas('fresco props', 'assets/art/props-fresco-v12.png', r.propFrames, r.propFeet)
  checkAtlas('fresco shrine', 'assets/art/shrine-fresco-v12.png', r.shrineFrames, r.shrineFeet)
  check(
    'the painted world and horizon retain their source dimensions',
    r.textures:getWidth() == 1254 and r.horizon:getWidth() > 2000
  )
  -- A neutral centre patch must retain authored pigment. This catches a return
  -- of blanket nearest-palette posterization independently of shader source text.
  local lg = love.graphics
  local sample = love.image.newImageData(1, 1)
  local canvas = lg.newCanvas(32, 32)
  local rgb = { { 0.37, 0.24, 0.16 }, { 0.29, 0.36, 0.42 }, { 0.71, 0.58, 0.39 } }
  local faithful = true
  for _, c in ipairs(rgb) do
    sample:setPixel(0, 0, c[1], c[2], c[3], 1)
    local image = lg.newImage(sample)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    lg.setShader(r.post)
    lg.setScissor()
    lg.setDepthMode()
    lg.setColor(1, 1, 1)
    r.post:send('size', { 32, 32 })
    for _, name in ipairs({ 'hurt', 'surge', 'low', 'kill' }) do
      r.post:send(name, 0)
    end
    lg.draw(image, 0, 0, 0, 32, 32)
    lg.pop()
    local output = canvas:newImageData()
    local red, green, blue = output:getPixel(16, 16)
    faithful = faithful
      and math.abs(red - c[1]) < 0.007
      and math.abs(green - c[2]) < 0.007
      and math.abs(blue - c[3]) < 0.007
    image:release()
    output:release()
  end
  sample:release()
  canvas:release()
  check(
    'neutral compositor preserves varied source pigments instead of quantizing the painting',
    faithful
  )
end
return T

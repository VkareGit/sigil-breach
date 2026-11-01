-- Inspect all supplemental frames and the actual arena. Only the pigment
-- profile changes between each pair: exact alpha, pose and simulation remain.
local Pigment = require('src.render.creature_pigment')
local Art = require('src.content.ability_art')
local Field = require('src.run.test_field')
local Integrity = require('src.session.integrity')
local Review = {}
local function save(canvas, output, name)
  local data = canvas:newImageData()
  local png = data:encode('png')
  local f = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
  f:write(png:getString())
  f:close()
  png:release()
  data:release()
end
local function paint(canvas, draw)
  love.graphics.push('all')
  love.graphics.setCanvas(canvas)
  love.graphics.origin()
  love.graphics.setShader()
  love.graphics.setDepthMode()
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1)
  draw()
  love.graphics.pop()
end
function Review.run(Game, renderer, output)
  local lg = love.graphics
  local shader = lg.newShader('extern vec4 frameRect;\n' .. Pigment.shader .. [[
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 pixel){
 vec4 p=Texel(tex,uv);
 vec2 localUV=(uv-frameRect.xy)/frameRect.zw;
 return vec4(bodyPigment(tex,localUV,p),p.a)*color;
}
]])
  local lines = {
    'CREATURE PIGMENT: exact original images and alpha; no anatomy/pose changes.',
    'All 16 ability frames; paired native arena screenshots, same state and light.',
    'Variation measures adjacent opaque luminance, not artistic quality.',
    'Sheets: upper row original, lower row matched paint; two four-frame groups.',
  }
  for _, key in ipairs({ 'leap', 'evade' }) do
    local entry, image = Art[key], renderer.abilityArt[key].image
    local profile = entry.pigment
    local sheet = lg.newCanvas(896, 1200)
    paint(sheet, function()
      lg.clear(0.09, 0.07, 0.055, 1)
    end)
    for index, frame in ipairs(entry.frames) do
      local rect, w, h = frame.rect, image:getDimensions()
      local fw, fh = rect[3] * w, rect[4] * h
      local quad = lg.newQuad(rect[1] * w, rect[2] * h, fw, fh, w, h)
      local before, after = lg.newCanvas(fw, fh), lg.newCanvas(fw, fh)
      local function draw(target, setting)
        paint(target, function()
          shader:send('frameRect', rect)
          Pigment.apply(shader, setting)
          lg.setShader(shader)
          lg.draw(image, quad)
        end)
      end
      draw(before)
      draw(after, profile)
      local a, b = before:newImageData(), after:newImageData()
      local noRed
      if profile.red then
        local neutral = lg.newCanvas(fw, fh)
        draw(neutral, { grid = profile.grid, tone = profile.tone, lift = profile.lift })
        noRed = neutral:newImageData()
        neutral:release()
      end
      local changed, edges, va, vb, la, lb, pixels = 0, 0, 0, 0, 0, 0, 0
      local redPixels, otherChannels = 0, 0
      local function luma(data, x, y)
        local r, g, blue, alpha = data:getPixel(x, y)
        return r * 0.30 + g * 0.59 + blue * 0.11, alpha
      end
      for y = 0, fh - 1 do
        for x = 0, fw - 1 do
          local old, oa = luma(a, x, y)
          local new, na = luma(b, x, y)
          changed = changed + (oa ~= na and 1 or 0)
          if noRed then
            local r0, g0, b0, a0 = noRed:getPixel(x, y)
            local r1, g1, b1, a1 = b:getPixel(x, y)
            otherChannels = otherChannels + ((g0 ~= g1 or b0 ~= b1 or a0 ~= a1) and 1 or 0)
            redPixels = redPixels + (r0 - r1 > 1 / 255 and 1 or 0)
            assert(r1 <= r0 + 1 / 255, 'red match must not brighten the pigment')
          end
          if oa > 0.95 then
            la, lb, pixels = la + old, lb + new, pixels + 1
            if x < fw - 1 then
              local nextOld, alpha = luma(a, x + 1, y)
              if alpha > 0.95 then
                va, vb, edges =
                  va + math.abs(nextOld - old), vb + math.abs(luma(b, x + 1, y) - new), edges + 1
              end
            end
          end
        end
      end
      assert(changed == 0, key .. ' pigment changed the source alpha')
      assert(edges > 0 and vb < va, key .. ' pigment did not reduce fine contrast')
      if noRed then
        assert(redPixels > 0 and otherChannels == 0, 'red match leaked into other channels')
        lines[#lines + 1] = string.format(
          '%s %d: excess-red pixels reduced %d; changes to green/blue/alpha %d',
          key,
          index,
          redPixels,
          otherChannels
        )
        noRed:release()
      end
      lines[#lines + 1] = string.format(
        '%s %d: alpha changes %d, mean light %.4f -> %.4f, fine contrast %.4f -> %.4f',
        key,
        index,
        changed,
        la / pixels,
        lb / pixels,
        va / edges,
        vb / edges
      )
      lg.push('all')
      lg.setCanvas(sheet)
      lg.origin()
      lg.setShader()
      lg.setDepthMode()
      lg.setColor(1, 1, 1)
      local x, y = ((index - 1) % 4) * 224, math.floor((index - 1) / 4) * 600
      lg.setBlendMode('alpha', 'premultiplied')
      lg.draw(before, x, y, 0, 224 / fw, 300 / fh)
      lg.draw(after, x, y + 300, 0, 224 / fw, 300 / fh)
      lg.pop()
      a:release()
      b:release()
      before:release()
      after:release()
      quad:release()
    end
    save(sheet, output, 'pigment-' .. key .. '-frames')
    sheet:release()

    -- Deliberately staged pose, compared under identical actual world lighting.
    local g = Field.new(Game)
    g.ephemeral = true
    Field.close(g)
    g.testField.frozen = true
    g.enemies, g.pickups = {}, {}
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 25, math.pi, 0.07
    g.view.messageTimer, g.view.feedbackTimer, g.zoneTimer = 0, 0, 0
    local kind = key == 'leap' and 'imp' or 'stolas'
    local base = g:spawn(kind, 18, 19)
    base.spawnAge, base.previewFrame = 1, 1
    local e = g:spawn(kind, 14, 19)
    e.spawnAge = 1
    if key == 'leap' then
      e.ai, e.attackKind, e.phase = 'strike', 'leap', 0.35
      e.leaping, e.leapY, e.leapVY, e.leapFlight = true, 0.4, 1, 1
    else
      e.ai, e.evadeTime, e.evadeSide = 'move', 0.13, -1
    end
    local state = Integrity.capture(g)
    for _, setting in ipairs({ 'before', 'after' }) do
      entry.pigment = setting == 'after' and profile or nil
      renderer:resize(1280, 720)
      renderer:draw(g, 1280, 720)
      save(renderer.canvas, output, 'pigment-' .. key .. '-' .. setting)
    end
    entry.pigment = profile
    assert(
      not Integrity.difference(state, Integrity.capture(g)),
      'pigment rendering changed simulation'
    )
    lines[#lines + 1] = key .. ': paired arena render leaves simulation unchanged.'

    -- Check the final match in shade, muzzle light, and with the two positions
    -- exchanged. These are deliberately staged lighting/placement controls.
    local lamps = {}
    for _, lamp in ipairs(g.world.lamps) do
      lamps[#lamps + 1] = { lamp = lamp, color = lamp.color }
    end
    for _, mode in ipairs({ 'shade', 'flash', 'swapped' }) do
      for _, lamp in ipairs(lamps) do
        lamp.lamp.color = mode == 'shade' and { 0, 0, 0 } or lamp.color
      end
      g.view.muzzle = mode == 'flash' and 0.14 or 0
      base.x, e.x = mode == 'swapped' and 14 or 18, mode == 'swapped' and 18 or 14
      local control = Integrity.capture(g)
      renderer:draw(g, 1280, 720)
      save(renderer.canvas, output, 'pigment-' .. key .. '-' .. mode)
      assert(not Integrity.difference(control, Integrity.capture(g)), 'lighting mutated simulation')
      lines[#lines + 1] = key .. ': ' .. mode .. ' control rendered, simulation unchanged.'
    end
  end
  Pigment.apply(renderer.spriteShader)
  shader:release()
  local f = assert(io.open(output .. '/creature-pigment.txt', 'w'))
  f:write(table.concat(lines, '\n') .. '\n')
  f:close()
  print('Creature pigment: all 16 frames preserve alpha; paired scenes preserve simulation.')
end
return Review

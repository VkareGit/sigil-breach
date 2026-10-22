local V = {}
local Reload = require('src.combat.reload')
local Motion = require('src.feedback.weapon_motion')
local Art = require('src.render.weapon_art')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
function V.init()
  local paths = {}
  for _, id in ipairs(Art.ids) do
    paths[id] = Art[id].path
  end
  V.manifests = Art
  V.paths = paths
  V.images = {}
  V.quads = {}
  V.origins = {}
  V.centers = {}
  V.cellWidths = {}
  for _, k in ipairs(Art.ids) do
    local path = paths[k]
    local data = love.image.newImageData(path)
    local w, h = data:getDimensions()
    local manifest = Art[k]
    assert(w == manifest.width and h == manifest.height, 'Weapon atlas registration needs updating')
    local img = love.graphics.newImage(data)
    V.images[k] = img
    img:setFilter('nearest', 'nearest')
    V.quads[k] = {}
    V.origins[k] = {}
    V.centers[k] = {}
    V.cellWidths[k] = manifest.cellWidth
    for i, frame in ipairs(manifest.frames) do
      local r = frame.rect
      V.quads[k][i] = love.graphics.newQuad(r[1], r[2], r[3], r[4], w, h)
      V.centers[k][i], V.origins[k][i] = frame.grip[1], frame.grip[2]
    end
    data:release()
  end
  V.chargePath = 'assets/art/charge-fresco-v12.png'
  local chargeData = love.image.newImageData(V.chargePath)
  local cw, ch = chargeData:getDimensions()
  V.chargeImage = love.graphics.newImage(chargeData)
  V.chargeImage:setFilter('nearest', 'nearest')
  V.chargeQuads = {}
  V.chargeOrigins = {}
  V.chargeWorldFrames = {}
  -- Measured empty rows between the spinning bomb and the throwing hand; the
  -- raised hand's fuse flame in column 2 reaches above the sheet's midline.
  local throwTops = { 443, 441, 443, 443 }
  for col = 0, 3 do
    local left, right = math.ceil(col * cw / 4), math.ceil((col + 1) * cw / 4)
    local top = throwTops[col + 1]
    -- World spins and throwing hands share the same measured boundary. The
    -- second column's raised match starts above the nominal half-sheet line.
    V.chargeWorldFrames[col + 1] = {
      rect = { left / cw, 0, (right - left) / cw, top / ch },
      width = (right - left) / (cw / 4),
      height = top / (ch / 2),
    }
    V.chargeQuads[col + 1] = love.graphics.newQuad(left, top, right - left, ch - top, cw, ch)
    local bottom = ch - 1
    for y = ch - 1, top, -1 do
      local count = 0
      for x = left, right - 1 do
        local _, _, _, a = chargeData:getPixel(x, y)
        if a > 0.6 then
          count = count + 1
        end
      end
      if count > 4 then
        bottom = y
        break
      end
    end
    V.chargeOrigins[col + 1] = bottom - top + 1
  end
  chargeData:release()
  V.muzzlePath = 'assets/art/muzzle-fresco-v12.png'
  local muzzleData = love.image.newImageData(V.muzzlePath)
  local mw, mh = muzzleData:getDimensions()
  V.muzzleImage = love.graphics.newImage(muzzleData)
  V.muzzleImage:setFilter('nearest', 'nearest')
  V.muzzleFrames = {}
  for row = 0, 1 do
    for col = 0, 3 do
      local left, right = math.ceil(col * mw / 4), math.ceil((col + 1) * mw / 4)
      if row == 0 then
        if col == 0 then
          right = 470
        elseif col == 1 then
          left = 470
        end
      end
      local top, bottom = row == 0 and 0 or 530, row == 0 and 530 or mh
      local ymin, ymax = bottom, top
      for py = top, bottom - 1 do
        for px = left, right - 1 do
          local _, _, _, a = muzzleData:getPixel(px, py)
          if a > 0.10 then
            ymin = math.min(ymin, py)
            ymax = math.max(ymax, py)
          end
        end
      end
      -- The source's painted ignition point, not the centre of its empty cell,
      -- anchors the effect to the two muzzles (or the revolver's single barrel).
      local sum, count = 0, 0
      for py = math.max(ymin, ymax - 7), ymax do
        for px = left, right - 1 do
          local _, _, _, a = muzzleData:getPixel(px, py)
          if a > 0.20 then
            sum = sum + px - left
            count = count + 1
          end
        end
      end
      V.muzzleFrames[row * 4 + col + 1] = {
        quad = love.graphics.newQuad(left, top, right - left, bottom - top, mw, mh),
        x = count > 0 and sum / count or (right - left) * 0.5,
        y = ymax - top,
        height = ymax - ymin + 1,
      }
    end
  end
  muzzleData:release()
  -- The surface and contours are authored pigment: no palette or outline
  -- filter. The hands shader groups fine scratches into painted masses and
  -- sets that pigment in the scene's light and air (weapon_art.lua: look).
  V.shader = love.graphics.newShader(require('src.render.shaders').hands)
end
-- The hands shader with the scene's light at the knight (tint), for a frame
-- h pixels high (reviews draw the same grading).
function V.handsShader(tint, h, image)
  local look, s = Art.look, V.shader
  local width, height = image:getDimensions()
  s:send('light', tint or { 1, 1, 1 })
  s:send('mist', look.mist)
  s:send('contrast', look.contrast)
  s:send('saturation', look.saturation)
  s:send('haze', look.haze)
  s:send('shade', look.shade)
  s:send('height', h)
  s:send('pigmentStep', { look.pigmentRadius / width, look.pigmentRadius / height })
  s:send('pigmentBlend', look.pigmentBlend)
  love.graphics.setShader(s)
end
-- The throwing hand after a 'throw' cast from Q (age since the cast).
function V.throwFrame(g)
  if not (g.player and g.player.abilityState) then
    return nil
  end
  local ability, power = Abilities.slot(g, 1)
  if not ability or ability.action.kind ~= 'throw' then
    return nil
  end
  local age = ability.action.cooldown - (power.readyAt - (g.elapsed or 0))
  if age < 0 or age >= 0.30 then
    return nil
  end
  -- The simulation releases immediately, so never draw a second, held grenade.
  return age < 0.10 and 3 or 4, age
end
function V.frame(g)
  return Reload.frame(g)
end
function V.sourceFrame(g)
  return Art.frame(g)
end
function V.muzzlePhase(g)
  local age = g.view.shotAge or math.huge
  local bright = Art.of(g).style.bright
  if age < 0 or age >= 0.15 then
    return nil
  end
  return age < bright * 0.5 and 1 or (age < bright and 2 or (age < 0.10 and 3 or 4))
end
local reloadKeys = {
  { 0, 0, 0, 0 },
  { 0.10, 1, 4, 0.015 },
  { 0.26, 4, 12, -0.025 },
  { 0.60, 4, 16, -0.02 },
  { 0.75, 0, 8, 0.01 },
  { 0.94, 0, 0, 0 },
}
local revolverKeys = {
  { 0, 0, 0, 0 },
  { 0.38, 2, 8, -0.035 },
  { 0.68, 4, 12, -0.025 },
  { 1.16, 4, 12, -0.025 },
  { 1.55, 1, 5, 0.015 },
  { 1.85, 0, 0, 0 },
}
-- The hands' reload path, by mechanism.
local poseKeys = { breech = reloadKeys, cylinder = revolverKeys }
function V.pose(g)
  local x, y, roll = 0, 0, 0
  if g.reload > 0 then
    local age = Reload.age(g)
    local keys = poseKeys[Weapons.inHand(g).mechanism]
    for i = 2, #keys do
      local a, b = keys[i - 1], keys[i]
      if age <= b[1] then
        local t = math.max(0, math.min(1, (age - a[1]) / (b[1] - a[1])))
        t = t * t * (3 - 2 * t)
        x = a[2] + (b[2] - a[2]) * t
        y = a[3] + (b[3] - a[3]) * t
        roll = a[4] + (b[4] - a[4]) * t
        break
      end
    end
    local entry = math.max(0, math.min(1, ((g.reloadDuration or g.reload) - g.reload) / 0.08))
    entry = entry * entry * (3 - 2 * entry)
    x, y, roll = x * entry, y * entry, roll * entry
  end
  return x, y, roll
end
function V.transform(g, w, h)
  local unit = h / 450
  local extra = (1 - math.min(1, g.view.swapAge / 0.20)) * h * 0.35
  local rx, ry, roll = V.pose(g)
  local mx, my, mroll = Motion.pose(g)
  rx, ry, roll = rx + mx, ry + my, roll + mroll
  local kick = 0
  local wrist = 0
  if g.view.motion ~= false then
    -- Two stages (src/feedback/weight.lua): the shove back at the eye (kickBack, fast,
    -- lower and larger) and the slower muzzle rise of the recoil spring.
    kick = g.view.kickBack or 0
    wrist = g.view.weaponShotRoll or 0
    roll = roll - g.view.recoil * 0.018 - kick * (g.view.kickFlip or 0) + wrist
  end
  local x = w * 0.5 + rx * unit
  local bodyPunch = g.view.motion ~= false
      and math.max(-4, math.min(4, (g.view.viewPunch or 0) * 80))
    or 0
  -- The wrist pivots at the registered grip, not the atlas centre. Its small
  -- upward follow-through keeps the revolver from merely falling down-screen.
  local y = h
    + (11 + ry + (g.view.motion ~= false and g.view.recoil * 14 or 0) + kick * 6 + bodyPunch + wrist * 32) * unit
    + extra
  return x, y, roll, 1 + 0.045 * kick
end
function V.draw(g, w, h, tint)
  if g.state == 'menu' or g.state == 'dead' or g.state == 'won' then
    return
  end
  -- Shotgun has wider transparent gutters; compensate to retain its screen scale.
  local lg = love.graphics
  local frame = V.sourceFrame(g)
  local art = Art.idOf(g)
  local size = h * Art[art].screenScale
  local q = V.quads[art][frame]
  local x, y, roll, grow = V.transform(g, w, h)
  -- Use the same pixel-aligned grip for the weapon and its ignition point.
  -- Independent rounding before/after rotation made the powder slide a pixel.
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  V.handsShader(tint, h, V.images[art])
  lg.setColor(1, 1, 1)
  local scale = size / V.cellWidths[art] * (grow or 1)
  lg.draw(V.images[art], q, x, y, roll, scale, scale, V.centers[art][frame], V.origins[art][frame])
  lg.setShader()
  local muzzlePhase = V.muzzlePhase(g)
  if muzzlePhase then
    local effect = V.muzzleFrames[Art[art].style.muzzleRow * 4 + muzzlePhase]
    local muzzle = Art[art].frames[frame].muzzle
    local sourceX, sourceY = muzzle[1], muzzle[2]
    local mx = (sourceX - V.centers[art][frame]) * scale
    local my = (sourceY - V.origins[art][frame]) * scale
    local px = x + math.cos(roll) * mx - math.sin(roll) * my
    local py = y + math.sin(roll) * mx + math.cos(roll) * my
    local height = h * Art[art].style.flare
    if muzzlePhase == 2 then
      height = height * 0.72
    elseif muzzlePhase == 3 then
      height = height * 0.80
    elseif muzzlePhase == 4 then
      height = height * 0.62
    end
    local factor = height / effect.height
    -- Readable pigment against the background; no additive screen-wide flare.
    lg.setColor(1, 1, 1, muzzlePhase < 3 and 1 or (muzzlePhase == 3 and 0.48 or 0.26))
    lg.draw(
      V.muzzleImage,
      effect.quad,
      math.floor(px + 0.5),
      math.floor(py + 0.5),
      roll,
      factor,
      factor,
      effect.x,
      effect.y
    )
  end
  local throwFrame, throwAge = V.throwFrame(g)
  if throwFrame then
    local tq = V.chargeQuads[throwFrame]
    local _, _, tw = tq:getViewport()
    local ts = h * 0.46 / tw
    V.handsShader(tint, h, V.chargeImage)
    lg.setColor(1, 1, 1)
    lg.draw(
      V.chargeImage,
      tq,
      w * 0.30,
      h + 11 + (throwAge / 0.30) ^ 2 * h * 0.30,
      0,
      ts,
      ts,
      tw * 0.36,
      V.chargeOrigins[throwFrame]
    )
    lg.setShader()
  end
  for _, s in ipairs(g.view.shells) do
    local alpha = math.min(1, s.life * 4)
    lg.push()
    lg.translate(w * 0.5 + s.x, h * 0.62 + s.y)
    lg.rotate(s.angle)
    -- Paper cartridge in umber with a dull bone rim, not polished brass.
    lg.setColor(0.34, 0.19, 0.11, alpha)
    lg.rectangle('fill', -2, -5, 4, 10)
    lg.setColor(0.66, 0.55, 0.37, alpha)
    lg.rectangle('fill', -2, -5, 4, 3)
    lg.pop()
  end
  lg.setColor(1, 1, 1)
end
return V

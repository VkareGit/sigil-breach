local Shaders = require('src.render.shaders')
local Context = require('src.session.context')
-- Draw the selected firearm and equipment hands over the world. CPU atlas
-- metadata owns registration/timing; this module owns only GPU realization.
local V = {}
local Reload = require('src.combat.reload')
local Weapons = require('src.content.weapons')
local Motion = require('src.feedback.weapon_motion')
local Art = require('src.render.weapon_art')
local AbilityFeedback = require('src.feedback.ability_feedback')
local EquipmentArt = require('src.content.equipment_art')
local HandAtlas = require('src.render.hand_atlas')
-- Incremental catalogue loading also supports a content pack registered before
-- entering the arena. Existing images are reused; removed entries release GPU memory.
function V.loadAtlases(checkpoint)
  V.atlases, V.handAtlases = V.atlases or {}, V.handAtlases or {}
  V.manifests = Art
  V.paths, V.images, V.quads, V.origins, V.centers, V.cellWidths = {}, {}, {}, {}, {}, {}
  local function load(catalogue, loaded, each)
    for id, old in pairs(loaded) do
      if catalogue[id] ~= old.definition then
        HandAtlas.release(old)
        loaded[id] = nil
      end
    end
    for id, entry in each() do
      if not loaded[id] then
        loaded[id] = HandAtlas.load(entry, checkpoint)
        loaded[id].definition = entry
      end
    end
  end
  load(Art.entries, V.atlases, Art.each)
  load(EquipmentArt.atlases, V.handAtlases, EquipmentArt.eachAtlas)
  for _, definition in Weapons.registry:each() do
    if Art.entries[definition.art or definition.id] then
      Art.validateWeapon(definition)
    end
  end
  for id, entry in Art.each() do
    local atlas = V.atlases[id]
    V.paths[id], V.images[id], V.quads[id] = entry.path, atlas.image, atlas.quads
    V.origins[id], V.centers[id], V.cellWidths[id] = atlas.origins, atlas.centers, entry.cellWidth
  end
  -- Compatibility for the current world-charge renderer and source QA. Hand
  -- drawing itself selects the actual equipment atlas, never this alias.
  local world = EquipmentArt.getAtlas(EquipmentArt.worldAtlas)
  local loaded = V.handAtlases[EquipmentArt.worldAtlas]
  V.chargePath, V.chargeImage = world.path, loaded.image
  V.chargeQuads, V.chargeOrigins, V.chargeWorldFrames =
    loaded.quads, loaded.origins, world.worldFrames
  if V.muzzleFrames then
    V.validateMuzzles()
  end
end
function V.validateMuzzles()
  for id, entry in Art.each() do
    for _, phase in ipairs(entry.style.muzzle) do
      assert(
        V.muzzleFrames[phase.frame],
        'weapon artwork ' .. id .. ': unknown muzzle effect frame ' .. phase.frame
      )
    end
  end
end
function V.init(checkpoint)
  V.release()
  V.loadAtlases(checkpoint)
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
  V.validateMuzzles()
  -- The surface and contours are authored pigment: no palette or outline
  -- filter. The hands shader groups fine scratches into painted masses and
  -- sets that pigment in the scene's light and air (weapon_art.lua: look).
  V.shader = love.graphics.newShader(Shaders.hands)
  if checkpoint then
    checkpoint('weapon muzzle and hands shader')
  end
end
-- Only the owning tables release GPU handles; compatibility aliases never do.
-- Idempotent shutdown supports both application quit and complete reinitialization.
function V.release()
  for _, atlases in ipairs({ V.atlases or {}, V.handAtlases or {} }) do
    for _, atlas in pairs(atlases) do
      HandAtlas.release(atlas)
    end
  end
  for _, frame in ipairs(V.muzzleFrames or {}) do
    frame.quad:release()
  end
  if V.muzzleImage then
    V.muzzleImage:release()
  end
  if V.shader then
    V.shader:release()
  end
  V.atlases, V.handAtlases = nil, nil
  V.paths, V.images, V.quads, V.origins, V.centers, V.cellWidths = nil, nil, nil, nil, nil, nil
  V.chargeImage, V.chargeQuads, V.chargeOrigins, V.chargeWorldFrames = nil, nil, nil, nil
  V.muzzleImage, V.muzzleFrames, V.shader = nil, nil, nil
end
-- The hands shader with the scene's light at the knight (tint), for a frame
-- h pixels high (reviews draw the same grading).
function V.handsShader(tint, h, image)
  local look, s = Art.look, V.shader
  local width, height = image:getDimensions()
  s:send('light', tint or { 1, 1, 1 })
  s:send('mist', look.mist)
  s:send('contrast', look.contrast)
  s:send('exposure', look.exposure)
  s:send('saturation', look.saturation)
  s:send('haze', look.haze)
  s:send('shade', look.shade)
  s:send('height', h)
  s:send('pigmentStep', { look.pigmentRadius / width, look.pigmentRadius / height })
  s:send('pigmentBlend', look.pigmentBlend)
  love.graphics.setShader(s)
end
-- The gesture attached to the actual cast, whichever equipment slot made it.
function V.throwFrame(g)
  return AbilityFeedback.frame(g)
end
function V.frame(g)
  return Art.frame(g)
end
function V.sourceFrame(g)
  return Art.frame(g)
end
function V.muzzlePhase(g, sourceFrame)
  local art = Art.of(g)
  if not art.frames[sourceFrame or V.sourceFrame(g)].muzzle then
    return nil
  end
  local age = g.view.shotAge or math.huge
  if age < 0 then
    return nil
  end
  for index, phase in ipairs(art.style.muzzle) do
    if age < phase.finish then
      return index
    end
  end
end
-- The authored reload motion belongs to the chosen illustration, independently
-- of the mechanism that owns rounds and latches.
function V.pose(g)
  local x, y, roll = 0, 0, 0
  local closeProgress, close = Art.interruptedProgress(g)
  local left = Reload.left(g, Context.actor(g))
  if left > 0 then
    closeProgress = nil
  end
  if left > 0 or closeProgress then
    local keys = Art.of(g).reloadMotion
    local age = left > 0 and Reload.age(g, Context.actor(g))
      or close.reloadAge + (keys[#keys][1] - close.reloadAge) * closeProgress
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
    local entry = closeProgress and 1
      or math.max(0, math.min(1, (Reload.duration(g, Context.actor(g)) - left) / 0.08))
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
  -- A cast whose hand is the gun's support hand lowers the gun meanwhile.
  local y = h
    + (11 + ry + (g.view.motion ~= false and g.view.recoil * 14 or 0) + kick * 6 + bodyPunch + wrist * 32) * unit
    + extra
    + AbilityFeedback.weaponLowered(g) * h
  local art = Art.of(g)
  if art.placement then
    local pixels = h * art.screenScale / art.cellWidth
    x, y = x + art.placement[1] * pixels, y + art.placement[2] * pixels
  end
  return x, y, roll, 1 + 0.045 * kick
end
-- Freeze the first visible launch point. A case already in flight belongs to
-- that point, not to the current weapon's pose or the player's next weapon.
function V.shellPosition(g, shell, w, h)
  if shell.hidden then
    return nil
  end
  if not shell.originX then
    local entry = Art.of(g)
    local frame = entry.frames[V.sourceFrame(g)]
    if shell.weapon ~= Weapons.idAt(g, nil, Context.actor(g)) or not frame.eject then
      shell.hidden = true
      return nil
    end
    local x, y, angle, growth = V.transform(g, w, h)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    local scale = h * entry.screenScale / entry.cellWidth * (growth or 1)
    local dx = (frame.eject[1] - frame.grip[1]) * scale
    local dy = (frame.eject[2] - frame.grip[2]) * scale
    shell.originX = (x + math.cos(angle) * dx - math.sin(angle) * dy) / w
    shell.originY = (y + math.sin(angle) * dx + math.cos(angle) * dy) / h
  end
  local unit = h / 450
  return shell.originX * w + shell.x * unit, shell.originY * h + shell.y * unit
end
function V.draw(g, w, h, tint)
  if g.state == 'menu' or g.state == 'dead' then
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
  local muzzlePhase = V.muzzlePhase(g, frame)
  if muzzlePhase then
    local phase = Art[art].style.muzzle[muzzlePhase]
    local effect = V.muzzleFrames[phase.frame]
    local muzzle = Art[art].frames[frame].muzzle
    local sourceX, sourceY = muzzle[1], muzzle[2]
    local mx = (sourceX - V.centers[art][frame]) * scale
    local my = (sourceY - V.origins[art][frame]) * scale
    local px = x + math.cos(roll) * mx - math.sin(roll) * my
    local py = y + math.sin(roll) * mx + math.cos(roll) * my
    local height = h * Art[art].style.flare * phase.scale
    local factor = height / effect.height
    -- Readable pigment against the background; no additive screen-wide flare.
    lg.setColor(1, 1, 1, phase.alpha)
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
  local throwFrame, throwAge, throwDuration, handAtlas = V.throwFrame(g)
  if throwFrame then
    local entry = EquipmentArt.getAtlas(handAtlas)
    local loaded =
      assert(V.handAtlases[handAtlas], 'equipment hand atlas not loaded: ' .. tostring(handAtlas))
    local tq =
      assert(loaded.quads[throwFrame], 'equipment hand frame not loaded: ' .. tostring(throwFrame))
    local _, _, tw = tq:getViewport()
    local ts = h * entry.screenScale / tw
    local position = entry.position
    V.handsShader(tint, h, loaded.image)
    lg.setColor(1, 1, 1)
    lg.draw(
      loaded.image,
      tq,
      w * position.x,
      h * position.y
        + position.biasY
        + (throwAge / throwDuration) ^ position.exitPower * h * position.exitY,
      0,
      ts,
      ts,
      loaded.centers[throwFrame],
      loaded.origins[throwFrame]
    )
    lg.setShader()
  end
  for _, s in ipairs(g.view.shells) do
    local sx, sy = V.shellPosition(g, s, w, h)
    if sx then
      local alpha = math.min(1, s.life * 4)
      lg.push()
      lg.translate(sx, sy)
      lg.rotate(s.angle)
      lg.scale(h / 450, h / 450)
      -- Paper cartridge in umber with a dull bone rim, not polished brass.
      lg.setColor(0.34, 0.19, 0.11, alpha)
      lg.rectangle('fill', -2, -5, 4, 10)
      lg.setColor(0.66, 0.55, 0.37, alpha)
      lg.rectangle('fill', -2, -5, 4, 3)
      lg.pop()
    end
  end
  lg.setColor(1, 1, 1)
end
return V

-- The painted material is tested without changing reload/damage simulation.
local T = {}
function T.run(check)
  local V = require('src.render.weapon')
  local F = require('src.render.fresco_effects')
  -- 0.26: the hands are graded into the scene's light and air, never
  -- posterized (no quantized colours, no outline filter).
  local hands = require('src.render.shaders').hands
  check(
    'fresco weapons use source pigment without posterizing shader',
    V.shader ~= nil and not hands:find('floor%(') and not hands:find('fwidth')
  )
  local Art = require('src.render.weapon_art')
  for slot, art in ipairs(Art.ids) do
    local path = V.paths[art]
    local data = love.image.newImageData(path)
    check(
      'fresco weapon ' .. slot .. ' loads every registered pose and round variant',
      #V.quads[art] == #Art.get(art).frames and #V.quads[art] > 0
    )
    for frame, q in ipairs(V.quads[art]) do
      local x, y, w, h = q:getViewport()
      local edges = 0
      local paint = 0
      for py = y, y + h - 1 do
        for px = x, x + w - 1 do
          local _, _, _, alpha = data:getPixel(px, py)
          if alpha > 0.065 then
            paint = paint + 1
            if px == x or px == x + w - 1 or py == y or py == y + h - 1 then
              edges = edges + 1
            end
          end
        end
      end
      check(
        'fresco weapon ' .. slot .. ' pose ' .. frame .. ' has complete isolated silhouette',
        paint > 500 and edges == 0
      )
      check(
        'fresco weapon ' .. slot .. ' pose ' .. frame .. ' anchors its painted wrist',
        V.origins[art][frame] > 0 and V.origins[art][frame] <= h
      )
    end
    data:release()
  end
  local r = { resources = require('src.render.resources').new('fresco-test') }
  F.load(r)
  for _, kind in ipairs({ 'effects', 'spells' }) do
    local definition = F[kind]
    local data = love.image.newImageData(definition.path)
    local width, height = data:getDimensions()
    local frames = kind == 'effects' and r.effectFrames or r.spellFrames
    check(
      'fresco ' .. kind .. ' retains every chronological cell in each meaning row',
      #frames == definition.columns * definition.rows and #definition.meanings == definition.rows
    )
    for frame, region in ipairs(frames) do
      local x, y =
        math.floor(region.rect[1] * width + 0.5), math.floor(region.rect[2] * height + 0.5)
      local w, h =
        math.floor(region.rect[3] * width + 0.5), math.floor(region.rect[4] * height + 0.5)
      local edges, paint = 0, 0
      for py = y, y + h - 1 do
        for px = x, x + w - 1 do
          local _, _, _, a = data:getPixel(px, py)
          if a > 0.065 then
            paint = paint + 1
            if px == x or px == x + w - 1 or py == y or py == y + h - 1 then
              edges = edges + 1
            end
          end
        end
      end
      check(
        'fresco ' .. kind .. ' pose ' .. frame .. ' isolated inside registered cell',
        paint > 100 and edges == 0
      )
    end
    data:release()
  end
  local charge = love.image.newImageData(V.chargePath)
  for frame, q in ipairs(V.chargeQuads) do
    local x, y, w, h = q:getViewport()
    local clipped = 0
    for py = y, y + h - 1 do
      for px = x, x + w - 1 do
        local _, _, _, a = charge:getPixel(px, py)
        if a > 0.065 and (px == x or px == x + w - 1 or py == y or py == y + h - 1) then
          clipped = clipped + 1
        end
      end
    end
    check('fresco physical charge hand ' .. frame .. ' has no neighbor fragment', clipped == 0)
  end
  local chargeWidth, chargeHeight = charge:getDimensions()
  for frame, region in ipairs(V.chargeWorldFrames) do
    local x, y =
      math.floor(region.rect[1] * chargeWidth + 0.5),
      math.floor(region.rect[2] * chargeHeight + 0.5)
    local w, h =
      math.floor(region.rect[3] * chargeWidth + 0.5),
      math.floor(region.rect[4] * chargeHeight + 0.5)
    local clipped, paint = 0, 0
    for py = y, y + h - 1 do
      for px = x, x + w - 1 do
        local _, _, _, a = charge:getPixel(px, py)
        if a > 0.065 then
          paint = paint + 1
          if px == x or px == x + w - 1 or py == y or py == y + h - 1 then
            clipped = clipped + 1
          end
        end
      end
    end
    check(
      'fresco world charge spin ' .. frame .. ' excludes the throwing hand below it',
      paint > 100 and clipped == 0
    )
  end
  charge:release()
  local muzzle = love.image.newImageData(V.muzzlePath)
  for frame, region in ipairs(V.muzzleFrames) do
    local x, y, w, h = region.quad:getViewport()
    local clipped, paint = 0, 0
    for py = y, y + h - 1 do
      for px = x, x + w - 1 do
        local _, _, _, a = muzzle:getPixel(px, py)
        if a > 0.065 then
          paint = paint + 1
          if px == x or px == x + w - 1 or py == y or py == y + h - 1 then
            clipped = clipped + 1
          end
        end
      end
    end
    check(
      'fresco muzzle pigment ' .. frame .. ' is isolated around its ignition anchor',
      paint > 100 and clipped == 0 and region.height > 0
    )
  end
  muzzle:release()
  r.resources:release()
end
return T

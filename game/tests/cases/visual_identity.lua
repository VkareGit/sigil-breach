-- Keep unreviewed replacement art out of every phase, including idle and death.
local T = {}
function T.run()
  local Identity = require('qa.art.visual_identity')
  local Baselines = require('qa.data.visual_baselines')
  local Sheets = require('src.content.art.atlases').sheets
  local Copy = require('src.core.schema').copy
  local lines, failures = {}, {}
  local function check(label, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'visual identity: ' .. label
    if not ok then
      failures[#failures + 1] = label
    end
  end
  for id, policy in pairs(Baselines) do
    local sheet = assert(Sheets[id], 'visual baseline has no creature sheet: ' .. id)
    local problems, pixels = Identity.problems(sheet, policy)
    check(
      id .. ' keeps approved paint throughout every frame: ' .. table.concat(problems, '; '),
      #problems == 0
    )
    if policy.copies then
      check(
        id .. ' verifies every visible copied pixel (' .. tostring(pixels) .. ' source pixels)',
        #problems == 0 and pixels > 0
      )
    end
    local reference = policy.approved[policy.reference]
    local bytes = assert(love.filesystem.read(policy.reference))
    check(
      id .. ' reference has its independently recorded owner-approved hash',
      Identity.hash(bytes) == reference.sha256
    )
    -- Even a replacement under the same path must fail; names are insufficient.
    local single = Copy(sheet)
    single.sources = { Copy(sheet.sources[1]) }
    single.sources[1].path = policy.reference
    single.frames = { { source = 1, cell = 1 } }
    local altered = love.image.newImageData(policy.reference)
    local w, h = altered:getDimensions()
    local changed = false
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local r, g, b, a = altered:getPixel(x, y)
        if a > 0.95 then
          altered:setPixel(x, y, r > 0.5 and r - 0.2 or r + 0.2, g, b, a)
          changed = true
          break
        end
      end
      if changed then
        break
      end
    end
    local changedPNG = altered:encode('png')
    local changedBytes = changedPNG:getString()
    changedPNG:release()
    altered:release()
    check(
      id .. ' rejects changed pixels under the approved filename',
      #Identity.problems(single, policy, function()
        return changedBytes
      end) > 0
    )
    single.sources[1].path = 'assets/art/unreviewed-replacement.png'
    check(
      id .. ' rejects a new painting even when the filename looks plausible',
      #Identity.problems(single, policy, function()
        return bytes
      end) > 0
    )
    single.sources[1].path = policy.reference
    single.sources[1].columns = reference.columns + 1
    check(
      id .. ' rejects slicing its reference into another grid',
      #Identity.problems(single, policy, function()
        return bytes
      end) > 0
    )
    for _, mutation in ipairs({ 'filter', 'mipmaps', 'scale' }) do
      local changed = Copy(sheet)
      changed.sources[2][mutation] = ({ filter = 'linear', mipmaps = true, scale = 2 })[mutation]
      check(id .. ' rejects a changed copy ' .. mutation, #Identity.problems(changed, policy) > 0)
    end
    local resampledIdle = Copy(sheet)
    resampledIdle.sources[3].filter = 'linear'
    check(
      id .. ' checks sampling even when idle reuses an already inspected image',
      #Identity.problems(resampledIdle, policy) > 0
    )
    local copied = love.image.newImageData(sheet.sources[2].path)
    local cw, ch = copied:getDimensions()
    local changed = false
    for y = 0, ch - 1 do
      for x = 0, cw - 1 do
        local r, g, b, a = copied:getPixel(x, y)
        if a > 0.95 then
          copied:setPixel(x, y, r > 0.5 and r - 0.2 or r + 0.2, g, b, a)
          changed = true
          break
        end
      end
      if changed then
        break
      end
    end
    local encoded = copied:encode('png')
    local damagedCopy = encoded:getString()
    check(
      id .. ' rejects repainting inside an allowed technical copy',
      #Identity.problems(sheet, policy, function(path)
          if path == sheet.sources[2].path then
            return damagedCopy
          end
          return love.filesystem.read(path)
        end) > 0
    )
    copied:release()
    encoded:release()
    local rendered = require('src.render.fresco_enemies')
    local image, _, frames, images, _, supplements = rendered.load(id)
    local framesToBake = require('qa.mask_provenance').frames()
    local matched = true
    for _, entry in ipairs(framesToBake) do
      if entry.group == 'layouts' and entry.id == id then
        local actual = images[entry.index] or image
        matched = matched
          and entry.linear == (actual:getFilter() == 'linear')
          and frames[entry.index].filter == actual:getFilter()
      end
    end
    check(id .. ' baked masks use the exact GPU sampling of every pose', matched)
    image:release()
    for _, supplement in ipairs(supplements) do
      supplement:release()
    end
    local roundtrip = assert(loadstring(require('qa.art.sheet_tool').text(sheet)))()
    check(
      id .. ' sheet export preserves sampling and audible movement',
      roundtrip.sources[2].filter == sheet.sources[2].filter
        and roundtrip.sources[2].mipmaps == sheet.sources[2].mipmaps
        and roundtrip.poses['strike.shoulder'].footsteps
          == sheet.poses['strike.shoulder'].footsteps
    )
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T

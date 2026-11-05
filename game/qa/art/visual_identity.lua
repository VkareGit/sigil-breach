-- A conservative image-identity gate, not an automated artistic judgement.
-- Exact approved pixels retain their palette, paint texture and detail. A new
-- painting must pass visual review before entering the approved set, even if
-- its colours happen to resemble a reference. All rendered frames are checked.
local Identity = {}
local Sheet = require('src.content.art.sheet')
-- Translate independently marked reference pixels through a verified copy.
function Identity.referencePoint(sheet, policy, index, x, y)
  local frame = sheet.frames[index]
  local source = sheet.sources[frame.source]
  local copy = policy.copies and policy.copies[source.path]
  if not copy then
    return x, y
  end
  local x0, _, y0 = Sheet.cut(sheet.sources[1], frame.cell)
  local tx0, _, ty0 = Sheet.cut(source, frame.cell)
  return x - x0 + tx0 + copy.padding, y - y0 + ty0 + copy.padding
end
function Identity.hash(bytes)
  return love.data.encode('string', 'hex', love.data.hash('sha256', bytes))
end
function Identity.problems(sheet, policy, read)
  read = read or love.filesystem.read
  local issues, checked = {}, {}
  local function bad(message)
    issues[#issues + 1] = sheet.id .. ': ' .. message
  end
  if not policy.approved[policy.reference] then
    bad('the reference is not approved')
    return issues
  end
  local referenceBytes = read(policy.reference)
  if
    not referenceBytes
    or Identity.hash(referenceBytes) ~= policy.approved[policy.reference].sha256
  then
    bad('the reference painting was replaced: ' .. policy.reference)
    return issues
  end
  local images, cells = {}, {}
  local function image(path)
    if not images[path] then
      local bytes = path == policy.reference and referenceBytes or assert(read(path))
      images[path] = love.image.newImageData(love.filesystem.newFileData(bytes, path))
    end
    return images[path]
  end
  local copiedPixels = 0
  for index, frame in ipairs(sheet.frames) do
    local source = sheet.sources[frame.source]
    local approved = source and policy.approved[source.path]
    local copy = source and policy.copies and policy.copies[source.path]
    if copy then
      local reference = sheet.sources[1]
      if
        source.filter ~= 'nearest'
        or source.mipmaps ~= false
        or math.abs(
            source.scale / (source.size[2] / source.rows) - reference.rows / reference.size[2]
          )
          > 1e-12
      then
        bad('frame ' .. index .. ' changes its reference sampling or pixel scale')
      end
      local key = source.path .. ':' .. frame.cell
      if not cells[key] then
        cells[key] = true
        local reference = sheet.sources[1]
        local x0, x1, y0, y1 = Sheet.cut(reference, frame.cell)
        local tx0, tx1, ty0, ty1 = Sheet.cut(source, frame.cell)
        local border = copy.padding
        local w, h = x1 - x0 + 1, y1 - y0 + 1
        if
          reference.path ~= policy.reference
          or tx1 - tx0 + 1 ~= w + 2 * border
          or ty1 - ty0 + 1 ~= h + 2 * border
        then
          bad('frame ' .. index .. ' changes its reference crop')
        else
          local a, b = image(policy.reference), image(source.path)
          local changed = 0
          for y = 0, h + 2 * border - 1 do
            for x = 0, w + 2 * border - 1 do
              local r, g, blue, alpha = b:getPixel(tx0 + x, ty0 + y)
              if x < border or y < border or x >= w + border or y >= h + border then
                if alpha ~= 0 then
                  changed = changed + 1
                end
              else
                local rr, gg, bb, aa = a:getPixel(x0 + x - border, y0 + y - border)
                if alpha ~= aa or (aa > 0 and (r ~= rr or g ~= gg or blue ~= bb)) then
                  changed = changed + 1
                end
                copiedPixels = copiedPixels + 1
              end
            end
          end
          if changed > 0 then
            bad('frame ' .. index .. ' repaints ' .. changed .. ' reference pixels')
          end
        end
      end
    elseif not approved then
      bad('frame ' .. index .. ' uses an unapproved painting ' .. tostring(source and source.path))
    elseif not checked[frame.source] then
      checked[frame.source] = true
      local bytes = read(source.path)
      if not bytes or Identity.hash(bytes) ~= approved.sha256 then
        bad('the approved painting was replaced: ' .. source.path)
      end
      if source.columns ~= approved.columns or source.rows ~= approved.rows then
        bad('the approved painting has another cell grid: ' .. source.path)
      end
    end
  end
  for _, data in pairs(images) do
    data:release()
  end
  return issues, copiedPixels
end
return Identity

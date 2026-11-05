-- An atlas sheet (plan v10 V7): the one data file of a painted creature
-- atlas (content/art/sheets/<id>.lua), written by the sheet tool
-- (qa/art/sheet_tool.lua, EXPORT-SHEET.ps1). It names:
--   id, size         the atlas and the height of its painted figure (m)
--   idle             { period, weights }: the quiet poses' breathing
--   sources          its images, in order; the first is the action atlas:
--                    { path, size = { w, h }, columns, rows, bands?,
--                      columnBands?, crops?, scale?, idle?, filter?, mipmaps? }
--   frames           in play order: { source, cell, feet, anchors }
--                    cell: a grid cell of its source (row by row) or a crop;
--                    feet: transparent pixels under the opaque feet;
--                    anchors: named points, { x from the centre in widths,
--                    y up from the base in heights }
--   poses            name -> the frames a state shows and the clock that
--                    chooses them (content/art/poses.lua, plan v11 E1); the
--                    quiet pose is derived from the idle frames
-- What the game reads of an atlas is derived here, never written by hand.
local Poses = require('src.content.art.poses')
local Sheet = {}
-- The quiet poses an atlas appends after its action frames.
Sheet.quietFrames = 4
-- The pixel rectangle (inclusive) of a cell of a source: a crop, or a cell
-- of its grid cut at its bands (rows, per column) and column bands (per row).
function Sheet.cut(source, cell)
  if source.crops then
    local c = assert(source.crops[cell], 'unknown crop ' .. tostring(cell))
    return c[1], c[1] + c[3] - 1, c[2], c[2] + c[4] - 1
  end
  local w, h = source.size[1], source.size[2]
  local columns, rows = source.columns, source.rows
  local col, row = (cell - 1) % columns, math.floor((cell - 1) / columns)
  local x0, x1 = math.ceil(col * w / columns), math.floor((col + 1) * w / columns) - 1
  local xcuts = source.columnBands and source.columnBands[row + 1]
  if xcuts then
    x0, x1 = xcuts[col + 1], xcuts[col + 2] - 1
  end
  -- Authored rows have uneven gutters. Preserve source pixel scale, not cell height.
  local cuts = source.bands
    and (type(source.bands[1]) == 'table' and source.bands[col + 1] or source.bands)
  local y0 = math.ceil(cuts and cuts[row + 1] or row * h / rows)
  local y1 = math.floor(cuts and cuts[row + 2] or (row + 1) * h / rows) - 1
  return x0, x1, y0, y1
end
-- The frame placement of an atlas: { size, feet, frames } (frame: rect in
-- its source's UV, width and height in nominal cells, sourcePath,
-- registration = named anchors).
function Sheet.layout(sheet)
  local layout = { size = sheet.size, feet = {}, frames = {} }
  for index, frame in ipairs(sheet.frames) do
    local source = assert(sheet.sources[frame.source], 'unknown source of frame ' .. index)
    local w, h = source.size[1], source.size[2]
    local x0, x1, y0, y1 = Sheet.cut(source, frame.cell)
    local cw, ch = x1 - x0 + 1, y1 - y0 + 1
    local nominal = h / source.rows
    local width, height
    if source.scale then
      -- A supplementary painting keeps its own pixel scale against the cell.
      width, height = source.scale * (cw / nominal), source.scale * ch / nominal
    else
      width, height = cw / (w / source.columns), ch / nominal
    end
    local registration = {}
    for name, point in pairs(frame.anchors) do
      registration[name] = { x = point[1], y = point[2] }
    end
    layout.feet[index] = frame.feet / ch
    layout.frames[index] = {
      rect = { x0 / w, y0 / h, cw / w, ch / h },
      width = width,
      height = height,
      sourcePath = source.path,
      filter = source.filter or (frame.source == 1 and 'nearest' or 'linear'),
      registration = registration,
    }
  end
  return layout
end
-- The catalogue entry of an atlas (content/enemy_art.lua): its action atlas
-- and cuts, and every other source with the frames it paints (targets, in
-- cell order).
function Sheet.entry(sheet)
  local main = sheet.sources[1]
  local entry = {
    path = main.path,
    columns = main.columns,
    rows = main.rows,
    bands = main.bands,
    columnBands = main.columnBands,
    replacements = {},
    originalCount = 0,
    totalFrames = #sheet.frames,
  }
  for index = 2, #sheet.sources do
    local s = sheet.sources[index]
    entry.replacements[index - 1] = {
      path = s.path,
      columns = s.columns,
      rows = s.rows,
      targets = {},
      scale = s.scale,
      bands = s.bands,
      columnBands = s.columnBands,
      crops = s.crops,
      idle = s.idle,
      filter = s.filter,
      mipmaps = s.mipmaps,
    }
  end
  for index, frame in ipairs(sheet.frames) do
    if frame.source > 1 then
      entry.replacements[frame.source - 1].targets[frame.cell] = index
    end
    if not sheet.sources[frame.source].idle then
      entry.originalCount = entry.originalCount + 1
    end
  end
  return entry
end
-- The quiet poses (content/enemy_idle.lua): the first idle frame and the
-- breathing of the sheet.
function Sheet.idle(sheet)
  for index, frame in ipairs(sheet.frames) do
    if sheet.sources[frame.source].idle then
      return { first = index, period = sheet.idle.period, weights = sheet.idle.weights }
    end
  end
  error('atlas ' .. tostring(sheet.id) .. ' has no quiet poses')
end
-- The named poses of a sheet: its own and the quiet breathing of its idle
-- frames (content/art/poses.lua).
function Sheet.poses(sheet)
  local out = {}
  for name, pose in pairs(sheet.poses or {}) do
    out[name] = pose
  end
  for index, frame in ipairs(sheet.frames or {}) do
    local source = sheet.sources and sheet.sources[frame.source]
    if source and source.idle then
      local frames = {}
      for i = 0, Sheet.quietFrames - 1 do
        frames[#frames + 1] = index + i
      end
      out.quiet = { clock = 'breath', frames = frames }
      break
    end
  end
  return out
end
-- What is wrong with a sheet (none: an empty list).
function Sheet.problems(sheet)
  local out = {}
  local function fail(message)
    out[#out + 1] = 'sheet ' .. tostring(sheet.id) .. ': ' .. message
  end
  if type(sheet.id) ~= 'string' or type(sheet.size) ~= 'number' or sheet.size <= 0 then
    fail('id and size')
  end
  if not (sheet.idle and sheet.idle.period and type(sheet.idle.weights) == 'table') then
    fail('idle breathing')
  end
  for index, source in ipairs(sheet.sources or {}) do
    if source.filter and source.filter ~= 'nearest' and source.filter ~= 'linear' then
      fail('source ' .. index .. ' filter')
    end
    if source.mipmaps ~= nil and type(source.mipmaps) ~= 'boolean' then
      fail('source ' .. index .. ' mipmaps')
    end
    if type(source.path) ~= 'string' or type(source.size) ~= 'table' then
      fail('source ' .. index .. ' path and size')
    elseif not (source.columns and source.rows) then
      fail('source ' .. index .. ' grid')
    elseif index > 1 and not source.scale then
      fail('source ' .. index .. ' scale')
    end
  end
  if #(sheet.sources or {}) == 0 or sheet.sources[1].idle or sheet.sources[1].crops then
    fail('the first source is the action atlas')
  end
  for index, frame in ipairs(sheet.frames or {}) do
    local source = sheet.sources and sheet.sources[frame.source]
    if not source then
      fail('frame ' .. index .. ' source')
    elseif source.crops and not source.crops[frame.cell] then
      fail('frame ' .. index .. ' crop')
    elseif
      not source.crops and not (frame.cell >= 1 and frame.cell <= source.columns * source.rows)
    then
      fail('frame ' .. index .. ' cell')
    end
    if type(frame.feet) ~= 'number' or frame.feet < 0 then
      fail('frame ' .. index .. ' feet')
    end
    if not (frame.anchors and frame.anchors.head) then
      fail('frame ' .. index .. ' head anchor')
    end
  end
  if type(sheet.poses) ~= 'table' then
    fail('no poses')
  elseif sheet.poses.quiet then
    fail('the quiet pose is derived from the idle frames')
  else
    for _, problem in ipairs(Poses.problems(Sheet.poses(sheet), #(sheet.frames or {}))) do
      fail(problem)
    end
  end
  return out
end
return Sheet

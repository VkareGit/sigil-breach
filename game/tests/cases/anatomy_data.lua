-- The data a shot meets on a painted demon, checked against its sources
-- The masks belong to exact source bytes and sampling rules, still match the
-- paintings, and every frame has complete, valid anatomy.
local Fixtures = require('tests.support.fixtures')
local Sources = require('src.content.art.sources')
local Masks = require('src.content.art.hit_masks')
local Anatomy = require('src.content.art.anatomy_regions')
local EnemyArt = require('src.content.enemy_art')
local Truth = require('qa.hit_truth')
local Provenance = require('qa.mask_provenance')
local Serialize = require('src.core.serialize')
local Author = require('src.content.art.anatomy.author')
local T = {}
function T.run()
  local lines = {}
  local check = Fixtures.checker(lines, 'anatomy data: ', 'anatomy data: ')
  local sizesOk, wrong = true, ''
  for path, size in pairs(Sources) do
    local data = love.image.newImageData(path)
    local w, h = data:getDimensions()
    data:release()
    if w ~= size[1] or h ~= size[2] then
      sizesOk, wrong = false, path
    end
  end
  check('every recorded source size is the real PNG size ' .. wrong, sizesOk)
  local list = Provenance.frames()
  local current = Provenance.capture(list)
  local stale = Provenance.problems(Masks.sources, current)
  check(
    #list
      .. ' masks are bound to source bytes, exact rectangles and sampling rules '
      .. table.concat(stale, '; ', 1, math.min(#stale, 6)),
    #stale == 0
  )
  check(
    'fingerprint is SHA-256',
    Provenance.digest('abc') == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
  )
  -- Real PNG edit in memory: same path and dimensions, one changed alpha.
  -- No shipped file is written and no pixel sampler is used as the oracle.
  local changedPath = list[#list].path
  local changed = love.image.newImageData(changedPath)
  local cr, cg, cb, ca = changed:getPixel(0, 0)
  changed:setPixel(0, 0, cr, cg, cb, ca < 0.5 and 1 or 0)
  local encoded = changed:encode('png')
  local bytes = encoded:getString()
  encoded:release()
  changed:release()
  local altered = Provenance.capture(list, function(path)
    return path == changedPath and bytes or love.filesystem.read(path)
  end)
  local edited = Provenance.problems(current, altered)
  check(
    'same-size PNG replacement at the same path is rejected',
    #edited == 1 and edited[1] == 'image content: ' .. changedPath
  )
  local function rejectsBinding(change)
    local copy = Serialize.decode(Serialize.encode(current))
    change(copy)
    return #Provenance.problems(current, copy) > 0
  end
  check(
    'subpixel rectangle change is rejected even within the same rounded pixel rect',
    rejectsBinding(function(copy)
      copy.layouts.imp[1].rect[1] = copy.layouts.imp[1].rect[1] + 0.000001
    end)
  )
  check(
    'filter change requires rebaking',
    rejectsBinding(function(copy)
      copy.layouts.imp[1].filter = 'linear'
    end)
  )
  check(
    'classification threshold change requires rebaking',
    rejectsBinding(function(copy)
      copy.semantics.cut = copy.semantics.cut + 0.01
    end)
  )
  -- A sample re-classified from the paintings now: an atlas frame (nearest),
  -- a supplement (linear filter) and an ability sheet.
  local truth = setmetatable({ data = {}, sizes = {} }, Truth)
  local samples = {
    { 'layouts', 'imp', 1 },
    { 'layouts', 'imp', 10 },
    { 'abilities', 'leap', 4 },
  }
  local fresh = true
  for _, s in ipairs(samples) do
    for _, f in ipairs(list) do
      if f.group == s[1] and f.id == s[2] and f.index == s[3] then
        local data = love.image.newImageData(f.path)
        local w, h = data:getDimensions()
        data:release()
        local p = {
          region = f.region,
          path = f.path,
          width = w,
          height = h,
          linear = f.linear,
          live = true,
        }
        local mask = Masks[f.group][f.id][f.index]
        for y = 0, Masks.grid - 1, 7 do
          for x = 0, Masks.grid - 1, 3 do
            local class = truth:texelUncached(p, x, y)
            local want = class == 'body' and 1 or (class == 'contour' and 2 or 0)
            local digit =
              tonumber(mask[y + 1]:sub(math.floor(x / 2) + 1, math.floor(x / 2) + 1), 16)
            local got = math.floor(digit / 4 ^ (1 - x % 2)) % 4
            fresh = fresh and got == want
          end
        end
      end
    end
  end
  truth:release()
  check('sampled masks still match the paintings they were baked from', fresh)
  -- Anatomy: one frame per mask, valid parts, a fallback region under all
  -- (content/art/anatomy_regions.lua: Anatomy.problems).
  local problems = {}
  for _, f in ipairs(list) do
    local group, id, index = f.group, f.id, f.index
    local where = group .. ' ' .. id .. ' ' .. index
    local frame = Anatomy[group][id] and Anatomy[group][id].frames[index]
    for _, message in
      ipairs(frame and Anatomy.problems(frame, where) or { 'no anatomy for ' .. where })
    do
      problems[#problems + 1] = message
    end
  end
  check(
    'every frame has valid anatomy: stable ids, zones, materials, polygons at the frame, a head, a fallback first '
      .. table.concat(problems, '; ', 1, math.min(#problems, 8)),
    #problems == 0
  )
  -- A creature naming another annotation of its atlas has one for every frame.
  local Creatures = require('src.content.enemies')
  local annotated, unannotated = true, ''
  for _, def in Creatures.each() do
    local look = def.appearance
    local regions = look.regions and Anatomy.layouts[look.regions]
    if
      look.regions and not (regions and #regions.frames == #EnemyArt.layouts[look.atlas].frames)
    then
      annotated, unannotated = false, def.id
    end
  end
  check('every named annotation covers every frame of its atlas ' .. unannotated, annotated)
  local function regionProblems(polygon, region)
    local frame = { parts = { Author.body(), Author.head(0.5, 0.1, 0.3, 0.1) } }
    if polygon then
      frame.parts[1].polygon = polygon
    end
    if region then
      frame.parts[#frame.parts + 1] = Author.part('clipped', 'lower', 'flesh', region)
    end
    return Anatomy.problems(frame, 'negative fixture')
  end
  check('collapsed fallback is rejected', #regionProblems({ 0, 0, 0, 0, 0, 0, 0, 0 }) > 0)
  check(
    'four corners in crossing order are rejected',
    #regionProblems({ 0, 0, 1, 1, 1, 0, 0, 1 }) > 0
  )
  check('repeated fallback corner is rejected', #regionProblems({ 0, 0, 1, 0, 1, 1, 1, 0 }) > 0)
  check(
    'counter-clockwise fallback in cyclic order is valid',
    #regionProblems({ 1, 1, 1, 0, 0, 0, 0, 1 }) == 0
  )
  check(
    'collinear non-fallback region is rejected',
    #regionProblems(nil, { 0, 0, 0.5, 0.5, 1, 1 }) > 0
  )
  check(
    'nonzero region crossing the frame edge remains valid',
    #regionProblems(nil, { -0.1, 0.2, 0.3, 0.2, 0.3, 0.7, -0.1, 0.7 }) == 0
  )
  check(
    'malformed numeric polygon is reported without crashing',
    #regionProblems({ 0, 0, 'bad', 0, 1, 1, 0, 1 }) > 0
  )
  return lines
end
return T

-- One check of a demon (plan v10 V7: CHECK-CREATURE.ps1 <id>): every element
-- the game needs of it, each reported OK or MISSING with what is wrong:
-- definition, atlas (sheet, images), frames (count for its layout, quiet
-- poses, feet as measured), anatomy, masks (baked and bound to the source),
-- anatomical points, gallery, bestiary, waves and its attack artwork.
local Enemies = require('src.content.enemies')
local Atlases = require('src.content.art.atlases')
local Sheet = require('src.content.art.sheet')
local Anatomy = require('src.content.art.anatomy_regions')
local Masks = require('src.content.art.hit_masks')
local Text = require('src.content.text')
local Waves = require('src.content.waves')
local Contract = require('src.enemies.art_contract')
local Provenance = require('qa.mask_provenance')
local Tool = require('qa.art.sheet_tool')
local Check = {}
-- Frames of each layout (enemies/animation.lua): the action poses, then four
-- quiet poses.
local ACTION_FRAMES = { extended = 24, compact = 16 }
function Check.run(id)
  local lines, missing = {}, 0
  local function report(ok, what, detail)
    lines[#lines + 1] = (ok and 'OK      ' or 'MISSING ')
      .. what
      .. (detail and (': ' .. detail) or '')
    missing = missing + (ok and 0 or 1)
  end
  local def = Enemies[id]
  report(
    def ~= nil and type(def) == 'table' and def.id == id,
    'definition',
    'content/enemies.lua: ' .. id
  )
  if not (def and def.id == id) then
    return lines, missing
  end
  local look = def.appearance
  local atlas = look.atlas or def.kind or id
  local sheet = Atlases.sheets[atlas]
  report(sheet ~= nil, 'atlas sheet', 'content/art/sheets/' .. atlas .. '.lua')
  if sheet then
    local problems = Sheet.problems(sheet)
    for _, source in ipairs(sheet.sources) do
      local info = love.filesystem.getInfo(source.path)
      if not info then
        problems[#problems + 1] = 'no image ' .. source.path
      else
        local data = love.image.newImageData(source.path)
        local w, h = data:getDimensions()
        data:release()
        if w ~= source.size[1] or h ~= source.size[2] then
          problems[#problems + 1] = 'size of ' .. source.path .. ' is ' .. w .. 'x' .. h
        end
      end
    end
    report(
      #problems == 0,
      'atlas images',
      #problems == 0 and (#sheet.sources .. ' images at their sizes')
        or table.concat(problems, '; ')
    )
    local wanted = ACTION_FRAMES[look.layout] + 4
    local entry = Atlases.entries[atlas]
    local quiet = Atlases.idle[atlas]
    report(
      #sheet.frames == wanted
        and entry.originalCount == ACTION_FRAMES[look.layout]
        and quiet.first == entry.originalCount + 1,
      'frames',
      #sheet.frames
        .. ' frames ('
        .. look.layout
        .. ' layout: '
        .. wanted
        .. ', the last four quiet)'
    )
    if #problems == 0 then
      local measured, differ = Tool.measure(sheet), {}
      for index, frame in ipairs(measured.frames) do
        if frame.feet ~= sheet.frames[index].feet then
          differ[#differ + 1] = index
        end
      end
      report(
        #differ == 0,
        'feet',
        #differ == 0 and 'as measured'
          or ('re-export the sheet, frames ' .. table.concat(differ, ','))
      )
    end
  end
  local layout = Atlases.layouts[atlas]
  if look.hit ~= 'volumes' then
    local regions = look.regions or atlas
    local annotation = Anatomy.layouts[regions]
    local problems = {}
    if not annotation then
      problems[1] = 'no annotation ' .. regions .. ' (content/art/anatomy/index.lua)'
    elseif layout and #annotation.frames ~= #layout.frames then
      problems[1] = #annotation.frames .. ' annotated frames of ' .. #layout.frames
    else
      for index, frame in ipairs(annotation.frames) do
        for _, problem in ipairs(Anatomy.problems(frame, regions .. '/' .. index)) do
          problems[#problems + 1] = problem
        end
      end
    end
    report(#problems == 0, 'anatomy', #problems == 0 and regions or table.concat(problems, '; '))
    local masks, bound = Masks.layouts[atlas], {}
    if not masks or (layout and #masks ~= #layout.frames) then
      bound[1] = 'not baked (BAKE-HIT-MASKS.ps1)'
    elseif layout then
      local frames = {}
      for _, f in ipairs(Provenance.frames()) do
        if f.group == 'layouts' and f.id == atlas then
          frames[#frames + 1] = f
        end
      end
      bound = Provenance.problems(Masks.sources, Provenance.capture(frames))
    end
    report(
      #bound == 0,
      'masks',
      #bound == 0 and 'baked from the current images' or table.concat(bound, '; ')
    )
  end
  local points = 0
  for _, entry in ipairs(require('qa.data.hit_landmarks')) do
    if entry.kind == id then
      points = points + #entry.points
    end
  end
  report(points > 0, 'anatomical points', points .. ' in qa/data/hit_landmarks.lua')
  local field = def.catalog.field
  report(field ~= nil, 'gallery', field and ('statue and pad ' .. field) or 'catalog.field')
  local card = def.catalog.bestiary
  report(
    type(card) == 'table' and Text.has(def.name) and Text.has(card.text) and Text.has(card.tip),
    'bestiary',
    type(card) == 'table' and ('card ' .. card.order) or 'catalog.bestiary with text keys'
  )
  local waves = {}
  for index, wave in ipairs(Waves) do
    for _, kind in ipairs(wave.queue) do
      if kind == id then
        waves[#waves + 1] = index
        break
      end
    end
  end
  report(
    #waves > 0,
    'waves',
    #waves > 0 and ('in waves ' .. table.concat(waves, ', ')) or 'content/waves.lua'
  )
  local art = Contract.problems(def)
  report(
    #art == 0,
    'attack artwork',
    #art == 0 and 'every sequence complete' or table.concat(art, '; ')
  )
  return lines, missing
end
return Check

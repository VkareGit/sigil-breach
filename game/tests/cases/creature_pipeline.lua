-- Plan v10 V7, the content pipeline for new demons. The sheet tool measures
-- every shipped atlas to its sheet and the frames are the sheets' result;
-- every annotation exported by the anatomy tools reads back exactly; the
-- region editor edits and undoes; and a demon with a new atlas (new images:
-- the Plague Gardener's sheets recoloured) enters the game from data and
-- tool output alone: its sheet proposed from the images, its anatomy
-- generated from part layers, its masks baked, its definition. It animates,
-- draws, and a shot aimed at its head meets its head. Test-only: everything
-- is removed again.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
local function recolour(from, to)
  local data = love.image.newImageData(from)
  data:mapPixel(function(_, _, r, g, b, a)
    return b, r * 0.8, g, a
  end)
  love.filesystem.write(to, data:encode('png'))
  data:release()
  return to
end
-- Part layers over a source: in every cell, the top fifth of the opaque
-- silhouette is the head, the bottom third the legs.
local function layers(sheet, source, index, head, legs)
  local Sheet = require('src.content.art.sheet')
  local data = love.image.newImageData(source.path)
  local w, h = data:getDimensions()
  local headMask, legMask = love.image.newImageData(w, h), love.image.newImageData(w, h)
  for _, frame in ipairs(sheet.frames) do
    if frame.source == index then
      local x0, x1, y0, y1 = Sheet.cut(source, frame.cell)
      local top, bottom
      for y = y0, y1 do
        for x = x0, x1, 2 do
          local _, _, _, a = data:getPixel(x, y)
          if a > 0.65 then
            top, bottom = top or y, y
            break
          end
        end
      end
      if top then
        local span = bottom - top
        for y = top, bottom do
          for x = x0, x1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.65 then
              if y < top + math.max(4, span * 0.2) then
                headMask:setPixel(x, y, 1, 1, 1, 1)
              elseif y > bottom - span / 3 then
                legMask:setPixel(x, y, 1, 1, 1, 1)
              end
            end
          end
        end
      end
    end
  end
  love.filesystem.write(head, headMask:encode('png'))
  love.filesystem.write(legs, legMask:encode('png'))
  data:release()
  headMask:release()
  legMask:release()
end
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'creature pipeline: ', 'creature pipeline: ')
  local Atlases = require('src.content.art.atlases')
  local Sheet = require('src.content.art.sheet')
  local Tool = require('qa.art.sheet_tool')
  local Export = require('qa.art.anatomy_export')
  local Anatomy = require('src.content.art.anatomy_regions')
  local Frames = require('src.content.art.enemy_frames')
  local Masks = require('src.content.art.hit_masks')

  -- The sheets: measured by the tool, and the frames are their result.
  local measured, written = true, true
  for _, id in ipairs(Atlases.kinds) do
    local sheet = Atlases.sheets[id]
    measured = measured and Export.same(Tool.measure(sheet), sheet)
    written = written and Export.same(Sheet.layout(Export.read(Tool.text(sheet))), Frames[id])
  end
  check(
    'the sheet tool measures all six atlases to their sheets (feet and sizes from the images)',
    measured and #Atlases.kinds == 6
  )
  check('a sheet written by the tool reads back to the same frames, bit for bit', written)
  check("the frame placement is the sheets' result", Frames == Atlases.layouts)
  -- Masks baked from the sheets' frames are the shipped ones, bit for bit (the
  -- first, a supplementary and the last frame of each atlas; BAKE-HIT-MASKS
  -- rebakes them all).
  local Bake = require('qa.bake_hit_masks')
  local rebaked, compared = true, 0
  for _, id in ipairs(Atlases.kinds) do
    local layout, entry = Frames[id], Atlases.entries[id]
    for _, index in ipairs({ 1, entry.replacements[1].targets[1], #layout.frames }) do
      local region = layout.frames[index]
      local mask = Bake.frame(region, region.sourcePath, region.sourcePath ~= entry.path)
      rebaked = rebaked and Export.same(mask, Masks.layouts[id][index])
      compared = compared + 1
    end
  end
  check(
    'masks rebaked from the sheets equal the shipped masks bit for bit (' .. compared .. ' frames)',
    rebaked
  )

  -- The anatomy export: every shipped annotation reads back exactly.
  local exported, count = true, 0
  local function exact(id, annotation)
    count = count + 1
    exported = exported and Export.same(Export.read(Export.text(id, annotation)), annotation)
  end
  for id, annotation in pairs(Anatomy.layouts) do
    exact(id, annotation)
  end
  for id in require('src.content.ability_art').each() do
    exact(id, Anatomy.abilities[id])
  end
  check(
    'the anatomy export of all ' .. count .. ' annotations reads back exactly',
    exported and count >= 8
  )

  -- The region editor: edits, keeps the source, undoes to it exactly.
  local Editor = require('qa.art.anatomy_editor')
  local source = Anatomy.layouts.imp
  local before = Export.text('imp', source)
  local editor = Editor.new('imp', source)
  editor:show(3)
  local target = editor:frame().parts[2].polygon
  local picked = editor:pick(target[1] + 0.002, target[2] - 0.002, 0.02)
  editor:grab()
  local moved = picked and editor:move(0.5, 0.5)
  local inserted = editor:insert()
  local vertices = #editor:part().polygon
  local removed = editor:remove()
  editor:add('trial_spur', 'lower', 'horn')
  editor:zone()
  editor:anchor('head', 0.4, 0.2)
  check(
    'the editor moves, inserts and removes vertices and adds parts without touching the source',
    picked
      and moved
      and inserted
      and removed
      and vertices % 2 == 0
      and editor:part().zone == false
      and Export.text('imp', source) == before
  )
  check('an edited annotation passes the anatomy rules', #editor:problems() == 0)
  while editor:undo() do
  end
  check('undo returns the annotation exactly', Export.same(editor.annotation, source))
  check(
    'an edited annotation is written as data that reads back',
    Export.same(Export.read(editor:text()), editor.annotation)
  )

  -- A demon with a new atlas, from data and tool output alone.
  local Creature = require('src.content.defs.creature')
  local A = require('src.content.enemies')
  local Provenance = require('qa.mask_provenance')
  local Layers = require('qa.art.anatomy_layers')
  local id = 'trial_gardener'
  local times = {}
  local function timed(name, run)
    local start = love.timer.getTime()
    local result = run()
    times[#times + 1] = string.format('%s %.0f ms', name, (love.timer.getTime() - start) * 1000)
    return result
  end
  love.filesystem.createDirectory('trial_atlas')
  local main = recolour('assets/art/buer-fresco-v12.png', 'trial_atlas/gardener-fresco.png')
  local quiet = recolour('assets/art/buer-idle-fresco-v13.png', 'trial_atlas/gardener-idle.png')
  local saved = { images = {}, layouts = Masks.sources.layouts[id] }
  local ok, problem = pcall(function()
    local sheet = timed('sheet', function()
      return Export.read(Tool.text(Tool.propose({
        id = id,
        size = 2.65,
        sources = {
          { path = main, columns = 4, rows = 4 },
          { path = quiet, columns = 2, rows = 2, scale = 0.96, idle = true },
        },
        -- A layout of its own (plan v11 E1): three walking frames and no back
        -- (it falls back to the walk), a heavy pain of its own, a wind-up in
        -- four phases; no frame number is written anywhere else.
        poses = {
          walk = { clock = 'stride', frames = { 1, 2, 3 }, rate = 3 },
          windup = { clock = 'action', frames = { 4, 5, 6, 7 }, bounds = { 0.25, 0.5, 0.75 } },
          strike = { frames = { 8 } },
          recover = { frames = { 9 } },
          pain = { frames = { 10 } },
          painHeavy = { clock = 'seconds', frames = { 11, 10 }, bounds = { 0.1 } },
          knockdown = { clock = 'seconds', frames = { 12 }, ends = 0.1 },
          rise = { clock = 'countdown', frames = { 13, 12 }, bounds = { -0.1 } },
          collapse = { clock = 'seconds', frames = { 12, 13, 14 }, step = 0.12 },
        },
      })))
    end)
    Atlases.register(sheet)
    local Poses = require('src.content.art.poses')
    local own = Atlases.poses[id]
    check(
      'its own layout registers: no back walk (the walk stands in), four wind-up phases',
      Poses.resolve(own, 'walkRear') == own.walk
        and Poses.resolve(own, 'watchRear') == own.quiet
        and #own.windup.frames == 4
        and Poses.frame(own.windup, 0.5) == 6
    )
    check(
      'the sheet tool cuts the new atlas into 16 action and 4 quiet frames in its gutters',
      #sheet.frames == 20
        and Atlases.entries[id].originalCount == 16
        and #Sheet.problems(sheet) == 0
    )
    local legend = { id = id, atlas = id, body = 'flesh', parts = {} }
    local heads, legs = {}, {}
    for index, s in ipairs(sheet.sources) do
      local head, leg =
        'trial_atlas/head-' .. index .. '.png', 'trial_atlas/legs-' .. index .. '.png'
      layers(sheet, s, index, head, leg)
      heads[s.path], legs[s.path] = head, leg
    end
    legend.parts[1] = { id = 'legs', zone = 'lower', material = 'flesh', masks = legs }
    legend.parts[2] = { id = 'head', zone = 'head', material = 'flesh', masks = heads }
    local annotation = timed('anatomy', function()
      return Export.read(Export.text(id, Layers.annotation(sheet, legend)))
    end)
    Anatomy.layouts[id] = annotation
    local problems = {}
    for index, frame in ipairs(annotation.frames) do
      for _, message in ipairs(Anatomy.problems(frame, id .. '/' .. index)) do
        problems[#problems + 1] = message
      end
    end
    check(
      'part layers give every frame its regions under the anatomy rules '
        .. table.concat(problems, '; '),
      #problems == 0 and #annotation.frames == 20
    )
    timed('masks', function()
      local layout, baked = Atlases.layouts[id], {}
      for index, region in ipairs(layout.frames) do
        baked[index] = Bake.frame(region, region.sourcePath, region.sourcePath ~= main)
      end
      Masks.layouts[id] = baked
      local frames = {}
      for _, f in ipairs(Provenance.frames()) do
        if f.id == id then
          frames[#frames + 1] = f
        end
      end
      local captured = Provenance.capture(frames)
      Masks.sources.layouts[id] = captured.layouts[id]
      for path, hash in pairs(captured.images) do
        saved.images[path] = Masks.sources.images[path]
        Masks.sources.images[path] = hash
      end
    end)
    Fixtures.words({ trial_gardener = 'Trial Gardener' })
    A[id] = Creature.define({
      extends = A.buer,
      id = id,
      kind = 'buer',
      variant = id,
      name = id,
      appearance = { atlas = id },
    })
    local report = require('qa.art.creature_check').run(id)
    local complete = 0
    for _, line in ipairs(report) do
      for _, what in ipairs({
        'atlas sheet',
        'atlas images',
        'frames',
        'feet',
        'anatomy',
        'masks',
        'attack artwork',
        'poses',
      }) do
        if line:find('OK      ' .. what .. ':', 1, true) == 1 then
          complete = complete + 1
        end
      end
    end
    check(
      'CHECK-CREATURE finds its atlas, frames, poses, feet, anatomy, masks and artwork complete',
      complete == 8
    )
    -- In play: the unchanged systems animate, draw and shoot it.
    local g = Fixtures.arena(G)
    g.state = 'playing'
    local e = g:spawn(id, 16, 21)
    e.spawnAge, e.dummy, e.hp, e.maxHp = 1, true, 1000, 1000
    local Pose = require('src.enemies.pose')
    local Surface = require('src.enemies.surface')
    local B = require('src.combat.ballistics')
    local frames = {}
    for _ = 1, 240 do
      g:update(1 / 120, {})
      frames[select(1, Pose.base(g, e))] = true
    end
    local _, _, _, _, _, _, _, _, _, atlas = Pose.base(g, e)
    require('src.render.fresco_enemies').add(renderer, id)
    local drew = pcall(function()
      renderer:draw(g, 1280, 720)
    end)
    check('it poses and draws from its own atlas', atlas == id and next(frames) ~= nil and drew)
    local prepared = Surface.prepare(g, e)
    local x, y, z = Surface.locateZone(prepared, 'head')
    local ox, oy, oz = B.origin(g)
    g:switchWeapon(2)
    g.cooldown = 0
    g.player.yaw = math.atan2(x - ox, z - oz)
    g.player.pitch = math.atan2(y - oy, math.sqrt((x - ox) ^ 2 + (z - oz) ^ 2))
    local volley
    g.bus:on('sim', 'VolleyResolved', function(event)
      volley = event.report
    end)
    g:shoot()
    local contact = volley and volley.contacts[1]
    check(
      'a shot aimed at its head meets its head',
      contact and contact.targetId == e.id and contact.zone == 'head' and e.hp < 1000
    )
    -- Every frame of every pose it uses: a shot at its painted head meets it
    -- (the proving ground holds a posed frame: previewFrame).
    local Field = require('src.run.test_field')
    local field = Field.new(G)
    field.testing = true
    Field.reset(field)
    Field.close(field)
    local target = field:spawn(id, 16, 18)
    target.spawnAge, target.dummy = 1, true
    local used, met = {}, 0
    for _, pose in pairs(own) do
      for _, frame in ipairs(pose.frames) do
        used[frame] = true
      end
    end
    local wanted = 0
    field.bus:on('sim', 'VolleyResolved', function(event)
      local c = event.report.contacts[1]
      if c and c.targetId == target.id and c.zone == 'head' then
        met = met + 1
      end
    end)
    for frame in pairs(used) do
      wanted = wanted + 1
      target.previewFrame, target.x, target.z, target.hp = frame, 16, 18, 1000
      target.pushX, target.pushZ = 0, 0
      local p = field.player
      p.x, p.z = 16, 22
      field:switchWeapon(2)
      p.arsenal.judge.mag, p.arsenal.judge.readyAt, field.cooldown = 6, 0, 0
      local aim = Surface.prepare(field, target)
      local hx, hy, hz = Surface.locateZone(aim, 'head')
      local sx, sy, sz = B.origin(field)
      p.yaw = math.atan2(hx - sx, hz - sz)
      p.pitch = math.atan2(hy - sy, math.sqrt((hx - sx) ^ 2 + (hz - sz) ^ 2))
      field:shoot()
    end
    check(
      string.format('a shot meets the painted head of every posed frame (%d of %d)', met, wanted),
      wanted == 18 and met == wanted
    )
  end)
  for _, field in ipairs({ 'animations', 'feet', 'frames', 'frameImages', 'frameMirrors' }) do
    if renderer[field] then
      renderer[field][id] = nil
    end
  end
  if renderer.frescoEnemySupplements then
    renderer.frescoEnemySupplements[id] = nil
  end
  A[id] = nil
  Anatomy.layouts[id], Masks.layouts[id], Masks.sources.layouts[id] = nil, nil, saved.layouts
  for path, hash in pairs(saved.images) do
    Masks.sources.images[path] = hash
  end
  Masks.sources.images[main], Masks.sources.images[quiet] = nil, nil
  Atlases.unregister(id)
  for _, file in ipairs(love.filesystem.getDirectoryItems('trial_atlas')) do
    love.filesystem.remove('trial_atlas/' .. file)
  end
  love.filesystem.remove('trial_atlas')
  assert(ok, problem)
  local file = assert(io.open(require('qa.output').path('creature-pipeline.txt'), 'w'))
  file:write('new atlas demon through the tools: ' .. table.concat(times, ', ') .. '\n')
  file:close()
  check('the tools took ' .. table.concat(times, ', '), #times == 3)
  return lines
end
return Tests

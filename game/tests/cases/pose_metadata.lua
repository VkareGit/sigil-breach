-- Presentation must consume authored placement without installing geometry.
-- These regressions use independent source pixels and perturb collision only.
local Fixtures = require('tests.support.fixtures')
local Pose = require('src.enemies.pose')
local Geometry = require('src.enemies.geometry')
local EnemyArt = require('src.content.enemy_art')
local HitVolumes = require('src.enemies.hit_volumes')
local Surface = require('src.enemies.surface')
local Anatomy = require('src.content.art.anatomy_regions')
local Archetypes = require('src.content.enemies')
local Schema = require('src.core.schema')
local Tests = {}
local function copyPlacement(p)
  return { p.sx, p.sy, p.size, p.baseY, p.lean, p.shift, p.yaw, p.sourcePath, p.region }
end
function Tests.run(Game, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'pose metadata ', '')
  local g = { mode = 'field', player = { x = 0, z = 8 }, time = 0, testField = {} }
  local data = {}
  for _, kind in ipairs(EnemyArt.kinds) do
    local layout = EnemyArt.layouts[kind]
    local registered, feetValid = true, true
    for index, frame in ipairs(layout.frames) do
      local e = { kind = kind, id = 7, hp = 100, x = 0, z = 0, previewFrame = index }
      local before = { Geometry.pose(g, e) }
      if renderer then
        Geometry.register(kind, renderer.frames[kind], renderer.feet[kind])
      end
      local after = { Geometry.pose(g, e) }
      for n, value in ipairs(before) do
        registered = registered and value == after[n]
      end
      local p = Pose.sample(g, e)
      registered = registered and p.region == frame and p.sourcePath == frame.sourcePath
      if not data[frame.sourcePath] then
        data[frame.sourcePath] = love.image.newImageData(frame.sourcePath)
      end
      local image = data[frame.sourcePath]
      local w, h = image:getDimensions()
      local r = frame.rect
      local x0, y0 = math.floor(r[1] * w + 0.5), math.floor(r[2] * h + 0.5)
      local width, height = math.floor(r[3] * w + 0.5), math.floor(r[4] * h + 0.5)
      local bottom = y0 + height - 1
      for y = bottom, y0, -1 do
        local pixels = 0
        for x = x0, x0 + width - 1 do
          if select(4, image:getPixel(x, y)) > 0.65 then
            pixels = pixels + 1
          end
        end
        if pixels >= 3 then
          bottom = y
          break
        end
      end
      feetValid = feetValid
        and math.abs(layout.feet[index] - (y0 + height - 1 - bottom) / height) < 1e-12
    end
    check(kind .. ' all authored floor anchors still match independent PNG alpha rows', feetValid)
    check(kind .. ' GPU registration never changes headless pose placement', registered)
  end
  for _, image in pairs(data) do
    image:release()
  end
  local e = {
    kind = 'imp',
    id = 7,
    hp = 100,
    x = 0,
    z = 0,
    ai = 'windup',
    attackKind = 'leap',
    windup = 0.1,
    spawnAge = 1,
    phase = 0,
    walk = 0,
  }
  g.testField = nil
  local oldGraphics = love.graphics
  love.graphics = nil
  -- Moving the authored head region changes where a shot meets the head, but
  -- never the drawing (leap artwork is registered to art anchors).
  local before = copyPlacement(Pose.sample(g, e))
  local frame = Pose.sample(g, e)
  local anatomy = Anatomy.abilities[frame.ability].frames[frame.abilityFrame]
  local head
  for _, part in ipairs(anatomy.parts) do
    head = part.id == 'head' and part or head
  end
  local _, headBefore = Surface.locate(Surface.prepare(g, e), 'head')
  local original = {}
  for i, value in ipairs(head.polygon) do
    original[i] = value
    head.polygon[i] = value + (i % 2 == 0 and 0.05 or 0)
  end
  local _, headAfter = Surface.locate(Surface.prepare(g, e), 'head')
  local after = copyPlacement(Pose.sample(g, e))
  for i, value in ipairs(original) do
    head.polygon[i] = value
  end
  love.graphics = oldGraphics
  local fixed = true
  for i, value in ipairs(before) do
    fixed = fixed and value == after[i]
  end
  check(
    'moving the head region changes where shots meet it but cannot move or scale leap artwork',
    fixed and headBefore and headAfter and headBefore ~= headAfter
  )
  local actor = {
    kind = 'imp',
    id = 9,
    hp = 100,
    x = 0,
    z = 0,
    previewFrame = 1,
    archetype = Schema.copy(Archetypes.imp),
  }
  g.testField, g.mode = {}, 'field'
  actor.archetype.appearance.hit = 'volumes'
  actor.archetype.appearance.anatomy = 'metadata-test'
  local shapes = {}
  for i = 1, 6 do
    shapes[i] = {
      id = 'limb-' .. i,
      zone = 'lower',
      material = i == 6 and 'bone' or 'flesh',
      x = 0.1 * i,
      bottom = 0,
      top = 0.4,
      radius = 0.04,
    }
  end
  HitVolumes.profiles['metadata-test'] =
    { shapes = shapes, frameShapes = { [2] = { shapes[6], shapes[2] } } }
  local volumes = Geometry.volumes(g, actor)
  local arbitrary = #volumes == 6 and Geometry.find(g, actor, 'limb-6').material == 'bone'
  actor.previewFrame = 2
  volumes = Geometry.volumes(g, actor)
  arbitrary = arbitrary
    and #volumes == 2
    and volumes[1].id == 'limb-6'
    and volumes[1].zone == 'lower'
    and Geometry.find(g, actor, 'limb-5') == nil
  actor.archetype.appearance.hit = 'painted'
  local painted = not Geometry.uses(actor)
    and not pcall(Geometry.volumes, g, actor)
    and Surface.locate(Surface.prepare(g, actor), 'head') ~= nil
  HitVolumes.profiles['metadata-test'] = nil
  check(
    'body volumes support six shapes, shared damage zones and per-frame removal without stale bodies',
    arbitrary
  )
  check('a painted body prepares no volumes: its head is a painted region of its surface', painted)
  return lines
end
return Tests

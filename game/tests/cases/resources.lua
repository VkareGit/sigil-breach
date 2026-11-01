-- Ownership checks exercise native sampling variants and local glyph data,
-- plus explicit release/failure paths without machine-dependent memory limits.
local Fixtures = require('tests.support.fixtures')
local Resources = require('src.render.resources')
local Tests = {}
function Tests.run(Game, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'resources: ', 'resources: ')
  local first, second = Resources.new('test first'), Resources.new('test second')
  local created, destroyed = 0, 0
  local function create()
    created = created + 1
    return {}
  end
  local function destroy()
    destroyed = destroyed + 1
  end
  local a = first:retain('test|shared', create, destroy)
  local b = second:retain('test|shared', create, destroy)
  check('equal resource keys share a single construction', a == b and created == 1)
  first:release()
  first:release()
  check('one owner cannot destroy a still-shared resource', destroyed == 0)
  second:release()
  check('the final owner destroys exactly once', destroyed == 1)
  check(
    'a released scope rejects accidental reuse',
    not pcall(first.retain, first, 'test|closed', create, destroy)
  )
  local retry = Resources.new('test retry')
  local failed = pcall(retry.retain, retry, 'test|retry', function()
    error('controlled failed allocation')
  end, destroy)
  local retried = retry:retain('test|retry', create, destroy)
  check('failed construction remains retryable', not failed and retried and created == 2)
  retry:release()
  do
    local abandoned = Resources.new('test abandoned tool')
    abandoned:retain('test|abandoned', create, destroy)
  end
  collectgarbage('collect')
  collectgarbage('collect')
  check('abandoned tools have a collection fallback', destroyed == 3)

  local meta = require('assets.fonts.painted-v16.catalog').sizes[11]
  first, second = Resources.new('test images one'), Resources.new('test images two')
  local nearest = first:image(meta.image)
  local shared = second:image(meta.image)
  local linear = second:image(meta.image, { filter = 'linear' })
  check(
    'same path shares only the same sampling variant',
    nearest == shared
      and nearest ~= linear
      and nearest:getFilter() == 'nearest'
      and linear:getFilter() == 'linear'
  )
  local manifest = second:manifest()
  check(
    'manifest lists actual paths and dimensions in stable order',
    #manifest == 2
      and manifest[1].key < manifest[2].key
      and manifest[1].descriptor.path == meta.image
      and manifest[1].descriptor.width == nearest:getWidth()
  )
  -- A renderer repeats its lookups every frame (gallery boards): a variant it
  -- already holds is named once and a lookup builds no table or key (before:
  -- about 0.6 KiB each). What remains is a fixed warm-up remainder.
  local sampling = { filter = 'linear' }
  second:image(meta.image, sampling)
  collectgarbage('collect')
  collectgarbage('stop')
  local heap = collectgarbage('count')
  local same = true
  for _ = 1, 200 do
    same = same
      and second:image(meta.image, sampling) == linear
      and second:image(meta.image) == shared
  end
  local grown = collectgarbage('count') - heap
  collectgarbage('restart')
  check(
    'a held image variant is found again without allocating',
    same and grown / 400 < 0.01 and second:hasImage(meta.image, sampling)
  )
  first:release()
  check('native shared image survives one consumer closing', shared:getWidth() > 0)
  second:release()

  local Bitmap = require('src.ui.fonts.bitmap_font')
  local one, two = Bitmap.load(11), Bitmap.load(11)
  local cp = string.byte('A')
  check(
    'glyph GPU quads stay outside shared content metadata',
    meta.glyphs[cp].quad == nil
      and one.glyphs[cp] ~= meta.glyphs[cp]
      and one.glyphs[cp].quad ~= two.glyphs[cp].quad
  )
  one:setFilter('linear', 'linear')
  check(
    'font sampling changes never repaint another consumer',
    one.image:getFilter() == 'linear' and two.image:getFilter() == 'nearest'
  )
  one:release()
  check(
    'other font metrics and image remain usable after release',
    two:getWidth('TEST') > 0 and two.image:getWidth() > 0
  )
  two:release()

  -- Recreating a renderer must close its own native allocation while the
  -- application's original renderer and shared artwork remain alive.
  local Renderer = require('src.render.renderer')
  collectgarbage('collect')
  local before = love.graphics.getStats()
  for cycle = 1, 2 do
    local fresh = Renderer.new()
    local entries = fresh.resources:manifest()
    local valid = #entries > 0
    for _, entry in ipairs(entries) do
      if entry.descriptor and entry.descriptor.path then
        valid = valid and love.filesystem.getInfo(entry.descriptor.path) ~= nil
      end
    end
    check('renderer manifest contains actual existing source dependencies ' .. cycle, valid)
    fresh:resize(960, 540)
    fresh:release()
    fresh:release()
    fresh = nil
    collectgarbage('collect')
    local after = love.graphics.getStats()
    check(
      'renderer recreate/release retains no extra native images or canvases ' .. cycle,
      after.images <= before.images and after.canvases <= before.canvases
    )
  end
  local UI = require('src.ui.interface')
  -- A living simulation world is not a resource owner. Closing one renderer
  -- must release its last mesh reference even if the session is kept for replay.
  local game = Game.new('floor')
  game.ephemeral = true
  local sceneRenderer = Renderer.new()
  sceneRenderer:draw(game, 960, 540)
  local oldMesh = sceneRenderer.worldMesh
  check(
    'real draw gives geometry an explicit renderer owner',
    sceneRenderer.worldResources and oldMesh:getVertexCount() > 0
  )
  sceneRenderer:release()
  check(
    'live world cannot retain the closed renderer mesh',
    not pcall(oldMesh.getVertexCount, oldMesh)
  )
  local rebuiltRenderer = Renderer.new()
  rebuiltRenderer:draw(game, 960, 540)
  check(
    'same living world draws again with a fresh native mesh',
    rebuiltRenderer.worldMesh ~= oldMesh and rebuiltRenderer.worldMesh:getVertexCount() > 0
  )
  rebuiltRenderer:release()

  local Lights = require('src.render.lights')
  local lights = Lights.new()
  lights:prepare(game.world)
  local previousWorld, previousAtlas = lights.world, lights.visibility
  local nextWorld = Game.new('floor').world
  nextWorld.lamps[1].x = nextWorld.lamps[1].x + 0.0001
  local newImage = love.graphics.newImage
  local attempts = 0
  love.graphics.newImage = function()
    attempts = attempts + 1
    error('visibility fixture allocation failure')
  end
  local accepted = pcall(lights.prepare, lights, nextWorld)
  love.graphics.newImage = newImage
  check(
    'failed visibility replacement preserves the prior usable atlas',
    not accepted
      and attempts == 1
      and lights.world == previousWorld
      and lights.visibility == previousAtlas
      and previousAtlas.image:getWidth() > 0
  )
  lights:prepare(nextWorld)
  check(
    'same failed world retries and tiny source differences cannot alias the cache',
    lights.world == nextWorld and lights.visibility ~= previousAtlas
  )
  lights:release()
  local fonts = UI.fonts
  local app = require('src.app.application').new()
  app.qa = require('qa.runtime').new({ '--selftest' })
  app:quit()
  check(
    'unloaded application cannot tear down another application UI',
    UI.fonts == fonts and fonts[11].image:getWidth() > 0
  )
  return lines
end
return Tests

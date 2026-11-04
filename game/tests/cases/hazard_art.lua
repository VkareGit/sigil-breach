-- The actual pool clock renders three painted phases without owning combat
-- state; world depth still hides a pool behind an existing pillar.
local Fixtures = require('tests.support.fixtures')
local HazardArt = require('src.render.hazard_art')
local Definition = require('src.content.art.hazards')
local Hazards = require('src.enemies.hazards')
local Archetypes = require('src.content.enemies')
local Integrity = require('src.session.integrity')
local UI = require('src.ui.interface')
local Field = require('src.run.test_field')
local Test = {}
local function save(data, path)
  local bytes = data:encode('png')
  local file = assert(io.open(path, 'wb'))
  file:write(bytes:getString())
  file:close()
  bytes:release()
end
function Test.run(Game, renderer)
  local output = os.getenv('SIGIL_UI_QA_DIR') or require('src.app.release').qaOutput
  local lines = {}
  local check = Fixtures.checker(lines, 'hazard art: ', 'hazard art: ')
  local function field()
    local game = Field.new(Game)
    Field.close(game)
    game.ephemeral = true
    game.enemies, game.bullets, game.hazards, game.pickups = {}, {}, {}, {}
    game.player.x, game.player.z, game.player.yaw = 16, 25, math.pi
    return game
  end
  check(
    'ground atlas is acquired during renderer startup',
    renderer.resources:hasImage(Definition.path)
  )
  local largest = 0
  for _, vertex in ipairs(HazardArt.vertices()) do
    largest = math.max(largest, math.sqrt(vertex[1] ^ 2 + vertex[3] ^ 2))
    assert(vertex[1] ^ 2 + vertex[3] ^ 2 <= 0.25 + 1e-12)
  end
  check(
    'textured footprint never extends beyond its authoritative radius',
    math.abs(largest - 0.5) < 1e-12
  )
  -- A single-suite run has not visited the creatures gallery. Match the real
  -- loading page before measuring allocations in this effect's draw calls.
  renderer:prepareCreatures({ 'boss', 'buer' })
  local nativeImage, imageData = love.graphics.newImage, love.image.newImageData
  local loads = 0
  local loaded = {}
  local drawing = false
  love.graphics.newImage = function(source, ...)
    if drawing and type(source) == 'string' and source:match('%.png$') then
      loads = loads + 1
      loaded[#loaded + 1] = source
    end
    return nativeImage(source, ...)
  end
  love.image.newImageData = function(source, ...)
    if drawing and type(source) == 'string' and source:match('%.png$') then
      loads = loads + 1
      loaded[#loaded + 1] = source
    end
    return imageData(source, ...)
  end
  local ok, problem = xpcall(function()
    for _, id in ipairs({ 'boss', 'buer' }) do
      local game = field()
      game.view.motion, game.view.swapAge, game.view.shotAge = false, 1, 10
      game.view.messageTimer, game.zoneTimer, game.view.feedbackTimer = 0, 0, 0
      game.player.pitch = -0.27
      local enemy = game:spawn(id, 16, 17)
      enemy.ai = 'idle'
      local attack = Archetypes[id].attacks[1]
      local spec = attack.line or attack.pool
      Hazards.add(game, 16, 21, spec.delay, spec.radius, spec.life, {
        packet = spec.packet,
        pulse = spec.pulse,
        condition = spec.condition,
      })
      local hazard = assert(game.hazards[1])
      local function capture(stage, label)
        local before = Integrity.capture(game)
        local sample = HazardArt.sample(hazard)
        check(id .. ' samples the real ' .. stage .. ' stage', sample.stage == stage)
        check(
          id .. ' keeps radius in ' .. stage,
          sample.radius == spec.radius and hazard.radius == spec.radius
        )
        drawing = true
        renderer:draw(game, 1280, 720)
        check(
          id .. ' draw leaves simulation unchanged in ' .. stage,
          not Integrity.difference(before, Integrity.capture(game))
        )
        local target = love.graphics.newCanvas(1280, 720)
        love.graphics.push('all')
        love.graphics.setCanvas(target)
        love.graphics.origin()
        renderer:present(game, 1280, 720)
        UI.draw(game, 1280, 720, { sensitivity = 1, motion = false, music = 0, hints = false })
        love.graphics.pop()
        drawing = false
        local pixels = target:newImageData()
        save(pixels, output .. '/hazard-' .. id .. '-' .. (label or stage) .. '-v33.png')
        pixels:release()
        target:release()
        return sample
      end
      capture('telegraph')
      Hazards.update(game, spec.delay - 0.001)
      local lastWarning = capture('telegraph', 'delay-end')
      Hazards.update(game, 0.001001)
      local ignition = capture('active', 'activation')
      check(
        id .. ' replaces the warning cel exactly when damage becomes active',
        ignition.first ~= lastWarning.first
          and ignition.mix == 0
          and lastWarning.mix == 0
          and ignition.warning >= 0.9
          and lastWarning.warning >= 0.9
      )
      Hazards.update(game, 0.2)
      local active = capture('active')
      check(
        id .. ' uses its packet pigment family',
        id == 'boss' and active.first <= 4 or id == 'buer' and active.first >= 5
      )
      Hazards.update(game, hazard.life - 0.12)
      local fading = capture('fading')
      check(
        id .. ' uses an ash cel without fading its still dangerous boundary',
        fading.first ~= active.first
          and fading.mix == 0
          and fading.alpha == active.alpha
          and fading.warning >= 0.9
      )
      Hazards.update(game, 0.13)
      check(id .. ' illustration expires with the real hazard', #game.hazards == 0)
    end
    local hidden = field()
    hidden.player.x, hidden.player.z, hidden.player.yaw, hidden.player.pitch =
      12, 24, math.pi, -0.25
    hidden.view.motion = false
    drawing = true
    renderer:draw(hidden, 1280, 720)
    drawing = false
    local clear = renderer.canvas:newImageData()
    local clearBytes = clear:getString()
    Hazards.add(hidden, 12, 18, 0, 0.35, 1, { packet = Archetypes.boss.attacks[1].line.packet })
    drawing = true
    renderer:draw(hidden, 1280, 720)
    drawing = false
    local covered = renderer.canvas:newImageData()
    check(
      'an existing opaque pillar occludes the complete ground illustration',
      clearBytes == covered:getString()
    )
    save(covered, output .. '/hazard-depth-occluded-v33.png')
    clear:release()
    covered:release()
    hidden.hazards[1].x, hidden.hazards[1].z = 13.3, 22
    drawing = true
    renderer:draw(hidden, 1280, 720)
    drawing = false
    local exposed = renderer.canvas:newImageData()
    check(
      'moving the same illustration in front of the pillar makes it visible',
      clearBytes ~= exposed:getString()
    )
    save(exposed, output .. '/hazard-depth-visible-v33.png')
    exposed:release()
  end, debug.traceback)
  love.graphics.newImage, love.image.newImageData = nativeImage, imageData
  assert(ok, problem)
  check(
    'drawing phases performs no lazy PNG decode or file upload: ' .. table.concat(loaded, ', '),
    loads == 0
  )
  return lines
end
return Test

-- CPU recording fixture through the production input/observation boundary.
-- Hardware buttons are controlled; no rasterization, audio listening or GPU
-- cost is claimed. Journal replay verifies both receipts and final integrity.
local Field = require('src.run.test_field')
local Input = require('src.app.input')
local Presentation = require('src.render.presentation')
local Journal = require('src.session.journal')
local Observation = require('src.combat.observation')
local Tooling = require('qa.tooling')
local Workload = {}
local clock = love.timer.getTime
local function heap()
  collectgarbage('collect')
  collectgarbage('collect')
  return collectgarbage('count')
end

function Workload.run(Game, count, seconds)
  -- The player-facing catalogue intentionally caps at20. Larger populations
  -- are labelled prepared diagnostics, reconstructed identically for replay.
  -- On the diagnostic crowd map every population is prepared the same way.
  local prepared = count > 20 or Tooling.crowdMap() ~= nil
  local function fresh()
    return prepared and Tooling.crowd(Game, count) or Field.new(Game)
  end
  local game = fresh()
  game.testing = true
  local input = Input.new()
  local keyboard, mouse = love.keyboard.isDown, love.mouse.isDown
  local held = false
  local journal, result
  local ok, problem = xpcall(function()
    love.keyboard.isDown = function()
      return false
    end
    love.mouse.isDown = function(button)
      return button == 1 and held
    end
    local start = clock()
    journal = Journal.record(game)
    local recordStart = (clock() - start) * 1000
    if not prepared then
      for i = 1, count do
        local kind = Field.catalog.enemies[1 + (i - 1) % #Field.catalog.enemies].id
        game:act('catalog', 'field_spawn_' .. kind .. '_1')
      end
      Field.close(game)
    end
    local preparation = Tooling.advanceUntil('recording portal arrival', function()
      return #game.run.pending == 0 and #game.enemies == count
    end, function(dt)
      game:update(dt, input:sample(game))
    end, 1 / 120, 5)
    input:present(game, Presentation.sample(game, 0))
    local initialTextBytes = #Journal.encode(journal)
    local beforeCommands, beforeBytes = journal.commands, journal.estimatedBytes
    local observed, observedBodies, frames = 0, 0, math.floor(seconds * 60 + 0.5)
    start = clock()
    held = true
    for frame = 1, frames do
      -- Real commands, not direct yaw assignment or an empty shoot boolean.
      game:look(0.002, 0)
      if frame % 180 == 0 then
        game:switchWeapon(1 + (math.floor(frame / 180) % #game.player.loadout))
      elseif frame % 90 == 0 then
        game:reloadGun()
      end
      local sample = input:sample(game)
      assert(
        sample.fireCommand and sample.fireCommand.observation,
        'held input lost its displayed observation'
      )
      observed = observed + 1
      observedBodies = observedBodies + #sample.fireCommand.observation.bodies
      for _ = 1, 2 do
        Presentation.capture(game)
        game:update(1 / 120, sample)
        input:consumeEdges(sample)
      end
      input:present(game, Presentation.sample(game, 0))
    end
    local fight = (clock() - start) * 1000
    assert(
      not journal.stopped,
      'recording workload reached a production limit; shorten the sample explicitly'
    )
    Journal.stop(game)
    local beforeCopy = heap()
    local copy = Observation.copy(journal)
    local retainedCopy = heap() - beforeCopy
    assert(copy.commands == journal.commands, 'detached journal copy is incomplete')
    copy = nil
    start = clock()
    local text = Journal.encode(journal)
    local export = (clock() - start) * 1000
    start = clock()
    local decoded = Journal.decode(text)
    local decode = (clock() - start) * 1000
    local replayed = prepared and fresh() or Journal.session(Game, decoded)
    replayed.testing = true
    start = clock()
    Journal.replay(replayed, decoded)
    result = {
      recordStart = recordStart,
      preparationSteps = preparation,
      seconds = frames / 60,
      fight = fight,
      export = export,
      decode = decode,
      replay = (clock() - start) * 1000,
      bytes = #text,
      retainedCopyKiB = retainedCopy,
      commands = journal.commands,
      commandsPerSecond = (journal.commands - beforeCommands) / (frames / 60),
      bytesPerSecond = (journal.estimatedBytes - beforeBytes) / (frames / 60),
      textBytesPerSecond = (#text - initialTextBytes) / (frames / 60),
      estimatedBytes = journal.estimatedBytes,
      budget = journal.budget,
      observations = observed,
      meanBodies = observedBodies / observed,
      receipts = #journal.receipts,
    }
  end, debug.traceback)
  love.keyboard.isDown, love.mouse.isDown = keyboard, mouse
  if journal then
    Journal.stop(game)
  end
  assert(ok, problem)
  return result
end

return Workload

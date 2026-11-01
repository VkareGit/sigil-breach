-- QA can fail too: check real delayed arrivals and the observed recording
-- boundary, in addition to bounds/argument contracts of diagnostic workloads.
local Fixtures = require('tests.support.fixtures')
local Tooling = require('qa.tooling')
local Field = require('src.run.test_field')
local Tests = {}

function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'QA tools: ', 'QA tools: ')
  local Samples = require('qa.frame_samples')
  -- Opposite rankings: sorting a phase before export would silently pair the
  -- long update of frame one with the long readback of frame two.
  local paired = {
    update = { 9, 1 },
    world = { 2, 3 },
    ui = { 1, 2 },
    submit = { 12, 6 },
    readback = { 1, 9 },
    total = { 13, 15 },
  }
  local csv = Samples.csv(paired)
  check(
    'raw frame rows retain chronological cross-phase pairing',
    csv:find('1,9.000000,2.000000,1.000000,12.000000,1.000000,13.000000', 1, true)
      and csv:find('2,1.000000,3.000000,2.000000,6.000000,9.000000,15.000000', 1, true)
      and paired.update[1] == 9
      and paired.readback[1] == 1
  )
  paired.readback[2] = nil
  check(
    'incomplete phase series cannot be exported as paired frames',
    not pcall(Samples.csv, paired)
  )
  local advances = 0
  local steps = Tooling.advanceUntil('already ready', function()
    return true
  end, function()
    advances = advances + 1
  end, 0.1, 1)
  check('ready condition does not advance time', steps == 0 and advances == 0)
  steps = Tooling.advanceUntil('three real steps', function()
    return advances == 3
  end, function()
    advances = advances + 1
  end, 0.1, 0.3)
  check('condition can complete on its last allowed step', steps == 3)
  local ok, reason = pcall(Tooling.advanceUntil, 'broken fixture', function()
    return false
  end, function() end, 0.1, 0.2)
  check(
    'a non-converging workload fails instead of claiming success',
    not ok and reason:find('did not converge', 1, true)
  )
  check(
    'smoke shortens samples but preserves full default',
    Tooling.count(true, 240, 4) == 4 and Tooling.count(false, 240, 4) == 240
  )
  local populations = Tooling.populations('20,48,96')
  check(
    'diagnostic population configuration is explicit and ordered',
    #populations == 3 and populations[3] == 96
  )
  for _, invalid in ipairs({ '0', '48,48', '513', '-1', 'all', '20;96' }) do
    check('invalid population is rejected: ' .. invalid, not pcall(Tooling.populations, invalid))
  end
  check(
    'the largest diagnostic crowd (plan v10 V0) is accepted',
    Tooling.populations('512')[1] == 512
  )
  check('only the diagnostic crowd map is accepted by name', not pcall(function()
    local getenv = os.getenv
    os.getenv = function(name)
      if name == 'SIGIL_CROWD_MAP' then
        return 'floor'
      end
      return getenv(name)
    end
    local ok, problem = pcall(Tooling.crowdMap)
    os.getenv = getenv
    assert(ok, problem)
  end))
  local QA = require('qa.runtime')
  local outputs = {}
  for _, entry in ipairs(Tooling.catalog) do
    local qa = QA.new({ entry.flag, '--qa-smoke' })
    check(
      entry.flag .. ' smoke stays captured and isolated',
      qa.capture and qa.isolated and qa:has('--qa-smoke')
    )
    for _, path in ipairs(entry.reports) do
      check('tool report has one owner: ' .. path, not outputs[path])
      outputs[path] = true
    end
  end
  local game = Field.new(Game)
  game.testing = true
  assert(Field.summon(game, 'imp', 1))
  Field.close(game)
  check(
    'catalogue begins with a pending gate and no immediate body',
    #game.enemies == 0 and #game.run.pending == 1
  )
  steps = Tooling.advanceUntil('real catalogue gate', function()
    return #game.run.pending == 0 and #game.enemies == 1
  end, function(dt)
    game:update(dt, {})
  end, 1 / 120, 5)
  check(
    'state-driven preparation reaches the real delayed summon',
    steps > 1 and game.enemies[1].kind == 'imp'
  )
  local recording = require('qa.recording_workload').run(Game, 3, 0.2)
  check(
    'real held input carries displayed bodies, including cooldown ticks',
    recording.observations == 12
      and recording.meanBodies >= 3
      and recording.commands > recording.observations
  )
  check(
    'recording reports plain-text and detached-memory quantities separately',
    recording.bytes > 0
      and recording.retainedCopyKiB > 0
      and recording.budget.maxBytes > recording.bytes
      and recording.receipts > 0
  )
  local app = require('src.app.application').new()
  app.qa = require('qa.runtime').new({ '--suite=core' })
  app:reset(false)
  check(
    'documented focused flag uses the full selftest application fixture',
    app.game.mode == 'floor'
  )
  return lines
end

return Tests

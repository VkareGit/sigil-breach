-- The 0.33 references of plan v11 (E0): every stage of the plan must
-- reproduce what 0.33 wrote before any stage changed the code (the state
-- projection of the golden scenarios and the expedition trial, the
-- attribution of every kill, the pose table) and must read the checkpoints
-- 0.33 wrote into the same state. The files in tests/fixtures/v033/ are
-- never regenerated; a difference names its step, record and field.
local Fixtures = require('tests.support.fixtures')
local Reference = require('qa.v11_reference')
local Projection = require('qa.state_projection')
local RunSave = require('src.storage.run_save')
local Run = require('src.run.descent')
local Trial = require('qa.scenarios.expedition_trial')
local Tests = {}
local function read(name)
  return love.filesystem.read(Reference.directory .. '/' .. name)
end
function Tests.run(G)
  G = require('tests.support.v033_encounters').game(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'v0.33 reference ', '')
  local files, digests = Reference.build(G)
  -- Strong attribution: the previous build's exact hashes return when ONLY
  -- the encounter content is restored. No solver or runtime function is patched.
  for name, expected in pairs({
    playtest = '31e0ff45/a9192235',
    human = 'c34e3780/563c8d0f',
    drill = '0bc736d6/f105ca06',
  }) do
    check(name .. ' with old encounters reproduces point 3 exact digest', digests[name] == expected)
  end
  -- The projections, the attribution and the pose table.
  local texts = { 'attribution.txt', 'pose-table.txt' }
  for _, run in ipairs(Reference.runs) do
    table.insert(texts, 1, 'projection-' .. run .. '.txt')
  end
  for _, name in ipairs(texts) do
    local reference, difference = read(name), 'no reference file'
    if reference then
      local current = files[name]
      if name == 'pose-table.txt' then
        -- New actions add rows, not changes to the old paintings. Compare
        -- EVERY old row (including absence/order/value), allowing extra ids.
        local keys, retained = {}, {}
        for row in reference:gmatch('[^\n]+') do
          keys[row:match('^(.-)|[^|]*$') or row] = true
        end
        for row in current:gmatch('[^\n]+') do
          if keys[row:match('^(.-)|[^|]*$') or row] then
            retained[#retained + 1] = row
          end
        end
        current = table.concat(retained, '\n') .. '\n'
      end
      difference = Projection.compare(reference, current)
    end
    check(name .. ' reproduces 0.33 (' .. (difference or 'equal') .. ')', difference == nil)
  end
  -- The comparison names the first difference: its record, step and field.
  local reference = read('projection-drill.txt') or ''
  local changed = reference:gsub('(body%.8%.hp=)(%d+)', '%1999999', 1)
  local missing = reference:gsub('\nE %d+ death\n', '\nE 0 lost\n', 1)
  local found = Projection.compare(reference, changed) or ''
  check(
    'a changed value is reported with its record and field (' .. found .. ')',
    found:find('body.8.hp=', 1, true) ~= nil and found:find('record [PE] %d+') ~= nil
  )
  local lost = Projection.compare(reference, missing) or ''
  check('a missing event record is reported (' .. lost .. ')', lost:find('death', 1, true) ~= nil)
  check('equal projections report nothing', Projection.compare(reference, reference) == nil)
  -- The checkpoints 0.33 wrote: every one reads into the state it read into
  -- then, and its save read again gives that state once more.
  local names, phases, echo, glyph = {}, {}, false, false
  for name in (read('saves/index.txt') or ''):gmatch('[^\n]+') do
    names[#names + 1] = name
  end
  check('the fixture names its checkpoints', #names >= 5)
  for _, name in ipairs(names) do
    local text = read('saves/' .. name .. '.save') or ''
    local data = RunSave.decode(text)
    check(
      'checkpoint ' .. name .. ' is a SIGIL09 save 0.33 wrote',
      data ~= nil and text:sub(1, 7) == 'SIGIL09'
    )
    if data then
      phases[data.phase] = true
      echo = echo or data.echo ~= nil
      glyph = glyph or data.glyph ~= 'none'
      local loaded = Reference.loadedProjection(G, text)
      local difference = Projection.compare(read('saves/' .. name .. '.txt') or '', loaded)
      check(
        'checkpoint ' .. name .. ' loads into the 0.33 state (' .. (difference or 'equal') .. ')',
        difference == nil
      )
      local g = Trial.loaded(G, text)
      local again = RunSave.encode(Run.snapshot(g), 2, g)
      check(
        'checkpoint ' .. name .. ' saved again reads into the same state',
        Projection.compare(loaded, Reference.loadedProjection(G, again)) == nil
      )
      -- Old-format inputs AND expected projections come from E0, before
      -- any refactor. tostring in legacy formats had lower precision than
      -- SIGIL09: comparing a legacy load with an unrounded new file is wrong.
      for _, version in ipairs({ 'SIGIL06', 'SIGIL07', 'SIGIL08' }) do
        local path = 'tests/fixtures/legacy-v033/' .. name .. '-' .. version
        local legacy = assert(love.filesystem.read(path .. '.save'))
        local expected = assert(love.filesystem.read(path .. '.txt'))
        local migrated = Reference.loadedProjection(G, legacy)
        local mismatch = Projection.compare(expected, migrated)
        check(
          name .. ' ' .. version .. ' restores its E0 projection (' .. (mismatch or 'equal') .. ')',
          not mismatch
        )
        local oldGame = Trial.loaded(G, legacy)
        local rewritten = RunSave.encode(Run.snapshot(oldGame), 3, oldGame)
        check(
          name .. ' ' .. version .. ' -> current -> read preserves the loaded projection',
          not Projection.compare(migrated, Reference.loadedProjection(G, rewritten))
        )
      end
    end
  end
  check(
    'the checkpoints cover preparation, defeat, victory, an echo and an engraving',
    phases.preparing and phases.defeated and phases.complete and echo and glyph
  )
  local damaged = (read('saves/preparing.save') or ''):gsub('%["wallet"%]=92', '["wallet"]=93', 1)
  check('a damaged 0.33 checkpoint is refused', RunSave.decode(damaged) == nil)
  return lines
end
return Tests

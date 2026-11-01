-- Golden master (0.24 / E0). Deterministic scenarios fold the simulation
-- state every second into one digest each. Every refactor must reproduce
-- tests/golden/baseline.lua exactly. A deliberate gameplay change updates
-- the baseline: copy work/<qa>/golden-current.lua over it and say why in
-- the change log.
local Fixtures = require('tests.support.fixtures')
local T = {}
function T.run(G)
  local lines = {}
  local Golden = require('qa.golden')
  local check = Fixtures.checker(lines, 'golden ', '')
  local current = {}
  local perfect = Golden.recorder(120)
  local result = require('qa.scenarios.chapel_walk').run(G, false, perfect.observe, 120)
  current.playtest = perfect.value .. '/' .. Golden.digest(result.session)
  local human = Golden.recorder(120)
  local humanResult = require('qa.scenarios.chapel_walk').run(G, true, human.observe, 120)
  current.human = human.value .. '/' .. Golden.digest(humanResult.session)
  local drill = Golden.recorder(60)
  local drilled = require('qa.scenarios.drill').run(G, drill.observe, 40)
  current.drill = drill.value .. '/' .. Golden.digest(drilled)
  current.playtestContacts = perfect.contacts .. '/' .. perfect.contactCount
  current.humanContacts = human.contacts .. '/' .. human.contactCount
  current.drillContacts = drill.contacts .. '/' .. drill.contactCount
  local keys =
    { 'playtest', 'human', 'drill', 'playtestContacts', 'humanContacts', 'drillContacts' }
  check(
    'golden scenarios include actual per-part contact receipts',
    perfect.contactCount > 0 and human.contactCount > 0 and drill.contactCount > 0
  )
  -- The current digests are always written, for a deliberate update.
  local out = { 'return {' }
  for _, key in ipairs(keys) do
    out[#out + 1] = string.format('  %s = %q,', key, current[key])
  end
  out[#out + 1] = '}'
  local f = assert(io.open(require('qa.output').path('golden-current.lua'), 'w'))
  f:write(table.concat(out, '\n') .. '\n')
  f:close()
  -- Every field these sessions ended with must be declared in the session
  -- field catalogue (src/session/fields.lua): who owns it, what it is.
  local Fields = require('src.session.fields')
  local unknown, seen = {}, {}
  for _, session in ipairs({ result.session, humanResult.session, drilled }) do
    for k in pairs(session) do
      if not seen[k] then
        seen[k] = true
        if not Fields.owner(k) then
          unknown[#unknown + 1] = tostring(k)
        end
      end
    end
    for k in pairs(session.view) do
      if not seen['view.' .. k] then
        seen['view.' .. k] = true
        if not Fields.viewOwner(k) then
          unknown[#unknown + 1] = 'view.' .. tostring(k)
        end
      end
    end
  end
  table.sort(unknown)
  check(
    'every session field is declared in the catalogue (unknown: '
      .. table.concat(unknown, ' ')
      .. ')',
    #unknown == 0
  )
  -- Definitions are read-only: no test or system may have changed them.
  local Suite = require('tests.suite')
  check(
    'content definitions are unchanged by the whole run',
    Suite.contentAtStart == nil or Suite.contentAtStart == Suite.contentText()
  )
  local ok, baseline = pcall(require, 'tests.golden.baseline')
  check('a golden baseline exists', ok and type(baseline) == 'table')
  for _, key in ipairs(keys) do
    check(
      'golden ' .. key .. ' reproduces the baseline (' .. tostring(current[key]) .. ')',
      baseline[key] == current[key]
    )
  end
  return lines
end
return T

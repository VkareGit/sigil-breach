-- The 0.33 references of plan v11 (E0), made from the old code before any
-- stage changes it, and the checks every later stage runs against them
-- (tests/cases/v033_reference.lua):
--   projection-<run>.txt   the state projection (qa/state_projection.lua) of
--                          the three golden scenarios, the expedition trial
--                          and the attribution trial (a kill by every source)
--   attribution.txt        every kill: source, off balance, healed, souls, score
--   pose-table.txt         the pose table (qa/pose_table.lua)
--   saves/<name>.save      SIGIL09 checkpoints written by 0.33
--   saves/<name>.txt       the projection of each, loaded into a new session
-- `--v11-reference` writes them into the QA output (never into tests/: the
-- reference in the repository is not regenerated) with the viewer report.
local Golden = require('qa.golden')
local Projection = require('qa.state_projection')
local Trial = require('qa.scenarios.expedition_trial')
local Run = require('src.run.descent')
local RunSave = require('src.storage.run_save')
local R = {}
R.directory = 'tests/fixtures/v033'
R.runs = { 'playtest', 'human', 'drill', 'expedition', 'sources' }
local function both(a, b)
  return function(g, step)
    a(g, step)
    b(g, step)
  end
end
-- One run: its projection recorder and its golden recorder side by side.
local function golden(G, name, observers)
  local projection = Projection.recorder(120)
  if name == 'drill' then
    local digest = Golden.recorder(60)
    local g = require('qa.scenarios.drill').run(G, both(projection.observe, digest.observe), 40)
    observers.digests[name] = digest.value .. '/' .. Golden.digest(g)
    return projection, g
  end
  local digest = Golden.recorder(120)
  local result = require('qa.scenarios.playtest').run(
    G,
    name == 'human',
    both(projection.observe, digest.observe)
  )
  observers.digests[name] = digest.value .. '/' .. Golden.digest(result.session)
  return projection, result.session
end
local function attribution(name, kills, out)
  for _, k in ipairs(kills) do
    out[#out + 1] = string.format(
      '%s|step=%d|body=%d|kind=%s|source=%s|offBalance=%s|healed=%s|souls=%s|reward=%s',
      name,
      k.step,
      k.id,
      k.kind,
      tostring(k.source),
      tostring(k.offBalance),
      Projection.value(k.healed),
      Projection.value(k.souls),
      Projection.value(k.reward)
    )
  end
end
-- The projection of a save loaded into a new session.
function R.loadedProjection(G, text)
  return table.concat(Projection.lines(Trial.loaded(G, text)), '\n') .. '\n'
end
-- Every reference text by its file name (relative to the directory).
function R.build(G)
  local files, kills, observers = {}, {}, { digests = {} }
  local saves = {}
  for _, name in ipairs({ 'playtest', 'human', 'drill' }) do
    local projection, g = golden(G, name, observers)
    files['projection-' .. name .. '.txt'] = projection.text()
    attribution(name, projection.kills, kills)
    if name ~= 'drill' then
      -- The end of a whole expedition: its last checkpoint as 0.33 writes it.
      saves['end-' .. name] = RunSave.encode(Run.snapshot(g), 9, g)
    end
  end
  local projection = Projection.recorder(Trial.rate)
  local trialSaves = Trial.run(G, projection.observe, function(g, kind)
    projection.full(g, kind)
  end)
  files['projection-expedition.txt'] = projection.text()
  attribution('expedition', projection.kills, kills)
  for name, text in pairs(trialSaves) do
    saves[name] = text
  end
  -- A kill by every source, steady and off balance (qa/scenarios/attribution_trial.lua).
  local sources = Projection.recorder(120)
  require('qa.scenarios.attribution_trial').run(G, sources.observe)
  files['projection-sources.txt'] = sources.text()
  attribution('sources', sources.kills, kills)
  files['attribution.txt'] = table.concat(kills, '\n') .. '\n'
  files['pose-table.txt'] = require('qa.pose_table').text()
  local names = {}
  for name in pairs(saves) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    files['saves/' .. name .. '.save'] = saves[name]
    files['saves/' .. name .. '.txt'] = R.loadedProjection(G, saves[name])
  end
  files['saves/index.txt'] = table.concat(names, '\n') .. '\n'
  return files, observers.digests
end
-- What each save holds (the fixture's coverage), one line per save.
function R.describeSaves(files)
  local out = {}
  for name in (files['saves/index.txt'] or ''):gmatch('[^\n]+') do
    local d = assert(RunSave.decode(files['saves/' .. name .. '.save']))
    out[#out + 1] = string.format(
      '%s: phase=%s wave=%d wallet=%d glyph=%s echo=%s kills=%d score=%d',
      name,
      d.phase,
      d.wave,
      d.wallet,
      d.glyph,
      d.echo and (d.echo.amount .. '@' .. d.echo.wave) or 'none',
      d.kills,
      d.score
    )
  end
  return out
end
-- The viewer report over the three golden scenarios.
function R.viewerReport(G)
  local V = require('qa.viewer_influence')
  local out = {
    'VIEWER INFLUENCE ON THE SIMULATION (plan v11 E0, gap C4)',
    "Headless golden scenarios: every pose query is the simulation's own.",
    "sample = Pose.sample (shot surfaces, missiles, claws); anchor = Pose.anchor (a demon's eye).",
    'back-or-turned-frame: the frame differs from what a viewer in front of the body sees.',
    '',
  }
  local runs = {
    {
      'playtest',
      function()
        require('qa.scenarios.playtest').run(G, false)
      end,
    },
    {
      'human',
      function()
        require('qa.scenarios.playtest').run(G, true)
      end,
    },
    {
      'drill',
      function()
        require('qa.scenarios.drill').run(G, nil, 40)
      end,
    },
  }
  for _, run in ipairs(runs) do
    for _, line in ipairs(V.lines(run[1], V.measure(run[2]))) do
      out[#out + 1] = line
    end
  end
  return table.concat(out, '\n') .. '\n'
end
local function write(path, text)
  local dir = path:match('^(.*)/[^/]+$')
  if dir then
    os.execute('mkdir "' .. dir:gsub('/', '\\') .. '" 2>nul')
  end
  local file = assert(io.open(path, 'wb'))
  file:write(text)
  file:close()
end
-- --v11-reference: the references into <output>/v11-reference/.
function R.run(G, output)
  local files, digests = R.build(G)
  local root = output .. '/v11-reference'
  local names = {}
  for name in pairs(files) do
    names[#names + 1] = name
  end
  table.sort(names)
  local report = { 'V11 E0 REFERENCES', 'golden digests seen while projecting:' }
  for _, name in ipairs({ 'playtest', 'human', 'drill' }) do
    report[#report + 1] = '  ' .. name .. ' ' .. tostring(digests[name])
  end
  for _, name in ipairs(names) do
    write(root .. '/' .. name, files[name])
    report[#report + 1] =
      string.format('%-36s %9d bytes  fnv %s', name, #files[name], Golden.hash(files[name]))
  end
  for _, line in ipairs(R.describeSaves(files)) do
    report[#report + 1] = 'save ' .. line
  end
  write(root .. '/viewer-influence.txt', R.viewerReport(G))
  write(root .. '/report.txt', table.concat(report, '\n') .. '\n')
  print(table.concat(report, '\n'))
end
return R

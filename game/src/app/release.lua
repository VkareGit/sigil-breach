-- Shared build identity. Simulation parameters belong to tuning/archetypes.
-- The version itself lives in core/build.lua (the simulation reads it too).
local Release = {
  version = require('src.core.build').version,
  title = 'SIGIL: BREACH / The Chapel',
  menuLabel = 'menu_release',
  -- The scripts read these relative names. Linux resolves work outside the
  -- checkout; Windows retains its existing location. Both pass a run id.
  qaOutput = 'work/qa',
  -- Where a run started by hand writes when no QA directory is named: never over the reports
  -- of a TEST.ps1 running beside it (audit E03: "Report was not written by run").
  handOutput = 'work/qa-direct',
  qaIdentity = 'sigil-breach-qa',
  -- Public entry points, separate from registered modes and regression tools.
  playableModes = { field = true, pilgrimage = true },
  sessionMaps = { field = 'proving' },
  sessionOptions = { field = { features = { trade = false } } },
}

function Release.output()
  local selected = os.getenv('SIGIL_UI_QA_DIR')
  if selected and selected ~= '' then
    return selected
  end
  if require('ffi').os == 'Linux' then
    return require('src.app.workspace').directory() .. '/qa-direct'
  end
  return Release.handOutput
end

return Release

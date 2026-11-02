-- Shared build identity. Simulation parameters belong to tuning/archetypes.
-- The version itself lives in core/build.lua (the simulation reads it too).
return {
  version = require('src.core.build').version,
  title = 'SIGIL: BREACH / The Chapel',
  menuLabel = 'menu_release',
  -- The QA directory of TEST.ps1 and BUILD.ps1 (tools/project.ps1 reads it from here); they
  -- always name it to the game with a run id.
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

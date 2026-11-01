-- Shared build identity. Simulation parameters belong to tuning/archetypes.
-- The version itself lives in core/build.lua (the simulation reads it too).
return {
  version = require('src.core.build').version,
  title = 'SIGIL: BREACH — 0.36 / Trial by Ash',
  menuLabel = 'menu_release',
  qaOutput = 'work/qa-v33',
  qaIdentity = 'sigil-breach-qa-v33',
  -- Public entry points, separate from registered modes and regression tools.
  playableModes = { field = true, pilgrimage = true },
  sessionMaps = { field = 'proving' },
  sessionOptions = { field = { features = { trade = false, waves = false } } },
}

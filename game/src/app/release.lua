-- Shared build identity. Simulation parameters belong to tuning/archetypes.
-- The version itself lives in core/build.lua (the simulation reads it too).
return {
  version = require('src.core.build').version,
  title = 'SIGIL: BREACH / The Chapel',
  menuLabel = 'menu_release',
  qaOutput = 'work/qa',
  qaIdentity = 'sigil-breach-qa',
  -- Public entry points, separate from registered modes and regression tools.
  playableModes = { field = true, pilgrimage = true },
  sessionMaps = { field = 'proving' },
  sessionOptions = { field = { features = { trade = false } } },
}

-- Shared build identity. Simulation parameters belong to tuning/archetypes.
-- The version itself lives in core/build.lua (the simulation reads it too).
return {
  version = require('src.core.build').version,
  title = 'SIGIL: BREACH — 0.32 / Foundation',
  menuLabel = 'menu_release',
  qaOutput = 'work/qa-v32',
  qaIdentity = 'sigil-breach-qa-v32',
}

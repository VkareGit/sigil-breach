-- Shared build identity. Simulation parameters belong to tuning/archetypes.
-- The version itself lives in core/build.lua (the simulation reads it too).
return {
  version = require('src.core.build').version,
  title = 'SIGIL: BREACH — 0.30 / Foundation',
  menuLabel = 'FOUNDATION  /  0.30',
  qaOutput = 'work/qa-v30',
  qaIdentity = 'sigil-breach-qa-v30',
}

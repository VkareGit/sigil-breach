-- Shared build identity. Simulation parameters belong to tuning/archetypes.
-- The version itself lives in core/build.lua (the simulation reads it too).
return {
  version = require('src.core.build').version,
  title = 'SIGIL: BREACH — 0.31 / Foundation',
  menuLabel = 'FOUNDATION  /  0.31',
  qaOutput = 'work/qa-v31',
  qaIdentity = 'sigil-breach-qa-v31',
}

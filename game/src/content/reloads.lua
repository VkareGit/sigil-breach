-- Reload mechanisms as data (combat/reload.lua reads them, one interpreter for
-- all). A new action is a new entry:
--   duration          the full timeline (s)
--   stages            in order: at, name = 'open' | 'load' | 'close'
--   ejects            the spent cases fly when it opens
--   resume            where a reload starts: loaded (open, rounds in), open (open,
--                     empty), afterShot (the automatic one), closed; none: 0
--   interruptBefore   a pull stops the reload before this time when rounds remain
--   closeOnFire       s a swung-out action needs to close when stopped
--   labels            { until, text key } the stage shown on the HUD
--   sounds, voices    volume and sound of each stage (presentation)
local Registry = require('src.core.registry')
local T = require('src.content.tuning')
local Reloads = Registry:new('reload mechanisms')
local B, C = T.reload.breech, T.reload.cylinder
-- The break-action shotgun: open, eject the spent shells, load two, close.
Reloads:register('breech', {
  duration = T.shotgunCycle,
  stages = {
    { at = B.open, name = 'open' },
    { at = T.reloadLoadTime, name = 'load' },
    { at = B.close, name = 'close' },
  },
  ejects = true,
  resume = B.resume,
  -- A loaded barrel fires until the breech breaks open.
  interruptBefore = B.open,
  labels = {
    { B.labels[1], 'reload_open' },
    { B.labels[2], 'reload_load' },
    { math.huge, 'reload_close' },
  },
  sounds = B.sounds,
  voices = B.voices,
})
-- The revolver: swing the cylinder out, eject, load all six, close.
Reloads:register('cylinder', {
  duration = T.revolverReload,
  stages = {
    { at = C.open, name = 'open' },
    { at = T.revolverLoadTime, name = 'load' },
    { at = T.revolverCloseTime, name = 'close' },
  },
  resume = { loaded = T.revolverLoadTime, open = C.resume.open },
  -- The rounds still in the cylinder fire until the new ones go in; a cylinder
  -- already swung out snaps shut first.
  interruptBefore = T.revolverLoadTime,
  closeOnFire = C.closeOnFire,
  labels = {
    { C.labels[1], 'reload_open' },
    { C.labels[2], 'reload_eject' },
    { T.revolverLoadTime, 'reload_load' },
    { math.huge, 'reload_close' },
  },
  sounds = C.sounds,
  voices = C.voices,
})
-- A schema check: nil when the id names a mechanism.
function Reloads.problem(id)
  if not Reloads:has(id) then
    return 'unknown reload mechanism ' .. tostring(id)
  end
end
return Reloads

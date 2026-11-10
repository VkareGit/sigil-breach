-- Reload mechanisms as data (combat/reload.lua reads them, one interpreter for
-- all). A new action is a new entry:
--   duration          the full timeline (s)
--   stages            in order: at, name (its voice and label), kind (what it does, a
--                     reload stage kind of combat/reload.lua: open, load, close, round;
--                     none: its name)
--   ejects            the spent cases fly when it opens
--   resume            where a reload starts: loaded (open, rounds in), open (open,
--                     empty), afterShot (the automatic one), closed; none: 0
--   interruptBefore   a pull stops the reload before this time when rounds remain
--   closeOnFire       s a swung-out action needs to close when stopped
--   labels            { until, text key } the stage shown on the HUD
--   sounds, voices    volume and sound of each stage (presentation)
local Registry = require('src.core.registry')
local Tuning = require('src.content.tuning')
local Reloads = Registry:new('reload mechanisms')
local B, C = Tuning.reload.breech, Tuning.reload.cylinder
-- The break-action shotgun: open, eject the spent shells, load two, close.
Reloads:register('breech', {
  duration = Tuning.shotgunCycle,
  stages = {
    { at = B.open, name = 'open' },
    { at = Tuning.reloadLoadTime, name = 'load' },
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
  duration = Tuning.revolverReload,
  stages = {
    { at = C.open, name = 'open' },
    { at = Tuning.revolverLoadTime, name = 'load' },
    { at = Tuning.revolverCloseTime, name = 'close' },
  },
  resume = { loaded = Tuning.revolverLoadTime, open = C.resume.open },
  -- The rounds still in the cylinder fire until the new ones go in; a cylinder
  -- already swung out snaps shut first.
  interruptBefore = Tuning.revolverLoadTime,
  closeOnFire = C.closeOnFire,
  labels = {
    { C.labels[1], 'reload_open' },
    { C.labels[2], 'reload_eject' },
    { Tuning.revolverLoadTime, 'reload_load' },
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

local Signal = require('src.session.signal')
local T = require('src.content.tuning')
local W = require('src.content.weapons')
local R = {}
-- Reload mechanisms (0.24, Strategy). A weapon names its mechanism in its
-- profile (content/weapons.lua: mechanism); one timeline per mechanism drives
-- the drawing, the mechanical sounds and the ammunition transaction. The
-- times of each timeline are data (content/tuning.lua: reload). A new action
-- (lever, magazine) is a new entry with the same fields:
--   duration                    full reload time
--   offset(g, w, def, afterShot) where the timeline starts, or nil if no reload
--   step(g, w, before, after)   events crossed between two timeline ages
--   finish(g, w)                the action closed
--   frame(g, reloading, t)      sheet frame of the hands (presentation)
--   primed(w)                   an open action already holds its new rounds
--   label(t)                    the stage shown on the HUD
--   sounds                      volume of each stage's sound (presentation)
--   interruptBefore             a trigger pull stops the reload before this
--                               time when rounds remain (nil: never)
--   closing(w, t)               s the action needs to close when stopped at t
-- w: the weapon's live record in the arsenal (content/weapons.lua), def: its
-- definition. What a stage looks like (the spent cases flying out) is the
-- presentation's answer to the ReloadStage event.
local Mechanisms = {}
R.mechanisms = Mechanisms
-- True when the timeline crossed time t between two ages.
local function crossed(before, after, t)
  return before < t and after >= t
end
-- The recoil frame of the hands by shot age (frames 2, 3, 4, then at rest).
local function shotFrame(g, ages)
  for i, age in ipairs(ages) do
    if g.view.shotAge < age then
      return i + 1
    end
  end
  return 1
end

-- The break-action shotgun: open, eject the spent shells, load two, close.
local B = T.reload.breech
Mechanisms.breech = {
  duration = T.shotgunCycle,
  sounds = B.sounds,
  -- A loaded barrel fires until the breech breaks open.
  interruptBefore = B.open,
  closing = function()
    return 0
  end,
  offset = function(_, w, def, afterShot)
    if not w.open and (w.mag >= def.capacity or w.reserve <= 0) then
      return nil
    end
    if w.open and w.mag > 0 then
      return B.resume.loaded
    elseif w.open then
      return B.resume.open
    end
    return afterShot and B.resume.afterShot or B.resume.closed
  end,
  step = function(g, w, before, after)
    if crossed(before, after, B.open) then
      w.open = true
      g.reloadStage = 1
      -- The spent cases fly out now (feedback/world_feedback.lua).
      Signal(g, 'ReloadStage', { stage = 'open', mechanism = 'breech', spent = w.spent or 0 })
      w.spent = 0
    end
    if crossed(before, after, T.reloadLoadTime) then
      local n = W.load(g, g.reloadWeapon)
      g.reloadStage = 2
      if n > 0 then
        Signal(g, 'ReloadStage', { stage = 'load', mechanism = 'breech' })
      end
    end
    if crossed(before, after, B.close) then
      w.open = false
      g.reloadStage = 3
      Signal(g, 'ReloadStage', { stage = 'close', mechanism = 'breech' })
    end
  end,
  finish = function(_, w)
    w.open = false
  end,
  primed = function(w)
    return w.mag > 0
  end,
  frame = function(g, reloading, t)
    if reloading then
      for i, cut in ipairs(B.frames.cuts) do
        if t < cut then
          return B.frames.first + i - 1
        end
      end
      return B.frames.last
    end
    return shotFrame(g, B.shot)
  end,
  label = function(t)
    return t < B.labels[1] and 'OPEN' or (t < B.labels[2] and 'LOAD' or 'CLOSE')
  end,
}

-- The revolver: swing the cylinder out, eject, load all six, close.
local C = T.reload.cylinder
-- A run of sheet frames: first + the step reached from start, every s (or
-- the span to stop split into parts), at most steps.
local function run(spec, t, start, stop)
  local every = spec.every or (stop - start) / spec.parts
  return spec.first + math.min(spec.steps, math.floor((t - start) / every))
end
Mechanisms.cylinder = {
  duration = T.revolverReload,
  sounds = C.sounds,
  -- The rounds still in the cylinder fire until the new ones go in; a
  -- cylinder already swung out snaps shut first.
  interruptBefore = T.revolverLoadTime,
  closing = function(w)
    return w.open and C.closeOnFire or 0
  end,
  offset = function(_, w, def)
    if not w.open and (w.mag >= def.capacity or w.reserve <= 0) then
      return nil
    end
    -- Live rounds left from before opening do not mean the loading transaction ran.
    return w.open and (w.loaded and T.revolverLoadTime or C.resume.open) or 0
  end,
  step = function(g, w, before, after)
    if crossed(before, after, C.open) then
      w.open = true
      w.loaded = false
      g.reloadStage = 1
      Signal(g, 'ReloadStage', { stage = 'open', mechanism = 'cylinder' })
    end
    if crossed(before, after, T.revolverLoadTime) then
      local n = W.load(g, g.reloadWeapon)
      w.loaded = true
      g.reloadStage = 2
      if n > 0 then
        Signal(g, 'ReloadStage', { stage = 'load', mechanism = 'cylinder' })
      end
    end
    if crossed(before, after, T.revolverCloseTime) then
      w.open = false
      w.loaded = false
      g.reloadStage = 3
      Signal(g, 'ReloadStage', { stage = 'close', mechanism = 'cylinder' })
    end
  end,
  finish = function(_, w)
    w.open = false
    w.loaded = false
  end,
  primed = function(w)
    return w.loaded
  end,
  frame = function(g, reloading, t)
    if reloading then
      local F = C.frames
      if t < F.swing.ends then
        return run(F.swing, t, 0)
      end
      if t < F.eject.ends then
        return run(F.eject, t, F.swing.ends)
      end
      if t < T.revolverLoadTime then
        return run(F.load, t, F.eject.ends, T.revolverLoadTime)
      end
      return run(F.close, t, T.revolverLoadTime, T.revolverReload)
    end
    return shotFrame(g, C.shot)
  end,
  label = function(t)
    return t < C.labels[1] and 'OPEN'
      or (t < C.labels[2] and 'EJECT' or (t < T.revolverLoadTime and 'LOAD' or 'CLOSE'))
  end,
}

-- The mechanism of the weapon in a slot of the knight's loadout.
local function mechanism(g, slot)
  local profile = W.inHand(g, slot) or W.inHand(g, 1)
  return Mechanisms[profile.mechanism]
end
R.mechanism = mechanism

function R.age(g)
  return (g.reloadOffset or 0) + (g.reloadDuration or 0) - g.reload
end
function R.progress(g)
  return g.reload > 0 and math.max(0, math.min(1, R.age(g) / mechanism(g, g.reloadWeapon).duration))
    or 0
end
function R.frame(g)
  local reloading = g.reload > 0 and g.reloadWeapon == g.weapon
  return mechanism(g, g.weapon).frame(g, reloading, reloading and R.age(g) or 0)
end
function R.label(g)
  return mechanism(g, g.reloadWeapon).label(R.age(g))
end
function R.start(g, afterShot)
  if g.reload > 0 or not W.validAmmo(g) then
    return false
  end
  local m = mechanism(g, g.weapon)
  local def, state = W.inHand(g)
  local offset = m.offset(g, state, def, afterShot)
  if not offset then
    return false
  end
  g.reloadWeapon = g.weapon
  g.reloadOffset = offset
  g.reloadDuration = m.duration - offset
  g.reload = g.reloadDuration
  g.reloadStage = 0
  return true
end
function R.cancel(g)
  g.reload = 0
  g.reloadStage = 0
  g.reloadWeapon = nil
end
-- A trigger pull during a reload (0.25): the reload of the weapon in hand
-- stops while rounds remain in it, before its new rounds go in. True when
-- the gun may fire now; a gun whose action must close first is ready later
-- (its readyAt).
function R.interrupt(g)
  if g.reload <= 0 or g.reloadWeapon ~= g.weapon then
    return false
  end
  local m, w = mechanism(g, g.weapon), W.state(g)
  local age = R.age(g)
  if not m.interruptBefore or (w.mag or 0) <= 0 or age >= m.interruptBefore then
    return false
  end
  local closing = m.closing(w, age)
  R.cancel(g)
  m.finish(g, w)
  if closing > 0 then
    w.readyAt = math.max(w.readyAt or 0, g.elapsed + closing)
    Signal(g, 'ReloadStage', { stage = 'close', mechanism = W.inHand(g).mechanism })
    return false
  end
  return true
end
function R.update(g, dt)
  if g.reload <= 0 or type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge then
    return
  end
  local before = R.age(g)
  g.reload = math.max(0, g.reload - dt)
  local after = R.age(g)
  local m = mechanism(g, g.reloadWeapon)
  local w = W.state(g, g.reloadWeapon)
  m.step(g, w, before, after)
  if g.reload == 0 then
    m.finish(g, w)
    g.reloadStage = 0
    g.reloadWeapon = nil
  end
end
return R

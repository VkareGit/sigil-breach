local Signal = require('src.session.signal')
local T = require('src.content.tuning')
local W = require('src.content.weapons')
local Text = require('src.content.text')
local Roles = require('src.core.roles')
local R = {}
-- The reload belongs to the actor (plan v11 E3): its timeline, stage and the
-- slot it reloads are fields of the knight's record (session/components.lua).
local function actor(g)
  return Roles.controlled(g)
end
-- Reload mechanisms (0.24, Strategy). A weapon names its mechanism in its
-- profile (content/weapons.lua: mechanism); one timeline per mechanism drives
-- the drawing, the mechanical sounds and the ammunition transaction. The
-- times of each timeline are data (content/tuning.lua: reload). A new action
-- (lever, magazine) is a new entry with the same fields:
--   duration                    full reload time
--   offset(g, w, def, afterShot) where the timeline starts, or nil if no reload
--   step(g, w, before, after)   events crossed between two timeline ages
--   finish(g, w)                the action closed
--   primed(w)                   an open action already holds its new rounds
--   label(t)                    the stage shown on the HUD
--   sounds                      volume of each stage's sound (presentation)
--   voices                      the sound each stage plays (presentation)
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
-- The break-action shotgun: open, eject the spent shells, load two, close.
local B = T.reload.breech
Mechanisms.breech = {
  duration = T.shotgunCycle,
  sounds = B.sounds,
  voices = B.voices,
  -- A loaded barrel fires until the breech breaks open.
  interruptBefore = B.open,
  closing = function()
    return 0
  end,
  offset = function(_, w, def, afterShot)
    if not w.open and (w.mag >= def.capacity or w.reserve <= 0) then
      return nil
    end
    -- Remaining live shells predate this reload. Only the completed loading
    -- transaction permits resuming after insertion, even when it moved zero.
    if w.open and w.loaded then
      return B.resume.loaded
    elseif w.open then
      return B.resume.open
    end
    return afterShot and B.resume.afterShot or B.resume.closed
  end,
  step = function(g, w, before, after)
    if crossed(before, after, B.open) then
      w.open = true
      w.loaded = false
      actor(g).reloadStage = 1
      -- The spent cases fly out now (feedback/world_feedback.lua).
      Signal(g, 'ReloadStage', {
        stage = 'open',
        mechanism = 'breech',
        spent = w.spent or 0,
        weapon = W.idAt(g, actor(g).reloadWeapon),
      })
      w.spent = 0
    end
    if crossed(before, after, T.reloadLoadTime) then
      local n = W.load(g, actor(g).reloadWeapon)
      w.loaded = true
      actor(g).reloadStage = 2
      if n > 0 then
        Signal(g, 'ReloadStage', { stage = 'load', mechanism = 'breech' })
      end
    end
    if crossed(before, after, B.close) then
      w.open = false
      w.loaded = false
      actor(g).reloadStage = 3
      Signal(g, 'ReloadStage', { stage = 'close', mechanism = 'breech' })
    end
  end,
  finish = function(_, w)
    w.open = false
    w.loaded = false
  end,
  primed = function(w)
    return w.loaded
  end,
  label = function(t)
    return Text.get(
      t < B.labels[1] and 'reload_open' or (t < B.labels[2] and 'reload_load' or 'reload_close')
    )
  end,
}

-- The revolver: swing the cylinder out, eject, load all six, close.
local C = T.reload.cylinder
Mechanisms.cylinder = {
  duration = T.revolverReload,
  sounds = C.sounds,
  voices = C.voices,
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
      actor(g).reloadStage = 1
      Signal(g, 'ReloadStage', { stage = 'open', mechanism = 'cylinder' })
    end
    if crossed(before, after, T.revolverLoadTime) then
      local n = W.load(g, actor(g).reloadWeapon)
      w.loaded = true
      actor(g).reloadStage = 2
      if n > 0 then
        Signal(g, 'ReloadStage', { stage = 'load', mechanism = 'cylinder' })
      end
    end
    if crossed(before, after, T.revolverCloseTime) then
      w.open = false
      w.loaded = false
      actor(g).reloadStage = 3
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
  label = function(t)
    return Text.get(
      t < C.labels[1] and 'reload_open'
        or (
          t < C.labels[2] and 'reload_eject'
          or (t < T.revolverLoadTime and 'reload_load' or 'reload_close')
        )
    )
  end,
}

-- The mechanism of the weapon in a slot of the knight's loadout.
local function mechanism(g, slot)
  local profile = W.inHand(g, slot) or W.inHand(g, 1)
  return Mechanisms[profile.mechanism]
end
R.mechanism = mechanism

function R.age(g)
  local a = actor(g)
  return (a.reloadOffset or 0) + (a.reloadDuration or 0) - a.reload
end
-- What presentation reads of the controlled actor's reload (a session
-- without a knight, a bare fixture, has none): the seconds left, the slot
-- being reloaded, its stage, its full length and where it started.
local function field(g, name, default)
  local a = g and actor(g)
  local v = a and a[name]
  if v == nil then
    return default
  end
  return v
end
function R.left(g)
  return field(g, 'reload', 0)
end
function R.slot(g)
  return field(g, 'reloadWeapon', nil)
end
function R.stage(g)
  return field(g, 'reloadStage', 0)
end
function R.duration(g)
  return field(g, 'reloadDuration', 0)
end
function R.offset(g)
  return field(g, 'reloadOffset', 0)
end
function R.progress(g)
  local a = actor(g)
  return a.reload > 0 and math.max(0, math.min(1, R.age(g) / mechanism(g, a.reloadWeapon).duration))
    or 0
end
function R.label(g)
  return mechanism(g, actor(g).reloadWeapon).label(R.age(g))
end
function R.start(g, afterShot)
  local a = actor(g)
  if a.reload > 0 or not W.validAmmo(g) then
    return false
  end
  local m = mechanism(g, a.weapon)
  local def, state = W.inHand(g)
  local offset = m.offset(g, state, def, afterShot)
  if not offset then
    return false
  end
  a.reloadWeapon = a.weapon
  a.reloadOffset = offset
  a.reloadDuration = m.duration - offset
  a.reload = a.reloadDuration
  a.reloadStage = 0
  return true
end
function R.cancel(g)
  local a = actor(g)
  a.reload = 0
  a.reloadStage = 0
  a.reloadWeapon = nil
end
-- A trigger pull during a reload (0.25): the reload of the weapon in hand
-- stops while rounds remain in it, before its new rounds go in. True when
-- the gun may fire now; a gun whose action must close first is ready later
-- (its readyAt).
function R.interrupt(g)
  local a = actor(g)
  if a.reload <= 0 or a.reloadWeapon ~= a.weapon then
    return false
  end
  local m, w = mechanism(g, a.weapon), W.state(g)
  local age = R.age(g)
  if not m.interruptBefore or (w.mag or 0) <= 0 or age >= m.interruptBefore then
    return false
  end
  local closing = m.closing(w, age)
  R.cancel(g)
  m.finish(g, w)
  if closing > 0 then
    w.readyAt = math.max(w.readyAt or 0, g.elapsed + closing)
    Signal(g, 'ReloadStage', {
      stage = 'close',
      mechanism = W.inHand(g).mechanism,
      weapon = W.idAt(g),
      interrupted = true,
      started = g.elapsed,
      duration = closing,
      reloadAge = age,
    })
    return false
  end
  return true
end
function R.update(g, dt)
  local a = actor(g)
  if a.reload <= 0 or type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge then
    return
  end
  local before = R.age(g)
  a.reload = math.max(0, a.reload - dt)
  local after = R.age(g)
  local m = mechanism(g, a.reloadWeapon)
  local w = W.state(g, a.reloadWeapon)
  m.step(g, w, before, after)
  if a.reload == 0 then
    m.finish(g, w)
    a.reloadStage = 0
    a.reloadWeapon = nil
  end
end
return R

local Sigils = require('src.combat.sigils')
local Signal = require('src.session.signal')
local T = require('src.content.tuning')
local W = require('src.content.weapons')
local Text = require('src.content.text')
local Roles = require('src.core.roles')
local Ammo = require('src.content.ammo.index')
local Reloads = require('src.content.reloads')
local R = {}
-- The reload belongs to the actor (plan v11 E3): its timeline, stage and the
-- slot it reloads are fields of the knight's record (session/components.lua).
-- Every function takes the actor (a knight; default the controlled one).
local function actor(g, a)
  return a or Roles.controlled(g)
end
-- A mechanism is data (content/reloads.lua); this one interpreter runs them all.
-- Each gives the drawing, the mechanical sounds and the ammunition transaction:
--   offset(g, w, def, afterShot) where the timeline starts, or nil if no reload
--   step(g, w, before, after, a) events crossed between two timeline ages
--   finish(g, w)                 the action closed
--   primed(w)                    an open action already holds its new rounds
--   label(t)                     the stage shown on the HUD
--   closing(w)                   s the action needs to close when stopped
-- w: the weapon's live record in the arsenal, def: its definition. What a stage
-- looks like (the spent cases flying out) is the presentation's answer to the
-- ReloadStage event.
local function crossed(before, after, t)
  return before < t and after >= t
end
local function finish(_, w)
  w.open = false
  w.loaded = false
end
local function primed(w)
  return w.loaded
end
local function build(id, data)
  local m = {
    id = id,
    duration = data.duration,
    sounds = data.sounds,
    voices = data.voices,
    interruptBefore = data.interruptBefore,
    finish = finish,
    primed = primed,
  }
  function m.closing(w)
    return w.open and data.closeOnFire or 0
  end
  function m.offset(_, w, def, afterShot)
    if not w.open and Ammo.of(def).full(def.ammo, w) then
      return nil
    end
    -- Remaining live rounds predate this reload. Only the completed loading
    -- transaction permits resuming after insertion, even when it moved zero.
    local resume = data.resume
    if w.open and w.loaded then
      return resume.loaded
    elseif w.open then
      return resume.open
    end
    return afterShot and resume.afterShot or resume.closed or 0
  end
  function m.step(g, w, before, after, a)
    for index, stage in ipairs(data.stages) do
      if crossed(before, after, stage.at) then
        local event = {
          stage = stage.name,
          mechanism = id,
          actor = a.id,
          byControlled = a == Roles.controlled(g),
        }
        local signalled = true
        if stage.name == 'open' then
          w.open = true
          w.loaded = false
          if data.ejects then
            -- The spent cases fly out now (feedback/world_feedback.lua).
            event.spent = w.spent or 0
            event.weapon = W.idAt(g, a.reloadWeapon, a)
          end
        elseif stage.name == 'load' then
          signalled = W.load(g, a.reloadWeapon, a) > 0
          w.loaded = true
        else
          w.open = false
          w.loaded = false
        end
        a.reloadStage = index
        if signalled then
          Signal(g, 'ReloadStage', event)
        end
        if stage.name == 'open' and data.ejects then
          w.spent = 0
        end
      end
    end
  end
  function m.label(t)
    for _, label in ipairs(data.labels) do
      if t < label[1] then
        return Text.get(label[2])
      end
    end
  end
  return m
end
local Mechanisms = setmetatable({}, {
  __index = function(built, id)
    local data = Reloads:find(id)
    local m = data and build(id, data)
    rawset(built, id, m)
    return m
  end,
})
R.mechanisms = Mechanisms

-- The mechanism of the weapon in a slot of the actor's loadout.
local function mechanism(g, slot, a)
  local profile = W.inHand(g, slot, a) or W.inHand(g, 1, a)
  return profile.reload and Mechanisms[profile.reload.mechanism]
end
R.mechanism = mechanism

function R.age(g, a)
  a = actor(g, a)
  return (a.reloadOffset or 0) + (a.reloadDuration or 0) - a.reload
end
-- What presentation reads of an actor's reload (default the controlled one;
-- a session without a knight, a bare fixture, has none): the seconds left,
-- the slot being reloaded, its stage, its full length and where it started.
local function field(g, a, name, default)
  a = a or (g and Roles.controlled(g))
  local v = a and a[name]
  if v == nil then
    return default
  end
  return v
end
function R.left(g, a)
  return field(g, a, 'reload', 0)
end
function R.slot(g, a)
  return field(g, a, 'reloadWeapon', nil)
end
function R.stage(g, a)
  return field(g, a, 'reloadStage', 0)
end
function R.duration(g, a)
  return field(g, a, 'reloadDuration', 0)
end
function R.offset(g, a)
  return field(g, a, 'reloadOffset', 0)
end
function R.progress(g, a)
  a = actor(g, a)
  return a.reload > 0
      and math.max(0, math.min(1, R.age(g, a) / mechanism(g, a.reloadWeapon, a).duration))
    or 0
end
function R.label(g, a)
  a = actor(g, a)
  return mechanism(g, a.reloadWeapon, a).label(R.age(g, a))
end
function R.start(g, afterShot, a)
  a = actor(g, a)
  if a.reload > 0 or not W.validAmmo(g, nil, a) then
    return false
  end
  local m = mechanism(g, a.weapon, a)
  if not m then
    return false
  end
  local def, state = W.inHand(g, nil, a)
  local offset = m.offset(g, state, def, afterShot)
  if not offset then
    return false
  end
  a.reloadWeapon = a.weapon
  a.reloadOffset = offset
  a.reloadDuration = m.duration
    - offset
    + Sigils.reloadStart(a, def.id, not Ammo.of(def).canFire(def.ammo, state))
  a.reload = a.reloadDuration
  a.reloadStage = 0
  return true
end
function R.cancel(g, a)
  a = actor(g, a)
  Sigils.reloadCancel(a)
  a.reload = 0
  a.reloadStage = 0
  a.reloadWeapon = nil
end
-- A trigger pull during a reload (0.25): the reload of the weapon in hand
-- stops while rounds remain in it, before its new rounds go in. True when
-- the gun may fire now; a gun whose action must close first is ready later
-- (its readyAt).
function R.interrupt(g, a)
  a = actor(g, a)
  if a.reload <= 0 or a.reloadWeapon ~= a.weapon then
    return false
  end
  local m, w = mechanism(g, a.weapon, a), W.state(g, nil, a)
  local age = R.age(g, a)
  local def = W.inHand(g, nil, a)
  if not m.interruptBefore or not Ammo.of(def).canFire(def.ammo, w) or age >= m.interruptBefore then
    return false
  end
  local closing = m.closing(w, age)
  R.cancel(g, a)
  m.finish(g, w)
  if closing > 0 then
    w.readyAt = math.max(w.readyAt or 0, g.elapsed + closing)
    Signal(g, 'ReloadStage', {
      stage = 'close',
      mechanism = def.reload.mechanism,
      weapon = W.idAt(g, nil, a),
      interrupted = true,
      started = g.elapsed,
      duration = closing,
      reloadAge = age,
      actor = a.id,
      byControlled = a == Roles.controlled(g),
    })
    return false
  end
  return true
end
function R.update(g, dt, a)
  a = actor(g, a)
  if a.reload <= 0 or type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge then
    return
  end
  local before = R.age(g, a)
  a.reload = math.max(0, a.reload - dt * W.inHand(g, a.reloadWeapon, a).reload.speed)
  local after = R.age(g, a)
  local m = mechanism(g, a.reloadWeapon, a)
  local w = W.state(g, a.reloadWeapon, a)
  m.step(g, w, before, after, a)
  if a.reload == 0 then
    local def = W.inHand(g, a.reloadWeapon, a)
    Sigils.reloaded(a, def.id, Ammo.of(def).canFire(def.ammo, w))
    m.finish(g, w)
    a.reloadStage = 0
    a.reloadWeapon = nil
  end
end
return R

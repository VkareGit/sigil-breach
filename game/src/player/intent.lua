local Sigils = require('src.combat.sigils')
-- Short input intentions, independent of render frames. The public scalar
-- fields remain compatible with saves, the test field and old QA fixtures.
-- Holding jump still repeats on landing; a quick tap survives for 120 ms. A shot or a dodge
-- pressed a moment too early happens when it can: a press is never lost to a lock that a
-- player cannot see end, and one that cannot happen says why (ui/hud.lua).
-- The trigger and jump buffers are the actor's (plan v11 E3): every function
-- takes the knight whose intention it is (default the controlled one).
local Tuning = require('src.content.tuning').input
local I = { window = Tuning.jumpWindow }
local Attributes = require('src.combat.attributes')
local Capabilities = require('src.session.capabilities')
local Observation = require('src.combat.observation')
local Presentation = require('src.session.presentation')
local Registry = require('src.core.registry')
local Reload = require('src.combat.reload')
local Resources = require('src.combat.resources')
local Rules = require('src.combat.rules')
local Weapons = require('src.content.weapons')
local function active(g)
  return g.state == 'playing' and not g.map and not g.help
end
local function validStep(dt)
  return type(dt) == 'number' and dt > 0 and dt < math.huge and dt == dt
end
function I.clear(g, actor)
  local p = actor or g.player
  if p then
    p.fireBuffer = 0
    p.fireCommand = nil
    p.jumpBuffer = 0
    p.dashBuffer = 0
  end
end
I.init = I.clear
-- Why the knight cannot do it now, as a text key, or nil when the wait is only the weapon's.
local function refusal(g, p, act)
  if Attributes.forbids(p, act) then
    return p.conditions and (p.conditions.drinking or 0) > 0 and 'hud_drinking' or 'hud_off_balance'
  elseif
    act == 'dash'
    and Capabilities.attrition(g)
    and not Resources.can(p, { stamina = Sigils.dodgeCost(p, Rules.playerBody(p).rollStamina) })
  then
    return 'hud_no_breath'
  elseif act == 'dash' and Capabilities.attrition(g) and (p.recoverAt or 0) > g.elapsed then
    -- The body is still in its shot (content/weapons: recover): the dodge goes when it is back.
    return 'hud_recovering'
  elseif act == 'fire' and Reload.left(g, p) > 0 then
    return 'hud_reloading'
  end
end
-- Say it where the eyes are, and once a moment however long the key is held.
local function tell(g, p, act)
  local reason = refusal(g, p, act)
  local view = g.view
  if reason and view and p == g.player then
    -- The hands reloading already sound like what they are doing, and a dodge waiting out a shot
    -- goes a moment later: neither is a refusal to thud.
    if
      (view.refusalTimer or 0) <= 0
      and reason ~= 'hud_reloading'
      and reason ~= 'hud_recovering'
    then
      Presentation.cue(g, 'thud', Tuning.refusalVolume)
    end
    view.refusal, view.refusalTimer = reason, Tuning.refusalTime
  end
end
function I.queue(g, kind, command, actor)
  if not active(g) then
    return false
  end
  local p = actor or g.player
  if kind == 'jump' then
    p.jumpBuffer = I.window
  elseif kind == 'fire' then
    p.fireBuffer = Tuning.fireWindow
    p.fireCommand = Observation.copy(command)
  else
    return false
  end
  return true
end
function I.jump(g, dt, held, onGround, actor)
  if not validStep(dt) then
    return false
  end
  if not active(g) then
    I.clear(g, actor)
    return false
  end
  local p = actor or g.player
  if held then
    p.jumpBuffer = I.window
  end
  -- Attempt before ageing: an intent valid at the beginning of this simulation
  -- step must not disappear merely because its last few milliseconds elapsed.
  if onGround and (p.jumpBuffer or 0) > 0 then
    p.jumpBuffer = 0
    return true
  end
  p.jumpBuffer = math.max(0, (p.jumpBuffer or 0) - dt)
  return false
end
-- A dodge wanted now, or pressed within dashWindow: it goes the moment it can, toward where the
-- keys point then.
function I.dash(g, dt, pressed, dx, dz, actor)
  local p = actor or g.player
  if not validStep(dt) then
    return false
  end
  -- A press during a dodge is that dodge, not the next one.
  if pressed and p.dashTimer <= 0 then
    p.dashBuffer = Tuning.dashWindow
  end
  if (p.dashBuffer or 0) <= 0 then
    return false
  end
  if not Attributes.forbids(p, 'dash') and g:dash(dx, dz, p) then
    p.dashBuffer = 0
    return true
  end
  if pressed then
    tell(g, p, 'dash')
  end
  p.dashBuffer = math.max(0, p.dashBuffer - dt)
  return false
end
-- What a press means, by trigger mode (content/triggers.lua):
--   modes[mode](p, held, dt, trigger) -> whether a shot is wanted now
--   p.trigger: what the mode keeps between steps
I.modes = Registry:new('trigger behaviours')
I.modes:register('auto', function(_, held)
  return held
end)
local function wanted(g, p, held, dt)
  local def = Weapons.inHand(g, nil, p)
  return def and I.modes:get(def.trigger.mode)(p, held, dt, def.trigger) or false
end
function I.fire(g, dt, held, command, actor)
  if not validStep(dt) then
    return false
  end
  if not active(g) then
    I.clear(g, actor)
    return false
  end
  -- A held trigger follows the newest observation; a released tap retains the
  -- exact observation and aim that were submitted with that press.
  local p = actor or g.player
  local submitted = p.fireCommand
  if held then
    submitted = command
  elseif submitted and Tuning.fireWindow - (p.fireBuffer or 0) > Tuning.freshAim then
    -- It had to wait: it goes where he is looking now, not where he looked then.
    submitted = nil
  end

  local trying = wanted(g, p, held, dt) or (p.fireBuffer or 0) > 0
  if trying and g:shoot(submitted, actor) then
    p.fireBuffer = 0
    p.fireCommand = nil
    return true
  end
  if trying then
    tell(g, p, 'fire')
  end
  p.fireBuffer = math.max(0, (p.fireBuffer or 0) - dt)
  if p.fireBuffer == 0 then
    p.fireCommand = nil
  end
  return false
end
return I

-- Short input intentions, independent of render frames. The public scalar
-- fields remain compatible with saves, the test field and old QA fixtures.
-- Holding jump still repeats on landing; a quick tap survives for 120 ms.
-- The trigger and jump buffers are the actor's (plan v11 E3): every function
-- takes the knight whose intention it is (default the controlled one).
local I = { window = 0.12 }
local Observation = require('src.combat.observation')
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
  end
end
I.init = I.clear
function I.queue(g, kind, command, actor)
  if not active(g) then
    return false
  end
  local p = actor or g.player
  if kind == 'jump' then
    p.jumpBuffer = I.window
  elseif kind == 'fire' then
    p.fireBuffer = I.window
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
  end
  if (held or (p.fireBuffer or 0) > 0) and g:shoot(submitted, actor) then
    p.fireBuffer = 0
    p.fireCommand = nil
    return true
  end
  p.fireBuffer = math.max(0, (p.fireBuffer or 0) - dt)
  if p.fireBuffer == 0 then
    p.fireCommand = nil
  end
  return false
end
return I

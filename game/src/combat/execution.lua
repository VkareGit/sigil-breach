-- The reward of a broken guard: a body held open can be finished up close with
-- the use key. Its share of the body's full health is the body's own
-- (content/defs/body.lua: execution). Emits Executed (session/event_catalog.lua).
local Defaults = require('src.content.combat_defaults').execution
local Presentation = require('src.session.presentation')
local Bodies = require('src.combat.bodies')
local Hit = require('src.combat.hit')
local Roles = require('src.core.roles')
local Rules = require('src.combat.rules')
local Signal = require('src.session.signal')
local Text = require('src.content.text')
local Execution = {}
-- The body the knight can finish where he stands and looks, if any.
function Execution.target(g, actor)
  local p = actor or Roles.controlled(g)
  local best, near = nil, math.huge
  Bodies.each(g, function(e)
    local dx, dz = e.x - p.x, e.z - p.z
    local d = math.sqrt(dx * dx + dz * dz)
    if
      e.hp > 0
      and e ~= p
      and Rules.body(e).execution
      and (e.stun or 0) > 0
      and Rules.has(e, 'exposed')
      and d < Rules.radius(e) + Defaults.reach
      and d < near
      and (d < 1e-6 or (dx * math.sin(p.yaw) + dz * math.cos(p.yaw)) / d >= Defaults.cone)
    then
      best, near = e, d
    end
  end)
  return best
end
function Execution.perform(g)
  local p = Roles.controlled(g)
  local e = Execution.target(g, p)
  if not e then
    return false
  end
  local amount = (e.maxHp or Rules.body(e).hp) * Rules.body(e).execution
  e.conditions.exposed = nil
  e.stun, e.poise = Defaults.rise, 0
  p.invuln = math.max(p.invuln, Defaults.iframes)
  g.impactSlow = math.max(g.impactSlow or 0, Defaults.stop)
  Hit.land(g, e, { damage = amount, impact = 0 }, {
    source = 'execution',
    owner = p.id,
    point = { e.x, Rules.body(e).aimY, e.z },
    numbered = true,
    label = 'execution',
  })
  Presentation.cue(g, 'seal', Defaults.cue)
  g:notify(Text.get('execution_done'), 2)
  Signal(g, 'Executed', { enemy = e, amount = amount, actor = p.id })
  return true
end
function Execution.prompt(g)
  return Execution.target(g) and Text.get('execution_prompt') or nil
end
return Execution

local Anim = {}
local Idle = require('src.enemies.idle')
local Motion = require('src.content.pose_motion')
local Archetypes = require('src.content.enemies')
local Corpse = require('src.enemies.corpse')
local ActionPhase = require('src.enemies.action_phase')
local Roles = require('src.core.roles')
local Flinch = require('src.enemies.flinch')
local Capabilities = require('src.session.capabilities')
local Atlases = require('src.content.art.atlases')
local Poses = require('src.content.art.poses')
local Action = require('src.content.defs.action')
local Registry = require('src.core.registry')
-- The bearing from body e to its observer (plan v11 E4): the point a
-- billboard turns to and its back frames are judged against. The caller names
-- it (a shooter's eye, a missile's owner, a creature's target, the camera of
-- a view); none given, the controlled knight. The simulation never asks the
-- camera.
local function viewerYaw(g, e, observer)
  local v = observer or Roles.controlled(g)
  return math.atan2(v.x - e.x, v.z - e.z)
end
Anim.actionPhase = ActionPhase.sample
-- A body's frames are chosen by name (plan v11 E1): its atlas's sheet names
-- the poses and the clock of each (content/art/poses.lua); this module only
-- says which pose a state shows and gives it the state's clock.
function Anim.poses(e)
  local atlas = Archetypes.look(e).atlas or e.kind
  local poses = Atlases.poses[atlas]
  if not poses then
    error('no named poses for atlas ' .. tostring(atlas))
  end
  return poses
end
-- The pose name stands for on a body's atlas (fallbacks followed).
function Anim.posed(e, name)
  local pose = Poses.resolve(Anim.poses(e), name)
  if not pose then
    error('atlas has no pose ' .. name)
  end
  return pose
end
local posed = Anim.posed
-- Painted motions (appearance.motion): fn(g, e, frame, bounce, lean, quiet, rear)
-- returns frame, bounce and lean of a living body. A pose places the body's hit
-- volumes, so every clock in it is the simulation's: a pause, a map or a menu
-- moves none of it (PLAN F3). The image drawn between two steps reads that
-- clock between them (poseTime, render/presentation.lua).
local function poseTime(g)
  return g.poseTime or g.elapsed
end
Anim.motions = Registry:new('painted motions', function(entry, id)
  assert(type(entry) == 'function', 'painted motion ' .. id .. ' needs a function')
end)
Anim.motions:register('hover', function(g, e, frame, _, lean, quiet, rear)
  local now = poseTime(g)
  if not quiet and (e.ai == 'idle' or e.ai == 'move') then
    local flight = posed(e, rear and 'hoverRear' or 'hover')
    frame = Poses.frame(flight, now + e.id * (flight.offset or 0))
  end
  local H = Motion.hover
  return frame,
    H.height + math.sin(now * H.bobRate + e.id) * H.bob,
    lean + math.sin(now * H.swayRate + e.id) * H.sway
end)
Anim.motions:register('heavy', function(_, e, frame, bounce, lean)
  if (e.walkSpeed or 0) > Motion.walking then
    return frame, bounce * Motion.heavy.bounce, lean * Motion.heavy.lean
  end
  return frame, bounce, lean
end)
Anim.motions:register('sway', function(_, e, frame, bounce, lean)
  return frame, bounce, lean + math.sin(e.walk * Motion.sway.rate) * Motion.sway.lean
end)
function Anim.frameCount(kind)
  return #Atlases.layouts[kind].frames
end
-- A normalized read of the current falter, independent of the world's clock.
-- Shorter guard windows use the same painted recovery without a second timer.
function Anim.exposedProgress(e)
  local left = e.conditions and e.conditions.exposed or 0
  local age = math.max(0, e.phase or 0)
  local body = Archetypes.of(e).body
  local duration = math.max(left, body.breakTime or (age + left), Motion.shortestFalter)
  return math.max(0, math.min(1, 1 - left / duration))
end
local function exhausted(e)
  local t = Anim.exposedProgress(e)
  local keys = Archetypes.defaults.exposedReel
  for i = 2, #keys do
    local a, b = keys[i - 1], keys[i]
    if t <= b[1] then
      local blend = (t - a[1]) / (b[1] - a[1])
      blend = blend * blend * (3 - 2 * blend)
      return Poses.frame(posed(e, 'exposed'), t),
        a[2] + (b[2] - a[2]) * blend,
        a[3] + (b[3] - a[3]) * blend
    end
  end
end
-- The state a body is drawn in (PLAN F3): Anim.pose asks the states in their
-- order and the first whose when(g, e, ctx) holds draws the body with
-- pose(g, e, ctx), which returns frame, bounce, lean, sx, sy, quiet and rear
-- (0, 0, 1, 1, false, false when left out). ctx carries what every state may
-- read: observer, look, encounter, transitionAge and flinchProjection. A
-- creature or a mod adds a state with Anim.state(id, { before = id, ... }).
Anim.states = Registry:new('pose states', function(entry, id)
  assert(type(entry.when) == 'function', 'pose state ' .. id .. ' needs when')
  assert(type(entry.pose) == 'function', 'pose state ' .. id .. ' needs pose')
end)
function Anim.state(id, def)
  if def.before then
    return Anim.states:insert(id, def, def.before)
  end
  return Anim.states:register(id, def)
end
local function facesAway(g, e, observer)
  return math.cos(viewerYaw(g, e, observer) - (e.facing or 0)) < Poses.rearCos
end
Anim.state('dead', {
  when = function(_, e)
    return e.hp <= 0
  end,
  pose = function(_, e, ctx)
    return Corpse.pose(e, posed(e, 'collapse'), ctx.flinchProjection)
  end,
})
-- Knocked down (0.24): the painted collapse frames carry the fall. The body
-- goes down (knockdown, seconds since the fall), stays low and climbs back
-- up (rise, on the time it has left; the hit volumes follow the pose).
Anim.state('knockedDown', {
  when = function(_, e)
    return e.knockedDown and (e.stun or 0) > 0
  end,
  pose = function(_, e)
    local total = math.max(e.knockTime or e.stun, e.stun)
    local frame = Poses.frame(posed(e, 'knockdown'), total - e.stun)
      or Poses.frame(posed(e, 'rise'), -e.stun)
    return frame, 0, Motion.knockedLean, 1, 1
  end,
})
Anim.state('exhausted', {
  when = function(_, e)
    return (e.stun or 0) > 0 and e.conditions and (e.conditions.exposed or 0) > 0
  end,
  pose = function(_, e)
    local frame, lean, sy = exhausted(e)
    return frame, 0, lean, 1, sy
  end,
})
-- A heavy stagger throws the body back (the first painted recoil frame),
-- then bows it in pain; a light falter only flinches in place.
Anim.state('hurt', {
  when = function(_, e)
    return e.ai == 'hurt' and (e.phase < Motion.hurt.recoil or (e.stun or 0) > 0)
  end,
  pose = function(_, e)
    if e.heavyStagger then
      return Poses.frame(posed(e, 'painHeavy'), e.phase),
        0,
        Motion.hurt.heavyLean,
        1,
        Motion.hurt.heavySquash
    end
    return Poses.frame(posed(e, 'pain'), e.phase), 0, Motion.hurt.lean, 1, 1
  end,
})
Anim.state('transition', {
  when = function(_, e, ctx)
    local encounter, age = ctx.encounter, ctx.transitionAge
    return e.ai == 'recover'
      and encounter
      and encounter.transitionPose
      and age
      and age >= 0
      and age < encounter.recovery
  end,
  pose = function(_, e, ctx)
    local encounter = ctx.encounter
    return Poses.frame(posed(e, encounter.transitionPose), ctx.transitionAge / encounter.recovery),
      0,
      0,
      1,
      1
  end,
})
Anim.state('windup', {
  when = function(_, e)
    return e.ai == 'windup'
  end,
  pose = function(g, e, ctx)
    local t = Anim.actionPhase(e)
    local pose = posed(e, e.attackKind and ('windup.' .. e.attackKind) or 'windup')
    if pose.rear and facesAway(g, e, ctx.observer) then
      pose = posed(e, pose.rear)
    end
    local T = Motion.transition
    return Poses.frame(pose, t), 0, T.lean * t, 1 + t * T.widen, 1 - t * T.widen
  end,
})
Anim.state('strike', {
  when = function(_, e)
    return e.ai == 'strike'
  end,
  pose = function(g, e, ctx)
    local t = Anim.actionPhase(e)
    -- An attack may hold its own painted frame (strike.<attack id>).
    local pose = posed(e, e.attackKind and ('strike.' .. e.attackKind) or 'strike')
    local act = e.act
    local clock = pose.clock == 'release' and math.max(0, (act and act.released or 0) - 1)
      or (pose.clock == 'seconds' and (e.phase or 0) or t)
    -- A returning charge plants its weight during its existing pause. Art
    -- samples that authoritative deadline; it never creates another timer.
    local turn = act
      and act.turnAt
      and e.attackKind
      and Poses.resolve(Anim.poses(e), 'turn.' .. e.attackKind)
    local pause = turn and ActionPhase.turn(e)
    if pause then
      pose = turn
      clock = pause
    end
    if pose.rear and facesAway(g, e, ctx.observer) then
      pose = posed(e, pose.rear)
    end
    return Poses.frame(pose, clock),
      0,
      Motion.strike.lean * (1 - t),
      1 + Motion.strike.widen * math.sin(t * math.pi),
      1
  end,
})
Anim.state('recover', {
  when = function(_, e)
    return e.ai == 'recover'
  end,
  pose = function(_, e)
    local t = Anim.actionPhase(e)
    local pose = posed(e, e.attackKind and ('recover.' .. e.attackKind) or 'recover')
    return Poses.frame(pose, t), 0, 0, 1, Motion.recover.squash + Motion.recover.rise * t
  end,
})
Anim.state('walk', {
  when = function(_, e)
    return (e.walkSpeed or 0) > Motion.walking
  end,
  pose = function(g, e, ctx)
    local walk = posed(e, 'walk')
    local count = #walk.frames
    local phase = e.walk * (walk.rate or 0)
    local bounce = math.abs(math.sin(phase * math.pi / (count * 0.5))) * Motion.walk.bounce
    local lean = math.sin(phase * math.pi / (count * 0.5)) * Motion.walk.lean
    local rear = facesAway(g, e, ctx.observer)
    return Poses.frame(rear and posed(e, 'walkRear') or walk, e.walk),
      bounce,
      lean,
      1,
      1,
      false,
      rear
  end,
})
-- Breath and vigilance are painted into the ribs, hands, wings and neck.
-- Never stretch armor, skull or the whole silhouette to fake breathing.
Anim.state('quiet', {
  when = function()
    return true
  end,
  pose = function(g, e, ctx)
    local watching = e.awake and (e.memory or 0) > 0 and facesAway(g, e, ctx.observer)
    local pose = watching and posed(e, 'watchRear') or posed(e, 'quiet')
    local frame
    if pose.clock == 'breath' then
      frame = Idle.sample(Idle.kind(e), poseTime(g), e.id)
    else
      frame = Poses.frame(pose, 0)
    end
    return frame, 0, 0, 1, 1, true
  end,
})
local ctx = {}
function Anim.pose(g, e, observer)
  if e.previewFrame and Capabilities.posed(g) then
    return e.previewFrame, 0, 0, 1, 1
  end
  local look = Archetypes.look(e)
  ctx.observer = observer
  ctx.look = look
  ctx.encounter = Archetypes.phase(e)
  ctx.transitionAge = e.phaseEnteredAt and (g.elapsed - e.phaseEnteredAt)
  ctx.flinchProjection = Flinch.projection(g, e, observer or Roles.controlled(g))
  local flinchProjection = ctx.flinchProjection
  local frame, bounce, lean, sx, sy, quiet, rear = 1
  local states = Anim.states
  for _, id in ipairs(states.order) do
    local state = states.entries[id]
    if state.when(g, e, ctx) then
      frame, bounce, lean, sx, sy, quiet, rear = state.pose(g, e, ctx)
      break
    end
  end
  bounce, lean, sx, sy = bounce or 0, lean or 0, sx or 1, sy or 1
  quiet, rear = quiet or false, rear or false
  if look.motion and e.hp > 0 then
    frame, bounce, lean = Anim.motions:get(look.motion)(g, e, frame, bounce, lean, quiet, rear)
  end
  -- Hit flinch from the shared rules: the body gives way on the side that was
  -- struck and compresses for a fraction of a second (weight of the blow).
  -- The calibrated hit volumes use the same transform, so they follow it.
  local f = e.hp > 0 and (e.flinch or 0) or 0
  if e.hp > 0 then
    lean = lean + (e.flinchLean or 0) * flinchProjection
  end
  if f > 0 then
    sx = sx * (1 + Motion.flinch.widen * f)
    sy = sy * (1 - Motion.flinch.squash * f)
  end
  -- The leap's crouch: the body sinks and widens as it gathers (telegraph).
  local spec = e.attackSpec
  -- A traced blow is carried to the side it starts from: the tell of its direction.
  if e.hp > 0 and e.ai == 'windup' and spec and spec.trace then
    local from = spec.trace[1].angle * (e.swingSide or 1)
    lean = lean + (from > 0 and 1 or -1) * Archetypes.defaults.attacks.swingLean
  end
  if e.hp > 0 and e.ai == 'windup' and spec and Action.trait(spec, 'gathers') then
    local t = Anim.actionPhase(e)
    sy = sy * (1 - Motion.gather.sink * t)
    sx = sx * (1 + Motion.gather.widen * t)
  end
  -- A sidestep leans the body into its direction.
  if e.hp > 0 and (e.evadeTime or 0) > 0 then
    lean = lean + Motion.evadeLean * (e.evadeSide or 1)
  end
  -- Arrival from a portal: the body climbs out of the floor in 0.6 s (the
  -- floor clips the sinking sprite; hit volumes follow the same pose).
  if e.hp > 0 and (e.spawnAge or 1) < Motion.arrival.time then
    local k = 1 - e.spawnAge / Motion.arrival.time
    bounce = bounce - k * k * Motion.arrival.depth
  end
  -- A leaping (or falling) body is lifted by its flight height.
  if e.hp > 0 and e.leapY then
    bounce = bounce + e.leapY
  end
  -- A crippled body (leg hit) limps: every other step sinks on one side.
  local crippled = e.hp > 0 and e.conditions and e.conditions.crippled
  if crippled and crippled > 0 then
    local L = Motion.limp
    local limp = math.max(0, math.sin((e.walk or 0) * L.rate + e.id))
    local side = (e.id % 2 == 0) and 1 or -1
    lean = lean + side * (L.lean + L.leanGain * limp)
    sy = sy * (1 - L.sink * limp)
  end
  -- A major wound trembles for its duration (condition 'wounded').
  local wound = e.hp > 0 and e.conditions and e.conditions.wounded
  if wound and wound > 0 then
    lean = lean
      + math.sin(poseTime(g) * Motion.tremble.rate + e.id)
        * Motion.tremble.lean
        * math.min(1, wound)
  end
  return frame, bounce, lean, sx, sy
end
return Anim

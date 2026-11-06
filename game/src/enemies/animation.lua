local Anim = {}
local Idle = require('src.enemies.idle')
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
-- returns frame, bounce and lean of a living body.
Anim.motions = Registry:new('painted motions', function(entry, id)
  assert(type(entry) == 'function', 'painted motion ' .. id .. ' needs a function')
end)
Anim.motions:register('hover', function(g, e, frame, _, lean, quiet, rear)
  if not quiet and (e.ai == 'idle' or e.ai == 'move') then
    local flight = posed(e, rear and 'hoverRear' or 'hover')
    frame = Poses.frame(flight, g.time + e.id * (flight.offset or 0))
  end
  return frame,
    0.17 + math.sin(g.time * 2.6 + e.id) * 0.065,
    lean + math.sin(g.time * 1.7 + e.id) * 0.018
end)
Anim.motions:register('heavy', function(_, e, frame, bounce, lean)
  if (e.walkSpeed or 0) > 0.1 then
    return frame, bounce * 0.3, lean * 0.55
  end
  return frame, bounce, lean
end)
Anim.motions:register('sway', function(_, e, frame, bounce, lean)
  return frame, bounce, lean + math.sin(e.walk * 5.5) * 0.018
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
  local duration = math.max(left, body.breakTime or (age + left), 0.001)
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
function Anim.pose(g, e, observer)
  if e.previewFrame and Capabilities.posed(g) then
    return e.previewFrame, 0, 0, 1, 1
  end
  local frame, bounce, lean, sx, sy = 1, 0, 0, 1, 1
  local quiet, rear = false, false
  local look = Archetypes.look(e)
  local encounter = Archetypes.phase(e)
  local transitionAge = e.phaseEnteredAt and (g.elapsed - e.phaseEnteredAt)
  local flinchProjection = Flinch.projection(g, e, observer or Roles.controlled(g))
  if e.hp <= 0 then
    frame, bounce, lean, sx, sy = Corpse.pose(e, posed(e, 'collapse'), flinchProjection)
  -- Knocked down (0.24): the painted collapse frames carry the fall. The body
  -- goes down (knockdown, seconds since the fall), stays low and climbs back
  -- up (rise, on the time it has left; the hit volumes follow the pose).
  elseif e.knockedDown and (e.stun or 0) > 0 then
    local total = math.max(e.knockTime or e.stun, e.stun)
    frame = Poses.frame(posed(e, 'knockdown'), total - e.stun)
      or Poses.frame(posed(e, 'rise'), -e.stun)
    lean = -0.06
  elseif (e.stun or 0) > 0 and e.conditions and (e.conditions.exposed or 0) > 0 then
    frame, lean, sy = exhausted(e)
  -- A heavy stagger throws the body back (the first painted recoil frame),
  -- then bows it in pain; a light falter only flinches in place.
  elseif e.ai == 'hurt' and (e.phase < 0.20 or (e.stun or 0) > 0) then
    frame = Poses.frame(posed(e, 'pain'), e.phase)
    lean = -0.03
    if e.heavyStagger then
      frame = Poses.frame(posed(e, 'painHeavy'), e.phase)
      lean = -0.08
      sy = 0.95
    end
  elseif
    e.ai == 'recover'
    and encounter
    and encounter.transitionPose
    and transitionAge
    and transitionAge >= 0
    and transitionAge < encounter.recovery
  then
    frame = Poses.frame(posed(e, encounter.transitionPose), transitionAge / encounter.recovery)
  elseif e.ai == 'windup' then
    local t = Anim.actionPhase(e)
    local pose = posed(e, e.attackKind and ('windup.' .. e.attackKind) or 'windup')
    if pose.rear and math.cos(viewerYaw(g, e, observer) - (e.facing or 0)) < Poses.rearCos then
      pose = posed(e, pose.rear)
    end
    frame = Poses.frame(pose, t)
    lean = -0.025 * t
    sx = 1 + t * 0.025
    sy = 1 - t * 0.025
  elseif e.ai == 'strike' then
    local t = Anim.actionPhase(e)
    -- An attack may hold its own painted frame (strike.<attack id>).
    local pose = posed(e, e.attackKind and ('strike.' .. e.attackKind) or 'strike')
    local clock = pose.clock == 'release' and math.max(0, (e.released or 0) - 1)
      or (pose.clock == 'seconds' and (e.phase or 0) or t)
    -- A returning charge plants its weight during its existing pause. Art
    -- samples that authoritative deadline; it never creates another timer.
    local turn = e.turnAt and e.attackKind and Poses.resolve(Anim.poses(e), 'turn.' .. e.attackKind)
    local pause = turn and ActionPhase.turn(e)
    if pause then
      pose = turn
      clock = pause
    end
    if pose.rear and math.cos(viewerYaw(g, e, observer) - (e.facing or 0)) < Poses.rearCos then
      pose = posed(e, pose.rear)
    end
    frame = Poses.frame(pose, clock)
    lean = 0.06 * (1 - t)
    sx = 1 + 0.035 * math.sin(t * math.pi)
  elseif e.ai == 'recover' then
    local t = Anim.actionPhase(e)
    frame = Poses.frame(posed(e, e.attackKind and ('recover.' .. e.attackKind) or 'recover'), t)
    sy = 0.98 + 0.02 * t
  elseif (e.walkSpeed or 0) > 0.1 then
    local walk = posed(e, 'walk')
    local count = #walk.frames
    local phase = e.walk * (walk.rate or 0)
    bounce = math.abs(math.sin(phase * math.pi / (count * 0.5))) * 0.008
    lean = math.sin(phase * math.pi / (count * 0.5)) * 0.012
    rear = math.cos(viewerYaw(g, e, observer) - (e.facing or 0)) < Poses.rearCos
    frame = Poses.frame(rear and posed(e, 'walkRear') or walk, e.walk)
  else
    -- Breath and vigilance are painted into the ribs, hands, wings and neck.
    -- Never stretch armor, skull or the whole silhouette to fake breathing.
    local watching = e.awake
      and (e.memory or 0) > 0
      and math.cos(viewerYaw(g, e, observer) - (e.facing or 0)) < Poses.rearCos
    local pose = watching and posed(e, 'watchRear') or posed(e, 'quiet')
    if pose.clock == 'breath' then
      frame = Idle.sample(Idle.kind(e), g.time, e.id)
    else
      frame = Poses.frame(pose, 0)
    end
    quiet = true
  end
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
    sx = sx * (1 + 0.05 * f)
    sy = sy * (1 - 0.045 * f)
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
    sy = sy * (1 - 0.10 * t)
    sx = sx * (1 + 0.06 * t)
  end
  -- A sidestep leans the body into its direction.
  if e.hp > 0 and (e.evadeTime or 0) > 0 then
    lean = lean + 0.09 * (e.evadeSide or 1)
  end
  -- Arrival from a portal: the body climbs out of the floor in 0.6 s (the
  -- floor clips the sinking sprite; hit volumes follow the same pose).
  if e.hp > 0 and (e.spawnAge or 1) < 0.6 then
    local k = 1 - e.spawnAge / 0.6
    bounce = bounce - k * k * 1.4
  end
  -- A leaping (or falling) body is lifted by its flight height.
  if e.hp > 0 and e.leapY then
    bounce = bounce + e.leapY
  end
  -- A crippled body (leg hit) limps: every other step sinks on one side.
  local crippled = e.hp > 0 and e.conditions and e.conditions.crippled
  if crippled and crippled > 0 then
    local limp = math.max(0, math.sin((e.walk or 0) * 4.2 + e.id))
    local side = (e.id % 2 == 0) and 1 or -1
    lean = lean + side * (0.02 + 0.05 * limp)
    sy = sy * (1 - 0.05 * limp)
  end
  -- A major wound trembles for its duration (condition 'wounded').
  local wound = e.hp > 0 and e.conditions and e.conditions.wounded
  if wound and wound > 0 then
    lean = lean + math.sin((g.time or 0) * 38 + e.id) * 0.010 * math.min(1, wound)
  end
  return frame, bounce, lean, sx, sy
end
return Anim

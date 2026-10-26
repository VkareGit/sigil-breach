local Anim = {}
local Idle = require('src.enemies.idle')
local Archetypes = require('src.content.enemies')
local Corpse = require('src.enemies.corpse')
local ActionPhase = require('src.enemies.action_phase')
local Roles = require('src.core.roles')
-- The bearing from body e to the viewer (core/roles.lua): what a
-- billboard turns to and what its back frames are judged against.
local function viewerYaw(g, e)
  local v = Roles.viewer(g)
  return math.atan2(v.x - e.x, v.z - e.z)
end
Anim.actionPhase = ActionPhase.sample
-- Painted atlases come in two layouts: the extended one (6 columns: walk,
-- windup, strike, pain, collapse, rear) and the compact one (4 columns).
-- A creature names its layout in its appearance (content/defs/creature.lua);
-- poses read only the layout.
local function extendedKind(kind)
  local def = Archetypes.get(kind)
  return def ~= nil and def.appearance.layout == 'extended'
end
function Anim.extended(kind)
  return extendedKind(kind)
end
function Anim.layout(kind)
  return extendedKind(kind) and 6 or 4, 4
end
function Anim.frameCount(kind)
  return Idle.total(kind)
end
function Anim.pose(g, e)
  if g.testField and e.previewFrame then
    return e.previewFrame, 0, 0, 1, 1
  end
  local frame, bounce, lean, sx, sy = 1, 0, 0, 1, 1
  local quiet = false
  -- 'imp' here means the extended atlas layout, not the creature.
  local look = Archetypes.look(e)
  local imp = look.layout == 'extended'
  if e.hp <= 0 then
    frame, bounce, lean, sx, sy = Corpse.pose(e, imp)
  -- Knocked down (0.24): the painted collapse frames carry the fall. The body
  -- goes down in 0.12 s, stays low, and climbs back up in the last 0.15 s
  -- (the hit volumes follow the painted pose).
  elseif e.knockedDown and (e.stun or 0) > 0 then
    local total = math.max(e.knockTime or e.stun, e.stun)
    local t = total - e.stun
    if imp then
      frame = (t < 0.06 and 14)
        or (t < 0.12 and 15)
        or (e.stun > 0.15 and 16)
        or (e.stun > 0.07 and 15)
        or 14
    else
      frame = (t < 0.08 and 10) or (e.stun > 0.12 and 11) or 10
    end
    lean = -0.06
  -- A heavy stagger throws the body back (the first painted recoil frame),
  -- then bows it in pain; a light falter only flinches in place.
  elseif e.ai == 'hurt' and (e.phase < 0.20 or (e.stun or 0) > 0) then
    frame = imp and 13 or 9
    lean = -0.03
    if e.heavyStagger then
      frame = (e.phase < 0.12) and (imp and 14 or 10) or frame
      lean = -0.08
      sy = 0.95
    end
  -- A boss falter (broken guard): the pain pose for the pause itself, bowed.
  elseif (e.stun or 0) > 0 and e.conditions and (e.conditions.exposed or 0) > 0 then
    frame = imp and 13 or 9
    lean = -0.05
    sy = 0.95
  elseif e.ai == 'windup' then
    local t = Anim.actionPhase(e)
    frame = imp and (t < 0.22 and 7 or (t < 0.6 and 8 or 9)) or (t < 0.42 and 5 or 6)
    lean = -0.025 * t
    sx = 1 + t * 0.025
    sy = 1 - t * 0.025
  elseif e.ai == 'strike' then
    local t = Anim.actionPhase(e)
    frame = (look.strikeFrames and look.strikeFrames[e.attackKind])
      or (imp and (t < 0.5 and 10 or 11) or 7)
    lean = 0.06 * (1 - t)
    sx = 1 + 0.035 * math.sin(t * math.pi)
  elseif e.ai == 'recover' then
    frame = imp and 12 or 8
    sy = 0.98 + 0.02 * Anim.actionPhase(e)
  elseif (e.walkSpeed or 0) > 0.1 then
    local count = imp and 6 or 4
    local phase = e.walk * (imp and 4.2 or 3.4)
    frame = 1 + math.floor(phase) % count
    bounce = math.abs(math.sin(phase * math.pi / (count * 0.5))) * 0.008
    lean = math.sin(phase * math.pi / (count * 0.5)) * 0.012
    local toCamera = viewerYaw(g, e)
    if math.cos(toCamera - (e.facing or 0)) < -0.25 then
      frame = frame + (imp and 18 or 12)
    end
  else
    -- Breath and vigilance are painted into the ribs, hands, wings and neck.
    -- Never stretch armor, skull or the whole silhouette to fake breathing.
    local rear = e.awake
      and (e.memory or 0) > 0
      and math.cos(viewerYaw(g, e) - (e.facing or 0)) < -0.25
    frame = rear and (imp and 19 or 13) or Idle.sample(Idle.kind(e), g.time, e.id)
    quiet = true
  end
  if look.motion == 'hover' and e.hp > 0 then
    bounce = 0.17 + math.sin(g.time * 2.6 + e.id) * 0.065
    lean = lean + math.sin(g.time * 1.7 + e.id) * 0.018
    if not quiet and (e.ai == 'idle' or e.ai == 'move') then
      local rear = frame >= 19
      frame = 1 + math.floor((g.time + e.id * 0.17) * 7) % 6 + (rear and 18 or 0)
    end
  elseif look.motion == 'heavy' and e.hp > 0 and (e.walkSpeed or 0) > 0.1 then
    bounce = bounce * 0.3
    lean = lean * 0.55
  elseif look.motion == 'sway' and e.hp > 0 then
    lean = lean + math.sin(e.walk * 5.5) * 0.018
  end
  -- Hit flinch from the shared rules: the body gives way on the side that was
  -- struck and compresses for a fraction of a second (weight of the blow).
  -- The calibrated hit volumes use the same transform, so they follow it.
  local f = e.hp > 0 and (e.flinch or 0) or 0
  if e.hp > 0 then
    lean = lean + (e.flinchLean or 0)
  end
  if f > 0 then
    sx = sx * (1 + 0.05 * f)
    sy = sy * (1 - 0.045 * f)
  end
  -- The leap's crouch: the body sinks and widens as it gathers (telegraph).
  local spec = e.attackSpec
  if e.hp > 0 and e.ai == 'windup' and spec and spec.kind == 'leap' then
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

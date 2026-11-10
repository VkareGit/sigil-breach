local Context = require('src.session.context')
local Roles = require('src.core.roles')
local Flinch = require('src.enemies.flinch')
-- Interpolate the fixed simulation without delaying raw mouse input or mutating gameplay.
local Pools = require('src.session.world')
local Components = require('src.session.components')
local HazardDefs = require('src.content.hazards')
local Rate = require('src.core.rate')
local P = {}
local playerKeys = { 'x', 'z', 'jump', 'crouch' }
local viewerKeys = { 'x', 'y', 'z', 'jump', 'crouch' }
-- time: the running clock of hover, breath and flicker (enemies/animation.lua,
-- render/lights.lua); it steps with the simulation and is drawn between steps.
local gameKeys = { 'step', 'time' }
-- Presentation state (g.view) blended the same way.
local viewKeys = {
  'land',
  'recoil',
  'bank',
  'bobWeight',
  'fovKick',
  'weaponLagX',
  'weaponLagY',
  'weaponClock',
  'weaponStride',
  'weaponCarry',
  'weaponAimX',
  'weaponAimY',
  'weaponLean',
  'weaponDip',
  'weaponLower',
  'weaponImpactX',
  'weaponImpactY',
  'weaponImpactRoll',
  'rollPunch',
  'viewPunch',
  'aimKick',
  'kickBack',
  'weaponShotRoll',
  'weaponStepY',
  'weaponStepRoll',
  'weaponAirY',
  'weaponGestureX',
  'weaponGestureY',
  'weaponGestureRoll',
}
-- Clocks of the view (seconds since an event) are shown at the image's own
-- time, a part of a step before the simulation: the flash of a shot and its
-- kick read one instant of the shot (PLAN E5).
local viewClocks = { 'shotAge' }
-- The members of the pools the image draws blend the fields their components
-- declare smooth (session/components.lua: f(..., 'linear'), PLAN E4): a new
-- moving field is smoothed by its declaration, not by a list kept here.
local drawn = { 'enemies', 'projectiles', 'charges', 'hazards' }
local memberKeys, memberRests = {}, {}
local function declared()
  for _, pool in ipairs(drawn) do
    memberKeys[pool], memberRests[pool] = Components.smoothed(pool), Components.rests(pool)
  end
end
declared()
-- A kind of marked ground registered later (a mod, a test) blends what it declares
-- (PLAN Z7): the fields are read again when the kinds changed.
local hazardKinds = HazardDefs:revision()
local function current()
  if HazardDefs:revision() ~= hazardKinds then
    hazardKinds = HazardDefs:revision()
    declared()
  end
end
local stateClocks = Components.smoothed('enemies', 'clock')
local function values(object, keys)
  local out = {}
  for _, key in ipairs(keys) do
    out[key] = object[key] or 0
  end
  return out
end
local function blend(object, previous, keys, t)
  local out = setmetatable({}, { __index = object })
  if previous then
    for _, key in ipairs(keys) do
      local now = object[key] or 0
      out[key] = previous[key] + (now - previous[key]) * t
    end
  end
  return out
end
-- A member's field may be absent (not leaping, not falling). It blends when the
-- current step has it and the previous one had it or its rest value; otherwise
-- the image shows the current value, so an absent field stays absent.
local function memberValues(object, keys)
  local out = {}
  for _, key in ipairs(keys) do
    out[key] = object[key]
  end
  return out
end
local function blendMember(object, previous, keys, t, rests)
  local out = setmetatable({}, { __index = object })
  if previous then
    for _, key in ipairs(keys) do
      local before, now = previous[key], object[key]
      if before == nil then
        before = rests[key]
      end
      if type(before) == 'number' and type(now) == 'number' then
        out[key] = before + (now - before) * t
      end
    end
  end
  return out
end
local function captureView(g, scene)
  if g.state ~= 'playing' or g.map then
    g.view.presentationPrevious = nil
    return
  end
  local old = {
    knights = scene.knights,
    viewer = values(Context.viewer(g), viewerKeys),
    game = values(g, gameKeys),
    elapsed = g.elapsed,
    view = values(g.view, viewKeys),
    enemies = scene.enemies,
    bullets = scene.bullets,
    charges = scene.charges,
    hazards = scene.hazards,
  }
  g.view.presentationPrevious = old
end
-- World positions are captured once; the motion history belongs to each
-- watched view. Unwatched actors still have a position sample, never a view.
function P.capture(g)
  current()
  if g.state ~= 'playing' or g.map then
    g.view.presentationPrevious = nil
    for _, view in pairs(Context.watched(g)) do
      view.presentationPrevious = nil
    end
    for _, observer in ipairs(Context.observers(g)) do
      observer.state.presentationPrevious = nil
    end
    return
  end
  local scene = { knights = {}, enemies = {}, bullets = {}, charges = {}, hazards = {} }
  for _, knight in ipairs(Pools.of(g, 'knights')) do
    scene.knights[knight] = values(knight, playerKeys)
  end
  -- Bare fixtures can provide a context actor without registering a pool.
  local actor = Context.actor(g)
  if actor and not scene.knights[actor] then
    scene.knights[actor] = values(actor, playerKeys)
  end
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    local v = memberValues(e, memberKeys.enemies)
    v.ai = e.ai
    v.attackKind = e.attackKind
    v.alive = e.hp > 0
    v.flinchOwner = e.flinchOwner
    v.flinchOriginX, v.flinchOriginZ = e.flinchOriginX, e.flinchOriginZ
    scene.enemies[e] = v
  end
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    scene.bullets[b] = memberValues(b, memberKeys.projectiles)
  end
  for _, c in ipairs(Pools.of(g, 'charges')) do
    scene.charges[c] = memberValues(c, memberKeys.charges)
  end
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    scene.hazards[h] = memberValues(h, memberKeys.hazards)
  end
  captureView(g, scene)
  if g._contextRoot then
    return
  end
  for id in pairs(Context.watched(g)) do
    local knight = Pools.get(g, id)
    if knight and knight ~= actor then
      captureView(Context.of(g, knight), scene)
    end
  end
  for _, observer in ipairs(Context.observers(g)) do
    local knight = Pools.get(g, observer.actor)
    if knight then
      captureView(Context.of(g, knight, observer.viewer), scene)
    end
  end
end
function P.sample(g, t)
  current()
  local prev = g.view.presentationPrevious
  if not prev or g.state ~= 'playing' or g.map then
    return g
  end
  t = math.max(0, math.min(1, t))
  local out = blend(g, prev.game, gameKeys, t)
  -- The simulation clock as the image shows it, between two steps: the clock
  -- of a creature's pose (enemies/animation.lua). The simulation reads
  -- g.elapsed itself, so its hit volumes keep the pose of the step.
  out.poseTime = prev.elapsed + (g.elapsed - prev.elapsed) * t
  out._contextRoot = g._contextRoot or g
  out.view = blend(g.view, prev.view, viewKeys, t)
  for _, key in ipairs(viewClocks) do
    if type(g.view[key]) == 'number' then
      out.view[key] = math.max(0, g.view[key] - (1 - t) * Rate.step)
    end
  end
  local samples = {}
  out.knights = {}
  for i, knight in ipairs(Pools.of(g, 'knights')) do
    local sample = blend(knight, prev.knights[knight], playerKeys, t)
    samples[knight], out.knights[i] = sample, sample
  end
  local actor, viewer = Context.actor(g), Context.viewer(g)
  out.contextActor = samples[actor] or blend(actor, prev.knights[actor], playerKeys, t)
  -- Retain the controlled alias for legacy consumers without confusing it
  -- with the HUD actor of an alternate context.
  for original, sample in pairs(samples) do
    if Context.isControlled(g, original) then
      Roles.control(out, sample)
    end
  end
  if Context.isControlled(g, actor) then
    Roles.control(out, out.contextActor)
  end
  out.viewer = viewer == actor and out.contextActor
    or samples[viewer]
    or blend(viewer, prev.viewer, viewerKeys, t)
  -- The sample is read as a session by the renderer; with no ECS world of its
  -- own, Pools.of(sample, ...) returns these interpolated arrays, not the
  -- live pools it would otherwise inherit from g.
  out.ecs = false
  out.enemies = {}
  out.bullets = {}
  for i, e in ipairs(Pools.of(g, 'enemies')) do
    local old = prev.enemies[e]
    local view = blendMember(e, old, memberKeys.enemies, t, memberRests.enemies)
    -- A new state (or a death) starts its clocks anew: they show the current value.
    if old and (old.ai ~= e.ai or old.alive ~= (e.hp > 0) or old.attackKind ~= e.attackKind) then
      for _, key in ipairs(stateClocks) do
        view[key] = e[key]
      end
    end
    if old and not Flinch.sameBasis(old, e) then
      -- The contact already rebased the spring into its new source basis.
      -- Blending its old scalar with the new one would reverse the apparent
      -- direction for an observer on the other side. Like a phase change,
      -- this contact uses the current value; later steps blend normally.
      view.flinchLean = e.flinchLean or 0
    end
    out.enemies[i] = view
  end
  for i, b in ipairs(Pools.of(g, 'projectiles')) do
    out.bullets[i] =
      blendMember(b, prev.bullets[b], memberKeys.projectiles, t, memberRests.projectiles)
  end
  out.charges = {}
  for i, c in ipairs(Pools.of(g, 'charges')) do
    out.charges[i] =
      blendMember(c, (prev.charges or {})[c], memberKeys.charges, t, memberRests.charges)
  end
  -- Marked ground drawn between two steps (PLAN Z4). The sound of a field follows the
  -- live pool (audio/field_voices.lua), never these.
  out.hazards = {}
  for i, h in ipairs(Pools.of(g, 'hazards')) do
    out.hazards[i] =
      blendMember(h, (prev.hazards or {})[h], memberKeys.hazards, t, memberRests.hazards)
  end
  return out
end
return P

local Context = require('src.session.context')
local Roles = require('src.core.roles')
-- Interpolate the fixed simulation without delaying raw mouse input or mutating gameplay.
local Pools = require('src.session.world')
local P = {}
local playerKeys = { 'x', 'z', 'jump', 'crouch' }
local viewerKeys = { 'x', 'y', 'z', 'jump', 'crouch' }
local gameKeys = { 'step' }
-- Presentation state (g.view) blended the same way.
local viewKeys = {
  'land',
  'recoil',
  'swayX',
  'swayY',
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
}
local enemyKeys = { 'x', 'z', 'walk', 'phase', 'deathTime', 'fallY', 'flinchLean' }
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
local function captureView(g, scene)
  if g.state ~= 'playing' or g.map then
    g.view.presentationPrevious = nil
    return
  end
  local old = {
    knights = scene.knights,
    viewer = values(Context.viewer(g), viewerKeys),
    game = values(g, gameKeys),
    view = values(g.view, viewKeys),
    enemies = scene.enemies,
    bullets = scene.bullets,
  }
  g.view.presentationPrevious = old
end
-- World positions are captured once; the motion history belongs to each
-- watched view. Unwatched actors still have a position sample, never a view.
function P.capture(g)
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
  local scene = { knights = {}, enemies = {}, bullets = {} }
  for _, knight in ipairs(Pools.of(g, 'knights')) do
    scene.knights[knight] = values(knight, playerKeys)
  end
  -- Bare fixtures can provide a context actor without registering a pool.
  local actor = Context.actor(g)
  if actor and not scene.knights[actor] then
    scene.knights[actor] = values(actor, playerKeys)
  end
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    local v = values(e, enemyKeys)
    v.ai = e.ai
    v.alive = e.hp > 0
    scene.enemies[e] = v
  end
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    scene.bullets[b] = values(b, { 'x', 'y', 'z' })
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
  local prev = g.view.presentationPrevious
  if not prev or g.state ~= 'playing' or g.map then
    return g
  end
  t = math.max(0, math.min(1, t))
  local out = blend(g, prev.game, gameKeys, t)
  out._contextRoot = g._contextRoot or g
  out.view = blend(g.view, prev.view, viewKeys, t)
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
    local view = blend(e, old, enemyKeys, t)
    if old and (old.ai ~= e.ai or old.alive ~= (e.hp > 0)) then
      view.phase = e.phase
      view.deathTime = e.deathTime
    end
    out.enemies[i] = view
  end
  for i, b in ipairs(Pools.of(g, 'projectiles')) do
    out.bullets[i] = blend(b, prev.bullets[b], { 'x', 'y', 'z' }, t)
  end
  return out
end
return P

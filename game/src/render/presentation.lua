-- Interpolate the fixed simulation without delaying raw mouse input or mutating gameplay.
local P = {}
local playerKeys = { 'x', 'z', 'jump', 'crouch' }
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
function P.capture(g)
  if g.state ~= 'playing' or g.map then
    g.view.presentationPrevious = nil
    return
  end
  local old = {
    player = values(g.player, playerKeys),
    game = values(g, gameKeys),
    view = values(g.view, viewKeys),
    enemies = {},
    bullets = {},
  }
  for _, e in ipairs(g.enemies) do
    local v = values(e, enemyKeys)
    v.ai = e.ai
    v.alive = e.hp > 0
    old.enemies[e] = v
  end
  for _, b in ipairs(g.bullets) do
    old.bullets[b] = values(b, { 'x', 'y', 'z' })
  end
  g.view.presentationPrevious = old
end
function P.sample(g, t)
  local prev = g.view.presentationPrevious
  if not prev or g.state ~= 'playing' or g.map then
    return g
  end
  t = math.max(0, math.min(1, t))
  local out = blend(g, prev.game, gameKeys, t)
  out.view = blend(g.view, prev.view, viewKeys, t)
  out.player = blend(g.player, prev.player, playerKeys, t)
  out.enemies = {}
  out.bullets = {}
  for i, e in ipairs(g.enemies) do
    local old = prev.enemies[e]
    local view = blend(e, old, enemyKeys, t)
    if old and (old.ai ~= e.ai or old.alive ~= (e.hp > 0)) then
      view.phase = e.phase
      view.deathTime = e.deathTime
    end
    out.enemies[i] = view
  end
  for i, b in ipairs(g.bullets) do
    out.bullets[i] = blend(b, prev.bullets[b], { 'x', 'y', 'z' }, t)
  end
  return out
end
return P

-- How each kind of marked ground looks (content/hazards.lua):
--   ground(r, g, h, effects)  drawn on the floor
--   air(r, g, h, effects)     its spell above it, if any (render/effects.lua)
local Definitions = require('src.content.hazards')
local Ballistics = require('src.combat.ballistics')
local Ground = require('src.physics.ground')
local HazardArt = require('src.render.hazard_art')
local Rites = require('src.content.art.rites')
local Registry = require('src.core.registry')
local Context = require('src.session.context')
local Kinds = Registry:new('hazard art', function(entry, id)
  Definitions:get(id)
  assert(type(entry.ground) == 'function', 'hazard art ' .. id .. ' needs ground')
end)
Kinds:register('pool', { ground = HazardArt.draw })
Kinds:register('lightning', {
  ground = function(r, g, h)
    HazardArt.circle(r, g, h, 'circle', h.radius, 1)
  end,
  air = function(r, g, h, effects)
    local preparing = h.delay > 0
    local progress = preparing and (1 - h.delay / math.max(0.01, h.maxDelay or 1))
      or (1 - (h.life or 0) / 0.22)
    if not preparing then
      -- A short narrow strike leaves the enemy silhouette visible. The ground ring
      -- is still the exact authoritative damage radius, not this ornamental width.
      effects.spell(r, g, 3, progress, h.x, Ground.of(g.world, h) + 1.5, h.z, 2.8, 0.9, false)
    end
  end,
})
Kinds:register('wave', {
  ground = function(r, g, h)
    if h.delay <= 0 then
      HazardArt.circle(r, g, h, 'wave', h.radius, 1)
    end
  end,
})
-- The circle is the only quiet place: while the sky gathers, the floor around it
-- is marked; when it strikes, bolts fall all around.
local spot = {}
local function around(h, i)
  local a = i * 2.399 + h.angle * 0.3
  local d = h.radius + Rites.storm.near + (i % 3) * Rites.storm.spread
  spot.x, spot.z = h.x + math.sin(a) * d, h.z + math.cos(a) * d
  return spot
end
Kinds:register('tempest', {
  ground = function(r, g, h)
    HazardArt.circle(r, g, h, 'circle', h.radius, 1)
  end,
  air = function(r, g, h, effects)
    local S = Rites.storm
    for i = 1, S.bolts do
      local at = around(h, i)
      local y = Ground.of(g.world, at)
      if h.delay > 0 then
        local progress = 1 - h.delay / math.max(0.01, h.maxDelay)
        effects.spell(r, g, 2, progress, at.x, y + 0.045, at.z, S.mark, 1, true)
      elseif h.pulse > h.interval * 0.72 then
        local progress = 1 - (h.pulse - h.interval * 0.72) / (h.interval * 0.28)
        effects.spell(r, g, 3, progress, at.x, y + S.height, at.z, S.size, 0.9, false)
      end
    end
  end,
})
Kinds:register('sweepline', {
  ground = function(r, g, h)
    local R = Rites.ray
    local ground = Ground.of(g.world, h)
    local dx, dz = math.sin(h.angle), math.cos(h.angle)
    local reach = Ballistics.world(g.world, h.x, ground + 1, h.z, dx, 0, dz, h.radius)
    local progress = h.delay > 0 and (1 - h.delay / math.max(0.001, h.maxDelay)) or 1
    local alpha = h.delay > 0 and R.warned or 1
    for step = 1, math.floor(reach / R.step) do
      local d = step * R.step
      spot.x, spot.z = h.x + dx * d, h.z + dz * d
      -- Alternate the irregular pigment and vary its extent, keeping the whole
      -- route present from the first warning. Extra fissures open within it.
      local yaw = h.angle + (step % 2) * math.pi
      local cell = progress >= 0.72 and 'damned' or 'fissure'
      HazardArt.band(r, g, spot, cell, R.size, yaw, alpha)
    end
  end,
})
-- The brief flame and settling fragments are a view record of a released ray.
-- No ground warning remains once the authoritative hazard has gone.
function Kinds.rayAfterimage(r, g, h, age)
  local R = Rites.ray
  if age < 0 or age >= R.embers then
    return
  end
  local ground = Ground.of(g.world, h)
  local dx, dz = math.sin(h.angle), math.cos(h.angle)
  local reach = Ballistics.world(g.world, h.x, ground + 1, h.z, dx, 0, dz, h.radius)
  for step = 1, math.floor(reach / R.step) do
    local d = step * R.step
    local x, z = h.x + dx * d, h.z + dz * d
    local y = Ground.height(g.world, x, z)
    if age < R.flare then
      HazardArt.upright(
        r,
        x,
        y + 0.03,
        z,
        'damned',
        0.9,
        math.atan2(Context.viewer(g).x - x, Context.viewer(g).z - z),
        1
      )
    end
    if age >= R.flare then
      HazardArt.upright(r, x, y + 0.04, z, 'fragments', 0.36, h.angle, 0.85)
    end
  end
end
function Kinds.of(h)
  return Kinds:get(h.kind or Definitions.default)
end
return Kinds

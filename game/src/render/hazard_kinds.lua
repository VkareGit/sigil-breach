-- How each kind of marked ground looks (content/hazards.lua):
--   ground(r, g, h, effects)  drawn on the floor
--   air(r, g, h, effects)     its spell above it, if any (render/effects.lua)
local HazardDefs = require('src.content.hazards')
local Ballistics = require('src.combat.ballistics')
local Ground = require('src.physics.ground')
local HazardArt = require('src.render.hazard_art')
local Rites = require('src.content.art.rites')
local Registry = require('src.core.registry')
local Painters = require('src.render.painters')
local Kinds = Registry:new('hazard art', function(entry, id)
  HazardDefs:get(id)
  assert(type(entry.ground) == 'function', 'hazard art ' .. id .. ' needs ground')
end)
-- A styled pool or lightning is its painter's (render/painters.lua); a plain
-- one is drawn here.
Kinds:register('pool', {
  ground = function(r, g, h)
    if not Painters.hazard('ground', r, g, h) then
      HazardArt.draw(r, g, h)
    end
  end,
  air = function(r, g, h)
    Painters.hazard('air', r, g, h)
  end,
})
Kinds:register('lightning', {
  ground = function(r, g, h)
    if Painters.hazard('ground', r, g, h) then
      return
    end
    HazardArt.circle(r, g, h, 'circle', h.radius, 1)
  end,
  air = function(r, g, h, effects)
    if Painters.hazard('air', r, g, h) then
      return
    end
    local preparing = h.delay > 0
    local A = Rites.air
    local progress = preparing and (1 - h.delay / math.max(1e-2, h.maxDelay or 1))
      or (1 - (h.life or 0) / A.strike)
    if not preparing then
      -- A short narrow strike leaves the enemy silhouette visible. The ground ring
      -- is still the exact authoritative damage radius, not this ornamental width.
      local y = Ground.of(g.world, h) + A.lift
      effects.spell(r, g, 3, progress, h.x, y, h.z, A.size, A.alpha, false)
    end
  end,
})
local function waveResidue(r, g, h, radius, alpha)
  local style = Rites.waves[h.art]
  if style and radius > 0 then
    HazardArt.ribbon(
      r,
      g,
      h,
      style.residue,
      'ring',
      radius,
      math.min(radius, style.trail),
      0,
      0,
      alpha
    )
  end
end
Kinds:register('wave', {
  ground = function(r, g, h)
    if Rites.waves[h.art] then
      if h.delay > 0 then
        HazardArt.circle(r, g, h, Rites.waves[h.art].warning or 'circle', h.radius, 1)
      else
        waveResidue(r, g, h, h.radius - h.width, 0.5)
      end
    elseif h.delay <= 0 then
      HazardArt.circle(r, g, h, 'wave', h.radius, 1)
    end
  end,
  air = function(r, g, h)
    local style = Rites.waves[h.art]
    if style and h.delay <= 0 then
      local frame = style.frames[1 + math.floor(-h.delay * style.rate) % #style.frames]
      if style.upright and h.radius > h.width then
        -- Both edges carry upright flames; the spent floor behind them is harmless.
        HazardArt.ribbon(
          r,
          g,
          h,
          frame,
          'ring',
          h.radius - h.width,
          h.width,
          h.volume.top,
          0,
          1,
          style
        )
      end
      HazardArt.ribbon(
        r,
        g,
        h,
        frame,
        'ring',
        h.radius,
        math.min(h.width, h.radius),
        h.volume.top,
        0,
        1,
        style.tileLength and style or nil
      )
    end
  end,
})
-- The circle is the only quiet place: while the sky gathers, the floor around it
-- is marked; when it strikes, bolts fall all around.
local spot = {}
local function around(h, i)
  local a = i * 2.399 + h.angle * Rites.storm.turn -- constant: the golden angle
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
        local progress = 1 - h.delay / math.max(1e-2, h.maxDelay)
        effects.spell(r, g, 2, progress, at.x, y + S.markLift, at.z, S.mark, 1, true)
      elseif h.pulse > h.interval * S.strike then
        local progress = 1 - (h.pulse - h.interval * S.strike) / (h.interval * S.strikeSpan)
        effects.spell(r, g, 3, progress, at.x, y + S.height, at.z, S.size, S.alpha, false)
      end
    end
  end,
})
-- Both the warning and its opened floor tear use the released width and wall reach.
local function floorTear(r, g, h, cell, alpha)
  local R = Rites.ray
  local ground = Ground.of(g.world, h)
  local dx, dz = math.sin(h.angle), math.cos(h.angle)
  local reach = Ballistics.world(g.world, h.x, ground + 1, h.z, dx, 0, dz, h.radius)
  spot.x, spot.z, spot.level = h.x + dx * reach / 2, h.z + dz * reach / 2, h.level
  HazardArt.strip(
    r,
    g,
    spot,
    cell,
    reach / R.pigmentLength,
    (h.width and h.width > 0 and h.width or R.defaultWidth) / R.pigmentWidth,
    h.angle,
    alpha
  )
end
Kinds:register('sweepline', {
  ground = function(r, g, h)
    local R = Rites.ray
    local progress = h.delay > 0 and (1 - h.delay / math.max(1e-3, h.maxDelay)) or 1
    floorTear(
      r,
      g,
      h,
      h.delay > 0 and HazardArt.sequence(R.warning, progress) or R.active,
      h.delay > 0 and R.warned or 1
    )
  end,
  air = function(r, g, h)
    local style = Rites.fissures[h.art]
    if not style or h.delay > style.opening then
      return
    end
    local height = h.volume.top
    local ground = Ground.of(g.world, h)
    local reach = Ballistics.world(
      g.world,
      h.x,
      ground + 1,
      h.z,
      math.sin(h.angle),
      0,
      math.cos(h.angle),
      h.radius
    )
    local preparing = h.delay > 0
    local growth = preparing and (1 - h.delay / style.opening) or 1
    HazardArt.ribbon(
      r,
      g,
      h,
      style.frames[preparing and 1 or 2],
      'line',
      reach,
      h.width or Rites.ray.defaultWidth,
      height * growth,
      h.angle,
      1
    )
  end,
})
-- Settled pigment follows the last real line, never a floating duplicate of its origin.
function Kinds.rayAfterimage(r, g, h, age)
  local R = Rites.ray
  if age < 0 or age >= R.embers then
    return
  end
  if h.kind == 'wave' then
    waveResidue(r, g, h, h.radius, 0.5 * (1 - age / R.embers))
  else
    floorTear(r, g, h, R.settling, Rites.rayAfterimage * (1 - age / R.embers))
    local style = Rites.fissures[h.art]
    if style then
      local ground = Ground.of(g.world, h)
      local reach = Ballistics.world(
        g.world,
        h.x,
        ground + 1,
        h.z,
        math.sin(h.angle),
        0,
        math.cos(h.angle),
        h.radius
      )
      HazardArt.ribbon(
        r,
        g,
        h,
        style.frames[3],
        'line',
        reach,
        h.width,
        h.height * (1 - age / R.embers),
        h.angle,
        1 - age / R.embers
      )
    end
  end
end
function Kinds.of(h)
  return Kinds:get(h.kind or HazardDefs.default)
end
return Kinds

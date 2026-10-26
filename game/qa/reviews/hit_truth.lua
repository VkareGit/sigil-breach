-- Plan v7 H0: what the hit volumes do against what is drawn, in live play.
-- Every demon is driven through its real states by the simulation (arrival,
-- walking, wind-up, strike, recovery, falter, stagger, knockdown, leap,
-- sidestep, death) on the proving ground, and every step the painting the
-- renderer would draw (qa/hit_truth.lua) is compared with the volumes a shot
-- meets (enemies/geometry.lua, combat/ballistics.lua). Reports:
--   hit-fit.txt / .csv   rays from the knight's eye through a grid over the
--                        drawn quad: a painted point whose ray meets no volume
--                        ('missed'), an air point whose ray meets one
--                        ('ghost'; 'head ghost' when it is the head), the
--                        one-texel edge band apart. Shares of rays in that
--                        grid, not shares of the player's shots.
--   hit-shots.txt        the same at 2/8/16/30 m from a standing, crouching
--                        and jumping eye; the order of contacts (two demons
--                        in a line, a pillar in front, a corpse in front);
--                        every pellet of a real volley.
--   hit-dying.txt        the dying and the dead: what is drawn and what a shot
--                        does (passes through).
--   hit-engine.txt       the CPU truth checked against the GPU; the pose seen
--                        versus the pose a shot is resolved against; volumes
--                        before/after the renderer's metadata check; the
--                        cost of a volume ray and of a painted-mask lookup.
local Truth = require('qa.hit_truth')
local Field = require('src.run.test_field')
local Rules = require('src.combat.rules')
local Attacks = require('src.enemies.actions')
local B = require('src.combat.ballistics')
local Geometry = require('src.enemies.geometry')
local Surface = require('src.enemies.surface')
local AbilityArt = require('src.render.ability_art')
local Catalog = require('src.render.fresco_enemies')
local Tuning = require('src.content.tuning')
local Grid = require('src.physics.grid')
local S = {}
local STEP = 1 / 120
local FIT = { cols = 32, rows = 48 }
local MATRIX = { cols = 20, rows = 30 }
local DISTANCES = { 2, 8, 16, 30 }
local sqrt, atan2, max, min, abs = math.sqrt, math.atan2, math.max, math.min, math.abs
local function percent(a, b)
  return b > 0 and 100 * a / b or 0
end
local function unit(dx, dy, dz)
  local l = sqrt(dx * dx + dy * dy + dz * dz)
  return dx / l, dy / l, dz / l
end
-- The knight's eyes: standing, at the bottom of a slide, at a jump's apex.
local EYES = {
  { name = 'stand', jump = 0, crouch = 0 },
  { name = 'crouch', jump = 0, crouch = Tuning.motion.crouch },
  { name = 'jump', jump = Tuning.jumpSpeed ^ 2 / (2 * Tuning.gravity), crouch = 0 },
}
local function aim(g, x, y, z)
  local ox, oy, oz = B.origin(g)
  local dx, dz = x - ox, z - oz
  g.player.yaw = atan2(dx, dz)
  g.player.pitch = atan2(y - oy, sqrt(dx * dx + dz * dz))
end
-- Aim at the painted torso (its region's painted centre).
-- Its source UV depends only on immutable mask/regions and life state, not on
-- world placement. Avoid scanning 320x320 pixels every simulation tick; keep
-- every live-state/ray sample and transform the exact cached UV each time.
local torsoCentres
local function aimAt(g, e)
  local p = Surface.prepare(g, e)
  local byMask = torsoCentres[p.parts]
  if not byMask then
    byMask = {}
    torsoCentres[p.parts] = byMask
  end
  local byLife = byMask[p.mask]
  if not byLife then
    byLife = {}
    byMask[p.mask] = byLife
  end
  local key = p.alive and 'live' or 'dead'
  local uv = byLife[key]
  if not uv then
    local _, _, _, u, v = Surface.locateZone(p, 'torso')
    assert(u and v, 'painted torso required by hit review')
    uv = { u, v }
    byLife[key] = uv
  end
  aim(g, Surface.point(p, uv[1], uv[2]))
end
-- What the body is doing, for the report (the painted pose follows it).
local function label(g, e, place)
  if e.hp <= 0 then
    return 'dying'
  end
  if (e.spawnAge or 1) < 0.6 then
    return 'emerge'
  end
  if place.painted then
    local key, frame = AbilityArt.select(g, e)
    return 'art-' .. tostring(key) .. '-' .. tostring(frame)
  end
  if e.knockedDown and (e.stun or 0) > 0 then
    local total = max(e.knockTime or e.stun, e.stun)
    local t = total - e.stun
    return t < 0.12 and 'down-fall' or (e.stun > 0.15 and 'down-low' or 'down-rise')
  end
  if e.ai == 'hurt' and ((e.phase or 0) < 0.20 or (e.stun or 0) > 0) then
    return e.heavyStagger and 'stagger' or 'falter'
  end
  if (e.stun or 0) > 0 and Rules.has(e, 'exposed') then
    return 'exposed'
  end
  if e.leapY then
    return 'leap-air'
  end
  if e.ai == 'windup' or e.ai == 'strike' or e.ai == 'recover' then
    return e.ai
  end
  if (e.evadeTime or 0) > 0 then
    return 'evade'
  end
  return (e.walkSpeed or 0) > 0.1 and 'walk' or 'idle'
end
local function tally()
  return {
    samples = 0,
    painted = 0,
    missed = 0,
    hits = 0,
    ghost = 0,
    headHits = 0,
    headGhost = 0,
    edge = 0,
    decorative = 0,
  }
end
local function add(into, from)
  for k, v in pairs(from) do
    into[k] = (into[k] or 0) + v
  end
end
-- Rays from the knight's eye through a cols x rows grid over the drawn quad.
local function sweep(truth, g, e, place, grid)
  local t = tally()
  t.samples = 1
  local ox, oy, oz = B.origin(g)
  local surface = Surface.prepare(g, e)
  for c = 0, grid.cols - 1 do
    for r = 0, grid.rows - 1 do
      local u, v = (c + 0.5) / grid.cols, (r + 0.5) / grid.rows
      local wx, wy, wz = Truth.world(place, u, v)
      local dx, dy, dz = unit(wx - ox, wy - oy, wz - oz)
      local class, edge = truth:classify(place, u, v)
      local d, part = B.body(g, e, ox, oy, oz, dx, dy, dz, 1000, nil, surface)
      local sourceU = surface.mirror > 0.5 and 1 - u or u
      local region = Surface.part(surface.parts, sourceU, 1 - v)
      local decorative = region and region.hittable == false
      if edge then
        t.edge = t.edge + 1
      elseif class ~= 'air' and decorative then
        t.decorative = t.decorative + 1
      elseif class ~= 'air' then
        t.painted = t.painted + 1
        t.missed = t.missed + (d and 0 or 1)
      end
      if d and not edge then
        t.hits = t.hits + 1
        t.headHits = t.headHits + (part == 'head' and 1 or 0)
        if class == 'air' then
          t.ghost = t.ghost + 1
          t.headGhost = t.headGhost + (part == 'head' and 1 or 0)
        end
      end
    end
  end
  return t
end
local function line(name, t)
  return string.format(
    '%-26s samples %4d  missed %5.1f %% of %6d hittable painted  ghost %5.1f %% of %6d hits  head ghost %5.1f %% of %5d  edge rays %d decorative %d',
    name,
    t.samples,
    percent(t.missed, t.painted),
    t.painted,
    percent(t.ghost, t.hits),
    t.hits,
    percent(t.headGhost, t.headHits),
    t.headHits,
    t.edge,
    t.decorative
  )
end
-- A proving ground with one demon of kind in front of the knight (the
-- catalogue's own placement), in play.
local function field(G, kind, tier)
  local g = Field.new(G)
  g.testing = true
  if tier then
    g.testField.tier = tier
  end
  local e = Field.spawn(g, kind, 1)[1]
  Field.close(g)
  return g, e
end
-- The episodes of one kind: each a fresh field and a real transition.
local function episodes(kind)
  local list = {
    {
      name = 'arrive-and-fight',
      seconds = 6,
      tier = 5,
      begin = function(_, e)
        e.spawnAge = 0
      end,
    },
    {
      name = 'falter',
      seconds = 1,
      begin = function(_, e)
        Rules.guard(e, Rules.body(e).poise * 1.05)
      end,
    },
  }
  local body = Rules.body({ kind = kind })
  if not body.boss then
    list[#list + 1] = {
      name = 'stagger',
      seconds = 1.2,
      begin = function(_, e)
        Rules.guard(e, Rules.body(e).poise * 3)
      end,
    }
    list[#list + 1] = {
      name = 'knockdown',
      seconds = 1.0,
      begin = function(_, e)
        Rules.knockDown(e)
      end,
    }
  end
  for _, atk in ipairs(Rules.archetype({ kind = kind }).attacks) do
    if atk.kind == 'leap' then
      list[#list + 1] = {
        name = 'leap',
        seconds = 2.2,
        begin = function(g, e)
          Attacks.begin(g, e, sqrt((e.x - g.player.x) ^ 2 + (e.z - g.player.z) ^ 2), atk)
        end,
      }
    end
  end
  list[#list + 1] = {
    name = 'death',
    seconds = 1.6,
    lethal = true,
    begin = function(g)
      g:switchWeapon(2)
    end,
  }
  return list
end
-- The fit of one kind over its episodes; the dying samples go to dying.
local function fitKind(G, truth, kind, out)
  local byLabel, byFrame, labels, frames = {}, {}, {}, {}
  local place, prev = {}, {}
  local seen = { max = 0, sum = 0, n = 0, frameChanges = 0 }
  local dying = { samples = 0, painted = 0, through = 0 }
  local matrix = {}
  for _, episode in ipairs(episodes(kind)) do
    local g, e = field(G, kind, episode.tier)
    episode.begin(g, e)
    local lastKey
    local ticks = math.floor(episode.seconds / STEP + 0.5)
    local tick, guard = 0, 0
    -- A lethal episode shoots until the body falls (at most a minute).
    while tick < ticks and guard < 60 / STEP do
      guard = guard + 1
      truth:place(g, e, prev)
      local _, hoverBefore = Geometry.pose(g, e)
      local xBefore, zBefore = e.x, e.z
      if episode.lethal and e.hp > 0 then
        aimAt(g, e)
        g:update(STEP, { shoot = true })
      else
        if e.hp > 0 then
          aimAt(g, e)
        end
        g:update(STEP, {})
        tick = tick + 1
      end
      truth:place(g, e, place)
      if e.hp > 0 then
        -- Seen versus resolved: the drawn pose blends the last two steps; a
        -- shot is resolved against the newer one. The body's root (feet and
        -- hover) moves continuously; the painted frame changes in steps.
        local _, hover = Geometry.pose(g, e)
        local d = sqrt((e.x - xBefore) ^ 2 + (e.z - zBefore) ^ 2 + (hover - hoverBefore) ^ 2)
        if d > seen.max then
          seen.where = string.format(
            '%s, %s, %s: across %.3f m, up %.3f m',
            kind,
            episode.name,
            label(g, e, place),
            sqrt((e.x - xBefore) ^ 2 + (e.z - zBefore) ^ 2),
            hover - hoverBefore
          )
        end
        seen.max, seen.sum, seen.n = max(seen.max, d), seen.sum + d, seen.n + 1
        seen.frameChanges = seen.frameChanges + (prev.key ~= place.key and 1 or 0)
        seen.steps = (seen.steps or 0) + 1
        -- Point blank: the knight's eye inside one of the demon's volumes;
        -- every ray then starts in contact (combat/ballistics.lua:
        -- cylinderShape), whichever way it points.
        local ox, oy, oz = B.origin(g)
        local away = atan2(g.player.x - e.x, g.player.z - e.z)
        local inside = B.body(g, e, ox, oy, oz, math.sin(away), 0, math.cos(away), 1000) == 0
        seen.inside = (seen.inside or 0) + (inside and 1 or 0)
        local name = inside and 'point-blank (eye inside)' or label(g, e, place)
        local t = sweep(truth, g, e, place, FIT)
        local frameKey = (place.painted and 'art ' or 'frame ') .. place.key:match('[^/]+$')
        if not byLabel[name] then
          byLabel[name] = tally()
          labels[#labels + 1] = name
        end
        if not byFrame[frameKey] then
          byFrame[frameKey] = tally()
          byFrame[frameKey].frame = place.frame
          byFrame[frameKey].painted_ = place.painted
          frames[#frames + 1] = frameKey
        end
        add(byLabel[name], t)
        local f = byFrame[frameKey]
        for k, v in pairs(t) do
          f[k] = f[k] + v
        end
        out.csv[#out.csv + 1] = string.format(
          '%s,%s,%s,%d,%s,%d,%d,%d,%d,%d,%d,%d',
          kind,
          episode.name,
          name,
          place.frame,
          place.painted and 'art' or 'atlas',
          t.painted,
          t.missed,
          t.hits,
          t.ghost,
          t.headHits,
          t.headGhost,
          t.edge
        )
        -- The distance and eye matrix, once per drawn frame.
        if place.key ~= lastKey then
          lastKey = place.key
          local p = g.player
          local px, pz, pj, pc = p.x, p.z, p.jump, p.crouch
          local nx, nz = px - e.x, pz - e.z
          local l = sqrt(nx * nx + nz * nz)
          for _, distance in ipairs(DISTANCES) do
            for _, eye in ipairs(EYES) do
              p.x, p.z = e.x + nx / l * distance, e.z + nz / l * distance
              p.jump, p.crouch = eye.jump, eye.crouch
              local key = distance .. ' m ' .. eye.name
              local cell = matrix[key] or tally()
              matrix[key] = cell
              add(cell, sweep(truth, g, e, truth:place(g, e, {}), MATRIX))
            end
          end
          p.x, p.z, p.jump, p.crouch = px, pz, pj, pc
        end
      else
        -- The dead: what is drawn, and whether a shot at it stops there.
        dying.samples = dying.samples + 1
        local ox, oy, oz = B.origin(g)
        local bodies = B.prepare(g)
        for c = 0, MATRIX.cols - 1 do
          for r = 0, MATRIX.rows - 1 do
            local u, v = (c + 0.5) / MATRIX.cols, (r + 0.5) / MATRIX.rows
            local class, edge = truth:classify(place, u, v)
            if class ~= 'air' and not edge then
              dying.painted = dying.painted + 1
              local wx, wy, wz = Truth.world(place, u, v)
              local dx, dy, dz = unit(wx - ox, wy - oy, wz - oz)
              local target = B.traceVector(g, dx, dy, dz, 1000, bodies)
              dying.through = dying.through + (target ~= e and 1 or 0)
            end
          end
        end
      end
    end
  end
  return {
    byLabel = byLabel,
    labels = labels,
    byFrame = byFrame,
    frames = frames,
    seen = seen,
    dying = dying,
    matrix = matrix,
  }
end
-- Order of contacts: rays over two drawn demons (or a pillar and a demon);
-- the truth is the nearest hittable painted plane or the nearer wall. Loose
-- cloth/effects explicitly authored as passthrough are not body occluders.
local function orderCheck(truth, g, bodies, label_)
  local ox, oy, oz = B.origin(g)
  local prepared = B.prepare(g)
  local places, surfaces = {}, {}
  for i, e in ipairs(bodies) do
    places[i] = truth:place(g, e, {})
    surfaces[i] = Surface.prepare(g, e)
  end
  local result =
    { rays = 0, agree = 0, wrongBody = 0, ghost = 0, missed = 0, edge = 0, decorative = 0 }
  for _, p in ipairs(places) do
    for c = 0, MATRIX.cols - 1 do
      for r = 0, MATRIX.rows - 1 do
        local wx, wy, wz = Truth.world(p, (c + 0.5) / MATRIX.cols, (r + 0.5) / MATRIX.rows)
        local dx, dy, dz = unit(wx - ox, wy - oy, wz - oz)
        local wall = B.world(g.world, ox, oy, oz, dx, dy, dz, 1000)
        local best, owner, uncertain, decorative = wall, nil, false, false
        for i, q in ipairs(places) do
          local d, u, v = Truth.cross(q, ox, oy, oz, dx, dy, dz)
          if d and d < best then
            local class, edge = truth:classify(q, u, v)
            if edge then
              uncertain = true
            end
            local surface = surfaces[i]
            local sourceU = surface.mirror > 0.5 and 1 - u or u
            local part = Surface.part(surface.parts, sourceU, 1 - v)
            if class ~= 'air' and part and part.hittable == false then
              decorative = true
            elseif class ~= 'air' then
              best, owner = d, bodies[i]
            end
          end
        end
        local target = B.traceVector(g, dx, dy, dz, 1000, prepared)
        result.rays = result.rays + 1
        if decorative and not uncertain then
          result.decorative = result.decorative + 1
        end
        if uncertain then
          result.edge = result.edge + 1
        elseif target == owner then
          result.agree = result.agree + 1
        elseif owner and target then
          result.wrongBody = result.wrongBody + 1
        elseif target then
          result.ghost = result.ghost + 1
        else
          result.missed = result.missed + 1
        end
      end
    end
  end
  return string.format(
    '%-40s rays %5d  agree %5.1f %%  other body %4d  ghost %4d  missed %4d  edge %4d  decorative rays %4d',
    label_,
    result.rays,
    percent(result.agree, result.rays - result.edge),
    result.wrongBody,
    result.ghost,
    result.missed,
    result.edge,
    result.decorative
  ),
    result
end
-- Also exercised by the focused observation regression, without a full atlas sweep.
S.orderCheck = orderCheck
local function frozenField(G)
  local g = Field.new(G)
  g.testing = true
  g.testField.frozen = true
  Field.close(g)
  return g
end
local function put(g, kind, x, z)
  local e = g:spawn(kind, x, z)
  e.spawnAge, e.awake = 1, false
  e.facing = atan2(g.player.x - x, g.player.z - z)
  return e
end
local function orderScenarios(G, truth, lines)
  -- Two thralls in a line, the second half a body to the side.
  local g = frozenField(G)
  local p = g.player
  local fx, fz = math.sin(p.yaw), math.cos(p.yaw)
  local rx, rz = math.cos(p.yaw), -math.sin(p.yaw)
  local front = put(g, 'imp', p.x + fx * 6, p.z + fz * 6)
  local back = put(g, 'imp', p.x + fx * 9 + rx * 0.35, p.z + fz * 9 + rz * 0.35)
  lines[#lines + 1] = orderCheck(truth, g, { front, back }, 'two thralls in a line (6 m, 9 m)')
  -- A Margrave behind an Iron Thrall.
  g = frozenField(G)
  front = put(g, 'armored', p.x + fx * 5, p.z + fz * 5)
  back = put(g, 'boss', p.x + fx * 10 - rx * 0.6, p.z + fz * 10 - rz * 0.6)
  lines[#lines + 1] = orderCheck(truth, g, { front, back }, 'Iron Thrall before the Margrave')
  -- A thrall half behind the nearest pillar in view.
  g = frozenField(G)
  local best
  for z = 1, Grid.depth(g.world) do
    for x = 1, Grid.width(g.world) do
      if g.world.map[z] and g.world.map[z][x] == 2 then
        local d = sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
        if d > 4 and d < 12 and (not best or d < best.d) then
          best = { x = x, z = z, d = d }
        end
      end
    end
  end
  if best then
    local dx, dz = (best.x - p.x) / best.d, (best.z - p.z) / best.d
    p.yaw = atan2(dx, dz)
    local e = put(g, 'imp', best.x + dx * 1.6 + dz * 0.45, best.z + dz * 1.6 - dx * 0.45)
    lines[#lines + 1] = orderCheck(truth, g, { e }, 'thrall half behind a pillar')
  end
  -- A killed thrall falling in front of a living one.
  g = frozenField(G)
  p = g.player
  front = put(g, 'imp', p.x + fx * 5, p.z + fz * 5)
  back = put(g, 'imp', p.x + fx * 8, p.z + fz * 8)
  g:damageEnemy(front, front.hp + 1, 'weapon')
  for _ = 1, 30 do
    g:update(STEP, {})
  end
  local text, result = orderCheck(truth, g, { front, back }, 'corpse falling before a thrall')
  lines[#lines + 1] = text
    .. string.format(' (a ray at the drawn corpse goes on: %d)', result.wrongBody + result.ghost)
  -- Every pellet of a real volley at the front thrall of a line.
  g = frozenField(G)
  p = g.player
  front = put(g, 'imp', p.x + fx * 7, p.z + fz * 7)
  back = put(g, 'imp', p.x + fx * 10 + rx * 0.5, p.z + fz * 10 + rz * 0.5)
  g:switchWeapon(1)
  g.cooldown = 0
  aimAt(g, front)
  local places = { truth:place(g, front, {}), truth:place(g, back, {}) }
  local ox, oy, oz = B.origin(g)
  local report
  g.bus:on('sim', 'VolleyResolved', function(event)
    report = event.report
  end)
  g:shoot()
  local volley = { pellets = 0, agree = 0, edge = 0 }
  local rays = report and report.rays
  if rays then
    for _, ray in ipairs(rays) do
      local wall = B.world(g.world, ox, oy, oz, ray.dx, ray.dy, ray.dz, 1000)
      local bestD, owner, uncertain = wall, nil, false
      for i, q in ipairs(places) do
        local d, u, v = Truth.cross(q, ox, oy, oz, ray.dx, ray.dy, ray.dz)
        if d and d < bestD then
          local class, edge = truth:classify(q, u, v)
          uncertain = uncertain or edge
          if class ~= 'air' then
            bestD, owner = d, ({ front, back })[i]
          end
        end
      end
      volley.pellets = volley.pellets + 1
      if uncertain then
        volley.edge = volley.edge + 1
      elseif (owner and owner.id) == ray.target then
        volley.agree = volley.agree + 1
      end
    end
  end
  lines[#lines + 1] = string.format(
    'Exorcist volley at 7 m (a second thrall behind): %d pellets, %d agree with the drawn body, %d in the edge band',
    volley.pellets,
    volley.agree,
    volley.edge
  )
end
-- The pose and painted surface with and without the renderer's metadata check.
local function headlessCheck(renderer)
  local worst, where = 0, ''
  for _, kind in ipairs(Catalog.kinds) do
    local layout = Geometry.layouts[kind]
    for frame = 1, Catalog.frameCount(kind) do
      local g = { player = { x = 0, z = 8 }, time = 0, testField = {} }
      local e = { kind = kind, id = 7, hp = 100, x = 0, z = 0, previewFrame = frame }
      -- The pose and the painted head a shot meets, before and after the
      -- renderer's metadata check (it validates; it never installs data).
      local function sample()
        local p = Surface.prepare(g, e)
        local x, y = Surface.locate(p, 'head')
        return { p.baseY, p.width, p.height, x or 0, y or 0 }
      end
      local with = sample()
      Geometry.register(kind, layout.frames, layout.feet)
      for i, value in ipairs(sample()) do
        local d = abs(value - with[i])
        if d > worst then
          worst, where = d, kind .. ' frame ' .. frame
        end
      end
      -- Validation cannot change immutable metadata.
    end
  end
  return worst, where
end
-- One sheet per landmark frame, in its live pose: what a shot from the
-- knight's place meets at every texel of the drawn painting (pigment tinted
-- by the zone it meets: head gold, torso red, legs orange; pigment a shot
-- passes, blue; air a shot meets, magenta) and the landmarks (white, a red
-- centre when the landmark is wrong today).
local ZONE = { head = { 1, 0.85, 0.2 }, torso = { 0.95, 0.25, 0.15 }, lower = { 1, 0.55, 0.1 } }
local function sheets(G, truth, output)
  local Landmarks = require('qa.hit_landmarks')
  local results = {}
  for _, r in ipairs(Landmarks.run(G, truth.renderer)) do
    results[r.entry] = results[r.entry] or {}
    table.insert(results[r.entry], r)
  end
  local n, count = Truth.grid, 0
  for _, entry in ipairs(Landmarks.data) do
    local g, e = Landmarks.reach(G, entry.kind, entry.frame, entry.via)
    if g then
      local q = truth:place(g, e, {})
      local ox, oy, oz = B.origin(g)
      local surface = Surface.prepare(g, e)
      local data = love.image.newImageData(n, n)
      for j = 0, n - 1 do
        for i = 0, n - 1 do
          local u = (i + 0.5) / n
          if q.mirror > 0.5 then
            u = 1 - u
          end
          local v = 1 - (j + 0.5) / n
          local class = truth:texel(q, i, j)
          local wx, wy, wz = Truth.world(q, u, v)
          local dx, dy, dz = unit(wx - ox, wy - oy, wz - oz)
          local d, part = B.body(g, e, ox, oy, oz, dx, dy, dz, 1000, nil, surface)
          local r, gg, b = 0.10, 0.12, 0.10
          if class ~= 'air' then
            local c = d and (ZONE[part] or { 0.7, 0.7, 0.7 }) or { 0.2, 0.35, 0.95 }
            r, gg, b = c[1], c[2], c[3]
          elseif d then
            r, gg, b = 0.9, 0.1, 0.8
          end
          data:setPixel(i, j, r, gg, b, 1)
        end
      end
      for _, res in ipairs(results[entry] or {}) do
        local u, v = Truth.fromPixel(q, res.point[1], res.point[2])
        local ci, cj = Truth.cell(q, u, v)
        for k = -4, 4 do
          for _, at in ipairs({ { ci + k, cj }, { ci, cj + k } }) do
            if at[1] >= 0 and at[2] >= 0 and at[1] < n and at[2] < n then
              local wrong = res.ok == false and math.abs(k) <= 1
              data:setPixel(at[1], at[2], 1, wrong and 0 or 1, wrong and 0 or 1, 1)
            end
          end
        end
      end
      local f = assert(
        io.open(output .. '/hit-landmarks-' .. entry.kind .. '-' .. entry.frame .. '.png', 'wb')
      )
      f:write(data:encode('png'):getString())
      f:close()
      data:release()
      count = count + 1
    end
  end
  return count
end
-- Every painted frame's source rectangle (pixels of its image), for the
-- landmark tools (tools/art/landmarks): the cuts come from the game's own
-- atlas data, never copied by hand.
local function frameRects(truth, output)
  local r = truth.renderer
  local rows = { 'kind,frame,image,x,y,w,h' }
  local function add_(kind, frame, image, rect)
    local path = truth.paths[image]
    local data = love.image.newImageData(path)
    local w, h = data:getDimensions()
    data:release()
    rows[#rows + 1] = string.format(
      '%s,%d,%s,%d,%d,%d,%d',
      kind,
      frame,
      path,
      math.floor(rect[1] * w + 0.5),
      math.floor(rect[2] * h + 0.5),
      math.floor(rect[3] * w + 0.5),
      math.floor(rect[4] * h + 0.5)
    )
  end
  for _, kind in ipairs(Catalog.kinds) do
    for frame = 1, Catalog.frameCount(kind) do
      local image = (r.frameImages[kind] and r.frameImages[kind][frame]) or r.animations[kind]
      add_(kind, frame, image, r.frames[kind][frame].rect)
    end
  end
  -- Rows in sequence order, the same on every run (not pairs() order).
  local keys = {}
  for key in pairs(r.abilityArt) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local sheet = r.abilityArt[key]
    for frame, region in ipairs(sheet.frames) do
      add_('art-' .. key, frame, sheet.image, region.rect)
    end
  end
  local f = assert(io.open(output .. '/hit-frame-rects.csv', 'w'))
  f:write(table.concat(rows, '\n') .. '\n')
  f:close()
end
-- The proving ground's HITBOXES view in real states, as the player sees it:
-- hit-overlay-<state>.png (render/effects.lua: hitboxes).
local function overlays(G, renderer, output)
  local Attacks = require('src.enemies.actions')
  local function shot(name, kind, setup, until_, limit)
    local g, e = field(G, kind, 5)
    g.testField.hitboxes, g.testField.invincible = true, true
    setup(g, e)
    for _ = 1, limit or 360 do
      if until_(g, e) then
        break
      end
      if e.hp > 0 then
        aimAt(g, e)
      end
      g:update(STEP, {})
    end
    if e.hp > 0 then
      aimAt(g, e)
    end
    g.view.messageTimer = 0
    renderer:draw(g, 1280, 720)
    love.graphics.setCanvas()
    local data = renderer.canvas:newImageData()
    local f = assert(io.open(output .. '/hit-overlay-' .. name .. '.png', 'wb'))
    f:write(data:encode('png'):getString())
    f:close()
    data:release()
    return name
  end
  local list = {}
  local function close(g, e)
    local p = g.player
    e.x, e.z = p.x + math.sin(p.yaw) * 1.6, p.z + math.cos(p.yaw) * 1.6
  end
  list[#list + 1] = shot('walk', 'imp', function() end, function(_, e)
    return (e.walkSpeed or 0) > 0.5
  end)
  list[#list + 1] = shot('claw-active', 'imp', function(g, e)
    close(g, e)
    Attacks.begin(g, e, 1.6, Rules.archetype(e).attacks[1])
  end, function(_, e)
    local spec = e.attackSpec
    return e.ai == 'strike' and spec and e.phase >= require('src.combat.melee').window(spec)
  end)
  list[#list + 1] = shot('leap-flight', 'imp', function(g, e)
    for _, atk in ipairs(Rules.archetype(e).attacks) do
      if atk.kind == 'leap' then
        Attacks.begin(g, e, 6, atk)
      end
    end
  end, function(_, e)
    return e.leaping and (e.leapY or 0) > 0.6
  end)
  list[#list + 1] = shot('evade', 'stolas', function() end, function(_, e)
    return (e.evadeTime or 0) > 0.05
  end, 720)
  list[#list + 1] = shot('knockdown', 'buer', function(_, e)
    Rules.knockDown(e)
  end, function(_, e)
    return (e.stun or 0) < 0.25
  end)
  list[#list + 1] = shot('falling-body', 'imp', function(g, e)
    g:damageEnemy(e, e.hp + 1, 'weapon')
  end, function(_, e)
    return (e.deathTime or 0) > 0.25
  end)
  list[#list + 1] = shot('boss-exposed', 'boss', function(_, e)
    Rules.guard(e, Rules.body(e).poise * 1.05)
  end, function(_, e)
    return true
  end)
  return list
end
function S.run(output, G, renderer)
  torsoCentres = {}
  local truth = Truth.new(renderer)
  local fit = {
    'HIT VOLUMES AGAINST THE DRAWN DEMON, LIVE STATES (plan v7 H0)',
    'Rays from the standing eye through a 32 x 48 grid over the drawn quad, every step of real',
    'episodes. missed: hittable pigment with no contact; ghost: contact in air. Explicit decorative regions counted separately.',
    "Shares of grid rays, not of the player's shots. Edge: one 320-grid texel at the outline.",
    '',
  }
  local shots = {
    'SHOTS: DISTANCE, EYE, ORDER OF CONTACTS, PELLETS (plan v7 H0)',
    '',
    'Per distance and eye (all live frames of all demons, 20 x 30 grid):',
  }
  local dyingLines = {
    'THE DYING AND THE DEAD (plan v7 H0)',
    'A falling painted corpse blocks shots through the authored settling interval, without health damage.',
    'After settling it stops blocking. Painted rays counted on a 20 x 30 grid every step; decorative regions still pass.',
    '',
  }
  local out =
    { csv = { 'kind,episode,state,frame,sheet,painted,missed,hits,ghost,headHits,headGhost,edge' } }
  local matrix, seen = {}, { max = 0, sum = 0, n = 0, frameChanges = 0 }
  local worstFrames = {}
  for _, kind in ipairs(Catalog.kinds) do
    print('Hit review: sampling live episodes for ' .. kind)
    io.stdout:flush()
    local r = fitKind(G, truth, kind, out)
    fit[#fit + 1] = string.upper(kind)
    local total, apart = tally(), tally()
    for _, name in ipairs(r.labels) do
      fit[#fit + 1] = '  ' .. line(name, r.byLabel[name])
      add(total, r.byLabel[name])
      if not name:match('^point%-blank') then
        add(apart, r.byLabel[name])
      end
    end
    fit[#fit + 1] = '  ' .. line('ALL LIVE STATES', total)
    fit[#fit + 1] = '  ' .. line('ALL BUT POINT BLANK', apart)
    table.sort(r.frames, function(a, b)
      local x, y = r.byFrame[a], r.byFrame[b]
      return percent(x.headGhost, x.headHits) > percent(y.headGhost, y.headHits)
    end)
    fit[#fit + 1] = '  worst drawn frames by head ghost:'
    for i = 1, min(4, #r.frames) do
      fit[#fit + 1] = '    ' .. line(r.frames[i], r.byFrame[r.frames[i]])
    end
    fit[#fit + 1] = ''
    worstFrames[kind] = r.frames
    for key, cell in pairs(r.matrix) do
      matrix[key] = matrix[key] or tally()
      add(matrix[key], cell)
    end
    if r.seen.max > seen.max then
      seen.where = r.seen.where
    end
    seen.max = max(seen.max, r.seen.max)
    seen.sum, seen.n = seen.sum + r.seen.sum, seen.n + r.seen.n
    seen.frameChanges = seen.frameChanges + r.seen.frameChanges
    seen.steps = (seen.steps or 0) + (r.seen.steps or 0)
    seen.inside = (seen.inside or 0) + (r.seen.inside or 0)
    seen.byKind = seen.byKind or {}
    seen.byKind[#seen.byKind + 1] =
      string.format('%s %d of %d', kind, r.seen.inside or 0, r.seen.steps or 0)
    dyingLines[#dyingLines + 1] = string.format(
      '%-8s %4d dying/dead steps, %6d painted rays, %6d (%5.1f %%) pass through to what is behind',
      kind,
      r.dying.samples,
      r.dying.painted,
      r.dying.through,
      percent(r.dying.through, r.dying.painted)
    )
  end
  for _, distance in ipairs(DISTANCES) do
    for _, eye in ipairs(EYES) do
      local key = distance .. ' m ' .. eye.name
      shots[#shots + 1] = '  ' .. line(key, matrix[key] or tally())
    end
  end
  shots[#shots + 1] = ''
  shots[#shots + 1] =
    'Order of contacts (truth: nearest hittable painted plane, or the wall first; decorative rays counted separately):'
  orderScenarios(G, truth, shots)
  shots[#shots + 1] = ''
  shots[#shots + 1] =
    'Anatomical landmarks (qa/data/hit_landmarks.lua) in live poses, shot from 3, 8 and 16 m:'
  local Landmarks = require('qa.hit_landmarks')
  local judged, wrong = 0, 0
  for _, r in ipairs(Landmarks.run(G, renderer)) do
    if not r.reached then
      shots[#shots + 1] = '  NOT REACHED ' .. r.entry.kind .. ' frame ' .. r.entry.frame
    else
      local check = ''
      local painted = r.point[3] ~= 'air'
      if r.alpha == nil or (painted and r.alpha < 0.65) or (not painted and r.alpha > 0.05) then
        check = string.format('  [annotation: alpha %.2f]', r.alpha or -1)
      elseif r.edge or (r.drawn ~= 'air') ~= painted then
        check = '  [drawn ' .. tostring(r.drawn) .. (r.edge and ', edge' or '') .. ']'
      end
      shots[#shots + 1] = '  ' .. Landmarks.describe(r) .. check
      if r.ok ~= nil then
        judged = judged + 1
        wrong = wrong + (r.ok and 0 or 1)
      end
    end
  end
  shots[#shots + 1] = string.format('  %d landmarks judged, %d wrong.', judged, wrong)
  shots[#shots + 1] = string.format(
    '  %d sheets hit-landmarks-<demon>-<frame>.png: pigment tinted by the zone a shot meets (head gold, torso red, legs orange), pigment a shot passes blue, air a shot meets magenta; landmarks white (red centre: wrong today).',
    sheets(G, truth, output)
  )
  local gpu = require('qa.reviews.hit_gpu').run(G, renderer, truth, output)
  -- The truth is what the shader draws, or nothing here means anything.
  assert(
    gpu.agree >= 0.995 * (gpu.points - gpu.edge),
    string.format(
      'hit truth disagrees with the sprite shader (%d of %d)',
      gpu.points - gpu.edge - gpu.agree,
      gpu.points - gpu.edge
    )
  )
  local headless, where = headlessCheck(renderer)
  require('qa.reviews.hit_performance').run(G, output)
  local timingCases = require('qa.reviews.hit_timing').run(G, truth, output)
  local engine = {
    'HIT TRUTH AND ENGINE MEASUREMENTS (plan v7 H0)',
    '',
    string.format(
      'Actual trigger versus last presented pose: %d schedules/creatures in hit-timing.csv (30/60/120/144/240 FPS and jitter). Root/frame statistics below are fixed-step observations, not the full display latency.',
      timingCases
    ),
    string.format(
      'CPU truth against the sprite shader: %d pixel-centre rays across all cases, %d agree, %d in the edge band, worst case %d disagreements. Living poses, ability sheets and interpolated samples; detailed coverage in hit-gpu.csv.',
      gpu.points,
      gpu.agree,
      gpu.edge,
      gpu.worst
    ),
    string.format(
      'Seen versus resolved: the drawn pose blends the last two steps (render/presentation.lua); a shot is resolved against the newer one. Per step the body root (feet, hover) moved at most %.3f m (%s; mean %.4f m); the painted frame changed in %d of %d live steps.',
      seen.max,
      seen.where or '-',
      seen.n > 0 and seen.sum / seen.n or 0,
      seen.frameChanges,
      seen.steps or 0
    ),
    string.format(
      'Point blank: shooting away from a touching demon produced a contact at the eye in %d of %d live steps (%s).',
      seen.inside or 0,
      seen.steps or 0,
      table.concat(seen.byKind or {}, ', ')
    ),
    string.format(
      'Pose and painted head before/after renderer compatibility validation: %.3f m difference (%s). Cold-load with graphics disabled is tested separately.',
      headless,
      where
    ),
    'Complete prepared-volley timings and allocations for mixed creature populations: hit-performance.txt/csv. No multiplication of a single mask lookup presented as a whole-engine benchmark.',
  }
  local function write(name, lines)
    local f = assert(io.open(output .. '/' .. name, 'w'))
    f:write(table.concat(lines, '\n') .. '\n')
    f:close()
  end
  write('hit-fit.txt', fit)
  write('hit-fit.csv', out.csv)
  write('hit-shots.txt', shots)
  write('hit-dying.txt', dyingLines)
  write('hit-engine.txt', engine)
  frameRects(truth, output)
  overlays(G, renderer, output)
  truth:release()
  return { fit = fit, shots = shots, engine = engine, gpu = gpu, worstFrames = worstFrames }
end
return S

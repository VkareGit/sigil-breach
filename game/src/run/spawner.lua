-- Wave spawner shared by the expedition and the proving ground's wave trial:
-- portals with a 1.2 s glow, packs that open several portals at once (the
-- later members preferring the player's flanks), queue order and caps.
-- Owns no rewards and no wave completion; callers decide what follows.
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Waves = require('src.content.waves')
local K = Waves.portal
local S = {}
-- Portal colours name what is coming: each creature's appearance.portal
-- (shared with src/render/portals.lua).
S.colors = {}
for id, def in require('src.content.enemies').each() do
  S.colors[id] = def.appearance.portal
end
-- The summoning gates of the default map (a session uses its world's gates).
local Maps = require('src.content.maps.index')
S.portals = Maps:get(Maps.default).gates
local distance = MathX.distance
S.distance = distance
-- flank: a later member of a pack prefers portals outside the player's view.
function S.choosePortal(g, flank)
  local r, p = g.run, g.player
  local flow = W.flow(g.world, p.x, p.z)
  local best, bestScore
  local opening = r.queueIndex == 1 and r.wave <= K.openingWaves
  local P = K.score
  for i, s in ipairs(g.world.gates or S.portals) do
    local path = flow[math.floor(s.z + 0.5) * g.world.size + math.floor(s.x + 0.5)]
    local d = distance(p, s)
    local crowded = false
    for _, e in ipairs(g.enemies) do
      if e.hp > 0 and distance(e, s) < K.crowd then
        crowded = true
      end
    end
    for _, pending in ipairs(r.pending) do
      if distance(pending, s) < K.crowd then
        crowded = true
      end
    end
    local visible = W.visible(g.world, p.x, p.z, s.x, s.z)
    local inFront = ((s.x - p.x) * math.sin(p.yaw) + (s.z - p.z) * math.cos(p.yaw))
        / math.max(0.01, d)
      > K.front
    local firstContact = opening and visible and inFront and d >= K.near and d <= K.far
    if path and not crowded and (firstContact or (d >= K.minDistance and path >= K.minPath)) then
      local score = firstContact and (P.contact - math.abs(d - K.ideal) * P.contactSlope)
        or (
          P.base
          - math.abs(path - K.pathIdeal) * P.pathSlope
          + (i ~= r.lastGate and P.fresh or P.repeated)
          + (visible and 0 or P.hidden)
        )
      if flank and not firstContact then
        score = score + (inFront and P.flankFront or P.flankBehind)
      end
      if not bestScore or score > bestScore then
        best, bestScore = { x = s.x, z = s.z, index = i }, score
      end
    end
  end
  return best
end
-- One tick of the wave in g.run (wave, queueIndex, pending, spawnTimer).
-- Returns the number of living demons and whether the wave is exhausted
-- (queue spawned, nothing pending, nobody alive).
-- The director's reading of the fight: stress = faded damage / reference.
function S.stress(g)
  return (g.intensity or 0) / Waves.director.reference
end
-- Multiplier of the pause between packs (see content/waves.lua director).
function S.pace(g)
  local d = Waves.director
  return d.fast + (d.slow - d.fast) * math.min(1, S.stress(g))
end
-- Extra demons alive at once for a calm, healthy knight.
function S.extraCap(g)
  local d = Waves.director
  local p = g.player
  local healthy = p.hp >= d.healthy * require('src.content.enemies').player.body.hp
  return (S.stress(g) < d.calm and healthy) and d.calmCap or 0
end
-- What a wave gives a demon stepping out of its gate: its reward, and the
-- knight's place to hunt.
function S.welcome(g, e, gate)
  local p = g.player
  e.rewardId = gate.rewardId
  e.awake = true
  e.memory = K.hunt
  e.lastX = p.x
  e.lastZ = p.z
end
-- A gate opened for a demon of kind at (x, z): it glows K.glow s before the
-- demon arrives. Drawn from g.run.pending (render/portals.lua).
function S.gate(kind, x, z)
  return { kind = kind, x = x, z = z, delay = K.glow, maxDelay = K.glow }
end
-- The gates waiting in g.run.pending count down; at zero a gate's demon
-- arrives (spawnAge 0: the portal's arrival art, a short pause) unless the
-- knight stands in it, when it waits K.retry more. arrive(g, e, gate) gives
-- the newcomer what its mode does (S.welcome for a wave) before it is
-- announced. In queue order, so a pack's demons appear as they were opened.
function S.arrivals(g, dt, arrive)
  local r, p = g.run, g.player
  local i = 1
  while i <= #r.pending do
    local s = r.pending[i]
    s.delay = s.delay - dt
    local spawned = false
    if s.delay <= 0 then
      -- Revalidate after the warning: a player can dash into the portal meanwhile.
      if distance(p, s) >= K.clear then
        local e = g:spawn(s.kind, s.x, s.z)
        arrive(g, e, s)
        e.spawnAge = 0
        -- Arrival: smoke, a burst in the portal's colour, a deep pulse.
        Signal(g, 'EnemyArrived', { enemy = e, gate = s })
        if (require('src.content.enemies').of(e) or {}).guardian then
          g.bossSpawned = true
        end
        table.remove(r.pending, i)
        spawned = true
      else
        s.delay = K.retry
      end
    end
    if not spawned then
      i = i + 1
    end
  end
end
-- arrive: what an arriving demon is given (S.welcome unless the mode says).
function S.step(g, dt, arrive)
  local r, p = g.run, g.player
  g.intensity = (g.intensity or 0) * math.exp(-dt / Waves.director.tau)
  r.phaseTime = (r.phaseTime or 0) + dt
  r.spawnTimer = (r.spawnTimer or 0) - dt
  S.arrivals(g, dt, arrive or S.welcome)
  local wave = Waves[r.wave]
  local alive = 0
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      alive = alive + 1
      -- Wave enemies search for the player even if the last sighting timed out.
      e.awake = true
      e.memory = K.hunt
      e.lastX = p.x
      e.lastZ = p.z
    end
  end
  local cap = wave.cap + S.extraCap(g)
  if r.queueIndex <= #wave.queue and alive + #r.pending < cap and r.spawnTimer <= 0 then
    -- A pack opens several portals at once (0.21); each keeps its 1.2 s glow.
    local opened = 0
    for k = 1, wave.pack or 1 do
      if r.queueIndex > #wave.queue or alive + #r.pending >= cap then
        break
      end
      local gate = S.choosePortal(g, k > 1)
      if not gate then
        break
      end
      gate.kind = wave.queue[r.queueIndex]
      gate.rewardId = r.wave .. '_' .. r.queueIndex
      gate.delay = K.glow
      gate.maxDelay = K.glow
      r.pending[#r.pending + 1] = gate
      r.lastGate = gate.index
      r.queueIndex = r.queueIndex + 1
      opened = opened + 1
      Signal(g, 'PortalOpened', { gate = gate })
    end
    if opened > 0 then
      -- The pause between packs grows with the pack it follows.
      r.spawnTimer = ((r.wave == 1 and K.first or K.between) + K.perGate * (opened - 1)) * S.pace(g)
    else
      r.spawnTimer = K.idle
    end
  end
  return alive, r.queueIndex > #wave.queue and alive == 0 and #r.pending == 0
end
return S

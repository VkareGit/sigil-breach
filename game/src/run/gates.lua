-- Summoning gates of the proving ground: a gate glows before its demon steps out.
-- The field hands in its record r (r.pending); nothing here reads a mode's record.
local Archetypes = require('src.content.enemies')
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local Roles = require('src.core.roles')
local Encounter = require('src.session.encounter')
local K = require('src.content.field').gates
local S = {}
-- Portal colours name what is coming: each creature's appearance.portal
-- (shared with src/render/portals.lua).
S.colors = {}
for id, def in require('src.content.enemies').each() do
  S.colors[id] = def.appearance.portal
end
local distance = MathX.distance
S.distance = distance
-- What a gate gives a demon stepping out of it: the knight's place to hunt.
function S.welcome(g, e)
  local p = Roles.controlled(g)
  e.awake = true
  e.memory = K.hunt
  e.lastX = p.x
  e.lastZ = p.z
end
-- A gate opened for a demon of kind at (x, z): it glows K.glow s before the
-- demon arrives. Drawn from the record's pending gates (render/portals.lua).
function S.gate(kind, x, z)
  return { kind = kind, x = x, z = z, delay = K.glow, maxDelay = K.glow }
end
-- The gates waiting in r.pending count down; at zero a gate's demon
-- arrives (spawnAge 0: the portal's arrival art, a short pause) unless the
-- knight stands in it, when it waits K.retry more. arrive(g, e, gate) gives
-- the newcomer what its mode does before it is announced. In queue order, so a
-- pack's demons appear as they were opened.
function S.arrivals(g, r, dt, arrive)
  local p = Roles.controlled(g)
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
        if (Archetypes.of(e) or {}).guardian then
          Encounter.guardianArrived(g)
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
return S

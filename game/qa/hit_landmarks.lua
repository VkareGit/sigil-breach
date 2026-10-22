-- Landmark shots (plan v7 H0): each anatomical landmark of qa/data/
-- hit_landmarks.lua, in its live pose reached by the real transition, shot
-- from 3, 8 and 16 m. Used by the test (tests/cases/hit_landmarks.lua) and the
-- hit review (qa/reviews/hit_truth.lua).
local Truth = require('qa.hit_truth')
local Field = require('src.run.test_field')
local Rules = require('src.combat.rules')
local Attacks = require('src.enemies.actions')
local B = require('src.combat.ballistics')
local Geometry = require('src.enemies.geometry')
local AbilityArt = require('src.render.ability_art')
local L = { data = require('qa.data.hit_landmarks'), distances = { 3, 8, 16 } }
local STEP = 1 / 120
-- Kinds a shot must meet as named; 'body' any zone; 'air' nothing.
L.zones = { head = true, torso = true, lower = true }
-- A proving ground showing kind in frame through the transition via, or nil.
function L.reach(G, kind, frame, via)
  local g = Field.new(G)
  g.testing = true
  local e = Field.spawn(g, kind, 1)[1]
  Field.close(g)
  if via == 'knockdown' then
    Rules.knockDown(e)
  elseif via == 'falter' then
    Rules.guard(e, Rules.body(e).poise * 1.05)
  elseif via == 'attack' then
    local d = math.sqrt((e.x - g.player.x) ^ 2 + (e.z - g.player.z) ^ 2)
    Attacks.begin(g, e, d, Rules.archetype(e).attacks[1])
  end
  for _ = 1, 600 do
    if Geometry.pose(g, e) == frame and not AbilityArt.select(g, e) then
      return g, e
    end
    g:update(STEP, {})
  end
end
-- What a shot at source pixel (x, y) meets from each distance: the part, or
-- false for nothing. Restores the knight.
local function shots(g, e, place, x, y)
  local p = g.player
  local px, pz = p.x, p.z
  local nx, nz = px - e.x, pz - e.z
  local l = math.sqrt(nx * nx + nz * nz)
  local u, v = Truth.fromPixel(place, x, y)
  local wx, wy, wz = Truth.world(place, u, v)
  local out, contacts = {}, {}
  for i, distance in ipairs(L.distances) do
    p.x, p.z = e.x + nx / l * distance, e.z + nz / l * distance
    local ox, oy, oz = B.origin(g)
    local dx, dy, dz = wx - ox, wy - oy, wz - oz
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    local d, part, contact = B.body(g, e, ox, oy, oz, dx / length, dy / length, dz / length, 1000)
    out[i] = d and part or false
    contacts[i] = contact or false
  end
  p.x, p.z = px, pz
  return out, u, v, contacts
end
-- Every landmark: { frame entry, point, reached, drawn (painted / air as
-- the live drawing has it), parts (per distance), ok (nil when not judged) }.
function L.run(G, renderer)
  local truth = Truth.new(renderer)
  local results = {}
  for _, entry in ipairs(L.data) do
    local g, e = L.reach(G, entry.kind, entry.frame, entry.via)
    local place = g and truth:place(g, e, {})
    for _, point in ipairs(entry.points) do
      local x, y, kind = point[1], point[2], point[3]
      local r = { entry = entry, point = point, reached = place ~= nil }
      if place then
        r.image = place.path == entry.image
        r.alpha = truth:pixel(entry.image, x, y)
        local parts, u, v, contacts = shots(g, e, place, x, y)
        r.parts = parts
        r.contacts = contacts
        r.drawn, r.edge = truth:classify(place, u, v)
        local ok = true
        for index, part in ipairs(parts) do
          local contact = contacts[index]
          if L.zones[kind] then
            ok = ok and part == kind
          elseif kind == 'body' then
            ok = ok and part ~= false
          elseif kind == 'air' then
            ok = ok and not contact
          elseif kind == 'horn' then
            ok = ok and contact and contact.material == 'horn' and contact.zone ~= 'head'
          elseif kind == 'effect' then
            ok = ok and not contact
          elseif kind == 'weapon' then
            ok = ok and contact and contact.material == 'metal' and contact.zone == false
          elseif kind == 'wing' or kind == 'mane' then
            ok = ok and (not contact or contact.zone ~= 'head')
          else
            ok = nil
          end
        end
        r.ok = ok
      end
      results[#results + 1] = r
    end
  end
  truth:release()
  return results
end
-- One line per landmark.
function L.describe(r)
  local parts = {}
  for i, part in ipairs(r.parts or {}) do
    parts[i] = L.distances[i] .. ' m ' .. (part or 'nothing')
  end
  return string.format(
    '%-8s frame %2d %-7s %-28s expects %-6s meets: %s%s',
    r.entry.kind,
    r.entry.frame,
    r.point[3],
    r.point[4],
    r.point[3],
    table.concat(parts, ', '),
    r.ok == nil and ' (rule undecided)' or (r.ok and '' or '  <- WRONG')
  )
end
return L

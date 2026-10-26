-- The role rotation of a wave queue: these creatures in this order, round
-- after round, while any of the composition remain. A creature the rotation
-- does not name (a new demon) follows in id order: every one still arrives.
local rotation = { 'imp', 'stolas', 'imp', 'buer', 'armored' }
-- pack: how many demons arrive together (from different portals, the later
-- ones preferring the player's flanks and back), Doom Eternal encounter style.
-- tip: a text key (content/text.lua).
local function wave(cap, tip, composition, pack)
  local queue = {}
  -- Interleave roles; specialists arrive throughout a wave rather than in one clump.
  local remaining = {}
  for k, v in pairs(composition) do
    remaining[k] = v
  end
  local order, named = {}, {}
  for i, k in ipairs(rotation) do
    order[i], named[k] = k, true
  end
  local extra = {}
  for k in pairs(composition) do
    if not named[k] then
      extra[#extra + 1] = k
    end
  end
  table.sort(extra)
  for _, k in ipairs(extra) do
    order[#order + 1] = k
  end
  while true do
    local added = false
    for _, kind in ipairs(order) do
      if (remaining[kind] or 0) > 0 then
        queue[#queue + 1] = kind
        remaining[kind] = remaining[kind] - 1
        added = true
      end
    end
    if not added then
      break
    end
  end
  return { cap = cap, tip = tip, queue = queue, pack = pack or 1 }
end
local list = {
  -- 0.21: one more demon alive at once in every wave (caps 5/6/7/8).
  wave(5, 'wave_tip_1', { imp = 6, stolas = 1 }, 2),
  wave(6, 'wave_tip_2', { imp = 5, stolas = 2, buer = 1 }, 2),
  wave(7, 'wave_tip_3', { imp = 6, stolas = 2, buer = 1, armored = 1 }, 3),
  wave(8, 'wave_tip_4', { imp = 8, stolas = 3, buer = 1, armored = 1 }, 3),
  {
    cap = 1,
    tip = 'wave_tip_guardian',
    queue = {
      'boss',
    },
  },
}
-- The builder and its rotation are exposed for tests and future encounter data.
list.build = wave
list.rotation = rotation
-- Pacing director (0.24, Left 4 Dead style). Intensity I is the damage the
-- knight took, fading with time constant tau seconds; stress = I / reference.
-- The pause between packs is multiplied by fast + (slow - fast) * min(1,
-- stress): a knight who is not being hurt meets the next pack sooner, a
-- pressed one gets a breath. A calm (stress < calm) and healthy (health
-- share >= healthy) knight also faces calmCap more demons alive at once.
-- Portal warnings never shorten.
list.director =
  { tau = 8, reference = 30, fast = 0.6, slow = 1.6, calm = 0.25, healthy = 0.7, calmCap = 1 }
-- Portals (run/spawner.lua). A gate glows glow s before its demon steps out,
-- re-checked every retry s while the knight stands within clear m. A gate
-- within crowd m of a living body or a pending gate is crowded. First contact
-- (the first pack of waves up to openingWaves): a visible gate in front of the
-- knight (cosine above front) between near and far m, best at ideal m.
-- Otherwise a gate at least minDistance m and minPath steps away, best at
-- pathIdeal steps. score: the weights of those preferences. Pauses between
-- packs: first (wave 1) or between s, plus perGate s for each extra gate of
-- the pack, or idle s when no gate was free. A wave demon hunts the knight
-- (remembers its position) for hunt s.
list.portal = {
  glow = 1.2,
  retry = 0.35,
  clear = 2.5,
  crowd = 1.5,
  openingWaves = 4,
  front = 0.25,
  near = 4.2,
  far = 10,
  ideal = 6,
  minDistance = 6,
  minPath = 8,
  pathIdeal = 14,
  score = {
    contact = 40,
    contactSlope = 2,
    base = 12,
    pathSlope = 0.8,
    fresh = 4,
    repeated = -3,
    hidden = 2,
    flankFront = -3,
    flankBehind = 4,
  },
  first = 1.6,
  between = 1.2,
  perGate = 0.7,
  idle = 0.3,
  hunt = 60,
}
return list

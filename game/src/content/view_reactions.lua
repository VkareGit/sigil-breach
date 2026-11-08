-- VIEW REACTIONS: how the hands, the head and the frame answer an event (PLAN E5).
-- An event brings its strength (a physical quantity named by the profile:
-- guard severity, contact kick, landing speed, released impulse), its
-- direction in the viewer's frame (side: +1 right, ahead: +1 in front) and its
-- distance. A profile names, per channel, the answer to that event:
--   amount = min(cap, base + gain * min(strength, upTo)), or with saturate
--   amount = gain * (1 - exp(-strength / saturate));
--   weight = flat + side*s + ahead*a + across*|s| + along*|a| + front*max(0, a),
--   or 1 for a channel with no direction terms.
-- A profile with reach fades with distance: in full within near m, to far of
-- itself at reach m, nothing beyond. feedback/impulses.lua applies it.
local R = {}
-- Every channel an event may move. A spring velocity adds; a peak keeps the
-- stronger answer. limits bound the summed velocity of all events at once.
-- motion = true: the reduced-motion setting removes the channel's answer.
R.channels = {
  weaponImpactVX = { motion = true, limits = { -150, 150 } },
  weaponImpactVY = { motion = true, limits = { -120, 120 } },
  weaponImpactVRoll = { motion = true, limits = { -0.36, 0.36 } },
  rollPunchV = { motion = true },
  viewPunchV = { motion = true },
  weaponDipV = { motion = true },
  recoilV = {},
  shake = { peak = true },
  killPunch = { peak = true },
}
R.profiles = {
  -- The knight is struck; strength: guard severity (impact / poise). The
  -- hands are knocked away from the source, the head twists away, a blow
  -- from the front snaps the head back and from behind throws it forward.
  blow = {
    weaponImpactVX = { base = 25, gain = 85, side = -1 },
    weaponImpactVY = { base = 18, gain = 60, flat = 0.45, front = 0.55 },
    weaponImpactVRoll = { base = 0.05, gain = 0.22, side = -1 },
    rollPunchV = { base = 0.06, gain = 0.30, side = -1 },
    viewPunchV = { base = 0.10, gain = 0.45, ahead = 1 },
    shake = { base = 0.05, gain = 0.08, upTo = 1 },
  },
  -- The hands meet a wall; strength: the contact kick (feedback/movement_impact.lua).
  wall = {
    weaponImpactVX = { gain = 0.85, side = 1 },
    weaponImpactVY = { gain = 1, along = 0.58, across = 0.12 },
    weaponImpactVRoll = { gain = 0.0022, side = 1 },
  },
  -- The feet leave the floor; strength: the released impulse.
  takeoff = { weaponDipV = { gain = 26, saturate = 5 } },
  -- The feet meet the floor; strength: the contact kick for the hands, the
  -- landing speed for the head.
  landingHands = { weaponDipV = { gain = 1 } },
  landingHead = { viewPunchV = { gain = 0.045, cap = 0.55, flat = -1 } },
  -- What a hit on a demon makes of the frame (feedback/weight.lua: confirm).
  falter = { killPunch = { base = 0.12 } },
  knocked = { killPunch = { base = 0.10 } },
  tripped = { killPunch = { base = 0.08 } },
  heavyStagger = { killPunch = { base = 0.06 } },
  decisive = { killPunch = { base = 0.08 }, viewPunchV = { base = 0.12 } },
  -- A hit of a shot; strength: its weight (dealt health over a heavy blow).
  shotHit = { shake = { base = 0.03, gain = 0.05 } },
  shotKill = { killPunch = { base = 0.14 } },
  -- Any blow taken, before its own weight (feedback/listeners.lua).
  hurt = { shake = { base = 0.1 } },
  breakKill = { killPunch = { base = 0.14 } },
  -- The world (feedback/world_feedback.lua, feedback/scenery_feedback.lua).
  tremor = { reach = 5, shake = { base = 0.07 } },
  knightSlam = { shake = { base = 0.12 } },
  bodySlam = { killPunch = { base = 0.06 } },
  stagger = { recoilV = { base = 14 }, shake = { base = 0.16 } },
  seized = { shake = { base = 0.16 } },
  -- A blast shakes the view in full within near m, fading to far of it at
  -- reach m and not at all beyond (0.43, audit D03: it shook as hard from
  -- across a hall).
  blast = { reach = 16, near = 3, far = 0.2, shake = { base = 0.09 } },
  collapse = { shake = { base = 0.55 } },
}
return R

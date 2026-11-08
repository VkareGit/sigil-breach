-- HAND MOTION: how the hands carry a weapon (feedback/weapon_motion.lua).
-- Presentation only. Distances are pixels at the 450 px scene height, angles
-- radians, rates 1/s; a spring is { stiffness, damping }. The weapon's own
-- weight (content/weapons.lua: weight.aim, weight.carry) scales these.
return {
  -- A reload braces the hands: the brace rises over rise s, leaves over fall s
  -- and takes share of the free motion away.
  brace = { rise = 0.10, fall = 0.12, share = 0.52 },
  -- A planted foot: an impulse in the hands (lift + load * liftLoad, by the
  -- gait's load) and a small alternating roll, on their own springs.
  step = {
    spring = { 520, 30 },
    rollSpring = { 620, 38 },
    lift = 20,
    liftLoad = 12,
    roll = 0.13,
    limitY = 1.8,
    limitVY = 55,
    limitRoll = 0.008,
    limitVRoll = 0.22,
  },
  -- A turn of the view: the gun trails the turn by gain px per radian (over
  -- the weapon's aim factor), with a turn of at most turn rad per step.
  aim = {
    turn = 0.25,
    tilt = 0.20,
    yawGain = 480,
    pitchGain = 390,
    speedX = 100,
    speedY = 80,
    spring = { 196, 28 },
    reachX = 7,
    reachY = 5,
  },
  -- Walking load: the share of running speed the hands carry (overrun above
  -- a full stride), eased at rate.
  carry = { overrun = 1.12, rate = 12 },
  -- Acceleration of the body leaves the hands behind (px per m/s^2).
  lag = { side = 0.075, sideLimit = 3.6, ahead = 0.045, aheadLimit = 2.5, spring = { 110, 17 } },
  -- Sideways travel leans the weapon (rad per m/s).
  lean = { side = 0.018, limit = 0.022, rate = 10 },
  -- The landing dip and the hands in the air (px per m/s of vertical speed);
  -- landing: the share of the landing's contact kick the hands take.
  dip = { landing = 1, spring = { 196, 20 } },
  air = { rise = 0.30, limit = 2.2, spring = { 120, 22 } },
  -- Knocks (content/view_reactions.lua) settle on these springs.
  impact = { spring = { 220, 23 }, rollSpring = { 210, 24 } },
  -- The gun drops out of the aim (px) while the body dashes, slides or is staggered.
  lower = { dash = 4, slide = 5, staggered = 9, rate = 15 },
  -- The resting pose: breathing returns quietAfter s after a shot over
  -- quietRise s and recedes by quietLower per px the gun is lowered; small
  -- corrections of the grip (gripRate rad/s) rest out of step with the breath;
  -- gait sway and roll per unit of load; the final reach.
  pose = {
    quietAfter = 0.16,
    quietRise = 0.35,
    quietGrip = 0.82,
    quietLower = 0,
    breathRate = 1.48,
    breathX = 0.30,
    breathY = 0.72,
    gripRate = 0,
    gripX = 0,
    gripY = 0,
    gripRoll = 0,
    gaitX = 4.8,
    gaitY = 1.55,
    gaitRoll = 0.0065,
    aimRoll = 0.0012,
    crouchRoll = 0.045,
    reachX = 13,
    low = -8,
    high = 14,
    reachRoll = 0.04,
  },
}

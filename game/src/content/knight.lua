-- The player is a body under the same rules. The consumable shield pool is
-- the player's only special component (it absorbs a share of each hit).
-- A character (content/defs/character.lua); the Body schema completes it.
return {
  id = 'knight',
  body = {
    hp = 100,
    -- The ward: a consumable pool the hero starts with.
    armor = 40,
    -- An armoured knight weighs more than a thrall: same law, less shove.
    mass = 1.5,
    poise = 70,
    -- Same guard rule as the demons, faster data: a hero must recover.
    regenDelay = 0.5,
    regenRate = 0.6,
    -- The hero's own stagger must be felt: longer tiers (after the knight's
    -- stability sqrt(1.5): light 0.22-0.32 s, heavy 0.30-0.40 s). A blow
    -- always moves the knight (brace 1): the shove is the player's feedback.
    stagger = {
      light = { base = 0.27, gain = 0.12 },
      heavy = { from = 1.0, base = 0.37, gain = 0.08, max = 0.49 },
    },
    brace = 1,
    woundAt = 0.30,
    radius = 0.22,
    -- Standing height of the hit volume (melee and projectiles use the same).
    height = 1.80,
    -- The volume starts this far above the floor (a blow at the ankles misses).
    feet = 0.08,
    -- The eye: where the view and every shot start, standing (m).
    eye = 1.38,
    shieldShare = 0.55,
    -- Invulnerability after a blow (used by the session).
    iframes = 0.32,
    -- A dodge in every mode (E1): its invulnerability, and what it costs where effort
    -- is paid (session/capabilities.lua: attrition); stamina is all that limits it
    -- (0.42: no charges). A shot out of one gives up what is left of its safety.
    rollIframes = 0.32,
    rollStamina = 26,
    -- Share of his walking speed going sideways and backwards.
    sideStep = 0.85,
    backStep = 0.6,
    -- Friction against a shove: feet on stone, and in the air.
    drag = 9,
    airDrag = 3.5,
    -- Perfect dodge: a blow landing during the dodge itself (not the later
    -- i-frames). Once per dodge: refund its stamina, freeze the demons for a
    -- beat, and a melee attacker within reach takes its own blow on its guard.
    perfectDodge = { refund = 1, freeze = 0.25, guardReturn = 1.0, reach = 3.5 },
    -- A major wound (woundAt) slows the knight for woundFor s.
    woundFor = 1.2,
    -- Driven into stone, the knight takes this share of a demon's slam harm
    -- (his armour and stance; the guard damage is the full one).
    slamShare = 0.5,
  },
  -- Three dodges from whole stamina, then one each 0.9 s or so: a quick pause before it comes
  -- back, so a fast fight keeps moving and a fourth dodge in a row is the one that fails.
  resources = { stamina = { max = 100, start = 100, regen = 48, pause = 0.4 } },
  -- Speeds m/s, accelerations m/s^2, times s (player/feel.lua).
  movement = {
    moveSpeed = 5.25,
    groundAccel = 68,
    groundBrake = 82,
    airAccel = 22,
    airSpeed = 6.1,
    airMomentumCap = 7.2,
    jumpSpeed = 5.5,
    slideSpeed = 8.7,
    slideTime = 0.52,
    slideCooldown = 0.85,
    dashSpeed = 16.0,
    dashTime = 0.155,
  },
}

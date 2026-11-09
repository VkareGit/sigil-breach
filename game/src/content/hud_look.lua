-- The measures of the status bar and its pieces (ui/*.lua). Pixels of the
-- 1280 by 720 frame, times in seconds. Moved here unchanged: the HUD's look
-- is the owner's.
return {
  -- The knight's portrait in the painted arch: its place, image, frames by
  -- bearing (hurt above, a shot within), the slow glance (rate, cycle of
  -- seven, the two glancing steps) and the helmet's room above its dome.
  portrait = {
    bounds = { x = 570, y = 602, w = 140, h = 105 },
    path = 'assets/art/nosiciel-iron-v16.png',
    hurt = 0.25,
    shot = 0.16,
    glance = 0.65,
    right = 3,
    left = 5,
    inset = { x = 0.045, y = 0.08, size = 0.91 },
  },
  -- The portrait's place on the bar.
  portraitAt = { 565, 584, size = 150 },
  font = 18,
  -- Fonts a fitted caption steps down through, and the last.
  fitted = { 22, 18, 16, 14, 12, 11 },
  smallest = 11,
  line = 2,
  -- The guard strip under a health bar: its ground, height, the exposed
  -- pulse (base, swing, rate, colour), the lock's grey and the guard's gold.
  guard = {
    ground = { 0.10, 0.07, 0.05, 0.9 },
    height = 4,
    frame = 6,
    pulse = { base = 0.65, swing = 0.35, rate = 9 },
    exposed = { 0.98, 0.86, 0.52 },
    lock = { 0.52, 0.50, 0.46, 0.85 },
    fill = { 0.98, 0.60, 0.14, 1 },
  },
  -- A combat notice at the left: widest, padding, height and the zone.
  notice = {
    widest = 450,
    pad = 28,
    x = 18,
    h = 44,
    corner = 10,
    inset = 10,
    text = { x = 30, y = 11, h = 22, pad = 24 },
    zone = { x = 28, h = 24, pad = 20 },
  },
  noticeY = 486,
  noticeFont = 16,
  -- The status bar: its light field, and each niche (zone; its centre; the
  -- caption's and the number's rows; sizes).
  bar = { 0, 584, 1280, 136 },
  caption = { y = 630, font = 14 },
  ammo = {
    zone = { 133, 628, 105, 68 },
    cx = 185,
    width = 100,
    number = { 646, 98, 29 },
    below = 678,
  },
  health = {
    zone = { 271, 628, 119, 68 },
    cx = 330,
    number = { 648, 112, 29 },
    meter = { 275, 686, 110, marks = 12 },
  },
  arsenal = {
    zone = { 421, 628, 115, 68 },
    cx = 478,
    -- A chain: its seal (size, gap to its count) and count.
    chainSeal = 18,
    chainGap = 4,
    chainTop = 629,
    chainCount = 631,
    -- The weapons' rows (first, step), the one in hand and the other, and
    -- a chain's small seal on its weapon's row.
    row = { y = 648, step = 16 },
    held = 14,
    quiet = 12,
    rowSeal = { x = 424, size = 12, cx = 486, width = 96 },
    width = 114,
    meter = { 425, 686, 106, marks = 12 },
    engraving = { y = 681, font = 12 },
  },
  ward = {
    zone = { 752, 628, 118, 68 },
    cx = 810,
    number = { 648, 114, 29 },
    meter = { 753, 686, 114, marks = 12 },
  },
  abilities = {
    zone = { 908, 628, 113, 68 },
    x = 912,
    key = { y = 630, font = 12 },
    uses = { y = 649, font = 14 },
    meter = { 912, 667, 104 },
    -- More than one item: a row each (roomy when two at most: font, step),
    -- the count at the right edge, a painted mark and the key beside it.
    roomy = { font = 18, step = 21 },
    tight = { font = 11, step = 15 },
    right = 1015,
    mark = { size = 18, after = 934 },
    labelRight = 1011,
    labelFont = 14,
    small = 12,
  },
  souls = {
    zone = { 1055, 628, 100, 76 },
    cx = 1105,
    width = 98,
    number = 648,
    height = 25,
    heightEcho = 22,
    echo = { y = 672, font = 11, number = 688, height = 13 },
    below = 680,
  },
  -- Effort while it is spent: the zone, the meter and the mark a dodge needs.
  stamina = {
    zone = { 496, 570, 288, 14 },
    x = 500,
    y = 574,
    w = 280,
    marks = 20,
    mark = { y = 572, w = 2, h = 10 },
  },
  -- What a blow took and can be fought back, on the health meter.
  rally = { x = 275, w = 110, y = 686, h = 4, right = 385 },
  -- The keys and the clock while the game stands.
  utility = {
    plate = { 1028, 12, 236, 68, corner = 10 },
    zone = { 1038, 22, 216, 48 },
    text = { 1041, 23, 210, 20, font = 14, small = 12 },
    clock = { right = 1250, y = 48, font = 18 },
  },
  -- The marks at the reticle (shapes; their sizes are Layout's).
  hit = {
    weight = 2,
    outline = 0.85,
    armor = { x = 19, y = -10, size = 18 },
    -- The precision diamond: its four strokes { x1, y1, x2, y2 }.
    diamond = { { -4, -21, 0, -25 }, { 0, -25, 4, -21 }, { 4, -21, 0, -17 }, { 0, -17, -4, -21 } },
    ink = 4,
  },
  -- A broken guard's brackets: from, how far they snap over their time,
  -- their arms.
  breaking = { from = 17, time = 0.22, snap = 7, arm = 6 },
  -- The reticle: its gap and growth with recoil, its arms, the centre dot.
  reticle = { gap = 5, recoil = 5, most = 6, arm = 6, dot = 3, core = 1, refusalFont = 16 },
  cone = { half = 3, ink = 3 },
  -- Incoming blows' marks round the aim.
  incoming = 92,
  -- The guardian's banner, and the panel of a body in the sights.
  boss = {
    plate = { 426, 16, 428, 64, corner = 10 },
    zone = { 438, 27, 402, 43 },
    skull = { 440, 28, size = 36 },
    name = { 483, 28, 345, 26, font = 20 },
    meter = { 483, 62, 345, marks = 32 },
    guard = 71,
  },
  sights = 25,
  target = {
    plate = { 503, 20, 274, 60, corner = 10 },
    zone = { 514, 30, 252, 40 },
    width = { shield = 150, plain = 165 },
    name = { shield = 552, plain = 520, y = 31, h = 22, font = 16, smallest = 12 },
    shield = { 515, 32, size = 22 },
    meter = { 520, 62, 240, marks = 24 },
    trail = { alpha = 0.8, h = 6 },
    guard = 71,
  },
  -- The reload notice over the breech.
  ammoNotice = {
    zone = { 512, 540, 256, 32 },
    plate = { 502, 530, 276, 52, corner = 10 },
    text = { 514, 542, 252, 28, font = 16 },
  },
  medalName = { gap = 2, font = 20 },
  -- The interaction prompt (shrinks, then drops the place before ' / ').
  prompt = {
    font = 16,
    smallest = 12,
    wide = 430,
    plate = { 18, 535, 460, 48, corner = 9 },
    zone = { 32, 545, 432, 28 },
    text = { 33, 546, 430, 26 },
  },
  -- A message: its top without a medal, widest, padding, its panel.
  message = {
    top = 91,
    widest = 1180,
    pad = 40,
    font = 16,
    h = 46,
    corner = 10,
    inset = 12,
    zone = { y = 10, h = 26, pad = 24 },
    text = { y = 11, h = 24 },
  },
  -- A hint: shown the first seconds, widest, padding, its panel.
  hint = {
    first = 8,
    widest = 1040,
    pad = 32,
    font = 16,
    y = 139,
    h = 46,
    corner = 10,
    zone = { x = 12, y = 149, h = 26, pad = 24 },
    text = { x = 16, y = 150, h = 24 },
  },
}

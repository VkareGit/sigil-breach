-- The look of a world drawn from its grid (render/world_mesh.lua): the colours
-- and the measures of its walls, slabs and dressing, where no painted hall
-- covers the map. Lengths are in metres; a colour is { r, g, b[, glow] }.
return {
  colors = {
    stone = { 0.24, 0.29, 0.30 },
    dark = { 0.095, 0.12, 0.14 },
    trim = { 0.42, 0.36, 0.24 },
    glow = { 1, 0.28, 0.055, 1 },
    floor = { 0.30, 0.33, 0.32 },
    nicheStripe = { 0.5, 0.31, 0.13 },
    ritual = { 0.59, 0.40, 0.18, 0.25 },
    sealRing = { 0.31, 0.22, 0.15, 0.05 },
    cloth = { 0.24, 0.045, 0.035, 0 },
    clasp = { 0.55, 0.32, 0.12, 0.08 },
    wax = { 0.57, 0.47, 0.29, 0.04 },
    flame = { 1, 0.47, 0.12, 1 },
    aisle = { 0.55, 0.35, 0.15, 0.1 },
  },
  -- The face a floor shows its solid neighbour: where it stands out from the
  -- cell, its thickness, base and cornice, and the body between them.
  wall = {
    out = 0.55,
    thickness = 0.12,
    base = 0.30,
    bodyFoot = 0.3,
    body = 0.55,
    cornice = 0.25,
  },
  -- A dark niche in every third face, and the brass stripe down it.
  niche = { inset = 0.06, bottom = 0.55, scale = 0.92, height = 2.8 },
  stripe = { inset = 0.12, bottom = 0.7, wide = 0.035, thin = 0.025, height = 2.25 },
  -- A round shaft: its plinth, drum, capital and abacus.
  shaft = {
    plinth = 1.15,
    plinthHeight = 0.22,
    drum = { foot = 0.48, head = 0.36, height = 4.5 },
    capital = { at = 3.8, foot = 0.37, head = 0.68, height = 0.5 },
    abacus = { at = 4.3, foot = 0.68, head = 0.45, height = 0.5 },
    sides = 8,
  },
  arch = { segments = 12, radius = 0.18 },
  -- The ritual inlay: rings and the small rings of its seals.
  ritual = {
    lift = 0.012,
    width = 0.025,
    sealLift = 0.014,
    sealRadius = 0.14,
    sealWidth = 0.02,
    sealSides = 16,
  },
  -- A seal's stone: base, shaft and crown, and the ring round it.
  sealStone = {
    base = { foot = 0.95, head = 0.85, height = 0.18, sides = 32 },
    shaft = { at = 0.18, foot = 0.48, head = 0.32, height = 0.75 },
    crown = { at = 0.92, foot = 0.32, head = 0.62, height = 0.12 },
    ring = { lift = 0.20, radius = 0.76, width = 0.025, sides = 40 },
  },
  portal = {
    sill = { width = 4, height = 0.2, depth = 0.9 },
    ring = { back = 0.05, width = 0.16, sides = 64 },
    glow = { back = 0.06, inset = 0.2, width = 0.04 },
    posts = { apart = 2.2, forward = 0.1, foot = 0.4, head = 0.25, height = 3.5, tip = 0.8 },
  },
  -- A banner by a wall: its rod, cloth and clasp.
  banner = {
    rod = { height = 3.8, half = 0.65, radius = 0.035, sides = 6 },
    strips = 10,
    out = 0.09,
    ripples = 4,
    ripple = 0.035,
    top = 3.75,
    half = 0.55,
    width = 1.1,
    hem = 1.9,
    sag = 0.12,
    clasp = { out = 0.14, height = 2.9, radius = 0.20, width = 0.02, sides = 24 },
  },
  candle = {
    apart = 0.16,
    height = 0.16,
    taller = 0.05,
    foot = 0.04,
    head = 0.035,
    sides = 6,
    flame = { radius = 0.027, height = 0.09, sides = 5 },
  },
  aisle = { lift = 0.01, width = 0.025, height = 0.01 },
  reliquary = {
    chest = { width = 0.50, height = 0.65, depth = 0.38 },
    lid = { width = 0.58, height = 0.07, depth = 0.43 },
  },
}

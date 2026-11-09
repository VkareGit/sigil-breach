-- The measures of painted stonework (render/kit/builder.lua): how far an
-- image repeats over stone, how rough a block or a lump is cut, how a chain
-- and a heap of rubble are made. Lengths are in metres.
return {
  -- Metres of column one repeat of its image covers.
  drumHeight = 2.2,
  -- Metres of dressed stone one repeat of its image covers.
  stoneSpan = 3.4,
  -- A rib's image: across its four faces, and along per segment.
  rib = { across = 0.3, along = 0.25 },
  -- A pointed arch rises by t^rise along its quarter: below 1 it springs steep.
  arcRise = 0.72,
  -- A forged link: its half length, half width and thickness; where the next
  -- link starts (a share of the step); when it counts as hanging straight
  -- down; and the facets of its ring.
  link = { long = 0.2, wide = 0.1, thick = 0.032, step = 0.6, upright = 0.95, sides = 12 },
  -- The tone of a block or a lump, a share of its shade: the darkest, and how
  -- much lighter one can be.
  tone = { base = 0.72, vary = 0.36 },
  -- A dressed block: each corner a share of its half size, and its image span.
  block = { rough = 0.88, roughVary = 0.24, span = 1.7 },
  -- A broken lump: each facet's reach a share of its half size, and its span.
  chunk = { rough = 0.62, roughVary = 0.5, span = 1.4 },
  -- A fallen drum: its sides, the jag of its broken end and the span of its
  -- cut faces on their image.
  drum = { sides = 14, jag = 0.11, jagWaves = 5, jagTurn = 7, capSpan = 0.18 },
  heap = {
    -- The edge of the mound: a share of its radius, and its swell.
    edge = 0.84,
    edgeVary = 0.16,
    -- Lumps on its slope, coarse and fine.
    lump = 0.13,
    lumpFine = 0.09,
    rings = 12,
    spokes = 34,
    -- The loose stone of its face: how far a point moves, and how much more
    -- it rises off the flat.
    jitter = 0.06,
    flat = 0.02,
    rough = 1.6,
    span = 2.6,
    shade = 0.72,
    shadeVary = 0.3,
    -- Blocks resting on it: the share that are big, how far out they lie,
    -- their sizes, length, height, how deep they sit and their tilt.
    bigShare = 0.24,
    bigReach = 0.78,
    smallReach = 0.98,
    big = { size = 0.12, vary = 0.15 },
    small = { size = 0.03, vary = 0.07 },
    long = 0.9,
    high = 0.55,
    highVary = 0.25,
    sit = 0.6,
    tilt = 0.9,
  },
}

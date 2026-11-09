-- The name plates of the proving ground's gallery (render/gallery.lua).
-- Sizes are pixels of a 600-pixel-high view; heights and reaches in metres.
return {
  referenceHeight = 600,
  -- Keep this far from the view's edge (at least, and per unit), and clear
  -- of the proving ground's header and bottom strip.
  margin = { least = 8, unit = 10 },
  header = 92,
  footer = 64,
  pad = { x = 8, y = 5 },
  -- The square round the aim no plate covers (half its side).
  aimHalf = 25,
  font = 14,
  ink = { 0.93, 0.87, 0.72, 1 },
  -- A pad's plate: where it hangs and where it is aimed at, on an altar
  -- (from its top) and on the floor; how near the knight must stand.
  altarDrop = 0.20,
  floorHeight = 0.35,
  altarFocus = 0.70,
  floorFocus = 0.1,
  altarReach = 5,
  floorReach = 3,
  -- A station's caption is read from farther.
  stationReach = 24,
  defaultReach = 8,
  -- Which pad is in focus: distance counts this much against being centred,
  -- and only one inside this share of the view across and up.
  distanceWeight = 0.0006,
  across = 0.25,
  up = 0.4,
}

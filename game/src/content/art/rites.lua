-- Painted effects of the fight: what a blow leaves in the air and on the floor.
-- Presentation only, never reach, timing or damage geometry.
--   cells     column and row in the atlas
--   rim       share of the half-cell a painted circle reaches
--   cut       the visible life of a cut, in seconds past its active window
--   ray       size of one length of a ray and its spacing (m)
return {
  path = 'assets/art/rites-fresco-v36.png',
  width = 2048,
  height = 2048,
  columns = 2,
  rows = 2,
  cells = { wave = { 0, 0 }, circle = { 1, 0 }, cut = { 0, 1 }, ray = { 1, 1 } },
  rim = 0.92,
  cut = 0.1,
  cutSize = 0.78,
  cutHeight = 1.4,
  cutForward = 0.2,
  ray = { size = 1.7, step = 1.5, warned = 0.3 },
  storm = { bolts = 12, near = 1.2, spread = 2.2, height = 1.5, size = 2.8, mark = 2.6 },
}

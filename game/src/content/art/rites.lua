-- Painted effects of the fight: what a blow leaves in the air and on the floor.
-- Presentation only, never reach, timing or damage geometry.
--   cells     column and row in the atlas
--   rim       share of the half-cell a painted circle reaches
--   cut       the visible life of a cut, in seconds past its active window
--   ray       size of one length of a ray and its spacing (m)
return {
  path = 'assets/art/rites-fresco-v45.png',
  width = 2048,
  height = 2048,
  columns = 2,
  rows = 2,
  cells = { wave = { 0, 0 }, circle = { 1, 0 }, cut = { 0, 1 }, ray = { 1, 1 } },
  supplements = {
    {
      path = 'assets/art/projectiles-fresco-v45.png',
      columns = 4,
      rows = 2,
      cells = {
        star1 = { 0, 0 },
        star2 = { 1, 0 },
        star3 = { 2, 0 },
        star4 = { 3, 0 },
        cinder1 = { 0, 1 },
        cinder2 = { 1, 1 },
        cinder3 = { 2, 1 },
        cinder4 = { 3, 1 },
      },
    },
    {
      path = 'assets/art/stolas-rites-v45.png',
      columns = 2,
      rows = 2,
      cells = { fissure = { 0, 0 }, damned = { 1, 0 }, feathers = { 0, 1 }, fragments = { 1, 1 } },
    },
  },
  blink = { duration = 0.36, limit = 12, size = 2.1 },
  -- Measured inscribed opaque core, distinct from the peripheral ice/flame tips.
  projectiles = {
    rate = 9,
    default = { prefix = 'cinder', core = 0.34, impact = 'arc' },
    styles = { astral = { prefix = 'star', core = 0.41, impact = 'stone' } },
  },
  rim = 0.92,
  cut = 0.1,
  cutSize = 0.78,
  cutHeight = 1.4,
  cutForward = 0.2,
  antlerCasts = { lightning = true, ['storm-steps'] = true },
  -- Opaque bone against burnt underpaint carries contrast without a luminous column.
  ray = { size = 1.7, step = 1.5, warned = 0.94, flare = 0.10, embers = 0.32, limit = 16 },
  storm = { bolts = 12, near = 1.2, spread = 2.2, height = 1.5, size = 2.8, mark = 2.6 },
}

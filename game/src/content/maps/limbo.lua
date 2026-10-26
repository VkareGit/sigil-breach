-- Limbo, the first circle, as data (0.24 F6): the grid, its rooms and
-- pillars, the seals of the classic trial, the exit portal, where the knight
-- starts, the braziers, the Ember (shrine), the summoning gates of the waves
-- and the zone names. world/arena.lua builds a world from it; nothing else
-- knows these numbers.
return {
  id = 'limbo',
  size = 31,
  -- Height of the walkable floor (m); walls and pillars rise from it.
  floor = 0,
  decor = require('src.content.maps.limbo_art'),
  anchors = { secret = { x = 3.7, z = 20.4 }, boss = { x = 16, z = 8 } },
  -- Open floor (x1, z1, x2, z2), carved in order out of solid wall.
  -- 0.14: an open arena. The two courts and the crossing are one wide
  -- transept, the nave and the altar are wider; pillars remain as cover.
  rooms = {
    { 9, 18, 23, 29 }, -- wide nave / entry
    { 3, 10, 29, 23 }, -- open transept: west court, crossing, east court
    { 8, 2, 24, 10 }, -- wide altar
  },
  -- Round pillars (x, z).
  pillars = {
    { 12, 20 },
    { 20, 20 },
    { 12, 25 },
    { 20, 25 },
    { 12, 5 },
    { 20, 5 },
    { 5, 14 },
    { 5, 19 },
    { 27, 14 },
    { 27, 19 },
    { 9, 12 },
    { 23, 12 },
    { 12, 10 },
    { 20, 10 },
    { 12, 15 },
    { 20, 15 },
  },
  seals = {
    -- id: the seal's Goetic spirit (ui/goetic_sigils.lua); name, court:
    -- text keys (content/text.lua).
    {
      x = 7,
      z = 17,
      id = 'asmoday',
      name = 'seal_asmoday',
      court = 'court_embers',
      color = { 1, 0.28, 0.07 },
    },
    {
      x = 25,
      z = 17,
      id = 'stolas',
      name = 'seal_stolas',
      court = 'court_stars',
      color = { 0.35, 0.65, 1 },
    },
    {
      x = 16,
      z = 5.5,
      id = 'buer',
      name = 'seal_buer',
      court = 'court_resin',
      color = { 0.38, 1, 0.57 },
    },
  },
  portal = { x = 16, z = 2.9 },
  spawn = { x = 16, z = 27.5, yaw = math.pi },
  -- Braziers, ritual workstations, and environmental landmarks (x, z) at
  -- lampHeight m; in an expedition none burns within emberClear m of the Ember.
  lamps = {
    { 13, 27 },
    { 19, 27 },
    { 10, 18 },
    { 22, 18 },
    { 9, 13 },
    { 23, 13 },
    { 13, 7 },
    { 19, 7 },
    { 13, 11 },
    { 19, 11 },
  },
  lampHeight = 1.18,
  emberClear = 2,
  -- The Ember: the shrine where the knight rests and trades.
  ember = { x = 18, z = 26 },
  -- Summoning gates of the waves (run/spawner.lua).
  gates = {
    { x = 7, z = 17 },
    { x = 25, z = 17 },
    { x = 16, z = 5.5 },
    { x = 16, z = 23 },
    { x = 10, z = 18 },
    { x = 22, z = 18 },
  },
  -- Zone names (text keys), the first that holds: x below / above, z below;
  -- the last names the rest.
  zones = {
    { name = 'zone_court_of_embers', xBelow = 11 },
    { name = 'zone_court_of_stars', xAbove = 21 },
    { name = 'zone_choir_of_resin', zBelow = 9 },
    { name = 'zone_nave' },
  },
}

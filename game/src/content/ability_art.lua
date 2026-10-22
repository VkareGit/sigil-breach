-- Source-art ability anchors and authored timing; immutable content, no GPU or hitboxes.
local Frames = require('src.content.art.ability_frames')
local AbilityArt = {
  leap = {
    path = 'assets/art/imp-leap-fresco-v23.png',
    columns = 4,
    rows = 2,
    scale = 1,
    -- The base thrall atlas is matte ochre, not the supplement's bright orange.
    -- RGB grouping at atlas-like detail; exact source alpha/geometry retained.
    pigment = {
      grid = { 192, 256 },
      tone = { 0.64, 0.92, 0.72 },
      lift = { 0.075, 0.045, 0.024 },
      -- Red-dominance gate, strength, target R/G. Keep ochre skin unchanged.
      red = { 0.45, 0.66, 0.90, 2.15 },
    },
    -- Source-pixel skull centre, virtual ground line, and ribcage centre.
    -- Flight poses retain a virtual ground under their tucked legs.
    anchors = {
      { 280, 207, 420, 209, 269 },
      { 662, 212, 420, 607, 282 },
      { 1046, 188, 446, 979, 247 },
      { 1420, 215, 467, 1343, 259 },
      { 282, 695, 947, 216, 749 },
      { 654, 670, 906, 593, 747 },
      { 1045, 670, 907, 985, 746 },
      { 1417, 656, 908, 1367, 737 },
    },
    actions = { 'crouch', 'gather', 'launch', 'flight', 'descend', 'land', 'rise', 'ready' },
  },
  evade = {
    path = 'assets/art/stolas-evade-fresco-v23.png',
    columns = 4,
    rows = 2,
    scale = 1,
    -- A gentler match for the owl: keep the pale face readable, quiet the sheen.
    pigment = { grid = { 192, 256 }, tone = { 0.89, 0.96, 0.65 }, lift = { 0.035, 0.022, 0.015 } },
    anchors = {
      { 214, 214, 430, 221, 284 },
      { 626, 211, 431, 597, 281 },
      { 957, 216, 429, 964, 276 },
      { 1276, 217, 423, 1309, 278 },
      { 215, 683, 884, 216, 744 },
      { 573, 664, 881, 576, 740 },
      { 957, 664, 882, 956, 742 },
      { 1342, 663, 881, 1343, 741 },
    },
    actions = { 'brace', 'push', 'sweep', 'coast', 'catch', 'recover', 'ready', 'ready' },
  },
}

for key, entry in pairs(AbilityArt) do
  entry.frames, entry.feet = Frames[key].frames, Frames[key].feet
end
AbilityArt.timing = {
  arrival = 0.6,
  coil = 0.52,
  launch = 0.16,
  land = 0.28,
  rise = 0.76,
  minimumFlight = 0.001,
  evade = { 0.08, 0.20, 0.43, 0.64, 0.78, 0.90, 0.96 },
}
return AbilityArt

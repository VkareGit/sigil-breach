-- The carved forms of a chapel hall (render/kit/chapel.lua): the profiles of
-- its stone, the cut of its ruins and how its cloth and chains hang. Lengths
-- are in metres; a profile is { radius or inset, height } from the foot up; a
-- shade darkens a face's light (1 = as lit); an aim is the point a face is lit
-- as if it looked at. The painted surfaces are content/art/chapel_hall.lua.
local pier = {
  { 0.8, 0.0 },
  { 0.8, 0.5 },
  { 0.72, 0.78 },
  { 0.65, 0.98 },
  { 0.62, 2.7 },
  { 0.69, 2.78 },
  { 0.69, 2.98 },
  { 0.62, 3.06 },
  { 0.62, 5.3 },
  { 0.68, 5.38 },
  { 0.68, 5.56 },
  { 0.62, 5.62 },
  { 0.62, 7.3 },
  { 0.71, 7.42 },
  { 0.88, 8.0 },
  { 0.88, 8.3 },
  { 0.62, 8.4 },
}
-- What stands of a fallen pier: its base mouldings.
local stump = {}
for i = 1, 4 do
  stump[i] = { pier[i][1], pier[i][2] }
end
return {
  -- The repeat of a stone texture along a wall, a riser or the vault.
  stoneSpan = 3.4,
  -- The repeat of the floor's flags.
  floorSpan = 9,
  -- The repeat of broken stone at the lip of a fall.
  rubbleSpan = 1.7,
  -- How far beyond a face its aim stands, near and far.
  aim = 9,
  farAim = 99,
  -- The height of the aim of a wall or the vault, and of the far backdrops.
  aimHeight = 3,
  backdropAim = 20,
  floor = { riserShade = 0.82 },
  -- The texture rectangles { u0, v0, u1, v1 } of a tomb's carved faces.
  tombFront = { 0.006, 0.49, 0.56, 0.006 },
  tombFigure = { 0.575, 0.49, 0.99, 0.006 },
  tombSlab = { 0.006, 0.99, 0.49, 0.51 },
  sarcophagus = {
    profile = {
      { 0, 0 },
      { 0, 0.14 },
      { 0.06, 0.18 },
      { 0.06, 0.8 },
      { 0, 0.84 },
      { 0, 1.0 },
    },
    shade = 0.95,
    -- The carved faces: in from the side, in from the ends, foot and head.
    inset = 0.05,
    margin = 0.1,
    bottom = 0.2,
    top = 0.8,
    lid = 1.003,
    -- How much of a pier's reach a tomb blocks of the light.
    blocks = 1.25,
  },
  banner = {
    columns = 10,
    rows = 14,
    -- The ripple across the cloth: waves per width and its depth.
    wave = 15,
    wobble = 0.04,
  },
  fallenBanner = {
    columns = 8,
    rows = 10,
    -- Where the cloth lies before its wall, and how much of it is spread.
    reach = 0.9,
    narrow = 0.9,
    spread = 0.42,
    -- Its loose folds: lift, ruck and their waves.
    lift = 0.05,
    ruck = 0.05,
    waveAcross = 11,
    waveAlong = 9,
    ripple = 7,
    drift = 0.1,
  },
  ribs = {
    inset = 0.1,
    drop = 0.5,
    spring = 8.3,
    foot = 0.7,
    segments = 14,
    width = 0.42,
    depth = 0.34,
    shade = 0.8,
    -- The rib that meets the side wall.
    wallTop = 10.4,
    wallSegments = 5,
    -- The ribs across the bay at the ends of the nave.
    crossFoot = 0.5,
    crossRise = 0.4,
    crossReach = 3.5,
    crossWidth = 0.2,
    crossDepth = 0.2,
    crossShade = 0.7,
  },
  pier = {
    profile = pier,
    sides = 28,
    wraps = 2,
    shade = 0.95,
    crackedShade = 0.8,
    -- The radius a pier holds back of the light.
    blocks = 0.62,
    -- The bite of a crack: waves round and up the drum, the depth it begins
    -- at and how deep it cuts.
    bite = { round = 2, up = 1.7, roundFine = 5, upFine = 3.1, from = 0.35, depth = 0.42 },
    stump = stump,
    stumpRise = 0.9,
    stumpTop = 0.9,
    stumpLobes = 3,
    stumpBite = 0.4,
  },
  ruin = {
    rise = 1.4,
    -- The sky through the hole: { height, r, g, b, power, reach }.
    glow = { height = 13, r = 1, g = 0.56, b = 0.32, power = 3.2, reach = 40 },
    -- The broken thickness of the vault round the hole.
    facets = 120,
    lipDrop = 0.04,
    lipHeight = 0.5,
    lipVary = 0.22,
    lipWave = 1.7,
    edgeShade = 0.85,
    -- Loose stones hanging at its lip.
    stones = 84,
    jitter = 0.3,
    stoneSize = 0.14,
    stoneVary = 0.22,
    stoneSink = 0.2,
    stoneLong = 1.5,
    stoneHigh = 0.8,
    -- The stepped courses along a tear in a side wall.
    tearInset = 0.1,
    tearStones = 48,
    tearTop = 10.5,
    tearSize = 0.13,
    tearVary = 0.17,
    course = 0.22,
    tearHigh = 0.7,
    tearLong = 1.5,
    -- The drum that came down with it.
    drum = { lift = 0.25, back = 0.8, radius = 0.5, length = 1.5, shade = 0.8 },
  },
  -- The ring of an opening: the share of its height that is straight jamb,
  -- the share that is arch, its steps and depth on the texture.
  reveal = { jamb = 0.4, arch = 0.6, steps = 30, depth = 0.33, shade = 0.85 },
  vault = {
    -- Grid points this near a hole's edge move onto it.
    snap = 0.3,
    -- Cells across half the nave, and across half the south wall's head.
    cells = 30,
    southCells = 15,
    -- The middle of a half-metre row.
    rowMiddle = 0.25,
    shade = 0.62,
    southShade = 0.7,
  },
  altar = {
    plinth = 0.14,
    waist = 0.2,
    inset = 0.1,
    overhang = 0.06,
    lip = 0.12,
    shade = 0.86,
    faceMargin = 0.2,
    faceInset = 0.08,
    faceGap = 0.22,
  },
  pedestal = {
    profile = {
      { 0.95, 0 },
      { 0.85, 0.18 },
      { 0.48, 0.18 },
      { 0.32, 0.93 },
      { 0.62, 1.046 },
      { 0, 1.046 },
    },
    sides = 18,
    shade = 0.8,
  },
  -- An offering table at a post, scaled to the post's height.
  table = {
    profile = { { 0, 0 }, { 0.0, 0.14 }, { 0.09, 0.2 }, { 0.09, 1 }, { 0.0, 1.06 }, { 0.0, 1.18 } },
    height = 1.18,
    shade = 0.86,
  },
  -- A free pedestal of the hall map.
  plinth = { foot = 0.12, waist = 0.16, inset = 0.1, neck = 0.14, lip = 0.08, shade = 0.86 },
  walls = {
    -- The thickness of the chancel wall, and the depth of the south opening.
    thickness = 0.6,
    southReveal = 0.3,
    -- Half the width of the rear wall, and the shade of the apse sides.
    rearHalf = 5.25,
    apseShade = 0.62,
  },
  heap = { blocks = 0.8 },
  chain = {
    shade = 0.8,
    -- A chain whose far end broke hangs this far from its hook.
    hang = 2.6,
    hangLinks = 7,
    -- A fallen chain on the floor: from its end, to where it lies, its sag.
    fallen = {
      lift = 0.2,
      out = 0.5,
      along = 1.2,
      rest = 0.08,
      reach = 0.9,
      sag = -0.02,
      links = 9,
    },
  },
  drumShade = 0.82,
  -- How the number of a pier and the hall's axis seed the shape of its
  -- cracks and of its ruin: other seeds, other broken stone.
  seeds = { pier = 1.7, ruin = 97, ruinAxis = 13 },
}

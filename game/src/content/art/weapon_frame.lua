-- How the hands and the gun stand in the frame (render/weapon.lua): the
-- muzzle sheet, the screen unit, the kick of a shot and the spent cases.
-- Pixels are of a 450-pixel-high view.
return {
  muzzle = {
    path = 'assets/art/muzzle-fresco-v12.png',
    -- The painted gutters of its first row: between the first two cells, and
    -- above the second row.
    split = 470,
    rowSplit = 530,
    -- A pixel counts as painted above this opacity; its ignition point is
    -- found in the lowest rows of the flash, over this opacity.
    painted = 0.10,
    ignitionRows = 7,
    ignition = 0.20,
  },
  referenceHeight = 450,
  -- The reload's opening fades the pose in over its last instant (s).
  reloadEntry = 0.08,
  -- A shot: roll per unit of recoil, the view punch's reach and scale, the
  -- rest height of the gun and how far recoil, the kick and the wrist lift
  -- it; the growth of the gun in a kick.
  shot = {
    roll = 0.018,
    punchReach = 4,
    punch = 80,
    rest = 11,
    recoil = 14,
    kick = 6,
    wrist = 32,
    grow = 0.045,
  },
  -- A spent case: fades out quickly; paper cartridge in umber with a dull
  -- bone rim, not polished brass.
  shell = {
    fade = 4,
    body = { 0.34, 0.19, 0.11 },
    rim = { 0.66, 0.55, 0.37 },
    width = 4,
    length = 10,
    rimLength = 3,
  },
}

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
}

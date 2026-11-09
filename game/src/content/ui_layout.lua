-- The one frame the world and the interface share (ui/layout.lua): its
-- size, the status bar's top, the aim, and the measures of the marks at the
-- aim and at the top of the view. Pixels of the 1280 by 720 frame.
return {
  width = 1280,
  height = 720,
  barTop = 600,
  aimX = 640,
  aimY = 300,
  -- How far the reticle opens while the hands cannot fire, and what is said below it (px).
  lockedGap = 7,
  -- The hit mark: four strokes from markGap to hitReach px off the centre, markWidth px wide,
  -- fading over their last markFade s; a kill's reach killReach, landing killPop larger.
  -- Small, as shooters keep it: about a hundredth of the screen's height across, never larger
  -- than a body in the distance; a kill differs by colour, hardly by size (owner, 0.42).
  markGap = 4,
  hitReach = 8,
  markWidth = 1.5,
  markFade = 0.06,
  killReach = 9,
  killPop = 0.1,
  refusalBelow = 34,
  -- A deed at the top of the view (px); it fades over the end of its time (s).
  medalSeal = 76,
  medalTop = 84,
  medalFade = 0.4,
  -- A message shown with a medal stands this far under its seal, past its name and effect (px).
  medalBelow = 46,
}

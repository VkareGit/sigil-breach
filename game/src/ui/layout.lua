-- World and GUI share one viewport, including letterboxing and the status bar.
local Queries = require('src.session.queries')
local L = {
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
function L.viewport(w, h)
  local scale = math.min(w / L.width, h / L.height)
  return scale, (w - L.width * scale) / 2, (h - L.height * scale) / 2
end
function L.hasBar(g)
  return Queries.run(g) ~= nil and (g.state == 'playing' or g.state == 'paused')
end
function L.scene(g, w, h)
  if not L.hasBar(g) then
    return 0, 0, w, h
  end
  local scale, x, y = L.viewport(w, h)
  return x, y, L.width * scale, L.barTop * scale
end
return L

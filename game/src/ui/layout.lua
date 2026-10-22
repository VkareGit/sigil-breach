-- World and GUI share one viewport, including letterboxing and the status bar.
local L = { width = 1280, height = 720, barTop = 600, aimX = 640, aimY = 300 }
function L.viewport(w, h)
  local scale = math.min(w / L.width, h / L.height)
  return scale, (w - L.width * scale) / 2, (h - L.height * scale) / 2
end
function L.hasBar(g)
  return g.run and (g.state == 'playing' or g.state == 'paused')
end
function L.scene(g, w, h)
  if not L.hasBar(g) then
    return 0, 0, w, h
  end
  local scale, x, y = L.viewport(w, h)
  return x, y, L.width * scale, L.barTop * scale
end
return L

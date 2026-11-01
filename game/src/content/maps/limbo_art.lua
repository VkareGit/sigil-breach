-- Placement belongs to the map. Renderers own reusable painting/mesh recipes,
-- never Limbo coordinates. Heights are relative to the supporting floor.
return {
  -- Walls carrying a mural: no joint stands out of them (feedback/surface_marks.lua).
  jointless = { { 3, 14, 3, 18 }, { 29, 14, 29, 18 }, { 14, 29, 18, 29 } },
  muralWalls = { { 3, 14, 3, 18 }, { 29, 14, 29, 18 }, { 14, 29, 18, 29 } },
  arches = {
    { x = 16, z = 10, halfSpan = 4, spring = 3.8, rise = 2 },
    { x = 16, z = 15, halfSpan = 4, spring = 3.8, rise = 2 },
    { x = 16, z = 20, halfSpan = 4, spring = 3.8, rise = 2 },
    { x = 16, z = 25, halfSpan = 4, spring = 3.8, rise = 2 },
  },
  rituals = { { x = 16, z = 17, rings = { 2.3, 2.4, 2.85 }, orbit = 2.62, seals = 9 } },
  aisles = { { x = 15.3, z = 24, length = 9 }, { x = 16.7, z = 24, length = 9 } },
  portal = { x = 16, z = 2.9, y = 2.1, radius = 1.7 },
  banners = {
    { x = 9.25, z = 25, side = 1 },
    { x = 22.75, z = 25, side = -1 },
    { x = 9.25, z = 28, side = 1 },
    { x = 22.75, z = 28, side = -1 },
  },
  candles = {
    { x = 14, z = 28 },
    { x = 18, z = 28 },
    { x = 6, z = 16 },
    { x = 26, z = 16 },
    { x = 14, z = 4 },
    { x = 18, z = 4 },
  },
  reliquaries = { { x = 3.7, z = 20.4 } },
  murals = {
    { frame = 1, x = 2.65, y = 0.72, z = 16, yaw = math.pi / 2, size = 2.7 },
    { frame = 2, x = 29.35, y = 0.72, z = 16, yaw = -math.pi / 2, size = 2.7 },
    { frame = 4, x = 16, y = 0.72, z = 29.35, yaw = math.pi, size = 2.7 },
  },
  props = {
    { frame = 5, x = 10.7, z = 3.5, size = 3.3, brightness = 0.95 },
    { frame = 5, x = 21.3, z = 3.5, size = 3.3, brightness = 0.95 },
    { frame = 6, x = 10.9, z = 28.5, size = 0.75, brightness = 0.95 },
    { frame = 6, x = 21.1, z = 28.5, size = 0.75, brightness = 0.95 },
    { frame = 6, x = 3.8, z = 12.8, size = 0.75, brightness = 0.95 },
    { frame = 6, x = 28.5, z = 20.5, size = 0.75, brightness = 0.95 },
    { frame = 8, x = 3.7, y = 0.62, z = 20.4, size = 0.75, brightness = 0.9, secret = true },
  },
}

-- A diagnostic map for space at scale (plan v10 V3): 256 x 128 cells in
-- three halls with doors between them, a bridge (a deck 2.9 m high on
-- stairs) across the middle hall over open floor, and 200 braziers, ten of
-- them on the bridge. QA and the tests register it on demand; it is never
-- offered in the menu and is not production content.
local width, depth = 256, 128
local top, thickness, riser = 2.9, 0.3, 0.29
-- The bridge runs along z 62..66 from x 96 to 160; stairs of ten risers
-- climb to it from x 86 and from x 170.
local bridge = { x1 = 96, x2 = 160, z1 = 62, z2 = 66 }
local elevations = {}
for k = 1, 10 do
  elevations[#elevations + 1] =
    { x1 = 85 + k, x2 = 85 + k, z1 = bridge.z1, z2 = bridge.z2, height = riser * k }
  elevations[#elevations + 1] =
    { x1 = 171 - k, x2 = 171 - k, z1 = bridge.z1, z2 = bridge.z2, height = riser * k }
end
local lamps = {}
for j = 0, 9 do
  for i = 0, 18 do
    lamps[#lamps + 1] = { 8 + i * 13, 8 + j * 13 }
  end
end
for k = 0, 9 do
  -- Five on the bridge, five on the floor under it.
  if k % 2 == 0 then
    lamps[#lamps + 1] = { 100 + k * 6, 64, top }
  else
    lamps[#lamps + 1] = { 100 + k * 6, 64 }
  end
end
return {
  id = 'qa_bridge',
  width = width,
  depth = depth,
  floor = 0,
  rooms = {
    { 2, 2, 80, depth - 1 },
    { 82, 2, 174, depth - 1 },
    { 176, 2, width - 1, depth - 1 },
    { 81, 20, 81, 24 },
    { 81, 100, 81, 104 },
    { 175, 30, 175, 34 },
    { 175, 90, 175, 94 },
  },
  elevations = elevations,
  decks = {
    {
      x1 = bridge.x1,
      x2 = bridge.x2,
      z1 = bridge.z1,
      z2 = bridge.z2,
      top = top,
      thickness = thickness,
    },
  },
  portal = { x = 230, z = 64 },
  spawn = { x = 40, z = 64, yaw = math.pi / 2 },
  ember = { x = 44, z = 70 },
  lamps = lamps,
  lampHeight = 1.18,
  gates = { { x = 128, z = 30 }, { x = 128, z = 100 } },
  zones = { { name = 'QA BRIDGE HALLS' } },
}

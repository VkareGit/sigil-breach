-- A diagnostic map for crowd measurements (plan v10 V0): one open hall large
-- enough for 512 bodies on the crowd factory's grid, with a few pillars so
-- sight and paths are not trivially open. QA registers it on demand; it is
-- never offered in the menu and is not production content.
local size = 72
local pillars = {}
for z = 12, size - 12, 12 do
  for x = 12, size - 12, 12 do
    pillars[#pillars + 1] = { x, z }
  end
end
return {
  id = 'qa_crowd',
  size = size,
  floor = 0,
  rooms = { { 3, 3, size - 3, size - 3 } },
  pillars = pillars,
  portal = { x = size / 2, z = 6 },
  spawn = { x = size / 2, z = size - 8, yaw = math.pi },
  ember = { x = size / 2 + 4, z = size - 8 },
  lamps = { { 18, 18 }, { 54, 18 }, { 18, 54 }, { 54, 54 } },
  lampHeight = 1.18,
  gates = { { x = size / 2, z = size / 2 } },
  zones = { { name = 'QA CROWD HALL' } },
}

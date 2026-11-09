-- The forms of a painted room (render/kit/rooms.lua): its stone, its pillars
-- and its lamps. Lengths are in metres.
return {
  -- The height of a wall with nothing above it.
  wallTop = 4.2,
  stoneSpan = 3.4,
  -- The floor's flags: their repeat and the axis they are centred on.
  floorSpan = 9,
  floorAxis = 24,
  ceilingShade = 0.8,
  riserShade = 0.82,
  -- A round pillar, from its foot up: plinth, waist, shaft and capital.
  pillar = {
    plinth = 0.62,
    plinthTop = 0.3,
    waist = 0.5,
    shaft = 0.46,
    shaftFoot = 0.7,
    neck = 0.5,
    capital = 0.15,
    sides = 16,
    shade = 0.9,
  },
  -- The warm light of a lamp and of a seal: height, colour, power, reach.
  lamp = { height = 1.4, color = { 1, 0.66, 0.38 }, power = 0.75, reach = 9 },
  seal = { height = 2.2, color = { 1, 0.66, 0.38 }, power = 0.5, reach = 9 },
}

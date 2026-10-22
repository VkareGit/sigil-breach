-- Armour, exposed skull and hands marked against each authored painting.
-- Source alpha supplies the contour and all gaps; polygons assign anatomy.
-- Atlas poses are traced in pixels of their cell of the 6 x 4 drawing grid,
-- the vigilance poses in their cell of the 2 x 2 idle sheet (author.lua:
-- cellPolygon / fromCell convert to frame UV from the frames' metadata).
local Layout = require('src.content.art.enemy_frames').armored
local Author = require('src.content.art.anatomy.author')
local Armored = { frames = {} }
local part, box = Author.part, Author.box
local GRID, IDLE = { 6, 4 }, { 2, 2 }
local function add(p, r)
  p[#p + 1] = r
end
local function base()
  -- Explicit torso fallback covers the integrated mail and cloth over armour.
  return { box('bodyFallback', 'torso', 'metal', 0, 0, 1, 1) }
end
local function convert(index, p, claw)
  local frame = Layout.frames[index]
  for i = 2, #p do
    p[i].polygon = Author.cellPolygon(frame, index, GRID[1], GRID[2], p[i].polygon)
  end
  return {
    parts = p,
    anchors = claw and {
      claw = { Author.fromCell(frame, index, GRID[1], GRID[2], claw[1], claw[2]) },
    } or nil,
  }
end
local heads = {
  [1] = { 166, 29, 195, 73 },
  [3] = { 127, 32, 153, 74 },
  [4] = { 146, 31, 170, 75 },
  [5] = { 94, 31, 121, 79 },
  [6] = { 111, 28, 138, 77 },
  [7] = { 171, 34, 197, 76 },
  [9] = { 155, 42, 181, 81 },
  [11] = { 172, 32, 196, 70 },
  [12] = { 133, 29, 155, 74 },
  [13] = { 75, 10, 114, 43 },
  [14] = { 184, 44, 221, 81 },
  [15] = { 171, 92, 210, 125 },
  [16] = { 39, 122, 85, 158 },
  [19] = { 122, 14, 160, 44 },
  [20] = { 122, 14, 155, 44 },
  [21] = { 122, 14, 156, 44 },
  [22] = { 120, 13, 156, 44 },
  [23] = { 122, 14, 157, 44 },
  [24] = { 123, 14, 158, 44 },
}
-- Walk/carry poses have separately measured legs and skin of the hands.
local walking = {
  [1] = {
    legA = { 102, 116, 147, 161, 140, 199, 130, 226, 105, 227, 110, 187, 106, 164 },
    legB = {
      143,
      119,
      178,
      144,
      188,
      187,
      179,
      225,
      191,
      252,
      152,
      254,
      145,
      223,
      152,
      185,
      137,
      160,
    },
    left = { 109, 118, 164, 160 },
    right = { 207, 117, 237, 177 },
  },
  [3] = {
    legA = { 94, 120, 121, 142, 117, 170, 105, 188, 113, 215, 88, 218, 81, 183, 91, 159 },
    legB = {
      113,
      114,
      148,
      139,
      148,
      183,
      143,
      225,
      154,
      254,
      118,
      255,
      117,
      214,
      121,
      176,
      111,
      153,
    },
    left = { 44, 121, 80, 176 },
    right = { 176, 126, 218, 184 },
  },
  [4] = {
    legA = { 102, 125, 127, 143, 123, 179, 111, 198, 122, 227, 94, 229, 86, 189, 98, 164 },
    legB = { 120, 118, 151, 140, 149, 187, 144, 225, 153, 254, 118, 255, 115, 219, 123, 179 },
    left = { 76, 93, 140, 148 },
    right = { 176, 128, 211, 188 },
  },
  [5] = {
    legA = { 108, 119, 141, 145, 144, 184, 133, 222, 144, 246, 115, 250, 111, 218, 117, 180 },
    legB = { 91, 118, 122, 142, 117, 181, 117, 224, 96, 252, 72, 252, 89, 222, 89, 179 },
    left = { 40, 111, 76, 165 },
    right = { 176, 121, 204, 179 },
  },
  [6] = {
    legA = { 81, 120, 112, 146, 108, 186, 97, 222, 76, 229, 74, 201, 89, 180 },
    legB = { 109, 116, 143, 140, 146, 181, 139, 223, 152, 252, 111, 253, 112, 222, 118, 179 },
    left = { 76, 83, 134, 137 },
    right = { 175, 118, 208, 179 },
  },
  [12] = {
    legA = { 94, 116, 118, 140, 115, 179, 102, 211, 78, 215, 77, 190, 91, 161 },
    legB = { 115, 116, 145, 140, 145, 184, 141, 224, 157, 252, 115, 255, 114, 217, 121, 177 },
    left = { 52, 131, 92, 185 },
    right = { 181, 130, 216, 189 },
  },
}
for index, d in pairs(walking) do
  local p = base()
  add(p, part('legRear', 'lower', 'metal', d.legA))
  add(p, part('legFront', 'lower', 'metal', d.legB))
  add(p, box('armLeft', 'torso', 'metal', d.left[1] - 14, 55, d.left[3], d.left[2]))
  add(p, box('armRight', 'torso', 'metal', d.right[1] - 21, 55, d.right[3], d.right[2]))
  add(p, box('handLeft', 'torso', 'flesh', unpack(d.left)))
  add(p, box('handRight', 'torso', 'flesh', unpack(d.right)))
  add(p, box('head', 'head', 'flesh', unpack(heads[index])))
  Armored.frames[index] = convert(index, p, index == 12 and { 72, 156 } or nil)
end
local attack = {
  [7] = {
    legs = {
      { 102, 128, 144, 144, 127, 184, 107, 216, 101, 239, 70, 246, 81, 213, 93, 175 },
      { 140, 122, 181, 139, 201, 179, 216, 222, 230, 254, 190, 255, 178, 219, 161, 181, 140, 166 },
    },
    arms = {
      { 50, 66, 72, 38, 115, 65, 133, 88, 112, 108, 76, 93 },
      {
        181,
        92,
        199,
        108,
        227,
        130,
        220,
        146,
        185,
        125,
      },
    },
    hands = { { 66, 16, 105, 54 }, { 217, 124, 269, 181 } },
  },
  [9] = {
    legs = {
      { 95, 142, 128, 148, 120, 186, 105, 219, 88, 249, 58, 251, 76, 213, 87, 176 },
      { 121, 138, 151, 143, 165, 182, 183, 224, 199, 253, 164, 255, 149, 221, 134, 184 },
    },
    arms = {
      { 111, 76, 143, 75, 179, 94, 194, 112, 177, 132, 143, 108, 110, 103 },
      { 177, 86, 192, 103, 213, 132, 210, 147, 183, 129 },
    },
    hands = { { 181, 99, 250, 178 }, { 208, 126, 242, 172 } },
  },
  [11] = {
    legs = {
      { 77, 140, 107, 151, 96, 185, 68, 222, 62, 249, 30, 253, 39, 225, 74, 181 },
      { 109, 136, 137, 144, 149, 185, 172, 221, 186, 252, 153, 255, 134, 215, 119, 184 },
    },
    arms = {
      { 127, 73, 159, 77, 185, 88, 210, 96, 204, 112, 174, 107, 138, 104 },
      { 171, 82, 189, 97, 202, 119, 200, 139, 180, 122 },
    },
    hands = { { 204, 88, 260, 148 }, { 195, 123, 226, 172 } },
  },
}
for index, d in pairs(attack) do
  local p = base()
  for i, poly in ipairs(d.legs) do
    add(p, part('leg' .. i, 'lower', 'metal', poly))
  end
  for i, poly in ipairs(d.arms) do
    add(p, part('arm' .. i, 'torso', 'metal', poly))
  end
  for i, b in ipairs(d.hands) do
    add(p, box('hand' .. i, 'torso', 'flesh', unpack(b)))
  end
  add(p, box('head', 'head', 'flesh', unpack(heads[index])))
  Armored.frames[index] =
    convert(index, p, index == 9 and { 214, 133 } or index == 11 and { 230, 115 } or { 85, 35 })
end
local fallen = {
  [13] = {
    legs = {
      { 112, 102, 155, 116, 142, 153, 117, 191, 101, 226, 97, 239, 65, 241, 76, 209, 99, 165 },
      {
        146,
        110,
        177,
        119,
        202,
        155,
        215,
        194,
        228,
        230,
        250,
        238,
        211,
        243,
        199,
        213,
        185,
        178,
        158,
        151,
      },
    },
    hands = { { 115, 109, 170, 152 }, { 218, 47, 264, 103 } },
  },
  [14] = {
    legs = {
      { 112, 135, 143, 146, 132, 180, 108, 207, 95, 231, 72, 230, 79, 205, 103, 174 },
      { 138, 130, 166, 143, 161, 180, 158, 216, 174, 237, 133, 239, 133, 209, 142, 177 },
    },
    hands = { { 156, 72, 210, 116 }, { 209, 155, 239, 218 } },
  },
  [15] = {
    legs = {
      { 78, 129, 121, 150, 109, 187, 84, 214, 58, 221, 23, 215, 27, 193, 60, 194 },
      { 111, 139, 146, 155, 169, 186, 175, 210, 143, 222, 99, 223, 92, 200, 111, 185 },
    },
    hands = { { 126, 204, 169, 240 }, { 197, 190, 250, 218 } },
  },
  [16] = {
    legs = {
      { 158, 153, 189, 159, 219, 174, 247, 176, 251, 199, 224, 203, 198, 190, 170, 186 },
      { 142, 157, 169, 177, 186, 192, 181, 215, 150, 214, 132, 196 },
    },
    hands = { { 26, 197, 78, 227 }, { 181, 103, 219, 144 } },
  },
}
for index, d in pairs(fallen) do
  local p = base()
  for i, poly in ipairs(d.legs) do
    add(p, part('leg' .. i, 'lower', 'metal', poly))
  end
  if index == 16 then
    add(
      p,
      part(
        'armLeft',
        'torso',
        'metal',
        { 30, 162, 70, 156, 80, 182, 57, 202, 26, 205, 8, 197, 15, 181 }
      )
    )
    add(
      p,
      part(
        'armRight',
        'torso',
        'metal',
        { 124, 112, 164, 93, 188, 101, 189, 118, 158, 117, 143, 135 }
      )
    )
  else
    add(p, box('armLeft', 'torso', 'metal', 81, 60, 140, 140))
    add(p, box('armRight', 'torso', 'metal', 174, 96, 205, 189))
  end
  for i, b in ipairs(d.hands) do
    add(p, box('hand' .. i, 'torso', 'flesh', unpack(b)))
  end
  add(p, box('head', 'head', 'flesh', unpack(heads[index])))
  Armored.frames[index] = convert(index, p)
end
for index = 19, 24 do
  local p = base()
  add(
    p,
    part(
      'legLeft',
      'lower',
      'metal',
      { 104, 113, 137, 122, 134, 168, 126, 202, 130, 240, 102, 256, 83, 249, 96, 211, 105, 171 }
    )
  )
  add(
    p,
    part(
      'legRight',
      'lower',
      'metal',
      { 134, 112, 160, 126, 166, 167, 154, 201, 160, 240, 138, 252, 119, 247, 128, 213, 136, 176 }
    )
  )
  add(p, box('armLeft', 'torso', 'metal', 66, 68, 110, 143))
  add(p, box('armRight', 'torso', 'metal', 171, 66, 207, 149))
  add(p, box('handLeft', 'torso', 'flesh', 55, 132, 104, 183))
  add(p, box('handRight', 'torso', 'flesh', 180, 136, 223, 190))
  -- The rear hood covers the skull; it is still head anatomy, not a face.
  add(p, box('head', 'head', 'metal', unpack(heads[index])))
  Armored.frames[index] = convert(index, p)
end
local function replacement(index, head, legs, arms, hands, claw)
  local p = base()
  for i, poly in ipairs(legs) do
    add(p, part('leg' .. i, 'lower', 'metal', poly))
  end
  for i, poly in ipairs(arms) do
    add(p, part('arm' .. i, 'torso', 'metal', poly))
  end
  for i, b in ipairs(hands) do
    add(p, box('hand' .. i, 'torso', 'flesh', unpack(b)))
  end
  add(p, box('head', 'head', 'flesh', unpack(head)))
  Armored.frames[index] = { parts = p, anchors = claw and { claw = claw } or nil }
end
replacement(2, { 0.535, 0.105, 0.627, 0.221 }, {
  {
    0.42,
    0.42,
    0.52,
    0.44,
    0.51,
    0.61,
    0.51,
    0.75,
    0.51,
    0.94,
    0.44,
    0.94,
    0.42,
    0.82,
    0.45,
    0.68,
    0.42,
    0.57,
  },
  {
    0.51,
    0.42,
    0.59,
    0.45,
    0.63,
    0.56,
    0.59,
    0.73,
    0.61,
    0.86,
    0.52,
    0.87,
    0.52,
    0.73,
    0.55,
    0.57,
  },
}, {
  { 0.32, 0.18, 0.44, 0.16, 0.46, 0.29, 0.38, 0.38, 0.34, 0.48, 0.28, 0.47, 0.28, 0.35 },
  { 0.61, 0.23, 0.68, 0.30, 0.71, 0.42, 0.75, 0.50, 0.70, 0.52, 0.66, 0.43, 0.63, 0.37 },
}, { { 0.28, 0.46, 0.39, 0.63 }, { 0.69, 0.49, 0.79, 0.66 } })
replacement(8, { 0.57, 0.139, 0.675, 0.255 }, {
  {
    0.32,
    0.46,
    0.45,
    0.48,
    0.43,
    0.59,
    0.35,
    0.71,
    0.31,
    0.87,
    0.15,
    0.91,
    0.15,
    0.85,
    0.24,
    0.73,
    0.26,
    0.59,
  },
  {
    0.52,
    0.45,
    0.62,
    0.47,
    0.69,
    0.57,
    0.71,
    0.70,
    0.83,
    0.91,
    0.77,
    0.95,
    0.67,
    0.91,
    0.65,
    0.77,
    0.60,
    0.63,
  },
}, {
  {
    0.36,
    0.19,
    0.44,
    0.21,
    0.44,
    0.29,
    0.33,
    0.31,
    0.23,
    0.29,
    0.23,
    0.18,
    0.29,
    0.12,
    0.33,
    0.14,
    0.31,
    0.23,
  },
  { 0.64, 0.28, 0.69, 0.30, 0.76, 0.38, 0.83, 0.45, 0.79, 0.49, 0.72, 0.43, 0.67, 0.39 },
}, { { 0.27, 0.05, 0.51, 0.18 }, { 0.77, 0.44, 0.96, 0.62 } })
replacement(10, { 0.60, 0.16, 0.71, 0.30 }, {
  {
    0.36,
    0.49,
    0.45,
    0.51,
    0.44,
    0.64,
    0.38,
    0.78,
    0.40,
    0.91,
    0.28,
    0.91,
    0.28,
    0.86,
    0.31,
    0.75,
    0.31,
    0.62,
  },
  {
    0.49,
    0.50,
    0.62,
    0.51,
    0.67,
    0.64,
    0.69,
    0.78,
    0.76,
    0.94,
    0.66,
    0.97,
    0.61,
    0.91,
    0.58,
    0.77,
    0.56,
    0.65,
  },
}, {
  { 0.45, 0.22, 0.55, 0.23, 0.55, 0.32, 0.59, 0.40, 0.53, 0.47, 0.45, 0.42, 0.41, 0.35 },
  { 0.70, 0.26, 0.75, 0.30, 0.80, 0.34, 0.90, 0.42, 0.86, 0.46, 0.77, 0.42, 0.72, 0.38 },
}, { { 0.51, 0.38, 0.78, 0.62 }, { 0.84, 0.41, 0.97, 0.62 } }, { 0.65, 0.48 })
replacement(17, { 0.13, 0.43, 0.25, 0.59 }, {
  {
    0.51,
    0.55,
    0.63,
    0.58,
    0.72,
    0.66,
    0.94,
    0.69,
    0.99,
    0.77,
    0.91,
    0.79,
    0.74,
    0.75,
    0.64,
    0.70,
  },
  { 0.47, 0.57, 0.59, 0.62, 0.66, 0.70, 0.68, 0.76, 0.63, 0.79, 0.53, 0.76, 0.47, 0.68 },
}, {
  { 0.31, 0.42, 0.43, 0.47, 0.46, 0.60, 0.45, 0.75, 0.37, 0.78, 0.34, 0.68, 0.36, 0.59 },
  { 0.13, 0.60, 0.22, 0.60, 0.19, 0.69, 0.12, 0.73, 0.06, 0.74, 0.05, 0.69 },
}, { { 0.34, 0.74, 0.47, 0.86 }, { 0.10, 0.72, 0.34, 0.83 } })
replacement(18, { 0.15, 0.64, 0.29, 0.72 }, {
  {
    0.50,
    0.58,
    0.62,
    0.60,
    0.74,
    0.66,
    0.94,
    0.68,
    0.99,
    0.76,
    0.87,
    0.78,
    0.71,
    0.74,
    0.63,
    0.69,
  },
  { 0.46, 0.61, 0.58, 0.65, 0.64, 0.71, 0.67, 0.78, 0.58, 0.80, 0.49, 0.77 },
}, {
  {
    0.30,
    0.56,
    0.42,
    0.56,
    0.46,
    0.64,
    0.43,
    0.73,
    0.35,
    0.79,
    0.23,
    0.80,
    0.20,
    0.74,
    0.32,
    0.70,
  },
  { 0.10, 0.70, 0.19, 0.68, 0.25, 0.72, 0.26, 0.77, 0.17, 0.81, 0.05, 0.80 },
}, { { 0.02, 0.73, 0.24, 0.83 }, { 0.23, 0.76, 0.39, 0.83 } })
-- Idle sheet coordinates are converted from its absolute painted source.
local idleHeads = {
  { 500, 66, 558, 142 },
  { 1079, 63, 1125, 145 },
  { 534, 570, 589, 653 },
  {
    1084,
    576,
    1135,
    651,
  },
}
for index = 25, 28 do
  local k = index - 24
  local p = base()
  local function raw(poly)
    return Author.cellPolygon(Layout.frames[index], k, IDLE[1], IDLE[2], poly)
  end
  local shift = k % 2 == 0 and -190 or 0
  add(
    p,
    part(
      'legLeft',
      'lower',
      'metal',
      raw({
        408 + shift,
        275,
        458 + shift,
        280,
        468 + shift,
        357,
        454 + shift,
        432,
        449 + shift,
        501,
        390 + shift,
        501,
        396 + shift,
        449,
        409 + shift,
        379,
      })
    )
  )
  add(
    p,
    part(
      'legRight',
      'lower',
      'metal',
      raw({
        480 + shift,
        273,
        527 + shift,
        285,
        558 + shift,
        358,
        539 + shift,
        427,
        563 + shift,
        502,
        488 + shift,
        503,
        485 + shift,
        444,
        501 + shift,
        382,
      })
    )
  )
  add(
    p,
    part(
      'armLeft',
      'torso',
      'metal',
      raw({
        375 + shift,
        130,
        423 + shift,
        157,
        397 + shift,
        213,
        410 + shift,
        273,
        376 + shift,
        290,
        346 + shift,
        242,
        347 + shift,
        190,
      })
    )
  )
  add(
    p,
    part(
      'armRight',
      'torso',
      'metal',
      raw({
        555 + shift,
        147,
        593 + shift,
        169,
        613 + shift,
        225,
        634 + shift,
        278,
        603 + shift,
        293,
        577 + shift,
        244,
      })
    )
  )
  add(
    p,
    part(
      'handLeft',
      'torso',
      'flesh',
      raw({
        402 + shift,
        274,
        449 + shift,
        278,
        494 + shift,
        305,
        489 + shift,
        352,
        428 + shift,
        349,
        403 + shift,
        324,
      })
    )
  )
  add(
    p,
    part(
      'handRight',
      'torso',
      'flesh',
      raw({
        615 + shift,
        272,
        642 + shift,
        275,
        675 + shift,
        333,
        665 + shift,
        385,
        604 + shift,
        366,
        600 + shift,
        320,
      })
    )
  )
  -- Skulls are traced in pixels of the idle sheet itself.
  local s = idleHeads[k]
  local u1, v1 = Author.fromPixels(Layout.frames[index], s[1], s[2])
  local u2, v2 = Author.fromPixels(Layout.frames[index], s[3], s[4])
  add(p, box('head', 'head', 'flesh', u1, v1, u2, v2))
  Armored.frames[index] = { parts = p }
end
-- Free cloth outside the body does not grant an armour contact. Anatomy
-- above these two backdrop regions overrides them where actual limbs or
-- the skull cover the cloak. Cloth over the body still represents that body.
local chests = {
  [1] = { 110, 72, 178, 142 },
  [3] = { 90, 75, 145, 136 },
  [4] = { 100, 70, 153, 135 },
  [5] = { 80, 75, 144, 131 },
  [6] = { 89, 68, 147, 135 },
  [7] = { 100, 80, 181, 152 },
  [9] = { 104, 77, 180, 155 },
  [11] = { 105, 78, 179, 150 },
  [12] = { 100, 72, 155, 140 },
  [13] = { 90, 42, 176, 138 },
  [14] = { 120, 68, 190, 145 },
  [15] = { 109, 62, 180, 161 },
}
for index, frame in ipairs(Armored.frames) do
  if index <= 15 or index >= 19 then
    local left = part(
      'looseCloakLeft',
      false,
      'cloth',
      { 0, 0.12, 0.38, 0.12, 0.37, 0.40, 0.43, 0.55, 0.38, 0.88, 0, 1 }
    )
    local right =
      part('looseCloakRight', false, 'cloth', { 0.70, 0.42, 0.82, 0.50, 1, 1, 0.65, 1, 0.62, 0.65 })
    left.hittable, right.hittable = false, false
    table.insert(frame.parts, 2, right)
    table.insert(frame.parts, 2, left)
    local chest = chests[index] or (index >= 19 and index <= 24 and { 104, 43, 173, 136 })
    local torso
    if chest then
      torso = convert(index, { base()[1], box('torso', 'torso', 'metal', unpack(chest)) }).parts[2]
    else
      torso = box('torso', 'torso', 'metal', 0.40, 0.26, 0.69, 0.57)
    end
    table.insert(frame.parts, 4, torso)
  end
end
return Armored

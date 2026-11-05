-- Armour, exposed skull and hands marked against each authored painting.
-- Source alpha supplies the contour and all gaps; polygons assign anatomy.
-- Every point is traced on the owner's original 6x4 painting. The runtime
-- copy adds one transparent pixel around each cell, without repainting it.
local Sheet = require('src.content.art.sheet')
local Reference = require('src.content.art.sheets.armored').sources[1]
local Author = require('src.content.art.anatomy.author')
local Armored = { frames = {} }
local part, box = Author.part, Author.box
local GRID, GUTTER = { 6, 4 }, 1
local function add(p, r)
  p[#p + 1] = r
end
local function base()
  -- Explicit torso fallback covers the integrated mail and cloth over armour.
  return { box('bodyFallback', 'torso', 'metal', 0, 0, 1, 1) }
end
local function convert(index, p, claw)
  local x0, x1, y0, y1 = Sheet.cut(Reference, index)
  local col, row = (index - 1) % GRID[1], math.floor((index - 1) / GRID[1])
  local function point(x, y)
    return (col * 256 + x - x0 + GUTTER) / (x1 - x0 + 1 + 2 * GUTTER),
      (row * 256 + y - y0 + GUTTER) / (y1 - y0 + 1 + 2 * GUTTER)
  end
  for i = 2, #p do
    local polygon = p[i].polygon
    for k = 1, #polygon, 2 do
      polygon[k], polygon[k + 1] = point(polygon[k], polygon[k + 1])
    end
  end
  return {
    parts = p,
    anchors = claw and {
      claw = { point(claw[1], claw[2]) },
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
-- The owner-selected original cells replace every later repaint. Coordinates
-- are traced on that 6x4 image; alpha still supplies all gaps and contours.
local original = {
  [2] = {
    head = { 145, 28, 169, 72 },
    legs = {
      { 103, 118, 140, 126, 147, 171, 133, 208, 138, 252, 112, 252, 113, 211, 109, 177 },
      { 135, 127, 158, 147, 155, 185, 138, 188, 140, 165 },
    },
    arms = { { 83, 75, 110, 94, 105, 150, 84, 161 }, { 171, 76, 193, 94, 214, 135, 201, 147 } },
    hands = { { 80, 151, 109, 191 }, { 198, 127, 223, 180 } },
  },
  [8] = {
    head = { 90, 73, 116, 111 },
    legs = {
      { 84, 157, 124, 159, 133, 194, 119, 221, 134, 253, 101, 253, 92, 221, 94, 193, 74, 186 },
      { 140, 157, 170, 161, 185, 200, 212, 239, 193, 250, 162, 220, 149, 189 },
    },
    arms = {
      { 61, 124, 87, 125, 70, 160, 57, 182, 44, 176 },
      { 137, 55, 157, 52, 167, 89, 149, 105 },
    },
    hands = { { 39, 174, 75, 225 }, { 146, 1, 208, 62 } },
    claw = { 160, 43 },
  },
  [10] = {
    head = { 146, 40, 175, 88 },
    legs = {
      { 109, 169, 147, 164, 162, 203, 156, 254, 113, 254, 105, 216 },
    },
    arms = {
      { 82, 67, 121, 72, 151, 114, 133, 141, 92, 126, 74, 102 },
      { 181, 76, 212, 83, 231, 111, 216, 130 },
    },
    hands = { { 128, 112, 213, 213 }, { 217, 100, 248, 153 } },
    claw = { 141, 134 },
  },
  [17] = {
    head = { 45, 158, 86, 181 },
    legs = {
      { 144, 151, 178, 151, 218, 174, 255, 166, 255, 196, 216, 202, 180, 184, 155, 188 },
      { 152, 183, 181, 174, 206, 188, 212, 204, 196, 210, 167, 199 },
    },
    arms = { { 86, 159, 112, 161, 127, 190, 109, 207, 78, 208, 75, 193 } },
    hands = { { 0, 184, 48, 218 }, { 43, 199, 96, 225 } },
  },
  [18] = {
    head = { 44, 192, 77, 215 },
    legs = {
      { 119, 173, 156, 171, 199, 182, 238, 180, 247, 197, 208, 205, 172, 195, 133, 198 },
    },
    arms = { { 79, 180, 105, 176, 122, 199, 151, 205, 141, 221, 101, 215, 83, 202 } },
    hands = { { 131, 202, 209, 226 } },
  },
}
for index, mark in pairs(original) do
  local p = base()
  for i, poly in ipairs(mark.legs) do
    add(p, part('leg' .. i, 'lower', 'metal', poly))
  end
  for i, poly in ipairs(mark.arms) do
    add(p, part('arm' .. i, 'torso', 'metal', poly))
  end
  for i, rect in ipairs(mark.hands) do
    add(p, box('hand' .. i, 'torso', 'flesh', unpack(rect)))
  end
  add(p, box('head', 'head', 'flesh', unpack(mark.head)))
  Armored.frames[index] = convert(index, p, mark.claw)
end
-- Free cloth outside the body does not grant an armour contact. Anatomy
-- above these two backdrop regions overrides them where actual limbs or
-- the skull cover the cloak. Cloth over the body still represents that body.
local chests = {
  [1] = { 110, 72, 178, 142 },
  [2] = { 105, 72, 174, 150 },
  [8] = { 92, 115, 157, 170 },
  [10] = { 110, 82, 188, 172 },
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
    -- Preserve the original backdrop UV through the transparent gutter.
    local x0, x1, y0, y1 = Sheet.cut(Reference, index)
    local w, h = x1 - x0 + 1, y1 - y0 + 1
    for _, cloth in ipairs({ left, right }) do
      for k = 1, #cloth.polygon, 2 do
        cloth.polygon[k] = (cloth.polygon[k] * w + GUTTER) / (w + 2 * GUTTER)
        cloth.polygon[k + 1] = (cloth.polygon[k + 1] * h + GUTTER) / (h + 2 * GUTTER)
      end
    end
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
-- Quiet breathing reuses the approved carry cells, without changing their pixels.
local Copy = require('src.core.schema').copy
for k, index in ipairs({ 1, 3, 4, 6 }) do
  Armored.frames[24 + k] = Copy(Armored.frames[index])
end
return Armored

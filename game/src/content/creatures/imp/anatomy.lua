-- Anatomical paint regions traced against the imp sheets, never hit volumes.
-- The atlas poses are traced in pixels of their cell of the 6 x 4 drawing
-- grid (content/art/anatomy/author.lua: cellPolygon converts them to frame
-- UV); replacements are traced directly in frame UV. Source alpha clips
-- every polygon.
local Layout = require('src.content.art.enemy_frames').imp
local Author = require('src.content.art.anatomy.author')
local Imp = { frames = {} }
local part, box = Author.part, Author.box
local GRID = { 6, 4 }
local function base()
  return { part('bodyFallback', 'torso', 'flesh', { 0, 0, 1, 0, 1, 1, 0, 1 }) }
end
-- Painted heads and horn roots; rows are individual authored poses.
local skulls = {
  { 140, 35, 204, 81 },
  { 137, 36, 194, 82 },
  { 139, 34, 192, 81 },
  { 139, 35, 192, 82 },
  { 139, 36, 208, 83 },
  { 139, 35, 208, 84 },
  { 141, 54, 211, 99 },
  { 141, 60, 199, 103 },
  { 142, 65, 196, 110 },
  false,
  false,
  { 149, 71, 201, 121 },
  { 90, 4, 146, 60 },
  { 130, 82, 174, 128 },
  { 147, 126, 194, 178 },
  { 177, 174, 219, 216 },
  { 175, 178, 219, 221 },
  { 174, 179, 222, 218 },
  { 115, 16, 151, 45 },
  { 112, 16, 151, 46 },
  { 112, 16, 151, 46 },
  { 111, 16, 154, 47 },
  { 113, 17, 153, 48 },
  { 113, 17, 154, 48 },
}
local horns = {
  { 115, 0, 147, 44, 169, 4, 181, 45 },
  { 103, 0, 146, 44, 148, 0, 177, 45 },
  { 112, 0, 151, 42, 151, 0, 176, 42 },
  { 109, 0, 150, 43, 148, 0, 175, 43 },
  { 106, 0, 151, 43, 149, 0, 177, 44 },
  { 110, 0, 154, 43, 151, 0, 183, 44 },
  { 116, 4, 161, 65, 155, 9, 184, 65 },
  { 102, 26, 148, 68, 148, 30, 174, 68 },
  { 131, 34, 169, 77, 166, 36, 190, 76 },
  false,
  false,
  { 141, 37, 170, 86, 172, 34, 193, 87 },
  { 30, 23, 103, 74, 55, 5, 107, 34 },
  { 138, 78, 151, 91, 159, 99, 168, 121 },
  { 162, 78, 195, 139, 185, 95, 214, 153 },
  { 177, 166, 200, 188, 218, 161, 245, 194 },
  { 166, 168, 195, 193, 212, 162, 243, 199 },
  { 175, 164, 200, 189, 211, 167, 238, 193 },
  { 91, 0, 125, 30, 143, 0, 171, 31 },
  { 86, 0, 122, 32, 143, 0, 174, 32 },
  { 88, 0, 122, 31, 144, 0, 173, 31 },
  { 88, 0, 123, 32, 147, 0, 176, 33 },
  { 94, 0, 127, 32, 142, 0, 173, 34 },
  { 91, 0, 128, 34, 144, 0, 176, 34 },
}
local function add(parts, p)
  parts[#parts + 1] = p
end
-- Grid-cell pixels to frame UV for every part after the frame-wide fallback.
local function convert(index, parts)
  for i = 2, #parts do
    parts[i].polygon =
      Author.cellPolygon(Layout.frames[index], index, GRID[1], GRID[2], parts[i].polygon)
  end
  return { parts = parts }
end
local function upright(index)
  local p = base()
  add(p, part('wingLeft', 'torso', 'membrane', { 36, 47, 113, 40, 137, 92, 96, 146, 39, 158 }))
  add(p, part('wingRight', 'torso', 'membrane', { 161, 50, 190, 66, 194, 147, 163, 143 }))
  add(p, part('tail', 'torso', 'flesh', { 3, 147, 65, 148, 121, 123, 111, 186, 30, 219, 2, 202 }))
  add(
    p,
    part('torso', 'torso', 'flesh', { 107, 73, 151, 72, 172, 104, 148, 149, 107, 143, 97, 114 })
  )
  add(
    p,
    part(
      'legRear',
      'lower',
      'flesh',
      { 103, 136, 131, 151, 120, 191, 91, 220, 111, 251, 74, 253, 67, 219, 93, 183 }
    )
  )
  add(
    p,
    part(
      'legFront',
      'lower',
      'flesh',
      { 112, 134, 137, 140, 154, 179, 148, 216, 181, 252, 137, 255, 132, 220, 131, 190, 104, 160 }
    )
  )
  add(
    p,
    part(
      'armLeft',
      'torso',
      'flesh',
      { 105, 70, 123, 89, 93, 123, 83, 160, 88, 180, 68, 196, 50, 184, 64, 151, 72, 109 }
    )
  )
  add(
    p,
    part(
      'armRight',
      'torso',
      'flesh',
      { 161, 87, 173, 100, 180, 123, 205, 141, 234, 166, 234, 206, 205, 199, 200, 161, 166, 139 }
    )
  )
  local s = skulls[index]
  add(p, box('head', 'head', 'flesh', unpack(s)))
  local h = horns[index]
  add(p, box('hornLeft', 'torso', 'horn', unpack(h, 1, 4)))
  add(p, box('hornRight', 'torso', 'horn', unpack(h, 5, 8)))
  return p
end
for _, index in ipairs({ 1, 2, 3, 4, 5, 6, 12 }) do
  Imp.frames[index] = convert(index, upright(index))
end
-- Wind-up arms have their own drawn path; do not reuse the resting hands.
for _, index in ipairs({ 7, 8, 9 }) do
  local p = upright(index)
  table.remove(p, #p)
  table.remove(p, #p)
  table.remove(p, #p)
  for i = #p, 1, -1 do
    if p[i].id == 'armLeft' then
      table.remove(p, i)
    end
  end
  if index == 7 then
    add(
      p,
      part(
        'armLeft',
        'torso',
        'flesh',
        { 23, 109, 38, 65, 80, 32, 124, 53, 137, 76, 111, 85, 82, 54, 52, 78, 48, 122 }
      )
    )
  else
    local dx = index == 8 and 0 or -8
    add(
      p,
      part('armLeft', 'torso', 'flesh', {
        47 + dx,
        14,
        102 + dx,
        0,
        118 + dx,
        33,
        77 + dx,
        35,
        65 + dx,
        74,
        116,
        88,
        112,
        110,
        48 + dx,
        96,
        42 + dx,
        58,
      })
    )
  end
  add(p, box('head', 'head', 'flesh', unpack(skulls[index])))
  add(p, box('hornLeft', 'torso', 'horn', unpack(horns[index], 1, 4)))
  add(p, box('hornRight', 'torso', 'horn', unpack(horns[index], 5, 8)))
  Imp.frames[index] = convert(index, p)
end
-- The chest, legs and hands in collapse poses are measured separately.
local prone = {
  [13] = {
    {
      'legRear',
      'lower',
      { 100, 119, 143, 146, 147, 189, 106, 219, 111, 241, 78, 242, 78, 217, 108, 173 },
    },
    {
      'legFront',
      'lower',
      { 146, 126, 177, 144, 202, 181, 195, 219, 216, 231, 179, 237, 173, 209, 177, 181, 145, 161 },
    },
    { 'armLeft', 'torso', { 87, 54, 113, 56, 115, 92, 158, 67, 170, 88, 118, 121, 91, 101 } },
  },
  [14] = {
    { 'legRear', 'lower', { 82, 139, 110, 145, 117, 175, 113, 205, 113, 228, 72, 231, 74, 196 } },
    {
      'legFront',
      'lower',
      { 88, 126, 120, 137, 145, 169, 142, 212, 167, 230, 123, 234, 125, 186, 98, 163 },
    },
    { 'armLeft', 'torso', { 108, 93, 133, 91, 143, 140, 173, 161, 166, 179, 132, 151, 115, 122 } },
    {
      'armRight',
      'torso',
      { 146, 113, 162, 123, 185, 166, 209, 210, 213, 231, 187, 223, 180, 186, 153, 156 },
    },
  },
  [15] = {
    {
      'legRear',
      'lower',
      { 84, 150, 104, 169, 101, 198, 71, 213, 48, 216, 42, 231, 25, 222, 31, 191, 70, 197 },
    },
    { 'legFront', 'lower', { 90, 143, 125, 164, 135, 191, 117, 210, 87, 215, 75, 190 } },
    {
      'armLeft',
      'torso',
      { 130, 116, 149, 123, 150, 170, 161, 209, 185, 226, 184, 238, 151, 231, 139, 207, 124, 163 },
    },
    {
      'armRight',
      'torso',
      { 174, 165, 185, 173, 197, 210, 223, 216, 227, 229, 194, 229, 180, 203 },
    },
  },
  [16] = {
    {
      'legRear',
      'lower',
      { 41, 181, 83, 169, 105, 188, 98, 216, 58, 225, 15, 229, 0, 224, 7, 202, 46, 207 },
    },
    { 'legFront', 'lower', { 81, 168, 105, 168, 119, 205, 97, 229, 62, 236, 41, 225, 82, 215 } },
    {
      'armLeft',
      'torso',
      { 147, 160, 168, 172, 174, 200, 197, 214, 242, 207, 251, 224, 204, 228, 165, 218, 147, 197 },
    },
  },
}
for index = 13, 18 do
  local p = base()
  if index <= 15 then
    add(p, box('wingLeft', 'torso', 'membrane', 23, 32, 107, 175))
    add(p, box('wingRight', 'torso', 'membrane', 156, 59, 192, 160))
    add(p, box('tail', 'torso', 'flesh', 0, 165, 84, 231))
  else
    add(p, box('wingLeft', 'torso', 'membrane', 71, 105, 196, 164))
    add(p, box('tail', 'torso', 'flesh', 15, 83, 87, 186))
  end
  for _, region in ipairs(prone[index] or prone[16]) do
    add(p, part(region[1], region[2], 'flesh', region[3]))
  end
  add(p, box('head', 'head', 'flesh', unpack(skulls[index])))
  add(p, box('hornLeft', 'torso', 'horn', unpack(horns[index], 1, 4)))
  add(p, box('hornRight', 'torso', 'horn', unpack(horns[index], 5, 8)))
  Imp.frames[index] = convert(index, p)
end
for index = 19, 24 do
  local p = base()
  add(p, box('wingLeft', 'torso', 'membrane', 44, 30, 112, 145))
  add(p, box('wingRight', 'torso', 'membrane', 152, 29, 199, 142))
  add(p, box('tail', 'torso', 'flesh', 135, 126, 244, 218))
  add(p, box('torso', 'torso', 'flesh', 104, 36, 154, 125))
  add(
    p,
    part(
      'legLeft',
      'lower',
      'flesh',
      { 106, 103, 133, 113, 133, 173, 121, 218, 143, 243, 100, 245, 100, 215, 104, 169 }
    )
  )
  add(
    p,
    part(
      'legRight',
      'lower',
      'flesh',
      { 134, 104, 155, 110, 161, 165, 150, 216, 169, 243, 132, 249, 128, 215, 135, 170 }
    )
  )
  add(p, box('armLeft', 'torso', 'flesh', 43, 69, 105, 177))
  add(p, box('armRight', 'torso', 'flesh', 153, 73, 197, 180))
  add(p, box('head', 'head', 'flesh', unpack(skulls[index])))
  add(p, box('hornLeft', 'torso', 'horn', unpack(horns[index], 1, 4)))
  add(p, box('hornRight', 'torso', 'horn', unpack(horns[index], 5, 8)))
  Imp.frames[index] = convert(index, p)
end
-- Supplementary strike paintings have different framing and foreshortened arms.
local function strike(frame)
  local p = base()
  add(
    p,
    part(
      'wingLeft',
      'torso',
      'membrane',
      { 0.25, 0.49, 0.30, 0.29, 0.51, 0.10, 0.64, 0.21, 0.52, 0.36 }
    )
  )
  add(p, box('wingRight', 'torso', 'membrane', 0.72, 0.11, 0.85, 0.44))
  add(p, box('tail', 'torso', 'flesh', 0.08, 0.47, 0.48, 0.73))
  add(
    p,
    part('legRear', 'lower', 'flesh', {
      0.61,
      0.50,
      0.69,
      0.51,
      0.79,
      0.66,
      0.73,
      0.79,
      0.82,
      0.91,
      0.66,
      0.89,
      0.61,
      0.81,
      0.66,
      0.68,
    })
  )
  add(
    p,
    part('legFront', 'lower', 'flesh', {
      0.46,
      0.46,
      0.61,
      0.50,
      0.61,
      0.64,
      0.52,
      0.81,
      0.57,
      0.98,
      0.35,
      0.99,
      0.38,
      0.85,
      0.43,
      0.68,
    })
  )
  add(
    p,
    part('armRight', 'torso', 'flesh', {
      0.70,
      0.28,
      0.76,
      0.29,
      0.81,
      0.40,
      0.87,
      0.43,
      0.87,
      0.61,
      0.76,
      0.57,
      0.72,
      0.49,
      0.75,
      0.42,
    })
  )
  if frame == 10 then
    add(
      p,
      part(
        'armLeft',
        'torso',
        'flesh',
        { 0.48, 0.19, 0.59, 0.20, 0.64, 0.29, 0.65, 0.40, 0.53, 0.38, 0.43, 0.38, 0.43, 0.26 }
      )
    )
    add(p, box('head', 'head', 'flesh', 0.57, 0.12, 0.79, 0.30))
    add(p, box('hornLeft', 'torso', 'horn', 0.44, 0.0, 0.68, 0.15))
    add(p, box('hornRight', 'torso', 'horn', 0.65, 0.0, 0.74, 0.15))
  else
    add(
      p,
      part('armLeft', 'torso', 'flesh', {
        0.47,
        0.20,
        0.58,
        0.21,
        0.64,
        0.32,
        0.78,
        0.41,
        0.88,
        0.49,
        0.91,
        0.66,
        0.76,
        0.65,
        0.74,
        0.50,
        0.59,
        0.42,
        0.47,
        0.31,
      })
    )
    add(p, box('head', 'head', 'flesh', 0.60, 0.15, 0.81, 0.30))
    add(p, box('hornLeft', 'torso', 'horn', 0.45, 0.01, 0.69, 0.17))
    add(p, box('hornRight', 'torso', 'horn', 0.58, 0.04, 0.77, 0.17))
  end
  return { parts = p, anchors = { claw = frame == 10 and { 0.54, 0.31 } or { 0.84, 0.52 } } }
end
Imp.frames[10], Imp.frames[11] = strike(10), strike(11)
for index, point in pairs({ [9] = { 91, 32 }, [12] = { 82, 177 } }) do
  Imp.frames[index].anchors = {
    claw = { Author.fromCell(Layout.frames[index], index, GRID[1], GRID[2], point[1], point[2]) },
  }
end
-- Idle crops: trace normalized to the actual exported cell (including its gutters).
local idleHeads = {
  { 0.49, 0.13, 0.72, 0.29 },
  { 0.49, 0.12, 0.72, 0.29 },
  { 0.50, 0.13, 0.75, 0.31 },
  {
    0.50,
    0.14,
    0.75,
    0.32,
  },
}
for index = 25, 28 do
  local p = base()
  add(
    p,
    part(
      'wingLeft',
      'torso',
      'membrane',
      { 0.20, 0.54, 0.22, 0.34, 0.42, 0.15, 0.52, 0.25, 0.39, 0.45 }
    )
  )
  add(p, box('wingRight', 'torso', 'membrane', 0.59, 0.20, 0.70, 0.55))
  add(p, box('tail', 'torso', 'flesh', 0.10, 0.59, 0.43, 0.90))
  add(
    p,
    part('legRear', 'lower', 'flesh', {
      0.40,
      0.52,
      0.53,
      0.61,
      0.49,
      0.76,
      0.38,
      0.87,
      0.43,
      0.96,
      0.29,
      0.96,
      0.28,
      0.85,
      0.38,
      0.73,
    })
  )
  add(
    p,
    part('legFront', 'lower', 'flesh', {
      0.43,
      0.51,
      0.57,
      0.57,
      0.61,
      0.68,
      0.57,
      0.87,
      0.66,
      0.98,
      0.49,
      0.99,
      0.47,
      0.88,
      0.52,
      0.72,
      0.42,
      0.63,
    })
  )
  add(
    p,
    part('armLeft', 'torso', 'flesh', {
      0.43,
      0.25,
      0.51,
      0.28,
      0.41,
      0.40,
      0.35,
      0.58,
      0.36,
      0.72,
      0.27,
      0.76,
      0.23,
      0.66,
      0.29,
      0.50,
      0.32,
      0.36,
    })
  )
  add(
    p,
    part('armRight', 'torso', 'flesh', {
      0.61,
      0.33,
      0.66,
      0.38,
      0.68,
      0.49,
      0.80,
      0.57,
      0.85,
      0.68,
      0.83,
      0.83,
      0.71,
      0.78,
      0.70,
      0.64,
      0.61,
      0.55,
    })
  )
  add(p, box('head', 'head', 'flesh', unpack(idleHeads[index - 24])))
  add(p, box('hornLeft', 'torso', 'horn', 0.40, 0.0, 0.61, 0.15))
  add(p, box('hornRight', 'torso', 'horn', 0.57, 0.02, 0.68, 0.16))
  Imp.frames[index] = { parts = p }
end
return Imp

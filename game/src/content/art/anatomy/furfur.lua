-- Deer anatomy measured on the original/idle source paintings. The skull is
-- distinct from branching antlers; four independent legs never fill their gaps.
local Author = require('src.content.art.anatomy.author')
local Frames = require('src.content.art.enemy_frames').furfur.frames
local Furfur = { frames = {} }
-- Absolute source-pixel skull bounds, checked on each source image/crop.
local skulls = {
  { 226, 91, 277, 145 },
  { 487, 93, 533, 145 },
  { 716, 91, 764, 143 },
  { 960, 91, 1008, 143 },
  { 1221, 97, 1270, 147 },
  { 1468, 91, 1518, 143 },
  { 232, 319, 282, 350 },
  { 461, 307, 509, 338 },
  { 670, 275, 724, 314 },
  { 962, 419, 1000, 475 },
  { 1262, 395, 1308, 444 },
  { 1470, 349, 1519, 391 },
  { 191, 536, 246, 577 },
  { 412, 547, 461, 592 },
  { 701, 598, 752, 640 },
  { 964, 697, 1010, 735 },
  { 1220, 697, 1270, 735 },
  { 1475, 702, 1525, 737 },
  { 224, 826, 261, 868 },
  { 464, 821, 503, 863 },
  { 694, 825, 734, 867 },
  { 951, 817, 990, 861 },
  { 1233, 828, 1275, 871 },
  { 1478, 825, 1521, 869 },
  { 553, 169, 647, 270 },
  { 1289, 166, 1386, 267 },
  { 573, 633, 670, 710 },
  { 1300, 663, 1395, 766 },
}
-- Four leg paths per pose: haunch/knee to hoof, in local UV.
local walks = {
  {
    { 0.43, 0.61, 0.24, 0.94 },
    { 0.48, 0.64, 0.55, 0.95 },
    { 0.67, 0.64, 0.63, 0.88 },
    {
      0.72,
      0.65,
      0.80,
      0.96,
    },
  },
  {
    { 0.42, 0.62, 0.18, 0.96 },
    { 0.47, 0.65, 0.51, 0.96 },
    { 0.68, 0.63, 0.75, 0.95 },
    {
      0.73,
      0.64,
      0.86,
      0.94,
    },
  },
  {
    { 0.40, 0.63, 0.20, 0.98 },
    { 0.49, 0.65, 0.60, 0.97 },
    { 0.70, 0.63, 0.79, 0.98 },
    {
      0.73,
      0.65,
      0.69,
      0.86,
    },
  },
  {
    { 0.40, 0.62, 0.20, 0.97 },
    { 0.46, 0.64, 0.52, 0.96 },
    { 0.65, 0.61, 0.71, 0.95 },
    {
      0.73,
      0.64,
      0.82,
      0.89,
    },
  },
  {
    { 0.40, 0.64, 0.21, 0.98 },
    { 0.47, 0.65, 0.58, 0.98 },
    { 0.68, 0.66, 0.72, 0.97 },
    {
      0.73,
      0.67,
      0.85,
      0.94,
    },
  },
  {
    { 0.38, 0.61, 0.17, 0.96 },
    { 0.46, 0.64, 0.52, 0.95 },
    { 0.66, 0.63, 0.74, 0.95 },
    {
      0.72,
      0.64,
      0.88,
      0.94,
    },
  },
}
local active = {
  [7] = {
    { 0.41, 0.66, 0.25, 0.99 },
    { 0.49, 0.69, 0.57, 0.98 },
    { 0.72, 0.62, 0.78, 0.86 },
    {
      0.73,
      0.64,
      0.73,
      0.94,
    },
  },
  [8] = {
    { 0.39, 0.68, 0.21, 0.99 },
    { 0.47, 0.69, 0.56, 0.99 },
    { 0.70, 0.50, 0.85, 0.65 },
    {
      0.73,
      0.47,
      0.93,
      0.62,
    },
  },
  [9] = {
    { 0.37, 0.71, 0.25, 0.99 },
    { 0.46, 0.72, 0.59, 0.99 },
    { 0.66, 0.45, 0.75, 0.67 },
    {
      0.70,
      0.40,
      0.91,
      0.55,
    },
  },
  [10] = {
    { 0.33, 0.61, 0.10, 0.99 },
    { 0.46, 0.66, 0.40, 0.99 },
    { 0.61, 0.75, 0.59, 0.99 },
    {
      0.69,
      0.76,
      0.86,
      0.99,
    },
  },
  [11] = {
    { 0.35, 0.66, 0.06, 0.94 },
    { 0.42, 0.68, 0.19, 0.91 },
    { 0.64, 0.72, 0.95, 0.91 },
    {
      0.65,
      0.74,
      0.88,
      0.98,
    },
  },
  [12] = {
    { 0.35, 0.66, 0.15, 0.99 },
    { 0.43, 0.70, 0.49, 0.99 },
    { 0.65, 0.64, 0.69, 0.99 },
    {
      0.69,
      0.65,
      0.88,
      0.99,
    },
  },
  [13] = {
    { 0.39, 0.69, 0.22, 0.99 },
    { 0.48, 0.73, 0.64, 0.98 },
    { 0.72, 0.49, 0.92, 0.62 },
    {
      0.74,
      0.51,
      0.87,
      0.99,
    },
  },
  [14] = {
    { 0.34, 0.69, 0.06, 0.94 },
    { 0.42, 0.75, 0.58, 0.94 },
    { 0.65, 0.69, 0.78, 0.99 },
    {
      0.68,
      0.69,
      0.91,
      0.99,
    },
  },
  [15] = {
    { 0.30, 0.80, 0.02, 0.95 },
    { 0.39, 0.81, 0.44, 0.96 },
    { 0.62, 0.81, 0.84, 0.96 },
    {
      0.69,
      0.82,
      0.95,
      0.95,
    },
  },
}
-- Antlers rotate independently of the torso. These outlines are especially
-- important in rearing/charging poses, where a standing box would cover ribs.
local antlers = {
  [7] = { 0.45, 0.04, 0.97, 0.04, 0.97, 0.25, 0.81, 0.28, 0.71, 0.35, 0.58, 0.38, 0.45, 0.32 },
  [8] = { 0.33, 0.04, 0.81, 0.04, 0.81, 0.20, 0.65, 0.24, 0.55, 0.34, 0.37, 0.37, 0.29, 0.29 },
  [9] = { 0.25, 0.00, 0.72, 0.00, 0.72, 0.12, 0.58, 0.15, 0.49, 0.26, 0.31, 0.29, 0.23, 0.22 },
  [10] = { 0.52, 0.27, 0.99, 0.27, 0.99, 0.66, 0.86, 0.65, 0.78, 0.51, 0.66, 0.46, 0.52, 0.45 },
  [12] = { 0.32, 0.02, 0.95, 0.02, 0.95, 0.30, 0.76, 0.30, 0.55, 0.26, 0.32, 0.20 },
  [13] = { 0.32, 0.00, 0.77, 0.00, 0.77, 0.17, 0.63, 0.22, 0.56, 0.39, 0.42, 0.42, 0.32, 0.33 },
  [14] = { 0.28, 0.00, 0.72, 0.00, 0.72, 0.23, 0.58, 0.28, 0.48, 0.44, 0.32, 0.47, 0.24, 0.37 },
  [15] = { 0.29, 0.11, 0.78, 0.11, 0.78, 0.40, 0.61, 0.44, 0.48, 0.55, 0.30, 0.58, 0.24, 0.47 },
}
local bentShins = {
  [2] = { { 0.75, 0.77, 0.72, 0.97 } },
  [4] = { { 0.79, 0.74, 0.91, 0.86 } },
  [7] = { { 0.87, 0.72, 0.82, 0.88 } },
  [8] = { { 0.91, 0.53, 0.87, 0.68 } },
  [9] = { { 0.87, 0.47, 0.91, 0.58 } },
  [10] = { { 0.34, 0.76, 0.39, 0.98 } },
  [12] = { { 0.63, 0.78, 0.62, 0.99 } },
  [13] = { { 0.92, 0.61, 0.87, 0.77 } },
  [14] = { { 0.78, 0.80, 0.87, 0.98 } },
}
for i, b in ipairs(skulls) do
  -- Skulls are traced in pixels of the atlas itself.
  local left, top = Author.fromPixels(Frames[i], b[1], b[2])
  local right, bottom = Author.fromPixels(Frames[i], b[3], b[4])
  local p = { Author.body('flesh') }
  local hornPolygon = antlers[i]
  if not hornPolygon then
    local lowered = i >= 10 and i <= 18
    hornPolygon = {
      math.max(0, left - 0.50),
      math.max(0, top - 0.58),
      math.min(1, right + 0.07),
      math.max(0, top - 0.58),
      math.min(1, right + 0.07),
      top + 0.02,
      left - 0.025,
      top + 0.02,
      left - 0.13,
      top - (lowered and 0.12 or -0.02),
      left - 0.40,
      top - (lowered and 0.24 or -0.02),
    }
  end
  p[#p + 1] = Author.part('antlers', 'torso', 'horn', hornPolygon)
  p[#p + 1] =
    Author.box('ears', 'torso', 'flesh', left - 0.11, top - 0.015, left + 0.015, top + 0.09)
  local legs = active[i] or walks[(i - 1) % 6 + 1]
  if i >= 16 and i <= 18 then
    legs = {
      { 0.30, 0.81, 0.02, 0.91 },
      { 0.42, 0.86, 0.24, 0.94 },
      { 0.65, 0.86, 0.43, 0.95 },
      {
        0.71,
        0.85,
        0.80,
        0.93,
      },
    }
  elseif i >= 19 and i <= 24 then
    legs = {
      { 0.39, 0.62, 0.22, 0.98 },
      { 0.46, 0.65, 0.60, 0.99 },
      { 0.66, 0.56, 0.70, 0.88 },
      {
        0.71,
        0.56,
        0.80,
        0.75,
      },
    }
  elseif i >= 25 then
    legs = {
      { 0.36, 0.60, 0.16, 0.99 },
      { 0.43, 0.64, 0.53, 0.99 },
      { 0.61, 0.63, 0.64, 0.99 },
      {
        0.67,
        0.64,
        0.81,
        0.99,
      },
    }
  end
  for n, l in ipairs(legs) do
    p[#p + 1] = Author.segment('leg-' .. n, 'lower', 'flesh', l[1], l[2], l[3], l[4], 0.060)
  end
  for n, l in ipairs(bentShins[i] or {}) do
    p[#p + 1] = Author.segment('shin-' .. n, 'lower', 'flesh', l[1], l[2], l[3], l[4], 0.055)
  end
  p[#p + 1] = Author.box('head', 'head', 'bone', left, top, right, bottom)
  local flameRight = i >= 25 and 0.15 or 0.20
  p[#p + 1] = Author.effect('tail-flame', { 0, 0.08, flameRight, 0.08, flameRight, 0.62, 0, 0.67 })
  if i >= 13 and i <= 18 then
    local flameBottom = i >= 16 and 0.77 or 0.86
    p[#p] = Author.effect('tail-flame', { 0, 0.32, 0.18, 0.32, 0.18, flameBottom, 0, flameBottom })
  end
  Furfur.frames[i] = { parts = p }
end
-- Lunge contact follows the painted muzzle. Depth remains authored action reach.
Furfur.frames[9].anchors = { claw = { 0.81, 0.22 } }
Furfur.frames[10].anchors = { claw = { 0.89, 0.81 } }
Furfur.frames[11].anchors = { claw = { 0.95, 0.70 } }
Furfur.frames[12].anchors = { claw = { 0.91, 0.49 } }
-- Supplemental breath changes interior pigment only, with identical source UV anatomy.
for i, base in ipairs({ 9, 9, 9, 13, 13, 13, 12, 12, 12 }) do
  Furfur.frames[28 + i] = require('src.core.schema').copy(Furfur.frames[base])
end
return Furfur

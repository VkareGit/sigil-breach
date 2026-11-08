-- Four-legged gardener: annotations are source-UV silhouettes, not humanoid bands.
-- All original, collapse, rear and idle crops inspected in work/anatomy-contact/buer.png.
local Author = require('src.content.art.anatomy.author')
local Buer = { frames = {} }
local heads = {
  { 0.661, 0.277, 0.515, 0.080 },
  { 0.707, 0.296, 0.507, 0.080 },
  { 0.731, 0.315, 0.525, 0.080 },
  { 0.723, 0.300, 0.514, 0.080 },
  { 0.562, 0.209, 0.400, 0.083 },
  { 0.512, 0.196, 0.373, 0.099 },
  { 0.637, 0.292, 0.474, 0.086 },
  { 0.685, 0.378, 0.549, 0.082 },
  { 0.409, 0.134, 0.265, 0.091 },
  { 0.548, 0.400, 0.590, 0.085 },
  { 0.735, 0.600, 0.820, 0.094 },
  { 0.737, 0.650, 0.820, 0.091 },
  { 0.578, 0.070, 0.255, 0.110 },
  { 0.538, 0.080, 0.268, 0.110 },
  { 0.553, 0.080, 0.271, 0.110 },
  { 0.629, 0.064, 0.248, 0.095 },
  { 0.666, 0.209, 0.391, 0.069 },
  { 0.658, 0.195, 0.375, 0.067 },
  { 0.720, 0.150, 0.314, 0.062 },
  { 0.658, 0.180, 0.350, 0.063 },
}
local legs = {
  {
    { 0.25, 0.66, 0.14, 0.96 },
    { 0.43, 0.68, 0.30, 0.99 },
    { 0.57, 0.70, 0.64, 0.91 },
    {
      0.71,
      0.67,
      0.87,
      0.98,
    },
  },
  {
    { 0.24, 0.66, 0.13, 0.97 },
    { 0.44, 0.69, 0.48, 0.99 },
    { 0.57, 0.70, 0.37, 0.89 },
    {
      0.71,
      0.69,
      0.86,
      0.97,
    },
  },
  {
    { 0.22, 0.65, 0.10, 0.97 },
    { 0.41, 0.68, 0.22, 0.99 },
    { 0.58, 0.68, 0.63, 0.93 },
    {
      0.72,
      0.65,
      0.83,
      0.96,
    },
  },
  {
    { 0.28, 0.66, 0.18, 0.97 },
    { 0.48, 0.68, 0.30, 0.99 },
    { 0.63, 0.68, 0.65, 0.92 },
    {
      0.76,
      0.66,
      0.89,
      0.97,
    },
  },
}
local arms = {
  { 0.43, 0.44, 0.55, 0.92, 0.76, 0.54, 0.91, 0.78 },
  { 0.47, 0.42, 0.32, 0.88, 0.75, 0.56, 0.91, 0.81 },
  { 0.47, 0.43, 0.60, 0.94, 0.78, 0.58, 0.91, 0.83 },
  { 0.43, 0.43, 0.46, 0.90, 0.79, 0.50, 0.89, 0.74 },
  { 0.39, 0.43, 0.55, 0.51, 0.71, 0.45, 0.52, 0.56 },
  { 0.35, 0.46, 0.17, 0.28, 0.72, 0.45, 0.92, 0.31 },
  { 0.42, 0.44, 0.42, 0.70, 0.67, 0.56, 0.87, 0.79 },
  { 0.45, 0.43, 0.55, 0.91, 0.72, 0.60, 0.82, 0.84 },
  { 0.38, 0.38, 0.54, 0.52, 0.62, 0.37, 0.79, 0.38 },
  { 0.38, 0.47, 0.31, 0.84, 0.64, 0.58, 0.83, 0.94 },
}
for i, h in ipairs(heads) do
  local p = { Author.body('flesh') }
  p[#p + 1] = Author.box(
    'mane',
    'torso',
    'flesh',
    h[1] - 0.26,
    math.max(0, h[2] - 0.13),
    h[1] + 0.19,
    h[4] + h[3]
  )
  p[#p + 1] = Author.part('horn-left', 'torso', 'horn', {
    h[1] - 0.26,
    h[2] - 0.16,
    h[1] - 0.17,
    h[2] - 0.17,
    h[1] - 0.05,
    h[2] + 0.02,
    h[1] - 0.10,
    h[2] + 0.04,
  })
  p[#p + 1] = Author.part('horn-right', 'torso', 'horn', {
    h[1] + 0.04,
    h[2] - 0.02,
    h[1] + 0.14,
    h[2] - 0.09,
    h[1] + 0.21,
    h[2] - 0.06,
    h[1] + 0.20,
    h[2] + 0.12,
    h[1] + 0.17,
    h[2] + 0.12,
    h[1] + 0.18,
    h[2] - 0.02,
    h[1] + 0.12,
    h[2] - 0.03,
    h[1] + 0.08,
    h[2] + 0.02,
  })
  local set = legs[(i - 1) % 4 + 1]
  for n, l in ipairs(set) do
    p[#p + 1] = Author.segment('leg-' .. n, 'lower', 'flesh', l[1], l[2], l[3], l[4], 0.070)
  end
  local a = arms[i]
    or (i >= 17 and { 0.39, 0.42, 0.56, 0.91, 0.76, 0.55, 0.88, 0.84 })
    or { 0.37, 0.36, 0.17, 0.70, 0.72, 0.39, 0.88, 0.70 }
  p[#p + 1] = Author.segment('arm-left', 'torso', 'flesh', a[1], a[2], a[3], a[4], 0.062)
  p[#p + 1] = Author.segment('arm-right', 'torso', 'flesh', a[5], a[6], a[7], a[8], 0.058)
  p[#p + 1] = Author.head(unpack(h))
  Buer.frames[i] = { parts = p }
end
-- Knockdown legs point across the floor; distinct hind and fore limbs remain lower zones.
for _, i in ipairs({ 11, 12 }) do
  local p = {
    Author.body(),
    Author.box('mane', 'torso', 'flesh', 0.54, 0.54, 0.91, 0.94),
    Author.box('horns', 'torso', 'horn', 0.60, 0.48, 0.94, 0.65),
    Author.segment('leg-rear-left', 'lower', 'flesh', 0.38, 0.70, 0.06, 0.83, 0.06),
    Author.segment('leg-rear-right', 'lower', 'flesh', 0.31, 0.67, 0.12, 0.79, 0.06),
    Author.segment('leg-front-left', 'lower', 'flesh', 0.34, 0.53, 0.28, 0.76, 0.08),
    Author.segment('leg-front-right', 'lower', 'flesh', 0.38, 0.71, 0.19, 0.84, 0.06),
    Author.segment('arm-left', 'torso', 'flesh', 0.51, 0.68, 0.49, 0.85, 0.065),
    Author.segment('arm-right', 'torso', 'flesh', 0.50, 0.85, 0.78, 0.88, 0.055),
    Author.head(unpack(heads[i])),
  }
  Buer.frames[i].parts = p
end
table.insert(
  Buer.frames[7].parts,
  Author.effect(
    'painted-spit',
    { 0.650, 0.418, 0.720, 0.385, 1, 0.400, 1, 0.720, 0.900, 0.680, 0.790, 0.555, 0.690, 0.485 }
  )
)
Buer.frames[7].parts[#Buer.frames[7].parts].detached = true
-- Mouth and hand landmarks belong to the unchanged source painting.
for i, frame in ipairs(Buer.frames) do
  local h = heads[i]
  frame.anchors = { mouth = { h[1], h[3] - 0.025 } }
  local a = arms[i]
  if a then
    frame.anchors['seed-hand'] = { a[7], a[8] }
  end
end
Buer.frames[7].anchors.mouth = { 0.650, 0.424 }
return Buer

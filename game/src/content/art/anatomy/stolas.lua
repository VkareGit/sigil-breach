-- Owl anatomy reviewed on all 28 actual frame crops (including repaired poses).
-- Face discs exclude ear tufts; feathers, limbs and painted spell light have their own IDs.
local Author = require('src.content.art.anatomy.author')
local Stolas = { frames = {} }
-- cx, face top, face bottom, half-width; independent source-art observations.
local heads = {
  { 0.537, 0.275, 0.447, 0.087 },
  { 0.504, 0.314, 0.475, 0.080 },
  { 0.483, 0.312, 0.472, 0.080 },
  { 0.514, 0.209, 0.366, 0.074 },
  { 0.467, 0.195, 0.350, 0.074 },
  { 0.473, 0.311, 0.466, 0.083 },
  { 0.531, 0.307, 0.468, 0.085 },
  { 0.477, 0.311, 0.472, 0.083 },
  { 0.480, 0.318, 0.480, 0.083 },
  { 0.510, 0.304, 0.469, 0.083 },
  { 0.514, 0.307, 0.470, 0.082 },
  { 0.500, 0.299, 0.462, 0.083 },
  { 0.469, 0.140, 0.325, 0.115 },
  { 0.672, 0.302, 0.503, 0.100 },
  { 0.710, 0.346, 0.535, 0.100 },
  { 0.292, 0.500, 0.698, 0.090 },
  { 0.110, 0.612, 0.781, 0.107 },
  { 0.599, 0.670, 0.837, 0.087 },
  { 0.510, 0.084, 0.193, 0.077 },
  { 0.492, 0.111, 0.224, 0.075 },
  { 0.496, 0.111, 0.224, 0.073 },
  { 0.500, 0.161, 0.243, 0.067 },
  { 0.476, 0.115, 0.197, 0.067 },
  { 0.478, 0.095, 0.207, 0.075 },
  { 0.495, 0.091, 0.286, 0.073 },
  { 0.494, 0.087, 0.278, 0.073 },
  { 0.544, 0.106, 0.262, 0.073 },
  { 0.501, 0.104, 0.280, 0.074 },
}
for i, h in ipairs(heads) do
  local cx = h[1]
  local p = { Author.body('flesh') }
  local firstLeg = i >= 25 and 0.52 or (i >= 19 and 0.50 or 0.59)
  local lastLeg = i >= 25 and 0.95 or (i >= 19 and 0.82 or 0.98)
  -- Default front/rear wings; active folds are replaced below.
  p[#p + 1] = Author.part(
    'wing-left',
    'torso',
    'flesh',
    { 0, 0.08, cx - 0.09, 0.08, cx - 0.10, 0.50, cx - 0.16, 0.80, 0, 0.90 }
  )
  p[#p + 1] = Author.part(
    'wing-right',
    'torso',
    'flesh',
    { cx + 0.09, 0.08, 1, 0.08, 1, 0.90, cx + 0.16, 0.80, cx + 0.10, 0.50 }
  )
  p[#p + 1] = Author.segment('arm-left', 'torso', 'flesh', cx - 0.09, 0.40, cx - 0.18, 0.82, 0.045)
  p[#p + 1] = Author.segment('arm-right', 'torso', 'flesh', cx + 0.09, 0.40, cx + 0.18, 0.82, 0.045)
  p[#p + 1] = Author.part('leg-left', 'lower', 'flesh', {
    cx - 0.10,
    firstLeg,
    cx - 0.01,
    firstLeg,
    cx + 0.01,
    lastLeg,
    cx - 0.13,
    lastLeg,
    cx - 0.08,
    0.72,
  })
  p[#p + 1] = Author.part('leg-right', 'lower', 'flesh', {
    cx + 0.01,
    firstLeg,
    cx + 0.10,
    firstLeg,
    cx + 0.08,
    0.72,
    cx + 0.13,
    lastLeg,
    cx - 0.01,
    lastLeg,
  })
  p[#p + 1] =
    Author.box('ear-tufts', 'torso', 'flesh', cx - 0.16, h[2] - 0.13, cx + 0.16, h[2] + 0.02)
  p[#p + 1] = Author.head(unpack(h))
  Stolas.frames[i] = { parts = p }
end
local function active(i, pelvisX, pelvisY, leftX, leftY, rightX, rightY)
  local p = Stolas.frames[i].parts
  for n = #p, 1, -1 do
    if p[n].id == 'leg-left' or p[n].id == 'leg-right' then
      table.remove(p, n)
    end
  end
  table.insert(
    p,
    #p,
    Author.segment('leg-left', 'lower', 'flesh', pelvisX - 0.04, pelvisY, leftX, leftY, 0.07)
  )
  table.insert(
    p,
    #p,
    Author.segment('leg-right', 'lower', 'flesh', pelvisX + 0.04, pelvisY, rightX, rightY, 0.07)
  )
end
for _, i in ipairs({ 7, 8, 9 }) do
  active(i, 0.50, 0.63, 0.31, 0.99, 0.72, 0.99)
end
for _, i in ipairs({ 10, 11 }) do
  active(i, 0.45, 0.60, 0.13, 0.99, 0.66, 0.99)
end
-- The shins bend in opposite directions; a hip-to-toe segment misses the knees.
for _, i in ipairs({ 7, 8, 9 }) do
  local p = Stolas.frames[i].parts
  table.insert(
    p,
    #p,
    Author.part(
      'shin-left',
      'lower',
      'flesh',
      { 0.36, 0.73, 0.44, 0.77, 0.36, 0.91, 0.35, 0.99, 0.23, 0.99, 0.27, 0.90 }
    )
  )
  table.insert(
    p,
    #p,
    Author.part(
      'shin-right',
      'lower',
      'flesh',
      { 0.54, 0.73, 0.62, 0.73, 0.63, 0.83, 0.76, 0.97, 0.69, 1, 0.60, 0.91, 0.53, 0.81 }
    )
  )
end
for _, i in ipairs({ 10, 11 }) do
  local p = Stolas.frames[i].parts
  table.insert(
    p,
    #p,
    Author.part('shin-right', 'lower', 'flesh', {
      0.48,
      0.68,
      0.56,
      0.70,
      0.54,
      0.79,
      0.48,
      0.84,
      0.59,
      0.94,
      0.68,
      0.98,
      0.57,
      1,
      0.45,
      0.89,
      0.42,
      0.81,
    })
  )
end
active(13, 0.53, 0.58, 0.26, 0.94, 0.75, 0.94)
active(14, 0.49, 0.70, 0.26, 0.95, 0.74, 0.95)
active(15, 0.54, 0.63, 0.25, 0.91, 0.83, 0.92)
table.insert(
  Stolas.frames[15].parts,
  #Stolas.frames[15].parts,
  Author.part(
    'thigh-right',
    'lower',
    'flesh',
    { 0.56, 0.61, 0.72, 0.61, 0.80, 0.73, 0.68, 0.82, 0.57, 0.73 }
  )
)
-- In folded/lying poses use manually separated legs and wings, not standing bands.
for _, i in ipairs({ 14, 15 }) do
  local p = Stolas.frames[i].parts
  p[2] = Author.part(
    'wing-left',
    'torso',
    'flesh',
    { 0.05, 0.10, 0.39, 0.10, 0.48, 0.42, 0.32, 0.78, 0.04, 0.74 }
  )
  p[3] =
    Author.part('wing-right', 'torso', 'flesh', { 0.61, 0.43, 0.85, 0.43, 0.83, 0.75, 0.71, 0.74 })
end
Stolas.frames[16].parts = {
  Author.body(),
  Author.part('wing-left', 'torso', 'flesh', {
    0.13,
    0.32,
    0.34,
    0.23,
    0.64,
    0.37,
    0.87,
    0.60,
    0.96,
    0.85,
    0.69,
    0.74,
    0.43,
    0.42,
    0.22,
    0.58,
  }),
  Author.part(
    'leg-left',
    'lower',
    'flesh',
    { 0.61, 0.64, 0.77, 0.64, 0.78, 0.87, 0.63, 0.91, 0.51, 0.84 }
  ),
  Author.part(
    'leg-right',
    'lower',
    'flesh',
    { 0.72, 0.61, 0.85, 0.70, 0.96, 0.85, 0.86, 0.88, 0.66, 0.77 }
  ),
  Author.segment('arm-left', 'torso', 'flesh', 0.39, 0.44, 0.15, 0.89, 0.05),
  Author.segment('arm-right', 'torso', 'flesh', 0.45, 0.44, 0.43, 0.89, 0.065),
  Author.box('ear-tufts', 'torso', 'flesh', 0.13, 0.37, 0.29, 0.62),
  Author.head(unpack(heads[16])),
}
for _, i in ipairs({ 17, 18 }) do
  local p = {
    Author.body(),
    Author.box('folded-wings', 'torso', 'flesh', 0.05, 0.40, 0.95, 0.75),
    Author.box('legs', 'lower', 'flesh', 0.59, 0.72, 1, 0.94),
    Author.head(unpack(heads[i])),
  }
  Stolas.frames[i].parts = p
end
-- Only free-floating motes are non-anatomical. Frame 8 light is painted over
-- the chest and hands, so it must never punch an invulnerable hole in the body.
table.insert(
  Stolas.frames[9].parts,
  Author.effect('cast-glow', { 0.40, 0.08, 0.59, 0.08, 0.59, 0.28, 0.40, 0.28 })
)
table.insert(
  Stolas.frames[10].parts,
  Author.effect('cast-glow', { 0.79, 0.26, 1, 0.26, 1, 0.64, 0.79, 0.64 })
)
table.insert(
  Stolas.frames[11].parts,
  Author.effect(
    'cast-glow',
    { 0.66, 0.26, 0.91, 0.26, 0.91, 0.40, 0.82, 0.40, 0.77, 0.36, 0.66, 0.36 }
  )
)
table.insert(
  Stolas.frames[11].parts,
  Author.effect('cast-glow-low', { 0.74, 0.58, 0.97, 0.58, 0.97, 0.71, 0.74, 0.71 })
)
return Stolas

-- Registered paintings of the hands and firearms: real grip pivots, measured
-- muzzle caps and the chamber a spent case leaves from. The v16 sheets are a
-- 4 x 4 grid of 400 px cells; each pose is named, so a later atlas may reorder
-- or add rectangles (content/weapon_art.lua validates and compiles this).
-- The v32/v33 retouched sheets wait outside the game (work/weapon-art-v32-v33-backup)
-- until their replacement is painted.
local A = {}
-- The sixteen poses of a sheet, in grid order.
local ids = {
  'ready',
  'recoil',
  'settle',
  'reach',
  'unlock',
  'release',
  'open',
  'extract',
  'insert_first',
  'insert_second',
  'seat',
  'loaded',
  'raise',
  'closing',
  'latched',
  'return_ready',
}
-- w x h: the painted extent of the grid; rows/baseline: each row's top and
-- the line its grip rests on; muzzles: the bore cap in the painted grid's
-- cell pixels; ejects: frame-local chamber points by pose id.
local function sheet(path, w, h, rows, baseline, muzzles, actions, scale, ejects)
  local m = {
    path = path,
    width = 1600,
    height = 1600,
    cellWidth = w / 4,
    screenScale = scale,
    frames = {},
  }
  for i = 1, 16 do
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4) + 1
    local top = rows[row]
    m.frames[i] = {
      id = ids[i],
      rect = { col * 400, (row - 1) * 400, 400, 400 },
      grip = { 200, 330 },
      muzzle = { muzzles[i][1] + 200 - w / 8, muzzles[i][2] + 330 - (baseline[row] - top) },
      action = actions[i],
      eject = ejects[ids[i]],
    }
  end
  return m
end
A.exorcist = sheet(
  'assets/art/shotgun-iron-v16.png',
  1444,
  1089,
  { 0, 314, 563, 808, 1089 },
  { 289, 541, 782, 1032 },
  {
    { 183, 116 },
    { 132, 72 },
    { 162, 121 },
    { 181, 118 },
    { 168, 43 },
    { 136, 24 },
    { 215, 60 },
    { 222, 71 },
    { 224, 82 },
    { 234, 95 },
    { 227, 93 },
    { 226, 84 },
    { 163, 26 },
    { 144, 11 },
    { 171, 41 },
    { 178, 56 },
  },
  {
    'ready',
    'recoil',
    'settle',
    'reach',
    'unlock',
    'release',
    'open',
    'extract',
    'insert_first',
    'insert_second',
    'seat',
    'loaded',
    'raise',
    'closing',
    'latched',
    'return_ready',
  },
  0.82,
  -- The breech as painted: just cracking open, open, drawn back.
  { release = { 226, 205 }, open = { 226, 186 }, extract = { 225, 199 } }
)
A.judge = sheet(
  'assets/art/revolver-iron-v16.png',
  1448,
  1086,
  { 0, 290, 552, 796, 1086 },
  { 277, 543, 788, 1057 },
  {
    { 183, 104 },
    { 136, 10 },
    { 174, 59 },
    { 183, 104 },
    { 197, 31 },
    { 122, 15 },
    { 191, 14 },
    { 197, 14 },
    { 187, 12 },
    { 172, 11 },
    { 204, 18 },
    { 176, 6 },
    { 133, 25 },
    { 188, 18 },
    { 210, 5 },
    { 184, 57 },
  },
  {
    'ready',
    'recoil',
    'settle',
    'reach',
    'unlock',
    'release',
    'open',
    'extract',
    'insert_first',
    'insert_second',
    'seat',
    'loaded',
    'raise',
    'closing',
    'latched',
    'return_ready',
  },
  0.56,
  -- The cylinder's cases are not reported spent by its mechanism.
  {}
)
-- The discharge changes the painted silhouette immediately. Hold the recoil
-- long enough to read at 30 Hz, then catch it with the authored recovery pose.
-- These are presentation clocks: ammunition, fire rate and latch transactions
-- remain owned by combat/reload. No shot is delayed to wait for an animation.
A.exorcist.fire = { { 0.08, 2 }, { 0.14, 3 } }
A.judge.fire = { { 0.09, 2 }, { 0.19, 3 } }
-- A closing drawing must never precede the mechanical latch transaction.
A.exorcist.timeline = {
  { 0.10, 1 },
  { 0.15, 4 },
  { 0.20, 5 },
  { 0.26, 6 },
  { 0.32, 7 },
  { 0.39, 8 },
  { 0.46, 9 },
  { 0.53, 10 },
  { 0.60, 11 },
  { 0.68, 12 },
  { 0.75, 13 },
  { 0.82, 14 },
  { 0.88, 15 },
  { 0.94, 16 },
}
A.judge.timeline = {
  { 0.10, 5 },
  { 0.20, 6 },
  { 0.45, 7 },
  { 0.68, 8 },
  { 0.80, 9 },
  { 0.96, 10 },
  { 1.16, 11 },
  { 1.55, 12 },
  { 1.60, 13 },
  { 1.66, 14 },
  { 1.76, 15 },
  { 1.85, 16 },
}
-- How each sheet's muzzle flash reads: brightness time (s), its row of
-- flare frames and its height (share of the screen).
-- open: the hands' frame of an action left open, loaded or empty.
A.exorcist.style =
  { bright = 0.045, muzzleRow = 0, flare = 0.085, open = { primed = 12, empty = 8 } }
A.judge.style = { bright = 0.055, muzzleRow = 1, flare = 0.060, open = { primed = 12, empty = 8 } }
-- How the hands sit in the scene (render/shaders.lua: hands; 0.26 G6): the
-- painted iron keeps saturation and contrast of its own colours, takes haze
-- of the ember mist, darkens by shade toward the bottom of the frame, and is
-- lit by the torches at the knight no darker than floor (render/renderer.lua:
-- weaponTint). Before 0.26 it was drawn unlit at full contrast and stood out
-- of the fresco. Source-space pigment grouping reduces the tiny metallic
-- scratches independently of the world/HUD, without changing authored alpha.
-- (The look of the v16 iron, exposure neutral.)
A.look = {
  saturation = 0.80,
  contrast = 0.84,
  exposure = 1,
  haze = 0.07,
  mist = { 0.24, 0.17, 0.12 },
  shade = 0.28,
  floor = 0.50,
  -- Source-pixel neighbourhood, not screen blur: soften tiny metal scratches
  -- into pigment masses while retaining the original silhouette and anchors.
  pigmentRadius = 1.35,
  pigmentBlend = 0.65,
}
-- Named poses are stable when a future atlas reorders or adds rectangles.
local function phases(entry, keys)
  local out = {}
  for i, key in ipairs(keys) do
    out[i] = { finish = key[1], frame = entry.frames[key[2]].id }
  end
  return out
end
local function present(entry, movement)
  entry.phases = { fire = phases(entry, entry.fire), reload = phases(entry, entry.timeline) }
  entry.fire, entry.timeline = nil, nil
  entry.ready = 'ready'
  entry.reloadComplete = 'return_ready'
  entry.open = {
    primed = entry.frames[entry.style.open.primed].id,
    empty = entry.frames[entry.style.open.empty].id,
  }
  entry.style.open = nil
  local bright, first = entry.style.bright, entry.style.muzzleRow * 4
  entry.style.muzzle = {
    { finish = bright * 0.5, frame = first + 1, scale = 1, alpha = 1 },
    { finish = bright, frame = first + 2, scale = 0.72, alpha = 1 },
    { finish = 0.10, frame = first + 3, scale = 0.80, alpha = 0.48 },
    { finish = 0.15, frame = first + 4, scale = 0.62, alpha = 0.26 },
  }
  entry.style.muzzleRow = nil
  entry.automaticFireUntil = 0.12
  entry.reloadMotion = movement
end
-- The hands' reload path (x, y in 1/450 of the screen, roll rad).
present(A.exorcist, {
  { 0, 0, 0, 0 },
  { 0.10, 1, 4, 0.015 },
  { 0.26, 4, 12, -0.025 },
  { 0.60, 4, 16, -0.02 },
  { 0.75, 0, 8, 0.01 },
  { 0.94, 0, 0, 0 },
})
present(A.judge, {
  { 0, 0, 0, 0 },
  { 0.38, 2, 8, -0.035 },
  { 0.68, 4, 12, -0.025 },
  { 1.16, 4, 12, -0.025 },
  { 1.55, 1, 5, 0.015 },
  { 1.85, 0, 0, 0 },
})
-- Each gun's cell on the shop's card sheet (ui/skin.lua: weapon cards).
A.judge.card = 1
A.exorcist.card = 2
-- The shotgun holds its discharge drawing as long as its fire phases (0.44, V01).
A.exorcist.automaticFireUntil = 0.14
-- A trigger pull on an open cylinder closes it over readyAt (0.25 s).
A.judge.phases.interruptedClose = {
  { finish = 0.12, frame = 'open' },
  { finish = 0.38, frame = 'raise' },
  { finish = 0.65, frame = 'closing' },
  { finish = 0.85, frame = 'latched' },
  { finish = 1, frame = 'return_ready' },
}
return A

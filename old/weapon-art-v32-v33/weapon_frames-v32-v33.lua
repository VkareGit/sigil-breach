-- Registered paintings: real grip pivots, measured muzzle caps and explicit chamber variants.
-- Transparent atlas gutters do not alter source-pixel scale or the painted grip placement.
local A = {}
A.exorcist = {
  path = 'assets/art/shotgun-fresco-v32.png',
  width = 1272,
  height = 2544,
  cellWidth = 313.5,
  screenScale = 0.7663384454513767,
  placement = { 41.323076923076925, -24.211332082551593 },
  frames = {
    {
      id = 'ready',
      rect = { 0, 0, 318, 318 },
      grip = { 192, 262 },
      action = 'ready',
      muzzle = { 153, 105 },
    },
    {
      id = 'recoil',
      rect = { 318, 0, 317, 318 },
      grip = { 198, 240 },
      action = 'recoil',
      muzzle = { 106, 57 },
    },
    {
      id = 'settle',
      rect = { 636, 0, 317, 318 },
      grip = { 192, 264 },
      action = 'settle',
      muzzle = { 121, 104 },
    },
    { id = 'reach', rect = { 954, 0, 318, 318 }, grip = { 213, 263 }, action = 'reach' },
    { id = 'unlock', rect = { 0, 318, 318, 317 }, grip = { 222, 241 }, action = 'unlock' },
    {
      id = 'release',
      rect = { 318, 318, 317, 317 },
      grip = { 228, 250 },
      action = 'release',
      eject = { 215, 148.5 },
      rounds = { 'release_rounds_0', 'release_rounds_1', 'release_rounds_2' },
    },
    {
      id = 'open',
      rect = { 636, 318, 317, 317 },
      grip = { 207, 245 },
      action = 'open',
      eject = { 170.5, 133.5 },
      rounds = { 'open_rounds_0', 'open_rounds_1', 'open_rounds_2' },
    },
    {
      id = 'extract',
      rect = { 636, 318, 317, 317 },
      grip = { 207, 245 },
      action = 'extract',
      eject = { 170.5, 133.5 },
      rounds = { 'open_rounds_0', 'open_rounds_1', 'open_rounds_2' },
    },
    {
      id = 'insert_first',
      rect = { 0, 636, 318, 317 },
      grip = { 212, 220 },
      action = 'insert_first',
      eject = { 182.5, 125.5 },
      -- The hand brings the first shell; the rest of the pair is still held.
      roundsSource = 'loading',
      inHand = 2,
      rounds = { 'insert_first_rounds_0', 'insert_first_rounds_1', 'insert_first_rounds_2' },
    },
    {
      id = 'insert_second',
      rect = { 318, 636, 317, 317 },
      grip = { 212, 224 },
      action = 'insert_second',
      eject = { 183, 125 },
      -- The first shell sits in its chamber; the hand holds the last one.
      roundsSource = 'loading',
      inHand = 1,
      rounds = { 'insert_second_rounds_0', 'insert_second_rounds_1', 'insert_second_rounds_2' },
    },
    {
      id = 'seat',
      rect = { 636, 636, 317, 317 },
      grip = { 225, 232 },
      action = 'seat',
      eject = { 181, 134.5 },
      -- Every shell of the transaction is home; the thumb presses them flush.
      roundsSource = 'loading',
      inHand = 0,
      rounds = { 'seat_rounds_0', 'seat_rounds_1', 'seat_rounds_2' },
    },
    {
      id = 'loaded',
      rect = { 636, 636, 317, 317 },
      grip = { 225, 232 },
      action = 'loaded',
      eject = { 181, 134.5 },
      rounds = { 'seat_rounds_0', 'seat_rounds_1', 'seat_rounds_2' },
    },
    {
      id = 'raise',
      rect = { 636, 318, 317, 317 },
      grip = { 207, 245 },
      action = 'raise',
      eject = { 170.5, 133.5 },
      rounds = { 'open_rounds_0', 'open_rounds_1', 'open_rounds_2' },
    },
    { id = 'closing', rect = { 318, 954, 317, 318 }, grip = { 220, 188 }, action = 'closing' },
    { id = 'latched', rect = { 636, 954, 317, 318 }, grip = { 217, 213 }, action = 'latched' },
    {
      id = 'return_ready',
      rect = { 954, 954, 318, 318 },
      grip = { 212, 212 },
      action = 'return_ready',
    },
    {
      id = 'release_rounds_0',
      rect = { 0, 1272, 317, 317 },
      grip = { 228, 250 },
      action = 'release',
      eject = { 215, 148.5 },
    },
    {
      id = 'release_rounds_1',
      rect = { 318, 1272, 317, 317 },
      grip = { 228, 250 },
      action = 'release',
      eject = { 215, 148.5 },
    },
    {
      id = 'release_rounds_2',
      rect = { 636, 1272, 317, 317 },
      grip = { 228, 250 },
      action = 'release',
      eject = { 215, 148.5 },
    },
    {
      id = 'open_rounds_0',
      rect = { 954, 1272, 317, 317 },
      grip = { 207, 245 },
      action = 'open',
      eject = { 170.5, 133.5 },
    },
    {
      id = 'open_rounds_1',
      rect = { 0, 1590, 317, 317 },
      grip = { 207, 245 },
      action = 'open',
      eject = { 170.5, 133.5 },
    },
    {
      id = 'open_rounds_2',
      rect = { 318, 1590, 317, 317 },
      grip = { 207, 245 },
      action = 'open',
      eject = { 170.5, 133.5 },
    },
    {
      id = 'insert_first_rounds_0',
      rect = { 636, 1590, 318, 317 },
      grip = { 212, 220 },
      action = 'insert_first',
      eject = { 182.5, 125.5 },
    },
    {
      id = 'insert_first_rounds_1',
      rect = { 954, 1590, 318, 317 },
      grip = { 212, 220 },
      action = 'insert_first',
      eject = { 182.5, 125.5 },
    },
    {
      id = 'insert_first_rounds_2',
      rect = { 0, 1908, 318, 317 },
      grip = { 212, 220 },
      action = 'insert_first',
      eject = { 182.5, 125.5 },
    },
    {
      id = 'insert_second_rounds_0',
      rect = { 318, 1908, 317, 317 },
      grip = { 212, 224 },
      action = 'insert_second',
      eject = { 183, 125 },
    },
    {
      id = 'insert_second_rounds_1',
      rect = { 636, 1908, 317, 317 },
      grip = { 212, 224 },
      action = 'insert_second',
      eject = { 183, 125 },
    },
    {
      id = 'insert_second_rounds_2',
      rect = { 954, 1908, 317, 317 },
      grip = { 212, 224 },
      action = 'insert_second',
      eject = { 183, 125 },
    },
    {
      id = 'seat_rounds_0',
      rect = { 0, 2226, 317, 317 },
      grip = { 225, 232 },
      action = 'seat',
      eject = { 181, 134.5 },
    },
    {
      id = 'seat_rounds_1',
      rect = { 318, 2226, 317, 317 },
      grip = { 225, 232 },
      action = 'seat',
      eject = { 181, 134.5 },
    },
    {
      id = 'seat_rounds_2',
      rect = { 636, 2226, 317, 317 },
      grip = { 225, 232 },
      action = 'seat',
      eject = { 181, 134.5 },
    },
  },
}
A.judge = {
  path = 'assets/art/revolver-speedloader-v33.png',
  width = 2544,
  height = 2544,
  cellWidth = 313.5,
  screenScale = 0.5355630191979014,
  placement = { 20.811074918566774, -46.926244765007 },
  frames = {
    {
      id = 'ready',
      rect = { 0, 0, 318, 318 },
      grip = { 179, 249 },
      action = 'ready',
      muzzle = { 160, 110 },
    },
    {
      id = 'recoil',
      rect = { 318, 0, 317, 318 },
      grip = { 171, 231 },
      action = 'recoil',
      muzzle = { 110, 43 },
    },
    {
      id = 'settle',
      rect = { 636, 0, 317, 318 },
      grip = { 190, 256 },
      action = 'settle',
      muzzle = { 139, 82 },
    },
    { id = 'reach', rect = { 954, 0, 318, 318 }, grip = { 178, 250 }, action = 'reach' },
    { id = 'unlock', rect = { 1272, 0, 318, 317 }, grip = { 205, 232 }, action = 'unlock' },
    {
      id = 'release',
      rect = { 1590, 0, 317, 317 },
      grip = { 204, 231 },
      action = 'release',
      rounds = {
        'release_rounds_0',
        'release_rounds_1',
        'release_rounds_2',
        'release_rounds_3',
        'release_rounds_4',
        'release_rounds_5',
        'release_rounds_6',
      },
    },
    {
      id = 'open',
      rect = { 1908, 0, 317, 317 },
      grip = { 208, 231 },
      action = 'open',
      rounds = {
        'open_rounds_0',
        'open_rounds_1',
        'open_rounds_2',
        'open_rounds_3',
        'open_rounds_4',
        'open_rounds_5',
        'open_rounds_6',
      },
    },
    {
      id = 'extract',
      rect = { 1908, 0, 317, 317 },
      grip = { 208, 231 },
      action = 'extract',
      rounds = {
        'open_rounds_0',
        'open_rounds_1',
        'open_rounds_2',
        'open_rounds_3',
        'open_rounds_4',
        'open_rounds_5',
        'open_rounds_6',
      },
    },
    {
      id = 'insert_first',
      rect = { 0, 318, 318, 317 },
      grip = { 210, 224 },
      action = 'insert_first',
      roundsSource = 'pending',
      rounds = {
        'insert_first_rounds_0',
        'insert_first_rounds_1',
        'insert_first_rounds_2',
        'insert_first_rounds_3',
        'insert_first_rounds_4',
        'insert_first_rounds_5',
        'insert_first_rounds_6',
      },
    },
    {
      id = 'insert_second',
      rect = { 318, 318, 317, 317 },
      grip = { 208, 224 },
      action = 'insert_second',
      roundsSource = 'pending',
      rounds = {
        'insert_second_rounds_0',
        'insert_second_rounds_1',
        'insert_second_rounds_2',
        'insert_second_rounds_3',
        'insert_second_rounds_4',
        'insert_second_rounds_5',
        'insert_second_rounds_6',
      },
    },
    {
      id = 'seat',
      rect = { 636, 318, 317, 317 },
      grip = { 210, 224 },
      action = 'seat',
      roundsSource = 'pending',
      rounds = {
        'seat_rounds_0',
        'seat_rounds_1',
        'seat_rounds_2',
        'seat_rounds_3',
        'seat_rounds_4',
        'seat_rounds_5',
        'seat_rounds_6',
      },
    },
    {
      id = 'loaded',
      rect = { 954, 318, 318, 317 },
      grip = { 205, 219 },
      action = 'loaded',
      rounds = {
        'loaded_rounds_0',
        'loaded_rounds_1',
        'loaded_rounds_2',
        'loaded_rounds_3',
        'loaded_rounds_4',
        'loaded_rounds_5',
        'loaded_rounds_6',
      },
    },
    { id = 'raise', rect = { 1272, 318, 318, 318 }, grip = { 206, 211 }, action = 'raise' },
    { id = 'closing', rect = { 1590, 318, 317, 318 }, grip = { 201, 211 }, action = 'closing' },
    { id = 'latched', rect = { 1908, 318, 317, 318 }, grip = { 196, 210 }, action = 'latched' },
    {
      id = 'return_ready',
      rect = { 2226, 318, 318, 318 },
      grip = { 175, 214 },
      action = 'return_ready',
    },
    {
      id = 'release_rounds_0',
      rect = { 0, 636, 317, 317 },
      grip = { 204, 231 },
      action = 'release',
    },
    {
      id = 'release_rounds_1',
      rect = { 318, 636, 317, 317 },
      grip = { 204, 231 },
      action = 'release',
    },
    {
      id = 'release_rounds_2',
      rect = { 636, 636, 317, 317 },
      grip = { 204, 231 },
      action = 'release',
    },
    {
      id = 'release_rounds_3',
      rect = { 954, 636, 317, 317 },
      grip = { 204, 231 },
      action = 'release',
    },
    {
      id = 'release_rounds_4',
      rect = { 1272, 636, 317, 317 },
      grip = { 204, 231 },
      action = 'release',
    },
    {
      id = 'release_rounds_5',
      rect = { 1590, 636, 317, 317 },
      grip = { 204, 231 },
      action = 'release',
    },
    {
      id = 'release_rounds_6',
      rect = { 1908, 636, 317, 317 },
      grip = { 204, 231 },
      action = 'release',
    },
    { id = 'open_rounds_0', rect = { 2226, 636, 317, 317 }, grip = { 208, 231 }, action = 'open' },
    { id = 'open_rounds_1', rect = { 0, 954, 317, 317 }, grip = { 208, 231 }, action = 'open' },
    { id = 'open_rounds_2', rect = { 318, 954, 317, 317 }, grip = { 208, 231 }, action = 'open' },
    { id = 'open_rounds_3', rect = { 636, 954, 317, 317 }, grip = { 208, 231 }, action = 'open' },
    { id = 'open_rounds_4', rect = { 954, 954, 317, 317 }, grip = { 208, 231 }, action = 'open' },
    { id = 'open_rounds_5', rect = { 1272, 954, 317, 317 }, grip = { 208, 231 }, action = 'open' },
    { id = 'open_rounds_6', rect = { 1590, 954, 317, 317 }, grip = { 208, 231 }, action = 'open' },
    {
      id = 'insert_first_rounds_0',
      rect = { 1908, 954, 318, 317 },
      grip = { 210, 224 },
      action = 'insert_first',
    },
    {
      id = 'insert_first_rounds_1',
      rect = { 2226, 954, 318, 317 },
      grip = { 210, 224 },
      action = 'insert_first',
    },
    {
      id = 'insert_first_rounds_2',
      rect = { 0, 1272, 318, 317 },
      grip = { 210, 224 },
      action = 'insert_first',
    },
    {
      id = 'insert_first_rounds_3',
      rect = { 318, 1272, 318, 317 },
      grip = { 210, 224 },
      action = 'insert_first',
    },
    {
      id = 'insert_first_rounds_4',
      rect = { 636, 1272, 318, 317 },
      grip = { 210, 224 },
      action = 'insert_first',
    },
    {
      id = 'insert_first_rounds_5',
      rect = { 954, 1272, 318, 317 },
      grip = { 210, 224 },
      action = 'insert_first',
    },
    {
      id = 'insert_first_rounds_6',
      rect = { 1272, 1272, 318, 317 },
      grip = { 210, 224 },
      action = 'insert_first',
    },
    {
      id = 'insert_second_rounds_0',
      rect = { 1590, 1272, 317, 317 },
      grip = { 208, 224 },
      action = 'insert_second',
    },
    {
      id = 'insert_second_rounds_1',
      rect = { 1908, 1272, 317, 317 },
      grip = { 208, 224 },
      action = 'insert_second',
    },
    {
      id = 'insert_second_rounds_2',
      rect = { 2226, 1272, 317, 317 },
      grip = { 208, 224 },
      action = 'insert_second',
    },
    {
      id = 'insert_second_rounds_3',
      rect = { 0, 1590, 317, 317 },
      grip = { 208, 224 },
      action = 'insert_second',
    },
    {
      id = 'insert_second_rounds_4',
      rect = { 318, 1590, 317, 317 },
      grip = { 208, 224 },
      action = 'insert_second',
    },
    {
      id = 'insert_second_rounds_5',
      rect = { 636, 1590, 317, 317 },
      grip = { 208, 224 },
      action = 'insert_second',
    },
    {
      id = 'insert_second_rounds_6',
      rect = { 954, 1590, 317, 317 },
      grip = { 208, 224 },
      action = 'insert_second',
    },
    { id = 'seat_rounds_0', rect = { 1272, 1590, 317, 317 }, grip = { 210, 224 }, action = 'seat' },
    { id = 'seat_rounds_1', rect = { 1590, 1590, 317, 317 }, grip = { 210, 224 }, action = 'seat' },
    { id = 'seat_rounds_2', rect = { 1908, 1590, 317, 317 }, grip = { 210, 224 }, action = 'seat' },
    { id = 'seat_rounds_3', rect = { 2226, 1590, 317, 317 }, grip = { 210, 224 }, action = 'seat' },
    { id = 'seat_rounds_4', rect = { 0, 1908, 317, 317 }, grip = { 210, 224 }, action = 'seat' },
    { id = 'seat_rounds_5', rect = { 318, 1908, 317, 317 }, grip = { 210, 224 }, action = 'seat' },
    { id = 'seat_rounds_6', rect = { 636, 1908, 317, 317 }, grip = { 210, 224 }, action = 'seat' },
    {
      id = 'loaded_rounds_0',
      rect = { 954, 1908, 318, 317 },
      grip = { 205, 219 },
      action = 'loaded',
    },
    {
      id = 'loaded_rounds_1',
      rect = { 1272, 1908, 318, 317 },
      grip = { 205, 219 },
      action = 'loaded',
    },
    {
      id = 'loaded_rounds_2',
      rect = { 1590, 1908, 318, 317 },
      grip = { 205, 219 },
      action = 'loaded',
    },
    {
      id = 'loaded_rounds_3',
      rect = { 1908, 1908, 318, 317 },
      grip = { 205, 219 },
      action = 'loaded',
    },
    {
      id = 'loaded_rounds_4',
      rect = { 2226, 1908, 318, 317 },
      grip = { 205, 219 },
      action = 'loaded',
    },
    {
      id = 'loaded_rounds_5',
      rect = { 0, 2226, 318, 317 },
      grip = { 205, 219 },
      action = 'loaded',
    },
    {
      id = 'loaded_rounds_6',
      rect = { 318, 2226, 318, 317 },
      grip = { 205, 219 },
      action = 'loaded',
    },
  },
}
-- The discharge changes the painted silhouette immediately. Hold the recoil
-- long enough to read at 30 Hz, then catch it with the authored recovery pose.
-- These are presentation clocks: ammunition, fire rate and latch transactions
-- remain owned by combat/reload. No shot is delayed to wait for an animation.
A.exorcist.fire = { { 0.065, 2 }, { 0.12, 3 } }
A.judge.fire = { { 0.09, 2 }, { 0.19, 3 } }
-- A closing drawing must never precede the mechanical latch transaction.
A.exorcist.timeline = {
  { 0.10, 1 },
  { 0.15, 4 },
  { 0.26, 5 },
  { 0.32, 6 },
  { 0.39, 7 },
  { 0.46, 9 },
  { 0.53, 10 },
  { 0.60, 11 },
  { 0.68, 12 },
  { 0.82, 13 },
  { 0.86, 14 },
  { 0.91, 15 },
  { 0.94, 16 },
}
A.judge.timeline = {
  { 0.20, 5 },
  { 0.30, 6 },
  { 0.45, 7 },
  { 0.68, 8 },
  { 0.80, 9 },
  { 0.96, 10 },
  { 1.16, 11 },
  -- The loaded cylinder shows, then swings in before the latch (1.55):
  -- closing (still open), latched, the gun raised back to aim.
  { 1.38, 12 },
  { 1.55, 14 },
  { 1.66, 15 },
  { 1.76, 13 },
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
A.look = {
  saturation = 0.64,
  contrast = 0.80,
  exposure = 0.84,
  haze = 0.08,
  mist = { 0.16, 0.145, 0.13 },
  shade = 0.24,
  floor = 0.50,
  -- Source-pixel neighbourhood, not screen blur: soften tiny metal scratches
  -- into pigment masses while retaining the original silhouette and anchors.
  pigmentRadius = 1.60,
  pigmentBlend = 0.90,
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
  -- The loader pushed into the cylinder, then eased back as it seats.
  { 0.90, 7, 9, -0.045 },
  { 1.08, 3, 13, -0.02 },
  { 1.38, 5, 11, -0.03 },
  -- A flick of the wrist swings the cylinder home at the latch.
  { 1.55, 1, 4, 0.035 },
  { 1.66, 0, 3, -0.01 },
  { 1.85, 0, 0, 0 },
})
A.judge.phases.interruptedClose = {
  { finish = 0.12, frame = 'open' },
  { finish = 0.55, frame = 'closing' },
  { finish = 0.75, frame = 'latched' },
  { finish = 0.88, frame = 'raise' },
  { finish = 1, frame = 'return_ready' },
}
return A

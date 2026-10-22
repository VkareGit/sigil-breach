-- Authored registration, measured once in the transparent PNG gutters.
-- No alpha scanning or guessed muzzle locations during loading/drawing.
-- One hands sheet per art id; a weapon names its sheet (definition art, else
-- its id), so a new gun may reuse a sheet until it has its own.
local Weapons = require('src.content.weapons')
local A = {}
-- Every sheet, in a stable order (loading, the gallery).
A.ids = { 'exorcist', 'judge' }
local function sheet(path, w, h, rows, baseline, muzzles, actions, scale)
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
    local left, right = math.floor(col * w / 4), math.floor((col + 1) * w / 4)
    local top, bottom = rows[row], rows[row + 1]
    m.frames[i] = {
      rect = { col * 400, (row - 1) * 400, 400, 400 },
      grip = { 200, 330 },
      muzzle = { muzzles[i][1] + 200 - w / 8, muzzles[i][2] + 330 - (baseline[row] - top) },
      action = actions[i],
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
    'unlatch',
    'unlatch',
    'open',
    'extract',
    'insert',
    'insert',
    'seat',
    'loaded',
    'open',
    'closing',
    'latched',
    'ready',
  },
  0.82
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
    'ready',
    'unlatch',
    'unlatch',
    'open',
    'extract',
    'insert',
    'insert',
    'seat',
    'loaded',
    'closing',
    'closing',
    'latched',
    'ready',
  },
  0.56
)
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
A.look = {
  saturation = 0.80,
  contrast = 0.84,
  haze = 0.07,
  mist = { 0.24, 0.17, 0.12 },
  shade = 0.28,
  floor = 0.50,
  -- Source-pixel neighbourhood, not screen blur: soften tiny metal scratches
  -- into pigment masses while retaining the original silhouette and anchors.
  pigmentRadius = 1.35,
  pigmentBlend = 0.65,
}
-- The art id of the weapon in hand (or in slot).
function A.idOf(g, slot)
  local def = Weapons.inHand(g, slot)
  return def and (def.art or def.id)
end
function A.of(g, slot)
  return A[A.idOf(g, slot)]
end
function A.fireFrame(g)
  local age = g.view.shotAge or math.huge
  if age < 0 then
    return nil
  end
  for _, key in ipairs(A.of(g).fire) do
    if age < key[1] then
      return key[2]
    end
  end
end
function A.frame(g)
  if (g.reload or 0) > 0 then
    local age = require('src.combat.reload').age(g)
    -- The shotgun's automatic reload includes its discharge. A manual/resumed
    -- reload skips that beat; never show a phantom kick when opening by hand.
    if Weapons.inHand(g).fire.autoReload and (g.reloadOffset or 0) == 0 and age < 0.12 then
      local fire = A.fireFrame(g)
      if fire then
        return fire
      end
    end
    for _, key in ipairs(A.of(g).timeline) do
      if age < key[1] then
        return key[2]
      end
    end
    return 16
  end
  -- A cancelled reload remains physically open; never paint a shut barrel.
  local state = g.player and Weapons.state(g)
  if state and state.open then
    local open = A.of(g).style.open
    return require('src.combat.reload').mechanism(g, g.weapon).primed(state) and open.primed
      or open.empty
  end
  return A.fireFrame(g) or 1
end
return A

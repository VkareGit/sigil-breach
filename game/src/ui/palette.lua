-- Every colour the interface draws with, by name ({r, g, b}, 0..1). Screens
-- and the HUD ask here (ui/skin.lua exposes the same table as Skin.colors);
-- a new screen reuses these names before it adds one.
return {
  -- Text and ornament.
  ivory = { 0.94, 0.89, 0.76 },
  muted = { 0.82, 0.77, 0.67 },
  gold = { 0.86, 0.68, 0.40 },
  red = { 0.88, 0.31, 0.24 },
  -- Only ever a kill.
  kill = { 0.80, 0.16, 0.11 },
  blue = { 0.46, 0.63, 0.65 },
  violet = { 0.64, 0.53, 0.67 },
  green = { 0.49, 0.74, 0.35 },
  -- The echo's cold light.
  cold = { 0.60, 0.89, 0.79 },
  -- Health above its warning threshold.
  wound = { 0.84, 0.28, 0.22 },
  -- A button that cannot be pressed.
  disabled = { 0.53, 0.54, 0.52 },
  -- The selected shop row.
  highlight = { 0.73, 0.42, 0.29 },
  -- Full-screen veils behind modal screens (map, shop, archive, death).
  veil = { 0.015, 0.013, 0.017 },
  veilCool = { 0.015, 0.014, 0.017 },
  veilDeep = { 0.014, 0.012, 0.018 },
  curtain = { 0.019, 0.016, 0.020 },
  -- Outlines under the crosshair and its marks.
  ink = { 0.01, 0.01, 0.02 },
  inkSoft = { 0.08, 0.09, 0.10 },
  -- Map cells, bars and empty chambers.
  stone = { 0.20, 0.18, 0.16 },
  track = { 0.16, 0.13, 0.11 },
  emptyRound = { 0.20, 0.15, 0.10 },
  -- Sigils drawn as burnt ink on parchment, and the plates' gilding.
  sepia = { 0.22, 0.13, 0.08 },
  gilt = { 0.84, 0.68, 0.44 },
}

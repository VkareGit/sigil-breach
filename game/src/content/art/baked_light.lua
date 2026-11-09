-- The light baked into a hall's vertices (render/kit/light.lua): how the
-- piers shadow the tear, how what stands darkens the floor round it, how a
-- source falls off and how the light fades up into the vault.
return {
  -- The piers' shadows from the tear: a blocker shades from this share of its
  -- radius on; the softness of its edge (a share of the radius, and growth
  -- per metre beyond it); the light that is left in its shadow, and the rest
  -- that its edge lets through.
  shadow = { from = 0.4, soft = 0.55, spread = 0.05, left = 0.34, lit = 0.66 },
  -- Only what is lower than this stands in the tear's light (m).
  shadowTop = 4,
  -- Soft contact round a blocker: darkest share and the rest, from inside its
  -- radius to a metre beyond it, on floors lower than height.
  contact = { darkest = 0.48, lit = 0.52, inner = 0.9, outer = 1.0, height = 0.9 },
  -- A face lit edge-on still takes this share of a source, a face turned to
  -- it the rest as well.
  wrap = 0.28,
  facing = 0.72,
  -- The light fades from this share at the vault (15 m) to all of it at 7 m.
  fade = { least = 0.35, rest = 0.65, top = 15, bottom = 7 },
}

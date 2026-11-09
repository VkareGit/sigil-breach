-- The fire round the arena's edge (render/arena_fire.lua): the four painted
-- brazier flames of the props sheet, with the metal bowl cut away.
return {
  -- How long the ring takes to show (s).
  fadeIn = 0.8,
  -- Where the flames end in the sheet (pixels of its 887-pixel height).
  flameTop = 192,
  sheetHeight = 887,
  alpha = 0.94,
  tint = { 1, 0.88, 0.72 },
  brightness = 0.94,
  -- Frames per second, and each flame's own offset so the perimeter does
  -- not march in unison; its height (base and swell, by its own wave); its
  -- width as a share of its height.
  rate = 7,
  offset = 1.37,
  height = 0.56,
  swell = 0.12,
  wave = 2.7,
  width = 2.3,
}

-- The painted chapel margin every panel is cut from (ui/reliquary.lua).
-- Pixels of the sheet, unless said otherwise.
return {
  path = 'assets/art/reliquary-ash-v16.png',
  -- The status bar strip along the top of the sheet.
  bar = 230,
  -- A panel's frame: the corner's side, the rows of the frame (top, middle
  -- and bottom) and their heights.
  corner = 108,
  rows = { 408, 482, 850 },
  heights = { 74, 368, 74 },
  -- The quiet lime ground live text is written on, and the thin sinopia
  -- rule above it.
  paper = { x = 200, y = 500, w = 1100, h = 326 },
  rule = { x = 200, w = 1100, h = 10 },
  -- The ground's tones: a warm and a cold plaster.
  tones = { [2] = { 0.98, 0.84, 0.68 }, [3] = { 0.83, 0.84, 0.82 } },
  -- A caption's rules are this thick on screen.
  ruleWidth = 2,
  -- A large panel (at least w by h) keeps a border this wide; otherwise
  -- it is at least least, by default border.
  large = { w = 500, h = 300, border = 32 },
  border = { least = 10, default = 14 },
  -- The status bar on screen: its top and height in frame pixels.
  status = { top = 584, height = 136 },
}

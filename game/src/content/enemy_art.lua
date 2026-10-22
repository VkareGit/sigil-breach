-- Authored sprite sources and immutable frame placement, shared by simulation and drawing.
-- No image allocation or collision calibration belongs to this catalogue.
local Idle = require('src.content.enemy_idle')
local Frames = require('src.content.art.enemy_frames')
local EnemyArt = { kinds = { 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }, entries = {} }
EnemyArt.entries.imp = {
  path = 'assets/art/imp-fresco-v12.png',
  columns = 6,
  rows = 4,
  bands = {
    { 0, 256, 512, 757, 1024 },
    { 0, 256, 512, 761, 1024 },
    { 0, 256, 512, 759, 1024 },
    { 0, 256, 513, 759, 1024 },
    { 0, 256, 512, 758, 1024 },
    { 0, 256, 512, 760, 1024 },
  },
  columnBands = {
    { 0, 256, 512, 768, 1024, 1280, 1536 },
    { 0, 256, 512, 754, 1065, 1306, 1536 },
    { 0, 256, 512, 755, 1024, 1280, 1536 },
    { 0, 256, 512, 768, 1024, 1280, 1536 },
  },
  replacements = {
    {
      path = 'assets/art/imp-strike-fresco-v12.png',
      columns = 2,
      rows = 1,
      targets = { 10, 11 },
      scale = 0.94,
    },
  },
}
EnemyArt.entries.armored = {
  path = 'assets/art/armored-fresco-v12.png',
  columns = 6,
  rows = 4,
  bands = {
    { 0, 256, 512, 752, 1024 },
    { 0, 256, 512, 752, 1024 },
    { 0, 256, 512, 752, 1024 },
    { 0, 256, 512, 752, 1024 },
    { 0, 256, 512, 752, 1024 },
    { 0, 256, 512, 754, 1024 },
  },
  columnBands = {
    { 0, 256, 512, 768, 1024, 1280, 1536 },
    { 0, 267, 512, 768, 1024, 1288, 1536 },
    { 0, 261, 512, 768, 1010, 1274, 1536 },
    { 0, 256, 512, 768, 1024, 1280, 1536 },
  },
  replacements = {
    {
      path = 'assets/art/armored-step-fresco-v12.png',
      columns = 1,
      rows = 1,
      targets = { 2 },
      scale = 1.02,
    },
    {
      path = 'assets/art/armored-windup-fresco-v12.png',
      columns = 1,
      rows = 1,
      targets = { 8 },
      scale = 1.03,
    },
    {
      path = 'assets/art/armored-strike-matte-fresco-v12.png',
      columns = 1,
      rows = 1,
      targets = { 10 },
      scale = 0.99,
    },
    {
      path = 'assets/art/armored-fall-fresco-v12.png',
      columns = 2,
      rows = 1,
      targets = { 17, 18 },
      scale = 0.98,
    },
  },
}
EnemyArt.entries.stolas = {
  path = 'assets/art/stolas-fresco-v12.png',
  columns = 6,
  rows = 4,
  bands = {
    { 0, 262, 529, 768, 1024 },
    { 0, 261, 527, 768, 1024 },
    { 0, 263, 528, 768, 1024 },
    { 0, 264, 526, 764, 1024 },
    { 0, 264, 528, 768, 1024 },
    { 0, 264, 528, 768, 1024 },
  },
  columnBands = {
    { 0, 242, 504, 767, 1028, 1293, 1536 },
    { 0, 256, 512, 762, 1019, 1280, 1536 },
    { 0, 256, 512, 729, 980, 1249, 1536 },
    { 0, 243, 501, 763, 1022, 1287, 1536 },
  },
  replacements = {
    {
      path = 'assets/art/stolas-repair-fresco-v12.png',
      columns = 3,
      rows = 2,
      targets = { 4, 5, 16, 22, 23, 17 },
      scale = 0.93,
      bands = { { 0, 503, 1024 }, { 0, 512, 1024 }, { 0, 512, 1024 } },
      columnBands = { { 0, 512, 1024, 1536 }, { 0, 512, 1006, 1536 } },
    },
  },
}
EnemyArt.entries.buer = {
  path = 'assets/art/buer-fresco-v12.png',
  columns = 4,
  rows = 4,
  bands = {
    { 0, 313, 634, 940, 1254 },
    { 0, 313, 633, 940, 1254 },
    { 0, 314, 629, 940, 1254 },
    {
      0,
      313,
      635,
      940,
      1254,
    },
  },
  columnBands = {
    { 0, 313, 627, 940, 1254 },
    { 0, 313, 635, 946, 1254 },
    { 0, 313, 627, 940, 1254 },
    { 0, 313, 627, 940, 1254 },
  },
}
EnemyArt.entries.boss = {
  path = 'assets/art/boss-fresco-v12.png',
  columns = 4,
  rows = 4,
  bands = {
    { 0, 309, 627, 937, 1254 },
    { 0, 307, 627, 930, 1254 },
    { 0, 313, 635, 930, 1254 },
    {
      0,
      313,
      628,
      929,
      1254,
    },
  },
  columnBands = {
    { 0, 313, 627, 940, 1254 },
    { 0, 313, 627, 940, 1254 },
    { 0, 313, 627, 944, 1254 },
    { 0, 313, 627, 940, 1254 },
  },
  replacements = {
    {
      path = 'assets/art/boss-fall-fresco-v12.png',
      columns = 2,
      rows = 1,
      targets = { 11, 12 },
      scale = 0.96,
    },
  },
}
EnemyArt.entries.furfur = {
  path = 'assets/art/furfur-fresco-v12.png',
  columns = 6,
  rows = 4,
  bands = {
    { 0, 256, 512, 753, 1024 },
    { 0, 256, 512, 754, 1024 },
    { 0, 244, 512, 756, 1024 },
    { 0, 256, 512, 756, 1024 },
    { 0, 256, 512, 756, 1024 },
    { 0, 256, 512, 757, 1024 },
  },
  columnBands = {
    { 0, 292, 533, 768, 1024, 1280, 1536 },
    { 0, 284, 518, 768, 1024, 1320, 1536 },
    { 0, 262, 510, 765, 1024, 1278, 1536 },
    { 0, 261, 512, 768, 1024, 1280, 1536 },
  },
}
-- The action atlases above never move. Quiet poses have their own transparent
-- source, appended after the original rear views, and share the same renderer.
for _, kind in ipairs(EnemyArt.kinds) do
  local entry, quiet = EnemyArt.entries[kind], Idle.entries[kind]
  entry.originalCount = entry.columns * entry.rows
  entry.totalFrames = quiet.first + Idle.count - 1
  entry.replacements = entry.replacements or {}
  entry.replacements[#entry.replacements + 1] = {
    path = 'assets/art/' .. kind .. '-idle-fresco-v13.png',
    columns = 2,
    rows = 2,
    targets = { quiet.first, quiet.first + 1, quiet.first + 2, quiet.first + 3 },
    scale = quiet.scale,
    crops = quiet.crops,
    idle = true,
  }
end
function EnemyArt.frameCount(kind)
  return assert(EnemyArt.entries[kind]).totalFrames
end

EnemyArt.layouts = Frames
return EnemyArt

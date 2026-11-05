-- Anatomical landmarks of painted frames (plan v7 H0): source pixels of the
-- frame's own image, marked by eye on magnified crops with a pixel grid
-- (work/annotate), never derived from the volumes they test. Each frame
-- names the real transition that shows it in play (via): a knockdown, a
-- falter (a broken guard; the exposed pain pose of a boss) or the
-- creature's first attack (wind-up, strike, recovery).
--   { x, y, kind, note[, pending] }
--   kind  head / torso / lower   the zone a shot there must meet
--         body                   painted flesh of some zone (arms, hips)
--         air                    a shot there must meet nothing
--         horn / wing / mane / weapon / effect
--                                painted, its rule is undecided (plan v7
--                                H5): measured and reported, not judged
--   pending  the plan v7 stage that will make a failing landmark pass; the
--            test requires it to fail until then (a fix must remove it)
-- Frames: the live poses whose measured head ghost was worst (hit-fit.txt)
-- and the Margrave's own poses (wind-up 5, strike 7, recovery 8, exposed 9).
-- The bosses are never knocked down alive: their collapse frames are the
-- dead's (enemies/corpse.lua) and are not here.
local landmarks = {
  {
    kind = 'imp',
    frame = 14,
    via = 'knockdown',
    image = 'assets/art/imp-fresco-v12.png',
    points = {
      { 404, 612, 'head', 'skull' },
      { 376, 632, 'torso', 'ribs' },
      { 356, 712, 'lower', 'shin' },
      { 396, 737, 'lower', 'foot' },
      { 496, 532, 'air', 'above the right wing' },
    },
  },
  {
    kind = 'imp',
    frame = 15,
    via = 'knockdown',
    image = 'assets/art/imp-fresco-v12.png',
    points = {
      { 683, 660, 'head', 'skull' },
      { 642, 642, 'torso', 'ribs' },
      { 597, 702, 'lower', 'thigh' },
      { 687, 562, 'air', 'above the skull' },
      { 652, 562, 'air', 'above the back' },
    },
  },
  {
    kind = 'imp',
    frame = 16,
    via = 'knockdown',
    image = 'assets/art/imp-fresco-v12.png',
    points = {
      { 968, 708, 'head', 'skull on the floor' },
      { 895, 692, 'torso', 'ribs, lying' },
      { 850, 707, 'lower', 'haunch' },
      { 780, 722, 'lower', 'outstretched leg' },
      { 895, 602, 'air', 'above the lying ribs' },
      { 965, 652, 'air', 'above the lying skull' },
      { 1002, 682, 'horn', 'horn tip' },
    },
  },
  {
    kind = 'armored',
    frame = 14,
    via = 'knockdown',
    image = 'assets/art/armored-fresco-v12.png',
    points = {
      { 462, 565, 'head', 'hooded skull' },
      { 401, 582, 'torso', 'breastplate' },
      { 406, 642, 'torso', 'belly plate' },
      { 401, 702, 'lower', 'greave' },
      { 348, 727, 'lower', 'rear boot' },
      { 496, 532, 'air', 'beside the hood' },
    },
  },
  {
    kind = 'armored',
    frame = 15,
    via = 'knockdown',
    image = 'assets/art/armored-fresco-v12.png',
    points = {
      { 707, 612, 'head', 'hooded skull' },
      { 652, 617, 'torso', 'back plate' },
      { 562, 712, 'lower', 'knee' },
      { 612, 722, 'lower', 'shin' },
      { 707, 557, 'air', 'above the hood' },
    },
  },
  {
    kind = 'armored',
    frame = 16,
    via = 'knockdown',
    image = 'assets/art/armored-fresco-v12.png',
    points = {
      { 833, 644, 'head', 'hooded skull on the floor' },
      { 893, 662, 'torso', 'back plate, lying' },
      { 968, 692, 'lower', 'legs, lying' },
      { 923, 617, 'body', 'outstretched arm' },
      { 833, 577, 'air', 'above the lying skull' },
      { 908, 562, 'air', 'above the lying back' },
    },
  },
  {
    kind = 'stolas',
    frame = 14,
    via = 'knockdown',
    image = 'assets/art/stolas-fresco-v12.png',
    points = {
      { 428, 619, 'head', 'owl face' },
      { 381, 647, 'torso', 'chest' },
      { 348, 697, 'lower', 'left leg' },
      { 413, 699, 'lower', 'right leg' },
      { 381, 712, 'air', 'between the legs' },
      { 426, 572, 'air', 'above the face' },
      { 306, 642, 'wing', 'wing' },
    },
  },
  {
    kind = 'stolas',
    frame = 15,
    via = 'knockdown',
    image = 'assets/art/stolas-fresco-v12.png',
    points = {
      { 664, 630, 'head', 'owl face' },
      { 617, 648, 'torso', 'chest' },
      { 609, 690, 'lower', 'thigh' },
      { 669, 690, 'lower', 'right leg' },
      { 667, 573, 'air', 'above the face' },
      { 627, 728, 'air', 'between the feet' },
      { 552, 643, 'wing', 'wing' },
    },
  },
  {
    kind = 'buer',
    frame = 10,
    via = 'knockdown',
    image = 'assets/art/buer-fresco-v12.png',
    points = {
      { 485, 788, 'head', 'face' },
      { 453, 813, 'torso', 'chest' },
      { 458, 888, 'lower', 'hoof' },
      { 363, 873, 'lower', 'left foot' },
      { 488, 698, 'air', 'above the mane' },
      { 498, 893, 'air', 'between hoof and hand' },
      { 438, 743, 'mane', 'mane' },
    },
  },
  {
    kind = 'buer',
    frame = 11,
    via = 'knockdown',
    image = 'assets/art/buer-fresco-v12.png',
    points = {
      { 857, 854, 'head', 'face on the floor' },
      { 792, 844, 'torso', 'chest, lying' },
      { 717, 869, 'lower', 'legs, lying' },
      { 732, 809, 'lower', 'raised knee' },
      { 792, 719, 'air', 'above the lying chest' },
      { 852, 744, 'air', 'above the lying face' },
    },
  },
  {
    kind = 'boss',
    frame = 5,
    via = 'attack',
    image = 'assets/art/boss-fresco-v12.png',
    points = {
      { 182, 401, 'head', 'skull' },
      { 140, 459, 'torso', 'chest' },
      { 140, 509, 'torso', 'belly' },
      { 135, 606, 'lower', 'left foot' },
      { 260, 611, 'lower', 'right foot' },
      { 195, 599, 'air', 'between the feet' },
      { 210, 354, 'air', 'above the skull' },
      { 255, 379, 'body', 'raised claw arm' },
    },
  },
  {
    kind = 'boss',
    frame = 7,
    via = 'attack',
    image = 'assets/art/boss-fresco-v12.png',
    points = {
      { 812, 420, 'head', 'skull' },
      { 767, 468, 'torso', 'chest' },
      { 752, 503, 'torso', 'belly' },
      { 722, 583, 'lower', 'left leg' },
      { 817, 593, 'lower', 'right leg' },
      { 767, 603, 'air', 'between the feet' },
      { 832, 363, 'air', 'above the skull' },
    },
  },
  {
    kind = 'boss',
    frame = 8,
    via = 'attack',
    image = 'assets/art/boss-fresco-v12.png',
    points = {
      { 1160, 428, 'head', 'skull' },
      { 1115, 463, 'torso', 'chest' },
      { 1115, 513, 'torso', 'belly' },
      { 1140, 538, 'lower', 'thigh' },
      { 1145, 613, 'lower', 'foot' },
      { 1105, 593, 'air', 'between the legs' },
      { 1080, 383, 'air', 'above the shoulder' },
      { 990, 563, 'weapon', 'cleaver' },
    },
  },
  {
    kind = 'boss',
    frame = 9,
    via = 'falter',
    image = 'assets/art/boss-fresco-v12.png',
    points = {
      { 125, 655, 'head', 'skull thrown back' },
      { 140, 712, 'torso', 'chest wound' },
      { 160, 762, 'torso', 'belly' },
      { 155, 817, 'lower', 'thigh' },
      { 105, 897, 'lower', 'left foot' },
      { 220, 887, 'lower', 'right foot' },
      { 165, 897, 'air', 'between the feet' },
      { 185, 657, 'air', 'beside the skull' },
      { 40, 877, 'weapon', 'cleaver' },
    },
  },
  {
    kind = 'furfur',
    frame = 13,
    via = 'falter',
    image = 'assets/art/furfur-fresco-v12.png',
    points = {
      { 220, 552, 'head', 'stag skull' },
      { 175, 632, 'torso', 'ribcage' },
      { 80, 712, 'lower', 'hind leg' },
      { 240, 650, 'lower', 'raised foreleg' },
      { 200, 717, 'air', 'between the legs' },
      { 125, 612, 'air', 'above the back' },
      { 140, 584, 'horn', 'antler' },
      { 45, 662, 'effect', 'flaming tail' },
    },
  },
}
-- These supplements preserve the original pixel silhouettes. Transfer the
-- independently marked source pixels by crop offset, not from the hit masks.
local supplements = {
  boss = {
    [7] = { first = 21, x = 627, y = 313, row = 0 },
    [8] = { first = 27, x = 940, y = 313, row = 1024 },
    [9] = { first = 24, x = 0, y = 627, row = 512 },
  },
  furfur = { [13] = { first = 32, x = 0, y = 512, row = 512 } },
}
-- Independent points on the supplemental Iron Thrall poses, reached by named attacks.
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 29,
  via = 'attack:cleave',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 244, 96, 'head', 'exposed face' },
    { 180, 152, 'torso', 'breastplate' },
    { 104, 289, 'lower', 'iron shin' },
    { 58, 129, 'body', 'exposed hand' },
    { 20, 20, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 30,
  via = 'attack:cleave',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 605, 94, 'head', 'exposed face' },
    { 549, 150, 'torso', 'breastplate' },
    { 463, 290, 'lower', 'iron shin' },
    { 476, 52, 'body', 'exposed hand' },
    { 382, 20, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 31,
  via = 'attack:cleave',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 950, 80, 'head', 'exposed face' },
    { 909, 169, 'torso', 'breastplate' },
    { 828, 280, 'lower', 'iron shin' },
    { 977, 126, 'body', 'exposed hand' },
    { 744, 20, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 32,
  via = 'attack:cleave',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 1322, 95, 'head', 'exposed face' },
    { 1263, 172, 'torso', 'breastplate' },
    { 1197, 275, 'lower', 'iron shin' },
    { 1394, 159, 'body', 'exposed hand' },
    { 1106, 20, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 33,
  via = 'attack:shoulder',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 236, 495, 'head', 'exposed face' },
    { 184, 531, 'torso', 'breastplate' },
    { 121, 638, 'lower', 'iron shin' },
    { 185, 561, 'body', 'exposed hand' },
    { 20, 382, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 34,
  via = 'attack:shoulder',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 639, 476, 'head', 'exposed face' },
    { 575, 528, 'torso', 'breastplate' },
    { 481, 635, 'lower', 'iron shin' },
    { 570, 536, 'body', 'exposed hand' },
    { 382, 382, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 35,
  via = 'attack:shoulder',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 1010, 471, 'head', 'exposed face' },
    { 951, 525, 'torso', 'breastplate' },
    { 852, 608, 'lower', 'iron shin' },
    { 994, 535, 'body', 'exposed hand' },
    { 744, 382, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 36,
  via = 'attack:shoulder',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 1295, 437, 'head', 'exposed face' },
    { 1255, 518, 'torso', 'breastplate' },
    { 1202, 610, 'lower', 'iron shin' },
    { 1360, 550, 'body', 'exposed hand' },
    { 1106, 382, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 37,
  via = 'attack:ground-slam',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 202, 825, 'head', 'exposed face' },
    { 182, 898, 'torso', 'breastplate' },
    { 134, 1000, 'lower', 'iron shin' },
    { 143, 759, 'body', 'exposed hand' },
    { 20, 744, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 38,
  via = 'attack:ground-slam',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 585, 925, 'head', 'exposed face' },
    { 546, 962, 'torso', 'breastplate' },
    { 473, 1000, 'lower', 'iron shin' },
    { 551, 1045, 'body', 'exposed hand' },
    { 382, 744, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 39,
  via = 'attack:ground-slam',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 950, 848, 'head', 'exposed face' },
    { 907, 914, 'torso', 'breastplate' },
    { 843, 983, 'lower', 'iron shin' },
    { 876, 950, 'body', 'exposed hand' },
    { 744, 744, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 40,
  via = 'attack:back-swing',
  image = 'assets/art/armored-attacks-v45.png',
  points = {
    { 1324, 806, 'head', 'exposed face' },
    { 1269, 877, 'torso', 'breastplate' },
    { 1182, 1015, 'lower', 'iron shin' },
    { 1214, 863, 'body', 'exposed hand' },
    { 1106, 744, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 41,
  via = 'attack:claw',
  image = 'assets/art/armored-claw-v45.png',
  points = {
    { 447, 155, 'head', 'exposed face' },
    { 335, 317, 'torso', 'breastplate' },
    { 188, 553, 'lower', 'iron knee' },
    { 301, 237, 'body', 'forward palm' },
    { 20, 20, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 42,
  via = 'attack:claw',
  image = 'assets/art/armored-claw-v45.png',
  points = {
    { 1141, 154, 'head', 'exposed face' },
    { 1097, 332, 'torso', 'breastplate' },
    { 912, 546, 'lower', 'iron knee' },
    { 1068, 293, 'body', 'forward palm' },
    { 740, 20, 'air', 'clear gutter' },
  },
}
landmarks[#landmarks + 1] = {
  kind = 'armored',
  frame = 43,
  via = 'attack:claw',
  image = 'assets/art/armored-claw-v45.png',
  points = {
    { 1878, 206, 'head', 'exposed face' },
    { 1836, 334, 'torso', 'breastplate' },
    { 1655, 542, 'lower', 'iron knee' },
    { 1678, 437, 'body', 'forward palm' },
    { 1460, 20, 'air', 'clear gutter' },
  },
}
local result = {}
for _, entry in ipairs(landmarks) do
  local group = supplements[entry.kind]
  local transfer = group and group[entry.frame]
  if transfer then
    for i = 0, 2 do
      local copy = require('src.core.schema').copy(entry)
      copy.frame = transfer.first + i
      copy.image = 'assets/art/' .. entry.kind .. '-breath-fresco-v45.png'
      for _, point in ipairs(copy.points) do
        point[1] = point[1] - transfer.x + i * 512
        point[2] = point[2] - transfer.y + transfer.row
      end
      result[#result + 1] = copy
    end
  else
    result[#result + 1] = entry
  end
end
return result

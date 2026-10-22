-- Pixel size of every painted source image an enemy frame or ability sheet is
-- cut from (width, height). Anatomy regions traced in source pixels are
-- converted to frame coordinates with these (content/art/anatomy/author.lua),
-- never with a size written into a creature's file. tests/cases/
-- anatomy_data.lua checks every entry against the real PNG: a resized atlas
-- fails there instead of silently moving its regions.
return {
  ['assets/art/armored-fall-fresco-v12.png'] = { 1774, 887 },
  ['assets/art/armored-fresco-v12.png'] = { 1536, 1024 },
  ['assets/art/armored-idle-fresco-v13.png'] = { 1536, 1024 },
  ['assets/art/armored-step-fresco-v12.png'] = { 1254, 1254 },
  ['assets/art/armored-strike-matte-fresco-v12.png'] = { 1254, 1254 },
  ['assets/art/armored-windup-fresco-v12.png'] = { 1196, 1315 },
  ['assets/art/boss-fall-fresco-v12.png'] = { 1774, 887 },
  ['assets/art/boss-fresco-v12.png'] = { 1254, 1254 },
  ['assets/art/boss-idle-fresco-v13.png'] = { 1254, 1254 },
  ['assets/art/buer-fresco-v12.png'] = { 1254, 1254 },
  ['assets/art/buer-idle-fresco-v13.png'] = { 1254, 1254 },
  ['assets/art/furfur-fresco-v12.png'] = { 1536, 1024 },
  ['assets/art/furfur-idle-fresco-v13.png'] = { 1536, 1024 },
  ['assets/art/imp-fresco-v12.png'] = { 1536, 1024 },
  ['assets/art/imp-idle-fresco-v13.png'] = { 1347, 1167 },
  ['assets/art/imp-leap-fresco-v23.png'] = { 1536, 1024 },
  ['assets/art/imp-strike-fresco-v12.png'] = { 1774, 887 },
  ['assets/art/stolas-evade-fresco-v23.png'] = { 1536, 1024 },
  ['assets/art/stolas-fresco-v12.png'] = { 1536, 1024 },
  ['assets/art/stolas-idle-fresco-v13.png'] = { 1536, 1024 },
  ['assets/art/stolas-repair-fresco-v12.png'] = { 1536, 1024 },
}

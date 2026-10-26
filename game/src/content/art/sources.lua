-- Pixel size of every painted source image an enemy frame or ability sheet is
-- cut from (width, height). Anatomy regions traced in source pixels are
-- converted to frame coordinates with these (content/art/anatomy/author.lua),
-- never with a size written into a creature's file. The atlas images carry
-- theirs in their sheets (content/art/atlases.lua: sizes, the same table);
-- the ability sheets are listed here. tests/cases/anatomy_data.lua checks
-- every entry against the real PNG: a resized atlas fails there instead of
-- silently moving its regions.
local Sizes = require('src.content.art.atlases').sizes
Sizes['assets/art/imp-leap-fresco-v23.png'] = { 1536, 1024 }
Sizes['assets/art/stolas-evade-fresco-v23.png'] = { 1536, 1024 }
return Sizes

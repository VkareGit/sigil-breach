-- The frame placement of every painted creature atlas, by atlas id: { size,
-- feet, frames } (content/art/sheet.lua: layout). A result of the atlas
-- sheets (content/creatures/<id>/sheet.lua), never written by hand (plan v10 V7). Pure
-- data: no GPU or collision dependency.
return require('src.content.art.atlases').layouts

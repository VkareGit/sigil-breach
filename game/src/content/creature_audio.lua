-- Presentation profiles augment existing action voices without entering frozen combat definitions.
-- A field selects its painted material first, then its geometric kind.
-- Each creature keeps its own profile in its package (PLAN F4:
-- content/creatures/<id>/audio.lua), by the package's id.
local Packages = require('src.content.creature_packages')
local Profiles = {}
for _, part in ipairs(Packages.parts('audio')) do
  Profiles[part.id] = require(part.module)
end
return Profiles

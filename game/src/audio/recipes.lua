-- Every sound recipe (PLAN G7): the files of content/sounds, each a bank of
-- recipes or a function of the synthesiser (audio/synth.lua) that makes one,
-- and every creature package's own performances (content/creatures/<id>/
-- voices.lua). A new sound is a new entry there; the player asks only by name.
local Synth = require('src.audio.synth')
local R = {}
-- The banks as they were made, by file: what each one added.
local banks = {}
local function bank(recipes)
  for name, recipe in pairs(recipes) do
    assert(not R[name], 'duplicate sound recipe ' .. name)
    R[name] = recipe
  end
  return recipes
end
local SOUNDS = 'src/content/sounds'
local files = love.filesystem.getDirectoryItems(SOUNDS)
table.sort(files)
for _, file in ipairs(files) do
  local name = file:match('^(.+)%.lua$')
  assert(name, SOUNDS .. ' holds only recipe banks: ' .. file)
  local made = require('src.content.sounds.' .. name)
  if type(made) == 'function' then
    made = made(Synth)
  end
  banks[name] = bank(made)
end
for _, part in ipairs(require('src.content.creature_packages').parts('voices')) do
  banks[part.id] = bank(require(part.module))
end
-- Not a recipe: the banks by file, for the tests (setmetatable keeps it out of
-- the names the player asks for).
return setmetatable(R, { __index = { banks = banks } })

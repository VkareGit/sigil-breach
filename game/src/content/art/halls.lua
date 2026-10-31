-- The kinds of painted hall a map may place. A new kind is one entry here and
-- one builder in render/kit/halls.lua.
local chapel = require('src.content.art.chapel_hall')
return { chapel = chapel, rooms = chapel }

-- What a mark of the knight's movement may say (content/movement_marks.lua,
-- read by feedback/movement_marks.lua): a spray of pigment flecks, and a
-- move's sprays with its flash and, for a trail, its rhythm.
local Schema = require('src.core.schema')
local Mark = {}
Mark.spray = Schema:new('movement spray', {
  pigment = { type = 'string', required = true, desc = 'a name of the pigments' },
  from = {
    type = 'string',
    required = true,
    values = { 'origin', 'feet', 'view', 'charge' },
    desc = 'the dodge left / the boots / before the eyes / a charge in flight',
  },
  count = { type = 'number', required = true, min = 1, desc = 'flecks' },
  ahead = { type = 'number', default = 0, desc = 'm along the move (the gaze for view)' },
  side = { type = 'number', default = 0, min = 0, desc = 'm at random either way across' },
  height = { type = 'number', default = 0, desc = 'm above the ground (the eye for view)' },
  rise = { type = 'number', default = 0, min = 0, desc = 'm more at random' },
  carry = { type = 'number', default = 0, desc = "share of the emitter's velocity" },
  along = { type = 'number', default = 0, desc = 'm/s with the move' },
  up = { type = 'number', default = 0, desc = 'm/s' },
  scatter = { type = 'number', default = 0, min = 0, desc = 'm/s at random' },
  ring = { type = 'boolean', default = false, desc = 'outward all round, not along' },
  life = { type = 'number', required = true, min = 0.01, desc = 's, + half again at random' },
  size = { type = 'number', required = true, min = 0.01, desc = 'x a 9 cm fleck' },
})
Mark.fall = Schema:new('movement fall', {
  from = { type = 'number', required = true, min = 0, desc = 'm/s: a slower fall raises none' },
  full = { type = 'number', required = true, min = 0, desc = 'm/s: the whole count from here' },
})
Mark.move = Schema:new('movement mark', {
  sprays = { type = 'table', required = true, list = Mark.spray },
  flash = { type = 'number', default = 0, min = 0, max = 1, desc = "the post's gilded wash" },
  every = { type = 'number', min = 0.005, desc = 'a trail: s between its sprays' },
  fall = { type = 'table', schema = Mark.fall, desc = 'a landing: counts scale with the fall' },
})
return Mark

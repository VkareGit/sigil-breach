-- How the knight's movement marks the painted world (feedback/movement_marks.lua):
-- the fresco's pigments, and for each move the flecks it throws. Presentation
-- only: nothing here changes how the knight moves or what a blow meets.
-- Every move is built by its schema (content/defs/movement_mark.lua).
local Mark = require('src.content.defs.movement_mark')
local Marks = {}
-- The pigments of the walls (rgb): lamp soot, wood ash, lime plaster, yellow
-- ochre, sinopia (the red earth of the underdrawing), gold leaf, a live ember.
Marks.pigments = {
  soot = { 0.10, 0.085, 0.075 },
  ash = { 0.46, 0.42, 0.38 },
  lime = { 0.90, 0.86, 0.74 },
  ochre = { 0.80, 0.54, 0.22 },
  sinopia = { 0.62, 0.22, 0.12 },
  gold = { 0.86, 0.66, 0.30 },
  ember = { 1.0, 0.46, 0.14 },
}
-- A spray of flecks. Where: from 'origin' (the spot a dodge left), 'feet',
-- 'view' (before the eyes) or 'charge' (a powder charge in flight); ahead (m,
-- along the move, or the gaze for 'view'), side (m, random either way across
-- it), height (m above the ground, or the eye for 'view') + rise (m, random).
-- How it flies: carry (share of the emitter's own velocity), along (m/s with
-- the move), up (m/s), scatter (m/s, random), ring (outward all round
-- instead of along). count, life (s, + half again at random), size (x a
-- 9 cm fleck).
-- A move: its sprays, a flash (the post's gilded wash, view.surge), every (s
-- between the sprays of a trail).
Marks.moves = {
  -- The dodge: ash stands where the knight was, soot kicks off the stone,
  -- motes of gold stream past his eyes.
  dash = {
    flash = 0.35,
    sprays = {
      {
        pigment = 'ash',
        from = 'origin',
        count = 8,
        side = 0.35,
        height = 0.3,
        rise = 1.2,
        along = 0.8,
        up = 0.9,
        scatter = 1.1,
        life = 0.6,
        size = 0.8,
      },
      {
        pigment = 'soot',
        from = 'origin',
        count = 5,
        side = 0.3,
        height = 0.05,
        rise = 0.3,
        along = 1.6,
        up = 0.5,
        scatter = 1.6,
        life = 0.45,
        size = 0.7,
      },
      {
        pigment = 'gold',
        from = 'view',
        count = 9,
        ahead = 2.6,
        side = 1.4,
        height = -0.6,
        rise = 1.1,
        carry = 0.3,
        up = 0.2,
        scatter = 0.4,
        life = 0.22,
        size = 0.45,
      },
      {
        pigment = 'ash',
        from = 'view',
        count = 6,
        ahead = 2.8,
        side = 1.6,
        height = -0.9,
        rise = 1.5,
        carry = 0.3,
        up = 0.3,
        scatter = 0.5,
        life = 0.25,
        size = 0.8,
      },
    },
  },
  -- The dodge under way: soot and ash from the heels.
  dashTrail = {
    every = 0.03,
    sprays = {
      {
        pigment = 'soot',
        from = 'feet',
        count = 1,
        ahead = -0.3,
        side = 0.25,
        height = 0.08,
        rise = 0.3,
        carry = 0.15,
        up = 0.6,
        scatter = 0.5,
        life = 0.4,
        size = 0.6,
      },
      {
        pigment = 'ash',
        from = 'feet',
        count = 1,
        ahead = -0.2,
        side = 0.3,
        height = 0.1,
        rise = 0.6,
        carry = 0.1,
        up = 0.8,
        scatter = 0.6,
        life = 0.5,
        size = 0.7,
      },
    },
  },
  -- The slide begins: plaster dust bursts off the floor.
  slide = {
    sprays = {
      {
        pigment = 'lime',
        from = 'feet',
        count = 7,
        ahead = 0.9,
        side = 0.5,
        height = 0.04,
        rise = 0.1,
        carry = 1,
        along = 1.2,
        up = 2.0,
        scatter = 1.0,
        life = 0.5,
        size = 0.4,
      },
      {
        pigment = 'ash',
        from = 'feet',
        count = 4,
        ahead = 0.3,
        side = 0.35,
        height = 0.04,
        carry = 0.5,
        up = 0.7,
        scatter = 0.9,
        life = 0.6,
        size = 0.7,
      },
    },
  },
  -- The slide: sparks fly up off the greaves, dust settles behind.
  slideTrail = {
    every = 0.035,
    sprays = {
      {
        pigment = 'ember',
        from = 'feet',
        count = 3,
        ahead = 0.55,
        side = 0.45,
        height = 0.04,
        carry = 1,
        along = 2.5,
        up = 3.2,
        scatter = 1.3,
        life = 0.32,
        size = 0.4,
      },
      {
        pigment = 'gold',
        from = 'feet',
        count = 1,
        ahead = 0.55,
        side = 0.45,
        height = 0.04,
        carry = 1,
        along = 2.8,
        up = 3.5,
        scatter = 1.1,
        life = 0.28,
        size = 0.32,
      },
      {
        pigment = 'ash',
        from = 'feet',
        count = 1,
        ahead = 0.2,
        side = 0.3,
        height = 0.05,
        carry = 0.3,
        up = 0.4,
        scatter = 0.5,
        life = 0.5,
        size = 0.6,
      },
    },
  },
  -- The jump: a ring of dust from the boots.
  takeoff = {
    sprays = {
      {
        pigment = 'ash',
        from = 'feet',
        count = 6,
        height = 0.04,
        carry = 0.3,
        ring = true,
        up = 0.5,
        scatter = 1.2,
        life = 0.45,
        size = 0.6,
      },
    },
  },
  -- The landing: dust and plaster all round, more for a harder fall; a fall
  -- slower than from (m/s) raises none, from full the whole count.
  landing = {
    fall = { from = 4, full = 12 },
    sprays = {
      {
        pigment = 'ash',
        from = 'feet',
        count = 10,
        height = 0.04,
        ring = true,
        up = 0.9,
        scatter = 3.0,
        life = 0.7,
        size = 0.8,
      },
      {
        pigment = 'lime',
        from = 'feet',
        count = 5,
        height = 0.04,
        ring = true,
        up = 1.8,
        scatter = 2.0,
        life = 0.5,
        size = 0.55,
      },
    },
  },
  -- The perfect dodge: the shade the knight leaves rises in gold leaf and
  -- lime over the red earth of the underdrawing.
  afterimage = {
    sprays = {
      {
        pigment = 'gold',
        from = 'origin',
        count = 14,
        side = 0.3,
        height = 0.2,
        rise = 1.5,
        up = 0.9,
        scatter = 0.45,
        life = 0.9,
        size = 0.45,
      },
      {
        pigment = 'lime',
        from = 'origin',
        count = 8,
        side = 0.25,
        height = 0.4,
        rise = 1.2,
        up = 0.7,
        scatter = 0.35,
        life = 0.8,
        size = 0.5,
      },
      {
        pigment = 'sinopia',
        from = 'origin',
        count = 6,
        side = 0.35,
        height = 0.05,
        rise = 0.4,
        ring = true,
        up = 0.3,
        scatter = 0.9,
        life = 0.7,
        size = 0.6,
      },
    },
  },
  -- A powder charge in flight: embers from its fuse, a thread of soot.
  charge = {
    every = 0.04,
    sprays = {
      {
        pigment = 'ember',
        from = 'charge',
        count = 1,
        carry = 0.2,
        up = 0.8,
        scatter = 1.2,
        life = 0.25,
        size = 0.2,
      },
      {
        pigment = 'soot',
        from = 'charge',
        count = 1,
        carry = 0.1,
        up = 0.5,
        scatter = 0.3,
        life = 0.5,
        size = 0.45,
      },
    },
  },
}
for name, move in pairs(Marks.moves) do
  local built = Mark.move:build(move, 'movement marks.' .. name)
  for i, spray in ipairs(built.sprays) do
    assert(
      Marks.pigments[spray.pigment],
      'movement marks.' .. name .. '[' .. i .. ']: no pigment ' .. spray.pigment
    )
  end
  Marks.moves[name] = built
end
return Marks

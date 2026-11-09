-- The colour and life of the map's lights (render/lights.lua): lamps, seals,
-- the Ember, projectiles, the ambient, and how the light of the slots is
-- sampled for a painted body. Colours are { r, g, b }, lengths in metres.
return {
  -- The Ember's light above its floor.
  emberHeight = 1.55,
  -- A lamp's flicker: its phase step, two waves (rate, depth) with the
  -- second offset, and its colour where it names none.
  lamp = {
    phase = 1.7,
    rate = 1.3,
    depth = 0.045,
    rate2 = 2.3,
    offset2 = 1.1,
    depth2 = 0.025,
    color = { 1.65, 1.02, 0.57 },
  },
  -- A seal's light: dim when active, brighter while it waits; a base and the
  -- share of its own colour.
  seal = { active = 0.18, waiting = 0.52, base = 0.38, own = 0.45 },
  -- The Ember's light, lit and resting, and its colour.
  shrine = { lit = 1.1, resting = 0.25, color = { 0.72, 1.02, 0.82 } },
  -- The two nearest projectiles light their surroundings: nearer than
  -- reach² m², in their colour (or this one) at this share.
  projectile = { reach2 = 36, color = { 1, 0.4, 0.1 }, share = 0.75 },
  -- Where the map's atmosphere names none: the shader's ambient, and the
  -- light on a painted body.
  ambient = { 0.29, 0.31, 0.35 },
  figures = { 0.51, 0.53, 0.57 },
  -- A body's light from the slots: share at the source, fall-off per m², and
  -- the brightest it is shown.
  sample = { share = 0.40, falloff = 0.22, brightest = { 1.08, 1.06, 1.02 } },
  -- Contact shade on the ground image beside a wall: darkest share, the rest,
  -- and the distance it fades over (render/light_visibility.lua).
  contact = { darkest = 0.72, rest = 0.28, reach = 1.35 },
}

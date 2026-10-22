-- Contact rules, separate from creature anatomy and weapon algorithms.
-- HP factors are explicit gameplay coefficients, not real-world joules.
--   wound       share of the hit that reaches health (the rest is absorbed)
--   guard       share of the impact that wears the guard
--   penetrable  a shot that passes this body may go on to the next one
--   debris      what a shot it stops throws (feedback/impact_response.lua);
--               none: a soft surface. Nothing asks for a material by name.
return {
  flesh = { wound = 1, guard = 1, penetrable = true },
  metal = { wound = 1, guard = 1, penetrable = false, debris = 'metal' },
  bone = { wound = 1, guard = 1, penetrable = true, debris = 'bone' },
  horn = { wound = 0, guard = 1, penetrable = true, debris = 'bone' },
  membrane = { wound = 0.25, guard = 0.25, penetrable = true },
  -- Clothing over a body is no armour. Loose cloth is authored hittable=false.
  cloth = { wound = 1, guard = 1, penetrable = true },
  effect = { wound = 0, guard = 0, penetrable = true },
}

-- How this creature sounds beyond its action voices (content/creature_audio.lua,
-- audio/creature_profiles.lua): its body, actions, projectiles and fields.
return {
  body = {
    step = 'owl_wings',
    evade = 'owl_evade',
    departure = 'owl_departure',
    impact = 'owl_impact_body',
    fall = 'owl_fall',
  },
  actions = {
    ['star-ray'] = { release = 'owl_wave_release' },
    ['star-lance'] = { release = 'owl_cleft_release' },
  },
  projectile = { flight = 'owl_flight', impact = 'owl_impact' },
  fields = {
    wave = { active = 'owl_wave_choir', finish = 'owl_wave_end', sustain = true },
    sweepline = { active = 'owl_cleft_choir', finish = 'owl_cleft_end', sustain = true },
  },
}

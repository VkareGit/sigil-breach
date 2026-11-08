-- How this creature sounds beyond its action voices (content/creature_audio.lua,
-- audio/creature_profiles.lua): its body, actions, projectiles and fields.
return {
  body = {
    step = 'gardener_step',
    evade = 'gardener_shift',
    impact = 'gardener_body_impact',
    fall = 'gardener_fall',
  },
  projectile = { flight = 'gardener_flight', impact = 'gardener_splash' },
  projectiles = {
    ['rot-seed'] = { flight = 'gardener_seed_flight', impact = 'gardener_seed_contact' },
  },
  fields = {
    ['rot-garden'] = { active = 'gardener_root', finish = 'gardener_root_end' },
    ['rot-harvest'] = { active = 'gardener_bloom', finish = 'gardener_bloom_end' },
  },
}

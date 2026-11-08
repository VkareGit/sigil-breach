-- How this creature sounds beyond its action voices (content/creature_audio.lua,
-- audio/creature_profiles.lua): its body, actions, projectiles and fields.
return {
  body = { evade = 'margrave_backstep', impact = 'margrave_crash', fall = 'margrave_fall' },
  projectile = { flight = 'margrave_cinder_flight', impact = 'margrave_cinder_contact' },
  fields = {
    wave = { active = 'margrave_ash_roll', finish = 'margrave_ash_end', sustain = true },
    pool = { active = 'margrave_ash_release', finish = 'margrave_ash_end' },
  },
}

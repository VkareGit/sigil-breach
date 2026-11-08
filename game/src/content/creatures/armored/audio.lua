-- How this creature sounds beyond its action voices (content/creature_audio.lua,
-- audio/creature_profiles.lua): its body, actions, projectiles and fields.
return {
  body = {
    windup = 'iron_prepare',
    strike = 'iron_cut',
    impact = 'iron_crash',
    fall = 'iron_fall',
  },
  actions = { ['ground-slam'] = { prepare = 'iron_prepare', release = 'iron_ground' } },
  fields = { wave = { active = 'iron_ground_roll', finish = 'iron_ground_end', sustain = true } },
}

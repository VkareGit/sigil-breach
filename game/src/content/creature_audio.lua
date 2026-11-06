-- Presentation profiles augment existing action voices without entering frozen combat definitions.
-- A field selects its painted material first, then its geometric kind.
return {
  imp = {
    body = {
      step = 'ember_step',
      evade = 'ember_backstep',
      impact = 'ember_landing',
      fall = 'ember_fall',
    },
  },
  armored = {
    body = {
      windup = 'iron_prepare',
      strike = 'iron_cut',
      impact = 'iron_crash',
      fall = 'iron_fall',
    },
    actions = { ['ground-slam'] = { prepare = 'iron_prepare', release = 'iron_ground' } },
    fields = { wave = { active = 'iron_ground_roll', finish = 'iron_ground_end', sustain = true } },
  },
  stolas = {
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
  },
  buer = {
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
  },
  furfur = {
    body = { evade = 'furfur_backstep', impact = 'furfur_crash', fall = 'furfur_fall' },
  },
  boss = {
    body = { evade = 'margrave_backstep', impact = 'margrave_crash', fall = 'margrave_fall' },
    projectile = { flight = 'margrave_cinder_flight', impact = 'margrave_cinder_contact' },
    fields = {
      wave = { active = 'margrave_ash_roll', finish = 'margrave_ash_end', sustain = true },
      pool = { active = 'margrave_ash_release', finish = 'margrave_ash_end' },
    },
  },
}

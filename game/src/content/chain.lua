-- Chains and deeds: what a run of kills is called and gives, as data. The rules are
-- combat/chain.lua, what is seen and heard feedback/medals.lua. A chain belongs to the weapon that
-- made it: its edge is on that weapon only, and a kill with another begins a new one.
--   steps   count: kills for it; penetration: armour it adds to the weapon's rounds; impact: what
--           it multiplies their guard damage by; heal: health each kill gives from here on
--   medals  rank: a higher one is not replaced by a lower one while it shows
return {
  -- Seconds a chain lives after a kill. A blow taken ends it.
  window = 6,
  medalTime = 1.5,
  medalVolume = 1,
  -- A kill at this share of health or less, and from this near (m), is a deed.
  lastRites = 0.25,
  pointBlank = 2.5,
  steps = {
    { count = 2, id = 'diptych', name = 'chain_diptych', rank = 5 },
    {
      count = 3,
      id = 'triptych',
      name = 'chain_triptych',
      effect = 'chain_effect_pierce',
      rank = 6,
      penetration = 0.25,
    },
    {
      count = 4,
      id = 'tetraptych',
      name = 'chain_tetraptych',
      effect = 'chain_effect_guard',
      rank = 7,
      penetration = 0.25,
      impact = 1.25,
    },
    {
      count = 5,
      id = 'polyptych',
      name = 'chain_polyptych',
      effect = 'chain_effect_heal',
      rank = 8,
      penetration = 0.25,
      impact = 1.25,
      heal = 8,
    },
  },
  medals = {
    absolved = { name = 'medal_absolved', rank = 4 },
    parry = { name = 'medal_parry', rank = 4 },
    one_shot = { name = 'medal_one_shot', rank = 3 },
    last_rites = { name = 'medal_last_rites', rank = 2 },
    smitten = { name = 'medal_smitten', rank = 1 },
    point_blank = { name = 'medal_point_blank', rank = 1 },
  },
}

-- D14 / PLAN P6: copy costs are total capacity, not currency. All values
-- for this first experiment live here. effect names the kind of effect
-- (combat/sigil_kinds.lua, PLAN G2) that reads the rest of a sigil's numbers.
return {
  capacity = 4,
  damageCap = 0.35,
  order = { 'sigil_stolas', 'sigil_furfur', 'sigil_buer', 'sigil_paimon' },
  sigil_stolas = {
    effect = 'verdict',
    costs = { 1, 2, 3 },
    bonus = { 0.15, 0.25, 0.35 },
    hits = 2,
    torso = 0.90,
    weapon = 'judge',
  },
  sigil_furfur = {
    effect = 'riposte',
    costs = { 2, 3, 4 },
    bonus = { 0.20, 0.30, 0.35 },
    window = 2,
    stamina = 4,
  },
  sigil_buer = {
    effect = 'reprisal',
    costs = { 1, 2, 3 },
    heal = { 8, 12, 16 },
    reach = 4,
    flask = 10,
  },
  sigil_paimon = { effect = 'impetus', costs = { 2, 3, 4 }, impact = { 20, 35, 50 }, reload = 0.2 },
}

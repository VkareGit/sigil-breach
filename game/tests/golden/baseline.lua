-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt, section 0.28).
-- 0.25 G3: the knight and the demons are bodies (no walking through, mass
-- shares), out-of-sight routes run straight, the blast meets the chest.
-- 0.25 G4: no aim while staggered, a pull stops a reload, the guard-break
-- hit-stop holds missiles, the dodge's afterimage takes perfect dodges.
-- 0.25 G5: break kills within a 2 s window, longer stagger tiers, the
-- pierce cost of the part passed through.
-- 0.28 H3-H9: painted anatomy, material/corpse contact rules, continuous
-- attacks and the pre-noise pose snapshot. Includes initial step zero and
-- per-part receipt digests; HP, weapon power and cadence are unchanged.
-- 0.31: impulses follow contact/velocity instead of the player's later position;
-- powder uses circular pillars, analytic contacts and the physical leap anchor.
-- Attribution restored HEAD hit_response + explosives IN MEMORY and reproduced
-- all six original hashes. See work/qa-observation/golden-attribution.txt.
-- 0.33 (plan v10 V1): digest v2, no simulation change. The description lists
-- creatures in id order across the living pool and the remains, and leaves out
-- the state clock (phase) of dead bodies, which nothing reads. It was recomputed
-- on the unchanged 0.32 simulation (only qa/golden.lua differed); the digests
-- of v1 were 57ba111d/960187d6, 98255b1c/361bb557 and 4192c0b6/8200078d. The
-- three contact digests are unchanged.
return {
  playtest = '07f73bfa/a9192235',
  human = 'fe26df14/563c8d0f',
  drill = 'c13bcaec/f105ca06',
  playtestContacts = 'aab9a46e/299',
  humanContacts = '4be34edb/671',
  drillContacts = '663b77fc/178',
}

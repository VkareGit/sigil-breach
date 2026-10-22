-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY-0.28.txt).
-- 0.25 G3: the knight and the demons are bodies (no walking through, mass
-- shares), out-of-sight routes run straight, the blast meets the chest.
-- 0.25 G4: no aim while staggered, a pull stops a reload, the guard-break
-- hit-stop holds missiles, the dodge's afterimage takes perfect dodges.
-- 0.25 G5: break kills within a 2 s window, longer stagger tiers, the
-- pierce cost of the part passed through.
-- 0.28 H3-H9: painted anatomy, material/corpse contact rules, continuous
-- attacks and the pre-noise pose snapshot. Includes initial step zero and
-- per-part receipt digests; HP, weapon power and cadence are unchanged.
return {
  playtest = 'a47ba20f/92d5fc87',
  human = 'ca158102/d4930751',
  drill = '646035a7/05626a12',
  playtestContacts = '948aa0e7/400',
  humanContacts = '06b120fd/704',
  drillContacts = '600c64b8/176',
}

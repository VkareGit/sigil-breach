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
-- 0.34 / proving-ground point 3: projectile elevation uses travel from the
-- muzzle, not from the caster's centre (d - muzzle). Only the intermediate
-- state digests change; final states and all three contact digests are equal.
-- Restoring just that denominator IN MEMORY reproduces all six old hashes:
-- work/point3-final/golden-attribution/legacy-aim.csv. No fixture weakened.
-- 0.34 / proving-ground point 4: contextual boss decisions and a second HP
-- stock deliberately change combat. The digest also covers phase/history.
-- tests/support/v033_encounters.lua restores only the old CONTENT per session;
-- v033_reference verifies all three exact point-3 digests on the current engine.
-- Frozen v0.33 references remain unchanged; current content is recorded here.
-- 0.34 / second-life refinement after point 5: distinct ground patterns,
-- longer second stocks and named phase/cast poses intentionally change combat.
-- Restoring ONLY the committed creature/sheet definitions IN MEMORY on the
-- new engine reproduces 6/6 previous digests (including per-part contacts):
-- work/phase2-refinement/golden-attribution/content-attribution.csv.
-- 2026-10-28: finite follow-ups, distinct close defences and phase distances.
-- Restoring ONLY HEAD creature/sheet definitions on the current engine gives
-- 6/6 previous hashes: work/combat-revision/golden-attribution/content-attribution.csv.
-- A completed follow-up opportunity is now included when present.
-- 2026-10-28: one-stock bosses, observed-velocity lead and physical horn thrusts.
-- Old creature/sheet data on the current engine reproduces 6/6 old hashes:
-- work/basilica-duel/golden/content-attribution.csv. v033 fixtures unchanged.
-- 2026-10-28: denser faster ash fan / spear and committed ground prediction
-- for the larger public halls. Restoring ONLY 63f6a85 creature/sheet content
-- reproduces 6/6 former digests on this engine:
-- work/basilica-duel/majestic-golden/content-attribution.csv.
-- 2026-10-28: ordinary-creature movement, predictive casts and attack cadence.
-- Only the four old creature definitions on the current engine reproduce all
-- six previous hashes: work/closure-28/golden-attribution/evidence/.
-- Geometry and HP were not inflated; v033 fixture files remain unchanged.
-- Souls S2-S4: the six creatures fight by the plan of game/docs/PLAN-WALKA-SOULS.md
-- (harder blows, strings, three acts of a guardian) and a guardian spills supplies
-- at its thresholds. The engine of S1 reproduced 6/6 former digests before this
-- content was laid on it; v033 fixture files remain unchanged.
-- Plan v13 W4-W6: the Margrave fights with paths, turns and answers, and the proving
-- ground pays effort. The former creature file with attrition off reproduces 6/6.
-- Then his card of blows: counters, a shell in his strikes, rolled sides and branches.
return {
  playtest = 'ff2f83f1/2bb2cc49',
  human = '5037caaf/f8c22251',
  drill = 'ddb19648/5bd6c6f4',
  playtestContacts = '2b2e6f57/370',
  humanContacts = 'e52d1f6f/841',
  drillContacts = '5524e142/277',
}

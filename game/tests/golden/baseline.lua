-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt).
-- 0.38: the old arena and its chapel are gone, so the scenarios are new: a walk up the
-- nave of the chapel by a reading and a clumsy knight, and the drill on the test room. The
-- earlier history of this file is in git.
-- 0.40: what the knight is looking at wakes (combat_defaults: seenRange), so the walk meets it sooner.
-- 0.40: breath never holds the trigger, so a tired knight keeps shooting.
return {
  playtest = 'ea4176b3/801e9f3a',
  human = '0f228502/9de405e7',
  drill = '693cf721/3ff62de9',
  playtestContacts = '8414c34e/732',
  humanContacts = 'e6b10dd2/150',
  drillContacts = '6fd6230a/355',
}

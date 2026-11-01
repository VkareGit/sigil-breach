-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt).
-- 0.38: the old arena and its chapel are gone, so the scenarios are new: a walk up the
-- nave of the chapel by a reading and a clumsy knight, and the drill on the test room. The
-- earlier history of this file is in git.
-- 0.40: what the knight is looking at wakes (combat_defaults: seenRange), so the walk meets it sooner.
-- 0.40: breath never holds the trigger, so a tired knight keeps shooting.
return {
  playtest = '9236a092/2e811344',
  human = '23d77efe/791e771a',
  drill = 'c33b6c5b/c5d4c9d8',
  playtestContacts = 'ebac4142/365',
  humanContacts = '3ed63158/217',
  drillContacts = '4095a19a/306',
}

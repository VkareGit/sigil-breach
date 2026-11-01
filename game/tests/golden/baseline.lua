-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt).
-- 0.38: the old arena and its chapel are gone, so the scenarios are new: a walk up the
-- nave of the chapel by a reading and a clumsy knight, and the drill on the test room. The
-- earlier history of this file is in git.
-- 0.40: what the knight is looking at wakes (combat_defaults: seenRange), so the walk meets it sooner.
-- 0.40: breath never holds the trigger, so a tired knight keeps shooting.
return {
  playtest = '6985ca73/74418d29',
  human = '136904ce/75802559',
  drill = '4e172628/192685fb',
  playtestContacts = 'bc771c30/258',
  humanContacts = '713deae2/790',
  drillContacts = '7962bb4b/316',
}

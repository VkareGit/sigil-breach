-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt).
-- 0.38: the old arena and its chapel are gone, so the scenarios are new: a walk up the
-- nave of the chapel by a reading and a clumsy knight, and the drill on the test room. The
-- earlier history of this file is in git.
-- 0.40: what the knight is looking at wakes (combat_defaults: seenRange), so the walk meets it sooner.
-- 0.40: breath never holds the trigger, so a tired knight keeps shooting.
return {
  playtest = '9e8db9fb/ece3b9c3',
  human = '92f75593/edd81cb1',
  drill = '088ec03e/dd65cc0a',
  playtestContacts = '05e670e7/493',
  humanContacts = '7b992be3/671',
  drillContacts = 'cd2bd74b/357',
}

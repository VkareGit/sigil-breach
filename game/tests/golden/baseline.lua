-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt).
-- 0.38: the old arena and its chapel are gone, so the scenarios are new: a walk up the
-- nave of the chapel by a reading and a clumsy knight, and the drill on the test room. The
-- earlier history of this file is in git.
-- 0.40: what the knight is looking at wakes (combat_defaults: seenRange), so the walk meets it sooner.
return {
  playtest = 'c76160d2/1b6b8e63',
  human = '901d693e/ae0c3e29',
  drill = '40400178/8f0854de',
  playtestContacts = 'ffa5ca09/368',
  humanContacts = '61bf4c8b/518',
  drillContacts = 'a919120a/297',
}

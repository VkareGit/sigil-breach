-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt).
-- 0.38: the old arena and its chapel are gone, so the scenarios are new: a walk up the
-- nave of the chapel by a reading and a clumsy knight, and the drill on the test room. The
-- earlier history of this file is in git.
-- 0.40: what the knight is looking at wakes (combat_defaults: seenRange), so the walk meets it sooner.
-- 0.40: breath never holds the trigger, so a tired knight keeps shooting.
return {
  playtest = 'ec3065c0/4d987b72',
  human = '2518632a/9de405e7',
  drill = '6335f6e9/1adb37e6',
  playtestContacts = '2375d3a9/298',
  humanContacts = 'e6b10dd2/150',
  drillContacts = '3e997544/352',
}

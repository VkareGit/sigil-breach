-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt).
-- 0.38: the old arena and its chapel are gone, so the scenarios are new: a walk up the
-- nave of the chapel by a reading and a clumsy knight, and the drill on the test room. The
-- earlier history of this file is in git.
-- 0.40: what the knight is looking at wakes (combat_defaults: seenRange), so the walk meets it sooner.
-- 0.40: breath never holds the trigger, so a tired knight keeps shooting.
-- 0.42: a retry and a rest start the knight afresh (run/actor_reset.lua): no shove, burn or
-- buffered pull carries over, so both walks change after their first death.
return {
  playtest = '8958ac6b/d8a28601',
  human = '954b7a72/c7bfdbb5',
  drill = '6335f6e9/1adb37e6',
  playtestContacts = 'b07330fe/583',
  humanContacts = 'e6b10dd2/150',
  drillContacts = '3e997544/352',
}

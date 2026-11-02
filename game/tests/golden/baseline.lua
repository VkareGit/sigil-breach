-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/ZMIANY.txt).
-- 0.38: the old arena and its chapel are gone, so the scenarios are new: a walk up the
-- nave of the chapel by a reading and a clumsy knight, and the drill on the test room. The
-- earlier history of this file is in git.
-- 0.40: what the knight is looking at wakes (combat_defaults: seenRange), so the walk meets it sooner.
-- 0.40: breath never holds the trigger, so a tired knight keeps shooting.
-- 0.42: a retry and a rest start the knight afresh (run/actor_reset.lua): no shove, burn or
-- buffered pull carries over, so both walks change after their first death.
-- 0.42: a dodge is paid with stamina alone, no charges (owner, D3), and the digest folds the
-- knight's stamina where it folded his charges; all three scenarios change.
-- 0.42: no fire takes in a hunted knight (owner, D1): the reading walk is refused a rest.
-- 0.42: creatures leave rounds (owner, D2): the drops take the session's rolls and refill the
-- guns, so both walks change.
-- 0.42: no queue of waiting creatures, an alarm wakes those that see the one that noticed him
-- (owner, D4), and two posts patrol: all three scenarios change.
return {
  playtest = '5d5aee1a/ba2cad7a',
  human = '4954a43c/ccca8c03',
  drill = '14f9ce3d/a64f81e9',
  playtestContacts = '1c88e888/747',
  humanContacts = 'a8136916/1143',
  drillContacts = 'df3be14a/359',
}

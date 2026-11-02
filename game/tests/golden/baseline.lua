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
-- 0.42: the alarm passes one step within its part of the hall, and a straight walk is tried only
-- near the goal and every 0.15 s (enemies/walking.lua): all three change again.
-- 0.42: a fire gives the Judge a full reserve (72) and keeps rounds gathered beyond it; a phase
-- drops its shells within reach: both walks change.
-- 0.42: rounds lie about the chapel and are laid again at each rest: both walks change.
-- 0.42: more rounds lie about, the halls have their own, and a cache taken lies again after a
-- minute: both walks change.
-- 0.42: held blows, waiting out of reach, shorter still recovery and hearing change the fights;
-- the Judge restores spare rounds, supplies leave their remainder, and Furfur is a short elite.
-- Both walks and the drill, including their contact receipts, agree in two fresh runs.
return {
  playtest = 'bd5dff28/4c70aaef',
  human = '5292b304/b08cad6e',
  drill = '6e83e64f/85c26f47',
  playtestContacts = '72e21535/1338',
  humanContacts = '0f5d2370/1461',
  drillContacts = '582e06df/310',
}

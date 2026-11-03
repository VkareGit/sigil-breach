-- Golden master baseline. Update only for a deliberate gameplay change; see
-- tests/suites/golden.lua and the change log (docs/HISTORIA.md).
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
-- 0.43 (A01): the bot walks only to supplies it can take; both walks change, the drill not.
-- 0.43 (A05): the whole recovery holds every blow and answer, a dodge in a string is answered;
-- both walks and the drill change.
-- 0.43 (B01): elites last longer (Margrave 2700, Furfur 2250 HP), a duellist walks the route to the knight,
-- and the elites' far blows reach 16-18 m.
-- 0.43 (C01): relics lie in the chapel (engravings and sigils found, not bought).
-- 0.43 (R01): Stolas casts a lance with a drawn line before it strikes.
-- 0.43 (D05): a heavy volley or a kill holds the demons a beat.
-- 0.43 (B01b): an elite held open reels and stays open 1.5-1.6 s (was 2.6-2.8).
-- 0.43: the D05 hold of the demons withdrawn (it took the cost from standing and shooting).
-- 0.45 (D15): a relic taken before a death is not laid again; the clumsy walk dies and changes.
-- 0.45 (D11, P4): the elites stand open 1.2 s and their new poses (masks of the hit) change the
-- drill; both walks of the chapel stay the same.
return {
  playtest = 'f26863c9/df75fad0',
  human = '965645ea/3500a3d2',
  drill = 'd80f2df1/3c4a4e65',
  playtestContacts = 'a3a00935/850',
  humanContacts = '5a97e736/1260',
  drillContacts = '0bc58ffe/377',
}

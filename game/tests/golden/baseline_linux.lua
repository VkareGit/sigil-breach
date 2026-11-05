-- Golden master baseline on Linux (glibc): see baseline.lua for the history of
-- every deliberate change. The drill ends in the same state as on Windows, but
-- its contacts and both chapel walks drift apart because sin, cos and atan2
-- round differently in the C libraries.
-- 0.45: recorded in WSL Ubuntu 26.04 with LÖVE 11.5 at the state of baseline.lua.
-- 0.45 P5/P6 (2026-11-04): deliberate new-way Judge-only start; three new
-- world relics. No automatic sigils. Existing two-weapon drill and contacts
-- remain identical. Linux repeat matched; Windows verified by the final gate.
-- 0.45 Stolas (2026-11-04): completed sidesteps with continuous cooldown,
-- wall-aware direction and distinct cast poses (therefore painted hit masks).
-- Two identical native Linux runs; HP, damage and spell timings unchanged.
-- Windows baseline requires its own verification and was not modified.
-- 0.45 Stolas review: both floor tears track during preparation and acquire
-- finite widths; the straight tear lasts 0.2 s instead of 0.02 s. Damage and HP
-- stay unchanged. Two identical native Linux runs on 2026-11-04; the drill
-- remains identical. Recorded voice and ground art are presentation only.
-- 0.45 Stolas follow-up (2026-11-05): the rotating beam becomes a low
-- jumpable wave; projectile casting uses the new hand poses and hit masks.
-- Two identical native Linux captures. Windows remains unverified.
-- 0.45 Iron Thrall (2026-11-05): distinct physical poses select new authored
-- hit masks; the forward claw now carries its painted palm through the target.
-- HP, damage packets and action timings are unchanged. Two identical native
-- Linux captures; Windows requires its own capture and remains untouched.
-- 0.45 visual continuity correction (2026-11-05): restore the owner's
-- original Iron Thrall poses and their masks, including nearest sampling
-- for the technical copy and passthrough of loose cloak. No combat tuning.
-- Two identical independent native Linux captures; Windows is not updated.
return {
  playtest = 'a416f22f/0f418894',
  human = 'b6593f81/f709d142',
  drill = '122d2542/f1953305',
  playtestContacts = 'b6de1242/147',
  humanContacts = 'dac355dc/173',
  drillContacts = '466ba09c/370',
}

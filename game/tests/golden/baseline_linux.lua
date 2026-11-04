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
return {
  playtest = 'd4d19581/e426f88c',
  human = '309f8e54/268527fd',
  drill = '30ea43a9/bdecd8ef',
  playtestContacts = '99bb8675/134',
  humanContacts = 'd9a060ab/172',
  drillContacts = '1c419a1d/381',
}

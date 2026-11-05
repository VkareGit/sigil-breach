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
return {
  playtest = '9d079cf9/f298cf18',
  human = '289b31af/63954170',
  drill = '1a5fcb89/d35eff44',
  playtestContacts = '5b3980dc/151',
  humanContacts = 'ecf47677/155',
  drillContacts = '6e664cd9/352',
}

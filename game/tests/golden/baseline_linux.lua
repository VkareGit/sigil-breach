-- Golden master baseline on Linux (glibc): see baseline.lua for the history of
-- every deliberate change. The drill ends in the same state as on Windows, but
-- its contacts and both chapel walks drift apart because sin, cos and atan2
-- round differently in the C libraries.
-- 0.45: recorded in WSL Ubuntu 26.04 with LÖVE 11.5 at the state of baseline.lua.
-- 0.45 P5/P6 (2026-11-04): deliberate new-way Judge-only start; three new
-- world relics. No automatic sigils. Existing two-weapon drill and contacts
-- remain identical. Linux repeat matched; Windows verified by the final gate.
return {
  playtest = 'df250a73/579db835',
  human = 'be5dd9f7/7e219861',
  drill = '1e05d6f6/ce2035f8',
  playtestContacts = 'd8f4c21c/126',
  humanContacts = '6a20ed12/196',
  drillContacts = '8f3896cc/377',
}

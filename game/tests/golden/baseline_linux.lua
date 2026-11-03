-- Golden master baseline on Linux (glibc): see baseline.lua for the history of
-- every deliberate change. The drill ends in the same state as on Windows, but
-- its contacts and both chapel walks drift apart because sin, cos and atan2
-- round differently in the C libraries.
-- 0.45: recorded in WSL Ubuntu 26.04 with LÖVE 11.5 at the state of baseline.lua.
return {
  playtest = 'eb227de5/23a9dc0f',
  human = '446e74b2/3500a3d2',
  drill = '1e05d6f6/ce2035f8',
  playtestContacts = 'c31a0e20/841',
  humanContacts = '73757d6e/1260',
  drillContacts = '8f3896cc/377',
}

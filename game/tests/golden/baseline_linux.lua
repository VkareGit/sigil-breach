-- Golden master baseline on Linux (glibc): see baseline.lua for the history of
-- every deliberate change. The drill ends in the same state as on Windows, but
-- its contacts and both chapel walks drift apart because sin, cos and atan2
-- round differently in the C libraries.
-- 0.44: recorded in WSL Ubuntu 26.04 with LÖVE 11.5 at the state of baseline.lua.
return {
  playtest = '09bc31e3/9cc3e964',
  human = 'b84aa9f5/ec49ed18',
  drill = 'a6aaf674/5ad03e34',
  playtestContacts = '20cd009d/841',
  humanContacts = '73757d6e/1260',
  drillContacts = '50001f43/362',
}

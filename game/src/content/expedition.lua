-- The expedition (descent mode) as data: its purse, rewards, supplies and
-- the reach of its souls and echo. The waves themselves are content/waves.lua;
-- the rules are run/descent.lua.
return {
  -- Souls at the start of an expedition; per cleansed wave; for the guardian.
  wallet = 100,
  waveReward = 60,
  guardianReward = 100,
  -- Crates laid out at the start of each ordinary wave (never the guardian's).
  supplies = {
    { kind = 'ammo', amount = 2, x = 7, z = 17 },
    { kind = 'ammo', amount = 2, x = 25, z = 17 },
    { kind = 'health', amount = 20, x = 16, z = 7 },
  },
  -- Souls drift toward a knight within reach m (in sight), at drift m/s, and
  -- are taken within take m; their notice stays notice s.
  souls = { reach = 2.6, take = 0.65, drift = 5.5, notice = 0.9 },
  -- The echo (souls lost at death) is recovered within reach m and its prompt
  -- shows within prompt m. An echo saved where no body fits (clearance m) or
  -- no path leads is moved to fallback.
  echo = { reach = 1.1, prompt = 2.5, clearance = 0.22, fallback = { x = 16, z = 26 } },
  -- A torch within this distance (m) of the Ember is removed.
  emberClearance = 2,
}

-- The way through the chapel as data: its fires, its doors and who stands where. The
-- rules are run/pilgrimage.lua.
--   fires     { id, name, x, z }
--   garrison  { id, creature, x, z, yaw }; alert: it notices only this near (an ambush);
--             leash: how far it follows, in place of the common leash; patrol: its points
return {
  map = 'proving',
  first = 'narthex',
  -- How near a fire must be to rest at it (m); how far a body follows from its post.
  reach = 2.6,
  leash = 16,
  -- Souls of a kill are the creature's own times this.
  souls = 10,
  -- The echo of a death is taken within echoReach m.
  echoReach = 1.2,
  -- A knight wakes this far from his fire (m).
  wake = 1.5,
  fires = {
    { id = 'narthex', name = 'fire_narthex', x = 27, z = 35 },
    { id = 'sanctuary', name = 'fire_sanctuary', x = 24, z = 9 },
    { id = 'west', name = 'fire_west', x = 10, z = 21 },
    { id = 'east', name = 'fire_east', x = 38, z = 21 },
  },
  -- A door is a wall until it is opened from its own side: the way back to a fire.
  doors = {
    {
      id = 'west_gallery',
      x = 14,
      z = 6,
      side = { x = 13.5, z = 7 },
      back = { x = 14.5, z = 4.5 },
    },
    {
      id = 'east_gallery',
      x = 34,
      z = 6,
      side = { x = 34.5, z = 7 },
      back = { x = 33.5, z = 4.5 },
    },
  },
  garrison = {
    -- The nave, in three bites: one that walks, then two with a caster behind them, then
    -- iron before the fire. Each notices only so far, so a careful knight takes them apart.
    {
      id = 'nave_1',
      creature = 'imp',
      x = 22,
      z = 29,
      yaw = 0,
      alert = 9,
      patrol = { { x = 22, z = 29 }, { x = 26, z = 29 }, { x = 26, z = 24 }, { x = 22, z = 24 } },
    },
    { id = 'nave_2', creature = 'imp', x = 21.5, z = 19, yaw = 0, alert = 6 },
    { id = 'nave_3', creature = 'imp', x = 26.5, z = 18, yaw = 0, alert = 6 },
    { id = 'nave_4', creature = 'stolas', x = 24, z = 16, yaw = 0, alert = 9 },
    { id = 'nave_5', creature = 'armored', x = 24, z = 11.5, yaw = 0, alert = 5 },
    -- The crypts: they wait in the dark for whoever comes close.
    { id = 'crypt_1', creature = 'imp', x = 19.5, z = 4, yaw = 1.5, alert = 4 },
    { id = 'crypt_2', creature = 'imp', x = 28.5, z = 4, yaw = -1.5, alert = 4 },
    { id = 'crypt_3', creature = 'buer', x = 24, z = 4.5, yaw = 0, alert = 7 },
    -- The thresholds of the halls: what stands in the door is met before the guardian.
    { id = 'west_1', creature = 'armored', x = 18.5, z = 27.5, yaw = 1.5, alert = 7 },
    { id = 'west_2', creature = 'imp', x = 19, z = 26.5, yaw = 1.5, alert = 5 },
    { id = 'east_1', creature = 'buer', x = 29.5, z = 27.5, yaw = -1.5, alert = 7 },
    { id = 'east_2', creature = 'stolas', x = 29, z = 28.5, yaw = -1.5, alert = 10 },
    { id = 'east_3', creature = 'imp', x = 29, z = 26.5, yaw = -1.5, alert = 5 },
    -- The halls: the hardest bodies of the chapel, standing before the doors back.
    { id = 'west_hall', creature = 'boss', x = 10, z = 14, yaw = 0, alert = 6, leash = 12 },
    { id = 'east_hall', creature = 'furfur', x = 38, z = 14, yaw = 0, alert = 6, leash = 12 },
  },
}

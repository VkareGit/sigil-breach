-- The way as data: its areas, each a map with its fires, doors and who stands where.
-- The rules are run/pilgrimage.lua. Ids go into saves: an id that leaves is dropped from a
-- save when it loads, an id that is renamed needs a migration there.
--   fires     { id, name, x, z }
--   doors     { id, side, back, leads }; leads: the area back stands in, when not this one
--   garrison  { id, creature, x, z, yaw }; alert: it notices only this near (an ambush);
--             leash: how far it follows, in place of the common leash; patrol: its points
local Registry = require('src.core.registry')
local Way = {
  first = 'chapel',
  -- Save slots a player can choose between.
  slots = 3,
  -- After a kill the save waits for this long (s) and for nobody awake, so no fight stops for
  -- the disk.
  saveEvery = 5,
  -- How near a fire must be to rest at it (m); how far a body follows from its post.
  reach = 2.6,
  leash = 16,
  -- Souls of a kill are the creature's own times this.
  souls = 10,
  -- The echo of a death is taken within echoReach m.
  echoReach = 1.2,
  -- A knight wakes this far before his fire (m), with it at his back.
  wake = 1.5,
  -- How near a door a knight must stand, and how tall it is painted (m).
  doorReach = 1.5,
  doorSize = 2.7,
  -- A knight fits where this much is free around him (m).
  clearance = 0.3,
}
-- Ids are unique across the way: a save names them without their area.
local function claim(seen, id, kind, taken)
  assert(type(id) == 'string', 'way: a ' .. kind .. ' needs an id')
  assert(not seen[id] and not (taken and taken(id)), 'way: ' .. kind .. ' id twice: ' .. id)
  seen[id] = true
end
local posts = {}
Way.areas = Registry:new('way areas', function(area, id)
  assert(area.id == id, 'way area ' .. id .. ' must carry its id')
  assert(type(area.map) == 'string', 'way area ' .. id .. ' needs a map')
  local first, seen = false, {}
  for _, fire in ipairs(area.fires) do
    claim(seen, fire.id, 'fire', Way.fireOf)
    first = first or fire.id == area.first
  end
  assert(first, 'way area ' .. id .. ' starts at no fire of its own')
  for _, door in ipairs(area.doors or {}) do
    claim(seen, door.id, 'door', Way.doorOf)
  end
  posts[id] = {}
  for _, post in ipairs(area.garrison) do
    claim(posts[id], post.id, 'post')
  end
end)
Way.areas:register('chapel', {
  id = 'chapel',
  map = 'proving',
  first = 'narthex',
  fires = {
    { id = 'narthex', name = 'fire_narthex', x = 27, z = 35 },
    { id = 'sanctuary', name = 'fire_sanctuary', x = 24, z = 9 },
    { id = 'west', name = 'fire_west', x = 10, z = 21 },
    { id = 'east', name = 'fire_east', x = 38, z = 21 },
  },
  -- A door stands on the wall between two places. It is barred until it is opened from
  -- its own side; from then on [E] goes through it either way. side and back are where
  -- a knight stands on each side, each with the door painted on the wall beside him.
  doors = {
    {
      id = 'west_gallery',
      side = {
        x = 13.6,
        z = 7.2,
        yaw = -math.pi / 2,
        art = { x = 14.46, z = 7.2, yaw = -math.pi / 2 },
      },
      back = { x = 15.2, z = 4.3, yaw = math.pi, art = { x = 15.2, z = 5.46, yaw = math.pi } },
    },
    {
      id = 'east_gallery',
      side = {
        x = 34.4,
        z = 7.2,
        yaw = math.pi / 2,
        art = { x = 33.54, z = 7.2, yaw = math.pi / 2 },
      },
      back = { x = 32.8, z = 4.3, yaw = math.pi, art = { x = 32.8, z = 5.46, yaw = math.pi } },
    },
  },
  garrison = {
    -- The nave, in three bites: one that walks, then two with a caster behind them, then
    -- iron before the fire. Each notices only so far, so a careful knight takes them apart.
    {
      id = 'nave_1',
      creature = 'imp',
      x = 22,
      z = 26,
      yaw = 0,
      alert = 6,
      patrol = { { x = 22, z = 26 }, { x = 26, z = 26 }, { x = 26, z = 22 }, { x = 22, z = 22 } },
    },
    { id = 'nave_2', creature = 'imp', x = 21.5, z = 19, yaw = 0, alert = 6 },
    { id = 'nave_3', creature = 'imp', x = 26.5, z = 18, yaw = 0, alert = 6 },
    { id = 'nave_4', creature = 'stolas', x = 24, z = 16, yaw = 0, alert = 9 },
    { id = 'nave_5', creature = 'armored', x = 24, z = 14, yaw = 0, alert = 5 },
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
})
-- Where a new way begins.
function Way.start()
  return Way.areas:get(Way.first)
end
-- A fire by id, and its area.
function Way.fireOf(id)
  for _, area in Way.areas:each() do
    for _, fire in ipairs(area.fires) do
      if fire.id == id then
        return fire, area
      end
    end
  end
end
-- Every fire of the way, area by area: travel walks this list.
function Way.fires()
  local list = {}
  for _, area in Way.areas:each() do
    for _, fire in ipairs(area.fires) do
      list[#list + 1] = fire
    end
  end
  return list
end
-- A door by id, and its area.
function Way.doorOf(id)
  for _, area in Way.areas:each() do
    for _, door in ipairs(area.doors or {}) do
      if door.id == id then
        return door, area
      end
    end
  end
end
return Way

-- The way as data: its areas, each a map with its fires, doors and who stands where.
-- The rules are run/pilgrimage.lua. Ids go into saves: an id that leaves is dropped from a
-- save when it loads, an id that is renamed needs a migration there.
--   fires     { id, name, x, z }; wake { x, z, yaw }: where a knight wakes, when not before it
--   doors     { id, side, back, leads }; leads: the area back stands in, when not this one
--   supplies  { id, kind, weapon, amount, x, z }: what lies on the floor (kind: a supply of
--             session/interactions.lua, 'ammo' when not named; weapon: the gun ammo is for),
--             taken for good at a rest (D10), laid again at a death when taken since
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
  -- A fire refuses a knight hunted by something awake within this far (m); a fight elsewhere
  -- in a crowded map does not keep him from it (0.42).
  huntReach = 14,
  -- Souls of a kill are the creature's own times this.
  souls = 10,
  -- The echo of a death is taken within echoReach m.
  echoReach = 1.2,
  -- A knight wakes this far before his fire (m), with it at his back.
  wake = 1.5,
  -- What a fire fills the reserve to: a way is walked on what was carried from the last fire.
  -- 0.42: the Judge, the gun of the ordinary fight, carries a full reserve (was 44); the
  -- Exorcist's shells stay scarce (owner: the strongest fire is not for every fight).
  carried = { exorcist = 20, judge = 72 },
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
    -- The hall fires wake the knight behind them, the guardian at his back and out of its
    -- notice (0.42: in front, 5.5 m from it and facing it, it woke before he moved).
    { id = 'west', name = 'fire_west', x = 10, z = 21, wake = { x = 10, z = 23, yaw = 0 } },
    { id = 'east', name = 'fire_east', x = 38, z = 21, wake = { x = 38, z = 23, yaw = 0 } },
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
  -- What lies about (0.42, the owner: like Doom, rounds everywhere). Taken, it is gone until the
  -- chapel stands again at a death before a rest (D10: a rest secures it, like Doom); a knight
  -- takes only what he has room for and the
  -- rest stays on the floor. Revolver rounds are plenty, shells fewer, and a few draughts for
  -- the flask (kind 'flask') lie behind the hardest bodies. The halls of the hardest have their
  -- own, so a long fight there is not lost for want of rounds.
  supplies = {
    { id = 'narthex_left', weapon = 'judge', amount = 6, x = 19.5, z = 35 },
    { id = 'narthex_right', weapon = 'judge', amount = 6, x = 29, z = 37 },
    { id = 'nave_back', weapon = 'judge', amount = 8, x = 24, z = 30 },
    { id = 'nave_left', weapon = 'judge', amount = 14, x = 21.5, z = 23 },
    { id = 'nave_right', weapon = 'judge', amount = 14, x = 26.5, z = 23 },
    { id = 'nave_front', weapon = 'judge', amount = 10, x = 24, z = 18.5 },
    { id = 'nave_draught', kind = 'flask', amount = 1, x = 24, z = 12 },
    { id = 'crypt', weapon = 'exorcist', amount = 6, x = 24, z = 7 },
    { id = 'crypt_west', weapon = 'judge', amount = 6, x = 19.5, z = 6.5 },
    { id = 'crypt_east', weapon = 'judge', amount = 6, x = 28.5, z = 6.5 },
    { id = 'gallery_west', weapon = 'exorcist', amount = 4, x = 16, z = 3.5 },
    { id = 'gallery_east', weapon = 'exorcist', amount = 4, x = 32, z = 3.5 },
    { id = 'threshold_west', weapon = 'judge', amount = 6, x = 18.5, z = 28 },
    { id = 'threshold_east', weapon = 'exorcist', amount = 2, x = 29.5, z = 28 },
    { id = 'west_hall', weapon = 'exorcist', amount = 6, x = 12, z = 18 },
    { id = 'west_hall_rounds', weapon = 'judge', amount = 14, x = 8, z = 18 },
    { id = 'west_hall_draught', kind = 'flask', amount = 1, x = 5, z = 26 },
    { id = 'west_apse', weapon = 'judge', amount = 10, x = 10, z = 10 },
    { id = 'east_hall', weapon = 'judge', amount = 16, x = 36, z = 18 },
    { id = 'east_hall_shells', weapon = 'exorcist', amount = 6, x = 40, z = 18 },
    { id = 'east_hall_draught', kind = 'flask', amount = 1, x = 43, z = 26 },
    { id = 'east_apse', weapon = 'judge', amount = 10, x = 38, z = 10 },
    -- Relics (0.43, owner D8): the engravings and sigils are found, not bought. The halls of
    -- the hardest bodies keep the best of them; the galleries and the crypt the rest.
    { id = 'relic_breaker', kind = 'relic', offer = 'breaker', amount = 1, x = 20.5, z = 23 },
    { id = 'relic_choke', kind = 'relic', offer = 'choke', amount = 1, x = 23, z = 7 },
    { id = 'relic_stolas', kind = 'relic', offer = 'sigil_stolas', amount = 1, x = 17, z = 3.5 },
    { id = 'relic_buer', kind = 'relic', offer = 'sigil_buer', amount = 1, x = 31, z = 3.5 },
    { id = 'relic_pierce', kind = 'relic', offer = 'pierce', amount = 1, x = 11, z = 10 },
    { id = 'relic_precision', kind = 'relic', offer = 'precision', amount = 1, x = 37, z = 10 },
    { id = 'relic_furfur', kind = 'relic', offer = 'sigil_furfur', amount = 1, x = 42, z = 26 },
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
    -- Before the alarm (owner, D4) some walk and some stand guard: the caster crosses the nave.
    {
      id = 'nave_4',
      creature = 'stolas',
      x = 24,
      z = 16,
      yaw = 0,
      alert = 9,
      patrol = { { x = 22, z = 16 }, { x = 26, z = 16 } },
    },
    { id = 'nave_5', creature = 'armored', x = 24, z = 14, yaw = 0, alert = 5 },
    -- The crypts: they wait in the dark for whoever comes close.
    { id = 'crypt_1', creature = 'imp', x = 19.5, z = 4, yaw = 1.5, alert = 4 },
    { id = 'crypt_2', creature = 'imp', x = 28.5, z = 4, yaw = -1.5, alert = 4 },
    {
      id = 'crypt_3',
      creature = 'buer',
      x = 24,
      z = 4.5,
      yaw = 0,
      alert = 7,
      patrol = { { x = 22, z = 4.5 }, { x = 26, z = 4.5 } },
    },
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
-- A post of a garrison by id, and its area (a save names the slain by post).
function Way.postOf(id)
  for _, area in Way.areas:each() do
    for _, post in ipairs(area.garrison) do
      if post.id == id then
        return post, area
      end
    end
  end
end
-- A supply by id, and its area (a save names what was taken).
function Way.supplyOf(id)
  for _, area in Way.areas:each() do
    for _, cache in ipairs(area.supplies or {}) do
      if cache.id == id then
        return cache, area
      end
    end
  end
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

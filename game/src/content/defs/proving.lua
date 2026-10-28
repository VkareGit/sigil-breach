-- Optional map-authored test chambers. No simulation or renderer dependency.
local Schema = require('src.core.schema')
local Id = require('src.core.id')
local Spot = Schema:new('trial spot', {
  x = { type = 'number', required = true },
  z = { type = 'number', required = true },
  yaw = { type = 'number' },
})
local Chamber = Schema:new('trial chamber', {
  id = { type = 'string', required = true },
  entry = { type = 'table', required = true, schema = Spot },
  slots = { type = 'table', required = true, list = Spot },
  fire = { type = 'table', list = Spot }, -- boundary flames, presentation only
})
local Trial = Schema:new('chamber trial', {
  id = { type = 'string', required = true },
  chamber = { type = 'string', required = true },
  creature = { type = 'string', required = true },
  readyDelay = {
    type = 'number',
    min = 0,
    desc = 'opening attack cooldown after arrival (s); arrival grace and telegraph still apply',
  },
})
local Pad = Schema:new('trial pad', {
  x = { type = 'number' },
  z = { type = 'number' },
  altar = { type = 'string' }, -- resolve position from an existing seal pedestal
  trial = { type = 'string' },
  spawn = { type = 'string' },
  weapon = { type = 'string' },
  refill = { type = 'boolean' },
})
local Row = Schema:new('domino row', {
  x = { type = 'number', required = true },
  z = { type = 'number', required = true },
  step = { type = 'number', required = true, min = 0.01 },
  count = { type = 'number', required = true, min = 1, max = 20 },
})
local Physics = Schema:new('physics station', {
  stand = { type = 'table', required = true, schema = Spot },
  slam = { type = 'table', required = true, schema = Spot },
  domino = { type = 'table', required = true, schema = Row },
  tripLabel = { type = 'number', required = true, min = 0 },
})
local Stations = Schema:new('field stations', {
  start = { type = 'table', required = true, schema = Spot },
  physics = { type = 'table', required = true, schema = Physics },
})
local Definition = Schema:new('proving layout', {
  stations = { type = 'table', schema = Stations },
  exhibits = { type = 'boolean', required = true },
  chambers = { type = 'table', required = true, list = Chamber },
  trials = { type = 'table', required = true, list = Trial },
  pads = { type = 'table', required = true, list = Pad },
})
local P = {}
function P.check(map)
  local data = map.proving
  if not data then
    return
  end
  Definition:validate(data, 'map ' .. map.id .. '.proving')
  if data.stations then
    assert(data.stations.physics.domino.count % 1 == 0, 'domino count must be integer')
  end
  local chambers, trials = {}, {}
  for _, c in ipairs(data.chambers) do
    Id.check(c.id, 'chamber id')
    assert(not chambers[c.id], 'duplicate chamber id')
    assert(c.entry.yaw ~= nil and #c.slots > 0, 'chamber needs facing and spawn slots')
    chambers[c.id] = c
  end
  for _, t in ipairs(data.trials) do
    Id.check(t.id, 'trial id')
    assert(not trials[t.id], 'duplicate trial id')
    assert(chambers[t.chamber], 'unknown trial chamber: ' .. t.chamber)
    -- Several trials can share a creature; the first is its catalogue default.
    trials[t.id] = t
  end
  for _, p in ipairs(data.pads) do
    if p.altar then
      assert(p.x == nil and p.z == nil, 'altar owns the pad coordinates')
      local found = false
      for _, seal in ipairs(map.seals or {}) do
        found = found or seal.id == p.altar
      end
      assert(found, 'unknown pad altar: ' .. p.altar)
    else
      assert(p.x ~= nil and p.z ~= nil, 'floor pad needs coordinates')
    end
    local actions = (p.trial and 1 or 0) + (p.weapon and 1 or 0) + (p.refill and 1 or 0)
    assert(actions == 1, 'pad needs exactly one action')
    if p.trial then
      assert(trials[p.trial] and trials[p.trial].creature == p.spawn, 'pad trial/creature mismatch')
    else
      assert(not p.spawn, 'spawn needs a trial')
    end
  end
  for _, c in ipairs(data.chambers) do
    assert(not c.fire or #c.fire <= 96, 'chamber fire exceeds presentation budget')
  end
end
return P

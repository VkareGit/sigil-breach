-- Two independently checksummed generations: an interrupted write preserves the other.
-- Strict data parser; save files are never executed as Lua.
-- SIGIL08 keeps equipment slot order as well as uses by id. SIGIL06 (two
-- fixed weapons) and SIGIL07 (arsenal and unordered kit) still read. Their
-- equipment migrates with powder on Q, then any other saved ids in sorted
-- order: those formats did not retain the player's equipment slot choices.
local P = { prefix = 'descent-v06', version = 'SIGIL08' }
local Weapons = require('src.content.weapons')
local Shop = require('src.content.shop')
local Expedition = require('src.content.expedition')
local Abilities = require('src.content.abilities')
local Id = require('src.core.id')
-- Accept coordinates from the deferred expansion so load can relocate an echo
-- without rejecting the save or discarding its souls. Active geometry is31x31.
local legacyCoordinateLimit = 38
-- The weapons a SIGIL06 save knew, in its slot order, and its one ability.
local legacyLoadout = { 'exorcist', 'judge' }
local legacyAbility = 'powder'
local lastWave = Expedition.totalWaves + 1
-- Weapons in one loadout (number keys 1-9).
local maxLoadout = 9
local function checksum(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + s:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return tostring(b * 65536 + a)
end
P.checksum = checksum
local function number(s, min, max, integer)
  local n = tonumber(s)
  if not n or n ~= n or n < min or n > max or (integer and n ~= math.floor(n)) then
    error('invalid save number')
  end
  return n
end
local function fields(s)
  local out = {}
  for field in (s .. ','):gmatch('(.-),') do
    out[#out + 1] = field
  end
  return out
end
-- SIGIL06 'charges': the powder charge's uses (its start when absent).
local function charges(s)
  local powder = Abilities:get(legacyAbility)
  return { [legacyAbility] = s and number(s, 0, powder.capacity, true) or powder.start }
end
-- SIGIL07 kit: id:uses,... (every ability the knight carries).
local function packKit(v)
  local ids = {}
  for id in pairs(v.abilities or {}) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  local out = {}
  for i, id in ipairs(ids) do
    out[i] = id .. ':' .. v.abilities[id]
  end
  return table.concat(out, ',')
end
local function kit(s)
  local uses = {}
  if s and s ~= '' then
    for _, entry in ipairs(fields(s)) do
      local id, n = entry:match('^([^:]+):([^:]+)$')
      assert(Id.valid(id) and Abilities:has(id) and not uses[id], 'invalid kit')
      uses[id] = number(n, 0, Abilities:get(id).capacity, true)
    end
  end
  return uses
end
local function legacySlots(uses)
  local rest = {}
  for id in pairs(uses) do
    if id ~= legacyAbility then
      rest[#rest + 1] = id
    end
  end
  table.sort(rest)
  local slots = { legacyAbility }
  uses[legacyAbility] = uses[legacyAbility] or Abilities:get(legacyAbility).start
  for _, id in ipairs(rest) do
    slots[#slots + 1] = id
  end
  return slots
end
-- Slots and records must agree exactly. Unknown, repeated and missing ids
-- fail decoding instead of dropping equipment or silently moving a key.
local function slots(s, uses)
  assert(type(s) == 'string', 'missing equipment slots')
  local out, seen = {}, {}
  if s ~= '' then
    for _, id in ipairs(fields(s)) do
      assert(
        Id.valid(id) and Abilities:has(id) and not seen[id] and uses[id] ~= nil,
        'invalid equipment slot'
      )
      out[#out + 1], seen[id] = id, true
    end
  end
  for id in pairs(uses) do
    assert(seen[id], 'equipment record has no slot')
  end
  return out
end
local function packSlots(v)
  -- Keep encode usable with a checkpoint made before the slot field existed.
  if v.abilityLoadout then
    return table.concat(v.abilityLoadout, ',')
  end
  local ordered = {}
  for id in pairs(v.abilities or {}) do
    ordered[#ordered + 1] = id
  end
  table.sort(ordered, function(a, b)
    if a == legacyAbility or b == legacyAbility then
      return a == legacyAbility and b ~= legacyAbility
    end
    return a < b
  end)
  return table.concat(ordered, ',')
end
-- One weapon's rounds and reserve, within its definition.
local function rounds(id, mag, reserve)
  local def = Weapons.get(id)
  return {
    mag = number(mag, 0, def.capacity, true),
    reserve = number(reserve, 0, def.maxReserve, true),
  }
end
-- SIGIL07 arsenal: id:mag:reserve,... in loadout order.
local function packArsenal(v)
  local out = {}
  for i, id in ipairs(v.loadout) do
    local w = v.weapons[id]
    out[i] = id .. ':' .. w.mag .. ':' .. w.reserve
  end
  return table.concat(out, ',')
end
local function arsenal(s)
  local loadout, weapons = {}, {}
  for _, entry in ipairs(fields(s)) do
    local id, mag, reserve = entry:match('^([^:]+):([^:]+):([^:]+)$')
    assert(Id.valid(id) and Weapons.registry:has(id) and not weapons[id], 'invalid arsenal')
    loadout[#loadout + 1] = id
    weapons[id] = rounds(id, mag, reserve)
  end
  assert(#loadout >= 1 and #loadout <= maxLoadout, 'invalid loadout')
  return loadout, weapons
end
local function inventory(s, arsenalText, kitText, slotsText, version)
  local f = fields(s)
  assert(#f == 3, 'invalid inventory')
  local loadout, weapons = arsenal(arsenalText)
  local uses = kit(kitText)
  return {
    armor = number(f[1], 0, Shop.maxWard),
    essence = number(f[2], 0, 100),
    weapon = number(f[3], 1, #loadout, true),
    loadout = loadout,
    weapons = weapons,
    abilities = uses,
    abilityLoadout = version == 'SIGIL08' and slots(slotsText, uses) or legacySlots(uses),
  }
end
-- SIGIL06: armor,mag,reserve,essence,weapon + optional revolver=mag,reserve.
local function inventory06(s, revolver, chargeText)
  local f = fields(s)
  assert(#f == 5, 'invalid inventory')
  local exorcist, judge = Weapons.get(legacyLoadout[1]), Weapons.get(legacyLoadout[2])
  local weapons = { [legacyLoadout[1]] = rounds(legacyLoadout[1], f[2], f[3]) }
  if revolver then
    local r = fields(revolver)
    assert(#r == 2, 'invalid revolver inventory')
    weapons[legacyLoadout[2]] = rounds(legacyLoadout[2], r[1], r[2])
  else
    weapons[legacyLoadout[2]] = { mag = judge.capacity, reserve = judge.startReserve }
  end
  assert(exorcist, 'legacy weapon missing')
  return {
    armor = number(f[1], 0, Shop.maxWard),
    essence = number(f[4], 0, 100),
    weapon = number(f[5], 1, #legacyLoadout, true),
    loadout = { legacyLoadout[1], legacyLoadout[2] },
    weapons = weapons,
    abilities = charges(chargeText),
    abilityLoadout = { legacyAbility },
  }
end
function P.encode(data, sequence)
  local keys = {}
  for k, v in pairs(data.claimed or {}) do
    if v then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys)
  local e = data.echo
  local inv, check = data.inventory, data.checkpoint
  local payload = table.concat({
    'mode=' .. (data.mode or 'expedition'),
    'phase=' .. data.phase,
    'wave=' .. data.wave,
    'wallet=' .. data.wallet,
    'glyph=' .. data.glyph,
    'owned=' .. (data.owned.choke and '1' or '0') .. ',' .. (data.owned.pierce and '1' or '0'),
    'claimed=' .. table.concat(keys, ','),
    'inventory=' .. table.concat({ inv.armor, inv.essence or 0, inv.weapon }, ','),
    'arsenal=' .. packArsenal(inv),
    'checkpoint=' .. table.concat({ check.armor, check.essence or 0, check.weapon }, ','),
    'checkarsenal=' .. packArsenal(check),
    'echo=' .. (e and table.concat({ e.amount, e.x, e.z, e.wave }, ',') or 'none'),
    'kit=' .. packKit(inv),
    'checkkit=' .. packKit(check),
    'slots=' .. packSlots(inv),
    'checkslots=' .. packSlots(check),
    'elapsed=' .. data.elapsed,
    'kills=' .. data.kills,
    'damage=' .. data.damage,
    'deaths=' .. data.deaths,
    'secret=' .. (data.secret and '1' or '0'),
    'secretopen=' .. (data.secretOpen and '1' or '0'),
    'score=' .. data.score,
    'fragment=' .. (data.fragment and '1' or '0'),
  }, '\n')
  return P.version .. '\n' .. sequence .. '\n' .. checksum(payload) .. '\n' .. payload
end
function P.decode(raw)
  if type(raw) ~= 'string' or #raw > 24000 then
    return nil, 'Invalid save size.'
  end
  local ok, data, seq = pcall(function()
    local version, sequence, hash, payload = raw:match('^(SIGIL0[678])\n(%d+)\n(%d+)\n(.*)$')
    assert(payload and hash == checksum(payload), 'checksum mismatch')
    sequence = number(sequence, 1, 1e12, true)
    local f = {}
    for line in (payload .. '\n'):gmatch('(.-)\n') do
      local k, v = line:match('^([a-z]+)=(.*)$')
      assert(k and not f[k], 'invalid or duplicate field')
      f[k] = v
    end
    assert(
      f.phase == 'preparing' or f.phase == 'defeated' or f.phase == 'complete',
      'invalid phase'
    )
    assert(f.glyph == 'none' or f.glyph == 'choke' or f.glyph == 'pierce', 'invalid glyph')
    assert(f.owned and f.owned:match('^[01],[01]$'), 'invalid ownership')
    assert(f.secret == '0' or f.secret == '1')
    assert(f.fragment == '0' or f.fragment == '1')
    assert(f.secretopen == nil or f.secretopen == '0' or f.secretopen == '1')
    local current, checkpoint
    if version == 'SIGIL06' then
      current = inventory06(f.inventory, f.revolver, f.charges)
      checkpoint = inventory06(f.checkpoint, f.checkrevolver, f.checkcharges)
    else
      current = inventory(f.inventory, f.arsenal, f.kit, f.slots, version)
      checkpoint = inventory(f.checkpoint, f.checkarsenal, f.checkkit, f.checkslots, version)
    end
    -- The mode the save belongs to (SIGIL06 knew only the expedition).
    assert(f.mode == nil or Id.valid(f.mode), 'invalid mode')
    local d = {
      mode = f.mode or 'expedition',
      phase = f.phase,
      wave = number(f.wave, 1, lastWave, true),
      wallet = number(f.wallet, 0, Shop.maxWallet, true),
      glyph = f.glyph,
      owned = { choke = f.owned:sub(1, 1) == '1', pierce = f.owned:sub(3, 3) == '1' },
      claimed = {},
      inventory = current,
      checkpoint = checkpoint,
      elapsed = number(f.elapsed, 0, 1e7),
      kills = number(f.kills, 0, 1000000, true),
      damage = number(f.damage, 0, 1e8),
      deaths = number(f.deaths, 0, 100000, true),
      secret = f.secret == '1',
      secretOpen = f.secretopen == '1',
      score = number(f.score, 0, 1e9, true),
      fragment = f.fragment == '1',
      version = version,
    }
    assert(d.glyph == 'none' or d.owned[d.glyph], 'unowned glyph')
    assert((d.phase == 'complete') == d.fragment, 'invalid completion')
    assert(not d.fragment or d.wave == lastWave, 'invalid circle progress')
    assert(f.claimed and #f.claimed < 3000, 'invalid ledger')
    if f.claimed ~= '' then
      for _, id in ipairs(fields(f.claimed)) do
        local w, index = id:match('^(%d+)_(%d+)$')
        w = number(w, 1, lastWave, true)
        index = number(index, 1, 20, true)
        assert(not d.claimed[id] and w <= d.wave, 'invalid reward id')
        d.claimed[id] = true
      end
    end
    if f.echo ~= 'none' then
      local e = fields(f.echo)
      assert(#e == 4, 'invalid echo')
      d.echo = {
        amount = number(e[1], 1, 1000000, true),
        x = number(e[2], 1, legacyCoordinateLimit),
        z = number(e[3], 1, legacyCoordinateLimit),
        wave = number(e[4], 1, d.wave, true),
      }
    end
    return d, sequence
  end)
  if not ok then
    return nil, 'The save is incomplete or damaged.'
  end
  return data, seq
end
function P.read(prefix)
  prefix = prefix or P.prefix
  local best, sequence, damaged = nil, 0, false
  for _, suffix in ipairs({ 'a', 'b' }) do
    local raw = love.filesystem.read(prefix .. '.' .. suffix)
    if raw then
      local d, s = P.decode(raw)
      if d and s > sequence then
        best, sequence = d, s
      elseif not d then
        damaged = true
      end
    end
  end
  return best, sequence, damaged
end
function P.write(data, prefix)
  prefix = prefix or P.prefix
  local _, seq = P.read(prefix)
  local nextSequence = seq + 1
  local encoded = P.encode(data, nextSequence)
  local checked = P.decode(encoded)
  if not checked then
    return false, 'Could not prepare the save.'
  end
  local filename = prefix .. (nextSequence % 2 == 0 and '.a' or '.b')
  local ok = love.filesystem.write(filename, encoded)
  if not ok then
    return false, 'Could not save the expedition.'
  end
  local verify = love.filesystem.read(filename)
  if verify ~= encoded then
    return false, 'Could not verify the save.'
  end
  return true
end
return P

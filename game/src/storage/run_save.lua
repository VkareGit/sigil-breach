-- The expedition's checkpoint file (plan v10 V4): the section 'run' of a
-- save of kind 'expedition' (storage/save.lua), a data tree checked by its
-- schema; any other section of that kind is saved and read beside it.
-- Saves are written atomically, the previous one kept beside the new.
-- Older checkpoints still read through the adapter below and are written
-- again only in the new format:
-- SIGIL08 keeps equipment slot order as well as uses by id. SIGIL06 (two
-- fixed weapons) and SIGIL07 (arsenal and unordered kit) still read. Their
-- equipment migrates with powder on Q, then any other saved ids in sorted
-- order: those formats did not retain the player's equipment slot choices.
-- Strict data parsers; save files are never executed as Lua.
local P = { prefix = 'descent-v06' }
local Ammo = require('src.content.ammo.index')
local Save = require('src.storage.save')
local Schema = require('src.core.schema')
local Weapons = require('src.content.weapons')
local Shop = require('src.content.shop')
local Expedition = require('src.content.expedition')
local Abilities = require('src.content.abilities')
local Id = require('src.core.id')
P.version = Save.format
-- Accept coordinates from the deferred expansion so load can relocate an echo
-- without rejecting the save or discarding its souls. Active geometry is31x31.
local legacyCoordinateLimit = 38
-- An echo of the new format lies on any map (cells).
local coordinateLimit = 4096
-- The weapons a SIGIL06 save knew, in its slot order, and its one ability.
local legacyLoadout = { 'exorcist', 'judge' }
local legacyAbility = 'powder'
local lastWave = Expedition.totalWaves + 1
-- Weapons in one loadout (number keys 1-9).
local maxLoadout = 9
-- Bounds of the run's counters.
local limits = {
  elapsed = 1e7,
  kills = 1000000,
  damage = 1e8,
  deaths = 100000,
  score = 1e9,
  echo = 1000000,
  rewards = 20,
  ledger = 3000,
}
local checksum = Save.checksum
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
-- One weapon's rounds and reserve, within its definition.
local function rounds(id, a, b)
  local def = Weapons.get(id)
  return Ammo.of(def).unpack(def.ammo, a, b, number)
end
-- Uses by ability id, each a known ability within its capacity.
local function uses(entries)
  local out = {}
  for _, entry in ipairs(entries) do
    local id, n = entry[1], entry[2]
    assert(Id.valid(id) and Abilities:has(id) and not out[id], 'invalid kit')
    out[id] = number(n, 0, Abilities:get(id).capacity, true)
  end
  return out
end
-- Slots and records must agree exactly. Unknown, repeated and missing ids
-- fail decoding instead of dropping equipment or silently moving a key.
local function slots(list, records)
  local out, seen = {}, {}
  for _, id in ipairs(list) do
    assert(
      Id.valid(id) and Abilities:has(id) and not seen[id] and records[id] ~= nil,
      'invalid equipment slot'
    )
    out[#out + 1], seen[id] = id, true
  end
  for id in pairs(records) do
    assert(seen[id], 'equipment record has no slot')
  end
  return out
end
-- The ids of a loadout and their rounds, in slot order.
local function arsenal(entries)
  local loadout, weapons = {}, {}
  for _, entry in ipairs(entries) do
    local id, first, second = entry[1], entry[2], entry[3]
    assert(Id.valid(id) and Weapons.registry:has(id) and not weapons[id], 'invalid arsenal')
    loadout[#loadout + 1] = id
    weapons[id] = rounds(id, first, second)
  end
  assert(#loadout >= 1 and #loadout <= maxLoadout, 'invalid loadout')
  return loadout, weapons
end
-- The reward ledger: ids wave_index up to the run's wave.
local function ledger(ids, wave)
  assert(#ids < limits.ledger, 'invalid ledger')
  local claimed = {}
  for _, id in ipairs(ids) do
    assert(type(id) == 'string', 'invalid reward id')
    local w, index = id:match('^(%d+)_(%d+)$')
    w = number(w, 1, lastWave, true)
    index = number(index, 1, limits.rewards, true)
    assert(not claimed[id] and w <= wave, 'invalid reward id')
    claimed[id] = true
  end
  return claimed
end
-- The checks every checkpoint passes, whatever its format.
local function settle(d)
  assert(d.glyph == 'none' or d.owned[d.glyph], 'unowned glyph')
  assert((d.phase == 'complete') == d.fragment, 'invalid completion')
  assert(not d.fragment or d.wave == lastWave, 'invalid circle progress')
  assert(Id.valid(d.mode), 'invalid mode')
  return d
end

-- THE SECTION 'run' (SIGIL09) -------------------------------------------------
local Inventory = Schema:new('inventory', {
  armor = { type = 'number', required = true, min = 0, max = Shop.maxWard },
  essence = { type = 'number', required = true, min = 0, max = 100 },
  weapon = { type = 'number', required = true, min = 1, max = maxLoadout },
  -- Lists and maps by id, checked against the definitions in unpack.
  loadout = { type = 'table', required = true },
  weapons = { type = 'table', required = true },
  abilities = { type = 'table', required = true },
  abilityLoadout = { type = 'table', required = true },
})
local function counter(max)
  return { type = 'number', required = true, min = 0, max = max }
end
local RunSchema = Schema:new('run', {
  mode = { type = 'string', required = true },
  phase = { type = 'string', required = true, values = { 'preparing', 'defeated', 'complete' } },
  wave = { type = 'number', required = true, min = 1, max = lastWave },
  wallet = counter(Shop.maxWallet),
  glyph = { type = 'string', required = true, values = { 'none', 'choke', 'pierce' } },
  owned = {
    type = 'table',
    required = true,
    schema = Schema:new('owned', {
      choke = { type = 'boolean', required = true },
      pierce = { type = 'boolean', required = true },
    }),
  },
  claimed = { type = 'table', required = true },
  inventory = { type = 'table', required = true, schema = Inventory },
  checkpoint = { type = 'table', required = true, schema = Inventory },
  echo = {
    type = 'table',
    schema = Schema:new('echo', {
      amount = { type = 'number', required = true, min = 1, max = limits.echo },
      x = { type = 'number', required = true, min = 1, max = coordinateLimit },
      z = { type = 'number', required = true, min = 1, max = coordinateLimit },
      wave = { type = 'number', required = true, min = 1, max = lastWave },
    }),
  },
  elapsed = counter(limits.elapsed),
  kills = counter(limits.kills),
  damage = counter(limits.damage),
  deaths = counter(limits.deaths),
  secret = { type = 'boolean', required = true },
  secretOpen = { type = 'boolean', required = true },
  score = counter(limits.score),
  fragment = { type = 'boolean', required = true },
})
-- Equipment slots of a checkpoint made before the slot field existed:
-- powder first, the rest by id.
local function orderedSlots(v)
  if v.abilityLoadout then
    return { unpack(v.abilityLoadout) }
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
  return ordered
end
local function packInventory(v)
  local weapons, abilities = {}, {}
  for _, id in ipairs(v.loadout) do
    weapons[id] = Ammo.of(Weapons.get(id)).pack(v.weapons[id])
  end
  for id, n in pairs(v.abilities or {}) do
    abilities[id] = n
  end
  return {
    armor = v.armor,
    essence = v.essence or 0,
    weapon = v.weapon,
    loadout = { unpack(v.loadout) },
    weapons = weapons,
    abilities = abilities,
    abilityLoadout = orderedSlots(v),
  }
end
local function packRun(data)
  local claimed = {}
  for k, v in pairs(data.claimed or {}) do
    if v then
      claimed[#claimed + 1] = k
    end
  end
  table.sort(claimed)
  local e = data.echo
  return {
    mode = data.mode or 'expedition',
    phase = data.phase,
    wave = data.wave,
    wallet = data.wallet,
    glyph = data.glyph,
    owned = { choke = data.owned.choke == true, pierce = data.owned.pierce == true },
    claimed = claimed,
    inventory = packInventory(data.inventory),
    checkpoint = packInventory(data.checkpoint),
    echo = e and { amount = e.amount, x = e.x, z = e.z, wave = e.wave } or nil,
    elapsed = data.elapsed,
    kills = data.kills,
    damage = data.damage,
    deaths = data.deaths,
    secret = data.secret == true,
    secretOpen = data.secretOpen == true,
    score = data.score,
    fragment = data.fragment == true,
  }
end
local function list(t, name)
  assert(type(t) == 'table', 'invalid ' .. name)
  local n = 0
  for k in pairs(t) do
    assert(type(k) == 'number' and k >= 1 and k % 1 == 0, 'invalid ' .. name)
    n = math.max(n, k)
  end
  assert(n == #t, 'invalid ' .. name)
  return t
end
local function unpackInventory(v)
  local entries = {}
  for i, id in ipairs(list(v.loadout, 'loadout')) do
    local w = v.weapons[id]
    assert(type(w) == 'table', 'invalid arsenal')
    local kept = Ammo.of(Weapons.get(id)).list(w)
    entries[i] = { id, kept[1], kept[2] }
  end
  for id in pairs(v.weapons) do
    assert(type(id) == 'string', 'invalid arsenal')
  end
  local loadout, weapons = arsenal(entries)
  local count = 0
  for _ in pairs(v.weapons) do
    count = count + 1
  end
  assert(count == #loadout, 'invalid arsenal')
  local kit = {}
  for id, n in pairs(v.abilities) do
    assert(type(id) == 'string', 'invalid kit')
    kit[#kit + 1] = { id, n }
  end
  table.sort(kit, function(a, b)
    return a[1] < b[1]
  end)
  local records = uses(kit)
  return {
    armor = v.armor,
    essence = v.essence,
    weapon = number(v.weapon, 1, #loadout, true),
    loadout = loadout,
    weapons = weapons,
    abilities = records,
    abilityLoadout = slots(list(v.abilityLoadout, 'equipment slots'), records),
  }
end
local function unpackRun(t)
  local d = {
    mode = t.mode,
    phase = t.phase,
    wave = number(t.wave, 1, lastWave, true),
    wallet = number(t.wallet, 0, Shop.maxWallet, true),
    glyph = t.glyph,
    owned = { choke = t.owned.choke, pierce = t.owned.pierce },
    inventory = unpackInventory(t.inventory),
    checkpoint = unpackInventory(t.checkpoint),
    elapsed = t.elapsed,
    kills = number(t.kills, 0, limits.kills, true),
    damage = t.damage,
    deaths = number(t.deaths, 0, limits.deaths, true),
    secret = t.secret,
    secretOpen = t.secretOpen,
    score = number(t.score, 0, limits.score, true),
    fragment = t.fragment,
    version = Save.format,
  }
  d.claimed = ledger(list(t.claimed, 'ledger'), d.wave)
  if t.echo then
    d.echo = {
      amount = number(t.echo.amount, 1, limits.echo, true),
      x = t.echo.x,
      z = t.echo.z,
      wave = number(t.echo.wave, 1, d.wave, true),
    }
  end
  return settle(d)
end
Save.declare({
  name = 'run',
  file = 'expedition',
  version = 1,
  schema = RunSchema,
  -- source: { run = the checkpoint (run/descent.lua snapshot), game = the
  -- session when there is one }.
  pack = function(source)
    return packRun(source.run)
  end,
  unpack = unpackRun,
})

-- THE ADAPTER (SIGIL06, SIGIL07, SIGIL08) -----------------------------------
-- SIGIL06 'charges': the powder charge's uses (its start when absent).
local function charges(s)
  local powder = Abilities:get(legacyAbility)
  return { [legacyAbility] = s and number(s, 0, powder.capacity, true) or powder.start }
end
-- SIGIL07 kit: id:uses,... (every ability the knight carries).
local function kit(s)
  local entries = {}
  if s and s ~= '' then
    for _, entry in ipairs(fields(s)) do
      local id, n = entry:match('^([^:]+):([^:]+)$')
      entries[#entries + 1] = { id, n }
    end
  end
  return uses(entries)
end
local function legacySlots(records)
  local rest = {}
  for id in pairs(records) do
    if id ~= legacyAbility then
      rest[#rest + 1] = id
    end
  end
  table.sort(rest)
  local out = { legacyAbility }
  records[legacyAbility] = records[legacyAbility] or Abilities:get(legacyAbility).start
  for _, id in ipairs(rest) do
    out[#out + 1] = id
  end
  return out
end
local function textSlots(s, records)
  assert(type(s) == 'string', 'missing equipment slots')
  return slots(s ~= '' and fields(s) or {}, records)
end
-- SIGIL07 arsenal: id:mag:reserve,... in loadout order.
local function textArsenal(s)
  local entries = {}
  for _, entry in ipairs(fields(s)) do
    local id, mag, reserve = entry:match('^([^:]+):([^:]+):([^:]+)$')
    entries[#entries + 1] = { id, mag, reserve }
  end
  return arsenal(entries)
end
local function inventory(s, arsenalText, kitText, slotsText, version)
  local f = fields(s)
  assert(#f == 3, 'invalid inventory')
  local loadout, weapons = textArsenal(arsenalText)
  local records = kit(kitText)
  return {
    armor = number(f[1], 0, Shop.maxWard),
    essence = number(f[2], 0, 100),
    weapon = number(f[3], 1, #loadout, true),
    loadout = loadout,
    weapons = weapons,
    abilities = records,
    abilityLoadout = version == 'SIGIL08' and textSlots(slotsText, records) or legacySlots(records),
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
    weapons[legacyLoadout[2]] = Ammo.of(judge).newState(judge.ammo)
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
-- Older checkpoints were at most this long (bytes).
local legacySize = 24000
local function decodeLegacy(raw)
  if #raw > legacySize then
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
      inventory = current,
      checkpoint = checkpoint,
      elapsed = number(f.elapsed, 0, limits.elapsed),
      kills = number(f.kills, 0, limits.kills, true),
      damage = number(f.damage, 0, limits.damage),
      deaths = number(f.deaths, 0, limits.deaths, true),
      secret = f.secret == '1',
      secretOpen = f.secretopen == '1',
      score = number(f.score, 0, limits.score, true),
      fragment = f.fragment == '1',
      version = version,
    }
    assert(f.claimed and #f.claimed < limits.ledger, 'invalid ledger')
    d.claimed = ledger(f.claimed ~= '' and fields(f.claimed) or {}, d.wave)
    if f.echo ~= 'none' then
      local e = fields(f.echo)
      assert(#e == 4, 'invalid echo')
      d.echo = {
        amount = number(e[1], 1, limits.echo, true),
        x = number(e[2], 1, legacyCoordinateLimit),
        z = number(e[3], 1, legacyCoordinateLimit),
        wave = number(e[4], 1, d.wave, true),
      }
    end
    return settle(d), sequence
  end)
  if not ok then
    return nil, 'The save is incomplete or damaged.'
  end
  return data, seq
end

-- THE FILE ------------------------------------------------------------------
-- game (optional): the session, for the other sections of the file.
function P.encode(data, sequence, game)
  return Save.encode(
    'expedition',
    Save.capture('expedition', { run = data, game = game }),
    sequence
  )
end
-- The checkpoint of a save (its other sections in d.sections) and its
-- sequence, or nil and a reason; a SIGIL06/07/08 text reads through the
-- adapter.
function P.decode(raw)
  if type(raw) ~= 'string' then
    return nil, 'Invalid save size.'
  end
  if raw:match('^SIGIL0[678]\n') then
    return decodeLegacy(raw)
  end
  local values, seq = Save.decode('expedition', raw)
  if not values then
    return nil, 'The save is incomplete or damaged.'
  end
  local d, others = values.run, nil
  for name, value in pairs(values) do
    if name ~= 'run' then
      others = others or {}
      others[name] = value
    end
  end
  d.sections = others
  return d, seq
end
-- The file of a save prefix (its temporary and previous copies beside it).
function P.file(prefix)
  return (prefix or P.prefix) .. '.save'
end
-- The newest complete checkpoint: the new file, else the older two
-- generations prefix.a / prefix.b of SIGIL06-08 (read until a new save
-- replaces them). Returns it, its sequence and whether damage was seen.
function P.read(prefix)
  prefix = prefix or P.prefix
  local best, sequence, damaged = nil, 0, false
  local values, seq, broken = Save.read('expedition', P.file(prefix))
  if values then
    sequence = seq
    local d = values.run
    for name, value in pairs(values) do
      if name ~= 'run' then
        d.sections = d.sections or {}
        d.sections[name] = value
      end
    end
    best = d
  end
  damaged = broken
  for _, suffix in ipairs({ 'a', 'b' }) do
    local raw = love.filesystem.read(prefix .. '.' .. suffix)
    if raw then
      local d, s = decodeLegacy(raw)
      if d and s > sequence then
        best, sequence = d, s
      elseif not d then
        damaged = true
      end
    end
  end
  return best, sequence, damaged
end
-- Write the checkpoint (game: the session, for the file's other sections).
function P.write(data, prefix, game)
  prefix = prefix or P.prefix
  local _, seq = P.read(prefix)
  local encoded = P.encode(data, seq + 1, game)
  if not P.decode(encoded) then
    return false, 'Could not prepare the save.'
  end
  local ok = Save.write(P.file(prefix), encoded)
  if not ok then
    return false, 'Could not save the expedition.'
  end
  return true
end
return P

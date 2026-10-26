-- The SIGIL06 save format exactly as 0.23 wrote it (two fixed weapons) and
-- the SIGIL08 format as 0.32 wrote it, for the migration tests: the game
-- itself only reads them (storage/run_save.lua).
local Save = require('src.storage.run_save')
local Legacy = {}
local function pack(v)
  local shotgun, revolver = v.weapons.exorcist, v.weapons.judge
  return table.concat({ v.armor, shotgun.mag, shotgun.reserve, v.essence or 0, v.weapon }, ','),
    table.concat({ revolver.mag, revolver.reserve }, ',')
end
function Legacy.encode06(data, sequence)
  local keys = {}
  for k, v in pairs(data.claimed or {}) do
    if v then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys)
  local e = data.echo
  local inventory, revolver = pack(data.inventory)
  local checkpoint, checkRevolver = pack(data.checkpoint)
  local payload = table.concat({
    'phase=' .. data.phase,
    'wave=' .. data.wave,
    'wallet=' .. data.wallet,
    'glyph=' .. data.glyph,
    'owned=' .. (data.owned.choke and '1' or '0') .. ',' .. (data.owned.pierce and '1' or '0'),
    'claimed=' .. table.concat(keys, ','),
    'inventory=' .. inventory,
    'checkpoint=' .. checkpoint,
    'echo=' .. (e and table.concat({ e.amount, e.x, e.z, e.wave }, ',') or 'none'),
    'revolver=' .. revolver,
    'checkrevolver=' .. checkRevolver,
    'charges=' .. (data.inventory.abilities.powder or 2),
    'checkcharges=' .. (data.checkpoint.abilities.powder or 2),
    'elapsed=' .. data.elapsed,
    'kills=' .. data.kills,
    'damage=' .. data.damage,
    'deaths=' .. data.deaths,
    'secret=' .. (data.secret and '1' or '0'),
    'secretopen=' .. (data.secretOpen and '1' or '0'),
    'score=' .. data.score,
    'fragment=' .. (data.fragment and '1' or '0'),
  }, '\n')
  return 'SIGIL06\n' .. sequence .. '\n' .. Save.checksum(payload) .. '\n' .. payload
end
-- SIGIL07/08 kit: id:uses,... (every ability the knight carries).
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
local function packSlots(v)
  if v.abilityLoadout then
    return table.concat(v.abilityLoadout, ',')
  end
  local ordered = {}
  for id in pairs(v.abilities or {}) do
    ordered[#ordered + 1] = id
  end
  table.sort(ordered, function(a, b)
    if a == 'powder' or b == 'powder' then
      return a == 'powder' and b ~= 'powder'
    end
    return a < b
  end)
  return table.concat(ordered, ',')
end
-- SIGIL07/08 arsenal: id:mag:reserve,... in loadout order.
local function packArsenal(v)
  local out = {}
  for i, id in ipairs(v.loadout) do
    local w = v.weapons[id]
    out[i] = id .. ':' .. w.mag .. ':' .. w.reserve
  end
  return table.concat(out, ',')
end
function Legacy.encode08(data, sequence)
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
  return 'SIGIL08\n' .. sequence .. '\n' .. Save.checksum(payload) .. '\n' .. payload
end
return Legacy

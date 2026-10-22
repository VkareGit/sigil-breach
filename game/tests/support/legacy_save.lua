-- The SIGIL06 save format exactly as 0.23 wrote it (two fixed weapons), for
-- the migration tests: the game itself only reads it (storage/run_save.lua).
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
return Legacy

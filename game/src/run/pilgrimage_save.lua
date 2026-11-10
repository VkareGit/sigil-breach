-- The file of the way (PLAN G5: the format of a pilgrimage save, apart from
-- the mode that plays it, run/pilgrimage.lua). A file is judged here before it
-- touches a session: a wrong type refuses the whole of it, and what names
-- content that is gone is dropped, so a save outlives a content change.
local Abilities = require('src.content.abilities')
local Destruction = require('src.combat.destruction')
local Way = require('src.content.pilgrimage')
local MathX = require('src.core.mathx')
local Roles = require('src.core.roles')
local Save = require('src.storage.save')
local Pools = require('src.session.world')
local Weapons = require('src.content.weapons')
local Ammo = require('src.content.ammo.index')
local Bodies = require('src.combat.bodies')
local Maps = require('src.content.maps.index')
local Shop = require('src.content.shop')
local Copy = require('src.core.schema').copy
local Economy = require('src.run.economy')
local SigilRules = require('src.content.sigils')
local Rng = require('src.core.rng')
local S = {}
-- What the way gives the format: area(g), the area the knight is in, and
-- stand(g), the world under him made his area's (S.declare).
local way
local function whole(value, low, high)
  return type(value) == 'number'
    and MathX.finite(value)
    and value == math.floor(value)
    and value >= low
    and value <= high
end
-- The ids of a set that the game still has; an id content dropped goes with it.
local function known(set, exists)
  assert(type(set) == 'table', 'invalid set of ids')
  local kept = {}
  for id, value in pairs(set) do
    assert(type(id) == 'string' and value == true, 'invalid entry of a set of ids')
    if exists(id) then
      kept[id] = true
    end
  end
  return kept
end
local function validEcho(echo, home)
  if echo == nil then
    return nil
  end
  assert(type(echo) == 'table', 'invalid echo')
  assert(whole(echo.amount, 1, Shop.maxWallet), 'invalid echo amount')
  assert(MathX.finite(echo.x) and MathX.finite(echo.z), 'invalid echo position')
  return {
    amount = echo.amount,
    x = echo.x,
    z = echo.z,
    area = Way.areas:has(echo.area) and echo.area or home,
  }
end
-- The ids of a list that the game still has, in order, once each.
local function listed(list, exists)
  assert(type(list) == 'table', 'invalid list of ids')
  local kept, seen = {}, {}
  for _, id in ipairs(list) do
    assert(type(id) == 'string', 'invalid entry of a list of ids')
    if exists(id) and not seen[id] then
      seen[id] = true
      kept[#kept + 1] = id
    end
  end
  return kept
end
-- The engraving each weapon wears: owned ones on their own weapon. A save from before one per
-- weapon (0.42) wears its one engraving on the weapon it belongs to.
local function validWorn(worn, owned, glyph)
  assert(worn == nil or type(worn) == 'table', 'invalid engravings worn')
  local kept = {}
  for weapon, id in pairs(worn or { [''] = glyph }) do
    local offer = type(id) == 'string' and Shop.find(id)
    if
      offer
      and offer.kind == 'engraving'
      and offer.weapon
      and owned[id]
      and (worn == nil or offer.weapon == weapon)
    then
      kept[offer.weapon] = id
    end
  end
  return kept
end
local function validVows(vows)
  assert(type(vows) == 'table', 'invalid vows')
  local kept = {}
  for id, rank in pairs(vows) do
    assert(type(id) == 'string' and whole(rank, 1, math.huge), 'invalid vow')
    local offer = Shop.find(id)
    if offer and (offer.kind == 'vow' or offer.kind == 'sigil') then
      kept[id] = math.min(rank, offer.limit)
    end
  end
  return kept
end
local function validRuins(ruins)
  assert(type(ruins) == 'table', 'invalid ruins')
  local kept = {}
  for mapId, states in pairs(ruins) do
    assert(type(mapId) == 'string' and type(states) == 'table', 'invalid ruin')
    if Maps:has(mapId) then
      kept[mapId] = Destruction.clean(mapId, states)
    end
  end
  return kept
end
-- The field as the knight stands in it (D9): written with every save while he lives on the
-- way, so a quit, a crash or a quiet save is taken up where it was. Nothing when he is down.
local function fieldOf(g)
  local r, p = g.run, Roles.controlled(g)
  if r.phase ~= 'journey' or g.state == 'dead' or (p.hp or 0) <= 0 then
    return nil
  end
  local field = {
    area = r.area,
    x = p.x,
    z = p.z,
    yaw = p.yaw or 0,
    hp = p.hp,
    armor = p.armor or 0,
    weapon = p.weapon,
    weapons = select(2, Weapons.inventory(g, p)),
    uses = {},
    fallen = {},
    picked = {},
    hunters = {},
  }
  for id, state in pairs(p.abilityState or {}) do
    field.uses[id] = state.uses
  end
  local alive, lying = {}, {}
  Bodies.eachCreature(g, function(e)
    if e.post and e.hp > 0 then
      alive[e.post] = true
      if e.awake then
        field.hunters[#field.hunters + 1] =
          { post = e.post, x = e.x, z = e.z, yaw = e.facing or 0, hp = e.hp }
      end
    end
  end)
  for _, pickup in ipairs(Pools.of(g, 'pickups')) do
    if pickup.rewardId then
      lying[pickup.rewardId] = true
    end
  end
  -- Every area of the map he stands on: all of them stand at once (PLAN Z6).
  for _, here in ipairs(Way.areasOf(way.area(g).map)) do
    for _, entry in ipairs(here.garrison) do
      if not alive[entry.id] and not r.slain[entry.id] then
        field.fallen[entry.id] = true
      end
    end
    for _, cache in ipairs(here.supplies or {}) do
      if not lying[cache.id] and not r.taken[cache.id] then
        field.picked[cache.id] = true
      end
    end
  end
  return S.fightOf(g, field)
end
-- The fight itself as the session save keeps it (plan v10 V4: its pools section): every
-- creature with its blow, clocks and wounds, what flies and burns, what lies where and how
-- much is left, the knight with what he was doing; the clock those times are on; and, since
-- PLAN Z2a, where the simulation's random stream stood and what is left of a hit's stop: a
-- quit neither redraws nor restarts a single roll, nor ends a stop early (D9). Packed, so
-- the way's origin stays plain data for a journal.
function S.fightOf(g, field)
  local pools = Save.section('pools')
  field.pools = { version = pools.version, data = pools.pack(g) }
  field.elapsed, field.nextAttack = g.elapsed, g.nextAttack
  field.rng = g.rng.sim:get()
  field.impactSlow, field.worldStop = g.impactSlow, g.worldStop
  return field
end
-- The same fight taken up in a session: its pools, its clock and its stream. A field
-- written before the stream was kept (section version 4) goes on from a fresh stream.
function S.resumeFight(g, field)
  if field.pools then
    Save.section('pools').restore(g, S.readPools(field.pools))
    g.elapsed = field.elapsed or g.elapsed
    g.nextAttack = field.nextAttack
  end
  if field.rng ~= nil then
    g.rng.sim:set(field.rng)
  end
  g.impactSlow = field.impactSlow or g.impactSlow
  g.worldStop = field.worldStop or g.worldStop
end
local function finiteNumber(value)
  return type(value) == 'number' and MathX.finite(value)
end
-- The pools of a field read as the session save reads them: migrated, then unpacked.
function S.readPools(packed)
  local def = Save.section('pools')
  assert(type(packed) == 'table' and whole(packed.version, 1, def.version), 'invalid field pools')
  local data = Copy(packed.data)
  for v = packed.version, def.version - 1 do
    data = def.migrations[v](data)
  end
  return def.unpack(data)
end
-- A field's packed pools when they read, else nothing.
local function fieldPools(packed)
  if packed ~= nil and pcall(S.readPools, packed) then
    return Copy(packed)
  end
end
-- A field from a file: judged like the rest, what names gone content is dropped.
local function validField(field)
  if field == nil then
    return nil
  end
  assert(type(field) == 'table', 'invalid field')
  assert(type(field.area) == 'string' and Way.areas:has(field.area), 'invalid field area')
  for _, key in ipairs({ 'x', 'z', 'yaw', 'hp', 'armor' }) do
    assert(finiteNumber(field[key]), 'invalid field ' .. key)
  end
  assert(field.hp > 0 and field.armor >= 0, 'invalid field health')
  assert(field.elapsed == nil or finiteNumber(field.elapsed), 'invalid field clock')
  assert(field.nextAttack == nil or finiteNumber(field.nextAttack), 'invalid field pacing')
  assert(field.rng == nil or Rng.valid(field.rng), 'invalid field random state')
  for _, key in ipairs({ 'impactSlow', 'worldStop' }) do
    assert(
      field[key] == nil or (finiteNumber(field[key]) and field[key] >= 0),
      'invalid field stop'
    )
  end
  assert(field.weapon == nil or whole(field.weapon, 1, math.huge), 'invalid field weapon')
  local out = {
    area = field.area,
    x = field.x,
    z = field.z,
    yaw = field.yaw,
    hp = field.hp,
    armor = field.armor,
    weapon = field.weapon,
    weapons = {},
    elapsed = field.elapsed,
    nextAttack = field.nextAttack,
    rng = field.rng,
    impactSlow = field.impactSlow,
    worldStop = field.worldStop,
    -- The fight's pools stay packed (plain data for a journal's origin); one that does not
    -- read is left out and the way is taken up from the rest of the field.
    pools = fieldPools(field.pools),
    uses = {},
    fallen = known(field.fallen or {}, Way.postOf),
    picked = known(field.picked or {}, Way.supplyOf),
    hunters = {},
  }
  -- Each weapon's rounds through its ammunition model, held within what the weapon holds.
  local function rounds(value, low, high)
    assert(whole(value, low, high), 'invalid field rounds')
    return value
  end
  for id, saved in pairs(field.weapons or {}) do
    assert(type(saved) == 'table', 'invalid field rounds')
    if Weapons.has(id) then
      local def = Weapons.get(id)
      local model = Ammo.of(def)
      local values = model.list(saved)
      values[#values + 1] = rounds
      out.weapons[id] = model.unpack(def.ammo, unpack(values))
    end
  end
  for id, uses in pairs(field.uses or {}) do
    assert(whole(uses, 0, math.huge), 'invalid field uses')
    if Abilities:has(id) then
      out.uses[id] = uses
    end
  end
  for _, hunter in ipairs(field.hunters or {}) do
    assert(type(hunter) == 'table' and type(hunter.post) == 'string', 'invalid hunter')
    assert(
      finiteNumber(hunter.x) and finiteNumber(hunter.z) and finiteNumber(hunter.yaw),
      'invalid hunter position'
    )
    assert(finiteNumber(hunter.hp) and hunter.hp > 0, 'invalid hunter health')
    if Way.postOf(hunter.post) then
      out.hunters[#out.hunters + 1] =
        { post = hunter.post, x = hunter.x, z = hunter.z, yaw = hunter.yaw, hp = hunter.hp }
    end
  end
  return out
end
-- Declare the section of the way's file (once, by run/pilgrimage.lua).
function S.declare(owner)
  way = owner
  Save.declare({
    name = 'pilgrimage',
    file = 'pilgrimage',
    version = 6,
    migrations = {
      -- A way kept neither its own seed nor its stream: it starts from the session's seed.
      [5] = function(data)
        return data
      end,
      -- A field kept no random stream: it is taken up from a fresh one, as before.
      [4] = function(data)
        return data
      end,
      [3] = function(data)
        -- Old saves wore types, not copies. Keep one of each formerly worn
        -- type in catalogue order within capacity; retain every found copy.
        local old, used, worn = data.sigils or {}, 0, {}
        for _, id in ipairs(SigilRules.order) do
          local cost = Economy.sigilCost(id, 1)
          if old[id] and (data.vows[id] or 0) > 0 and used + cost <= Shop.sigilSlots then
            worn[id], used = 1, used + cost
          end
        end
        data.sigils = worn
        return data
      end,
      [2] = function(data)
        data.loadout = data.loadout and data.loadout[1] and data.loadout or Copy(Way.legacyWeapons)
        return data
      end,
      -- One area, one map, one ruin.
      [1] = function(data)
        data.ruins, data.ruin = { proving = data.ruin }, nil
        if data.echo then
          data.echo.area = Way.first
        end
        return data
      end,
    },
    pack = function(g)
      local r = g.run
      local ruins = Copy(r.ruins)
      ruins[g.world.mapId] = g.world.destruction or {}
      return {
        wallet = r.wallet,
        deaths = r.deaths,
        fire = r.fire,
        lit = r.lit,
        echo = r.echo,
        owned = r.owned,
        glyph = r.glyph,
        worn = r.worn,
        sigils = r.sigils,
        slain = r.slain,
        taken = r.taken,
        opened = r.opened,
        ruins = ruins,
        vows = r.vows,
        loadout = (Weapons.inventory(g, Roles.controlled(g))),
        abilities = select(2, Abilities.inventory(g, Roles.controlled(g))),
        field = fieldOf(g),
        -- The way's own seed and where its stream stood (PLAN Z2b, D9): taken up at a fire
        -- or after a death it goes on, neither redrawn nor restarted.
        seed = r.seed,
        rng = g.rng.sim:get(),
      }
    end,
    -- A file is judged here, before it touches a session: a wrong type refuses the whole of
    -- it, and what names content that is gone is dropped, so a save outlives a content change.
    unpack = function(data)
      assert(type(data) == 'table', 'invalid way')
      assert(whole(data.wallet, 0, Shop.maxWallet), 'invalid wallet')
      assert(whole(data.deaths, 0, math.huge), 'invalid deaths')
      assert(type(data.fire) == 'string', 'invalid fire')
      assert(type(data.glyph) == 'string', 'invalid engraving')
      assert(data.seed == nil or Rng.validSeed(data.seed), 'invalid way seed')
      assert(data.rng == nil or Rng.valid(data.rng), 'invalid way random state')
      local fire, home = Way.fireOf(data.fire)
      if not fire then
        home = Way.start()
        fire = Way.fireOf(home.first)
      end
      local out = {
        wallet = data.wallet,
        deaths = data.deaths,
        seed = data.seed,
        rng = data.rng,
        area = home.id,
        fire = fire.id,
        lit = known(data.lit, Way.fireOf),
        owned = known(data.owned, Shop.find),
        opened = known(data.opened, Way.doorOf),
        slain = known(data.slain or {}, Way.postOf),
        taken = known(data.taken or {}, Way.supplyOf),
        ruins = validRuins(data.ruins),
        echo = validEcho(data.echo, home.id),
        vows = validVows(data.vows or {}),
        loadout = listed(data.loadout or {}, Weapons.has),
        abilities = listed(data.abilities or {}, function(id)
          return Abilities:has(id)
        end),
      }
      out.lit[fire.id] = true
      out.field = validField(data.field)
      out.glyph = out.owned[data.glyph] and data.glyph or 'none'
      out.worn = validWorn(data.worn, out.owned, out.glyph)
      -- What it wears beyond the copies found, the sigil's limit or the places
      -- comes off, in catalogue order (PLAN G1): a retuned sigil never refuses
      -- the file.
      out.sigils = {}
      assert(data.sigils == nil or type(data.sigils) == 'table', 'invalid sigil set')
      for id, copies in pairs(data.sigils or {}) do
        assert(type(id) == 'string' and whole(copies, 1, math.huge), 'invalid equipped copies')
      end
      local used = 0
      for _, id in ipairs(SigilRules.order) do
        local offer = Shop.find(id)
        local copies = data.sigils and data.sigils[id] or 0
        if offer and offer.kind == 'sigil' then
          copies = math.min(copies, offer.limit, out.vows[id] or 0)
          while copies > 0 and used + Economy.sigilCost(id, copies) > Shop.sigilSlots do
            copies = copies - 1
          end
          if copies > 0 then
            out.sigils[id], used = copies, used + Economy.sigilCost(id, copies)
          end
        end
      end
      return out
    end,
    restore = function(g, data)
      local r = g.run
      r.wallet, r.deaths, r.area, r.fire = data.wallet, data.deaths, data.area, data.fire
      r.lit, r.owned, r.glyph = Copy(data.lit), Copy(data.owned), data.glyph
      r.worn = Copy(data.worn)
      r.sigils = Copy(data.sigils or {})
      r.slain, r.taken = Copy(data.slain), Copy(data.taken)
      r.opened, r.ruins, r.echo = Copy(data.opened), Copy(data.ruins), Copy(data.echo)
      r.vows = Copy(data.vows)
      r.seed = data.seed
      -- Taken up by P.init once the kit below is in place (D9).
      r.resume = data.field and Copy(data.field) or nil
      way.stand(g)
      -- The kit last: nothing above can leave it half changed. A way with no kit of its own
      -- keeps the knight's.
      local p = Roles.controlled(g)
      if data.loadout[1] then
        Weapons.restore(g, data.loadout, nil, p)
      end
      if data.abilities[1] then
        Abilities.restore(g, nil, data.abilities, p)
        Abilities.give(g, 'flask', p)
      end
      -- And the stream where it stood, once nothing above can refuse the file (PLAN Z2b).
      if data.rng then
        g.rng.sim:set(data.rng)
      end
    end,
  })
end
return S

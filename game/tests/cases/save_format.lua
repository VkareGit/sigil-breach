-- Plan v10 V4: saves as data with a schema. Older checkpoints read the same
-- through the adapter; any state written reads back the same; a damaged,
-- cut or foreign file is refused before anything is touched; a section is
-- one declaration; an interrupted write keeps the previous save.
local Fixtures = require('tests.support.fixtures')
local Legacy = require('tests.support.legacy_save')
local Serialize = require('src.core.serialize')
local Save = require('src.storage.save')
local RunSave = require('src.storage.run_save')
local SessionSave = require('src.storage.session_save')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Shop = require('src.content.shop')
local Expedition = require('src.content.expedition')
local Pools = require('src.session.world')
local World = require('src.world.arena')
local Spawn = require('src.session.spawn')
local Tests = {}
-- A small deterministic generator (the property tests repeat exactly).
local function generator(seed)
  local state = seed
  return function(n)
    state = (state * 1103515245 + 12345) % 2147483648
    return n and (state % n) + 1 or state / 2147483648
  end
end
-- A checkpoint without what only its file adds (format, other sections).
local function plain(d)
  local out = {}
  for k, v in pairs(d) do
    if k ~= 'version' and k ~= 'sections' then
      out[k] = v
    end
  end
  return Serialize.encode(out)
end
-- A payload signed again after an edit (the checksum is not the guard).
local function resign(text, edit)
  local format, kind, seq, _, payload = text:match('^(SIGIL%d%d)\n([%w_]+)\n(%d+)\n(%d+)\n(.*)$')
  local changed = edit(payload)
  return table.concat({ format, kind, seq, Save.checksum(changed), changed }, '\n')
end
local function randomInventory(rand)
  local ids = Weapons.registry:ids()
  table.sort(ids)
  local loadout, weapons, used = {}, {}, {}
  for _ = 1, rand(math.min(#ids, 4)) do
    local id = ids[rand(#ids)]
    if not used[id] then
      used[id] = true
      loadout[#loadout + 1] = id
      local def = Weapons.get(id)
      weapons[id] = { mag = rand(def.capacity + 1) - 1, reserve = rand(def.maxReserve + 1) - 1 }
    end
  end
  local abilities, slots = {}, {}
  local kit = Abilities:ids()
  table.sort(kit)
  for _, id in ipairs(kit) do
    if rand(2) == 1 then
      abilities[id] = rand(Abilities:get(id).capacity + 1) - 1
      slots[#slots + 1] = id
    end
  end
  return {
    armor = rand(Shop.maxWard + 1) - 1,
    essence = rand(101) - 1,
    weapon = rand(#loadout),
    loadout = loadout,
    weapons = weapons,
    abilities = abilities,
    abilityLoadout = slots,
  }
end
local function randomRun(rand)
  local last = Expedition.totalWaves + 1
  local complete = rand(4) == 1
  local wave = complete and last or rand(last)
  local owned = { choke = rand(2) == 1, pierce = rand(2) == 1 }
  local glyphs = { 'none' }
  for _, g in ipairs({ 'choke', 'pierce' }) do
    if owned[g] then
      glyphs[#glyphs + 1] = g
    end
  end
  local claimed = {}
  for _ = 1, rand(6) - 1 do
    claimed[rand(wave) .. '_' .. rand(20)] = true
  end
  return {
    mode = 'expedition',
    phase = complete and 'complete' or (rand(2) == 1 and 'preparing' or 'defeated'),
    wave = wave,
    wallet = rand(Shop.maxWallet + 1) - 1,
    glyph = glyphs[rand(#glyphs)],
    owned = owned,
    claimed = claimed,
    inventory = randomInventory(rand),
    checkpoint = randomInventory(rand),
    -- Quarters: exact in the older text format too; the older format kept
    -- echoes within 38 cells.
    echo = rand(2) == 1
        and { amount = rand(500), x = 2 + rand(144) / 4, z = 2 + rand(144) / 4, wave = rand(wave) }
      or nil,
    elapsed = rand(20000) / 4,
    kills = rand(3000) - 1,
    damage = rand(36000) / 4,
    deaths = rand(40) - 1,
    secret = rand(2) == 1,
    secretOpen = rand(2) == 1,
    score = rand(90000) - 1,
    fragment = complete,
  }
end
-- A session with members of every pool in random states and edited cells.
local function randomSession(G, rand)
  local g = G.new('classic')
  g.testing = true
  g:start()
  local kinds = { 'imp', 'armored', 'stolas', 'boss' }
  for i = 1, 4 + rand(12) do
    local e = g:spawn(kinds[rand(#kinds)], 9 + rand() * 14, 12 + rand() * 9)
    e.hp = rand(e.maxHp)
    e.ai = ({ 'idle', 'move', 'windup', 'recover', 'hurt' })[rand(5)]
    e.phase = rand() * 2
    e.aimX, e.aimZ = 10 + rand() * 10, 14 + rand() * 8
    e.leapY = rand(3) == 1 and rand() * 1.5 or nil
    e.conditions = rand(2) == 1 and { burning = rand() * 3 } or e.conditions
    e.memory = rand(4) == 1 and math.huge or rand() * 4
    e.faction = rand(5) == 1 and 'knight' or nil
    e.awake = rand(2) == 1
    if i % 3 == 0 then
      e.pendingHazard = Spawn.make(g, 'hazard', {
        kind = 'lightning',
        x = e.aimX,
        z = e.aimZ,
        radius = 1.5,
        delay = 1,
        maxDelay = 1,
        life = 2,
        owner = e.id,
      })
    end
  end
  for _ = 1, rand(4) do
    Spawn.make(
      g,
      'pickup',
      { kind = 'ammo', amount = rand(9), x = 10 + rand() * 10, z = 14 + rand() * 8 }
    )
  end
  for _ = 1, rand(3) do
    Spawn.make(g, 'projectile', {
      x = 12 + rand() * 6,
      y = 1,
      z = 15 + rand() * 6,
      vx = rand() * 4,
      vz = rand() * 4,
      life = 2,
      owner = Pools.of(g, 'enemies')[1].id,
    })
  end
  local p = g.player
  p.x, p.z, p.hp, p.yaw = 12 + rand() * 8, 20 + rand() * 6, rand(100), rand() * 6
  for _ = 1, rand(5) do
    local x, z = 3 + rand(25), 3 + rand(25)
    if g.world.map[z][x] == 0 and (x - p.x) ^ 2 + (z - p.z) ^ 2 > 9 then
      g.world.map[z][x] = 1
    end
  end
  for _, seal in ipairs(g.world.seals) do
    seal.active = rand(2) == 1
  end
  World.rebuild(g.world)
  return g
end
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'save format: ', 'save format: ')
  local rand = generator(20261026)

  -- Older checkpoints read exactly as before; the same state reads the same
  -- from the new format.
  local same, legacyRead = true, true
  for _ = 1, 30 do
    local d = randomRun(rand)
    local old = RunSave.decode(Legacy.encode08(d, 7))
    local new = RunSave.decode(RunSave.encode(d, 7))
    legacyRead = legacyRead and old ~= nil and old.version == 'SIGIL08'
    same = same and old ~= nil and new ~= nil and plain(old) == plain(new)
  end
  local fresh = Fixtures.expedition(G)
  local six = RunSave.decode(Legacy.encode06(require('src.run.descent').snapshot(fresh), 3))
  check(
    'every SIGIL08 checkpoint of the tests reads as before and equals its new-format twin (30 states)',
    legacyRead and same
  )
  check(
    'a SIGIL06 checkpoint still reads through the adapter',
    six ~= nil and six.version == 'SIGIL06'
  )

  -- Write -> read gives the same state, for random states.
  local roundTrip = true
  for _ = 1, 40 do
    local d = randomRun(rand)
    local back = RunSave.decode(RunSave.encode(d, 3))
    roundTrip = roundTrip
      and back ~= nil
      and plain(back) == plain(RunSave.decode(RunSave.encode(back, 3)))
    local text = Save.encode('expedition', Save.capture('expedition', { run = d }), 3)
    local values = Save.decode('expedition', text)
    roundTrip = roundTrip and values ~= nil and plain(values.run) == plain(back)
  end
  check('a checkpoint written and read is the same checkpoint (40 random states)', roundTrip)
  local sessions, identities = true, true
  for _ = 1, 8 do
    local g = randomSession(G, rand)
    local before = Serialize.encode(Save.capture('session', g))
    local values = assert(SessionSave.decode(SessionSave.encode(g, 4)))
    local restored = G.new('classic')
    restored.testing = true
    SessionSave.restore(restored, values)
    sessions = sessions and Serialize.encode(Save.capture('session', restored)) == before
    local knights, enemies = Pools.of(restored, 'knights'), Pools.of(restored, 'enemies')
    identities = identities
      and restored.player == knights[1]
      and enemies[1].archetype == Pools.of(g, 'enemies')[1].archetype
    for _, e in ipairs(enemies) do
      if e.pendingHazard then
        local shared = false
        for _, h in ipairs(Pools.of(restored, 'hazards')) do
          shared = shared or h == e.pendingHazard
        end
        identities = identities and shared and Pools.get(restored, e.id) == e
      end
    end
  end
  check(
    'a session written and read has the same pools, sides and map (8 random sessions)',
    sessions
  )
  check(
    'definitions stay definitions, a hazard shared by its pool and its caster stays one table',
    identities
  )

  -- Refused whole: nothing of a bad file reaches the session.
  local d = randomRun(rand)
  local good = RunSave.encode(d, 5)
  local flipped = good:sub(1, #good - 20)
    .. (good:sub(-20, -20) == 'a' and 'b' or 'a')
    .. good:sub(-19)
  local refused = {
    damaged = flipped,
    cut = good:sub(1, math.floor(#good / 2)),
    foreign = (good:gsub('^SIGIL09', 'SIGIL10')),
    newer = resign(good, function(p)
      return (p:gsub('%["version"%]=1', '["version"]=2'))
    end),
    unknown = resign(good, function(p)
      return '{["mystery"]={["data"]=1,["version"]=1},' .. p:sub(2)
    end),
    invalid = resign(good, function(p)
      return (p:gsub('%["wallet"%]=%d+', '["wallet"]=-1'))
    end),
    code = 'return os.execute("x")',
    kind = (good:gsub('\nexpedition\n', '\nsession\n', 1)),
  }
  local allRefused = true
  for name, text in pairs(refused) do
    local ok = RunSave.decode(text)
    if ok then
      lines[#lines + 1] = 'save format: accepted ' .. name
    end
    allRefused = allRefused and not ok
  end
  check(
    'a damaged, cut, foreign, newer, unknown, invalid or executable file is refused',
    allRefused and RunSave.decode(good) ~= nil
  )
  local g = randomSession(G, rand)
  local text = SessionSave.encode(g, 2)
  local broken = resign(text, function(p)
    -- A valid map beside pools whose controlled knight does not exist.
    return (p:gsub('%["controlled"%]=%d+', '["controlled"]=99'))
  end)
  local target = randomSession(G, rand)
  local untouched = Serialize.encode(Save.capture('session', target))
  local loaded = SessionSave.load(target, broken)
  check(
    'a file refused in its last section leaves the session as it was (no partial state)',
    loaded == nil and Serialize.encode(Save.capture('session', target)) == untouched
  )

  -- A new section is one declaration; an older file without it reads with
  -- its default; a later version migrates.
  local flags, restored = setmetatable({}, { __mode = 'k' }), setmetatable({}, { __mode = 'k' })
  local base = Fixtures.expedition(G)
  flags[base] = { forge = true, archive = false }
  local def = {
    name = 'trialFlags',
    file = 'expedition',
    version = 1,
    pack = function(source)
      return source.game and flags[source.game] or {}
    end,
    unpack = function(t)
      assert(type(t) == 'table')
      for k, v in pairs(t) do
        assert(type(k) == 'string' and type(v) == 'boolean')
      end
      return t
    end,
    restore = function(target, value)
      restored[target] = value
    end,
    default = function()
      return {}
    end,
  }
  local oldFile = RunSave.encode(require('src.run.descent').snapshot(base), 1, base)
  Save.declare(def)
  local ok, problem = pcall(function()
    local saved = RunSave.encode(require('src.run.descent').snapshot(base), 2, base)
    local read = assert(RunSave.decode(saved))
    local into = Fixtures.expedition(G)
    require('src.run.descent').load(into, read)
    local older = assert(RunSave.decode(oldFile))
    check(
      'a section added by its declaration alone is written, read and restored',
      read.sections.trialFlags.forge == true and restored[into] and restored[into].forge == true
    )
    check(
      'an older file without the section reads with its default',
      older.sections and next(older.sections.trialFlags) == nil
    )
    Save.forget(def.name)
    def.version = 2
    def.migrations = {
      [1] = function(t)
        return { forge = t.forge, archive = t.archive, cellar = false }
      end,
    }
    Save.declare(def)
    local migrated = assert(RunSave.decode(saved))
    check(
      'a section of an older version migrates by its ordered functions',
      migrated.sections.trialFlags.cellar == false and migrated.sections.trialFlags.forge == true
    )
  end)
  Save.forget(def.name)
  assert(ok, problem)

  -- An interrupted write keeps the previous save.
  local name = 'qa-v4-interrupt.save'
  local function clean()
    for _, path in ipairs({ name, name .. '.tmp', name .. '.previous' }) do
      love.filesystem.remove(path)
    end
  end
  clean()
  local first = RunSave.encode(randomRun(rand), 1)
  local second = RunSave.encode(randomRun(rand), 2)
  assert(Save.write(name, first))
  Save.interrupt = function(stage)
    if stage == 'temp' then
      error('power cut', 0)
    end
  end
  local cut = pcall(Save.write, name, second)
  Save.interrupt = nil
  local _, sequence = Save.read('expedition', name)
  local kept = Save.decode('expedition', love.filesystem.read(name) or '')
  love.filesystem.write(name .. '.tmp', second:sub(1, math.floor(#second / 2)))
  local _, halfSequence, damaged = Save.read('expedition', name)
  Save.interrupt = function(stage)
    if stage == 'swap' then
      error('power cut', 0)
    end
  end
  local swapped = pcall(Save.write, name, second)
  Save.interrupt = nil
  local _, swapSequence = Save.read('expedition', name)
  local previous = Save.decode('expedition', love.filesystem.read(name .. '.previous') or '')
  clean()
  check(
    'a write cut before or in the middle of the swap keeps a complete save',
    not cut
      and sequence == 2
      and kept ~= nil
      and halfSequence == 1
      and damaged
      and not swapped
      and swapSequence == 2
      and previous ~= nil
  )
  return lines
end
return Tests

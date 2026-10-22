-- Command journal (0.24 E10, Command pattern): everything a player does to a
-- session, in order, as plain data — the aim, every update with its input
-- and every command (shoot, throw, reload, weapon, dodge, interact, start,
-- and the mode's commands through Game:act: ready, retry, shop, the proving
-- ground's catalogue). A session built the same way and given the same
-- journal reproduces the same simulation bit for bit (the golden master
-- checks it). A journal is text through core/serialize: a replay file, a bug
-- report, a demo.
--   local journal = Journal.record(g)   -- from now on g is recorded
--   Journal.stop(g)                     -- g is plain again
--   Journal.replay(fresh, journal)      -- the same session again
local Serialize = require('src.core.serialize')
local Integrity = require('src.session.integrity')
-- version: the journal's format; build: the game that recorded it (a replay
-- in another build is refused; core/build.lua, the same in every entry point).
local Journal = { version = 2, build = require('src.core.build').version }
local recordings = setmetatable({}, { __mode = 'k' })
local sessions = setmetatable({}, { __mode = 'k' })
local observers = setmetatable({}, { __mode = 'k' })
-- Store resolved outcomes, not pointers to mutable enemies or presentation.
-- Volley contacts retain shape/zone/material and each pellet's exact result.
local function observe(g, consume)
  local body = g.bus:on('sim', 'BodyHit', function(event)
    consume(Serialize.encode({
      kind = 'health',
      targetId = event.enemy.id,
      health = event.health,
      remaining = event.enemy.hp,
      source = event.source,
    }))
  end)
  local volley = g.bus:on('sim', 'VolleyResolved', function(event)
    consume(Serialize.encode({
      kind = 'volley',
      shot = event.report.shotSerial or g.shotSerial,
      contacts = event.report.contacts or {},
      targets = event.report.hitTargets,
      health = event.report.healthDamage,
      blocked = event.report.blocked,
    }))
  end)
  return function()
    g.bus:off('sim', 'BodyHit', body)
    g.bus:off('sim', 'VolleyResolved', volley)
  end
end
-- The session's commands that a player can issue (Game methods).
Journal.commands = {
  'look',
  'update',
  'shoot',
  'cast',
  'reloadGun',
  'switchWeapon',
  'dash',
  'interact',
  'start',
  'act',
}
-- Session fields the application sets directly, outside any command (a
-- pause, the help or the map, cleared intents). A change between two
-- commands is recorded as a 'set' entry before the next one, the way an
-- aim set by a tool is an 'aim' entry. Paths: 'field' or 'player.field'.
Journal.external = { 'state', 'map', 'help', 'fireBuffer', 'player.jumpBuffer' }
local function read(g, path)
  local owner, key = path:match('^(%w+)%.(%w+)$')
  if owner then
    return g[owner] and g[owner][key]
  end
  return g[path]
end
local function write(g, path, value)
  local owner, key = path:match('^(%w+)%.(%w+)$')
  if owner then
    g[owner][key] = value
  else
    g[path] = value
  end
end
local function copyInput(input)
  if type(input) ~= 'table' then
    return input
  end
  local out = {}
  for k, v in pairs(input) do
    out[k] = v
  end
  return out
end
-- Where the journal began: a replay must start from the same place. A
-- session recorded from its construction matches a new one built from the
-- header; a session recorded later (a return to a paused run) does not, and
-- its replay says so instead of diverging silently.
function Journal.origin(g)
  local alive = 0
  for _, e in ipairs(g.enemies or {}) do
    alive = alive + (e.hp > 0 and 1 or 0)
  end
  return {
    elapsed = g.elapsed,
    kills = g.kills,
    alive = alive,
    nextId = g.nextId,
    x = g.player.x,
    z = g.player.z,
  }
end
-- What rebuilds the session a journal starts from: its mode, map and origin.
function Journal.header(g)
  return {
    version = Journal.version,
    build = Journal.build,
    mode = g.mode,
    map = g.world and g.world.mapId,
    origin = Journal.origin(g),
    initial = Integrity.capture(g),
  }
end
-- A fresh session as the journal's began (Game: session/game.lua).
function Journal.session(Game, journal)
  local header = journal.header or {}
  if header.mode == 'field' then
    return require('src.run.test_field').new(Game)
  end
  return Game.new(header.mode == 'expedition' and 'descent' or 'classic', header.map)
end
function Journal.record(g)
  assert(not sessions[g], 'session is already being recorded')
  local journal = { entries = {}, receipts = {}, header = Journal.header(g) }
  observers[journal] = observe(g, function(receipt)
    journal.receipts[#journal.receipts + 1] = receipt
  end)
  local entries = journal.entries
  local depth = 0
  local aimYaw, aimPitch
  local known = {}
  local function remember()
    for i, path in ipairs(Journal.external) do
      known[i] = read(g, path)
    end
  end
  local function sync()
    if depth > 0 then
      return false
    end
    local p = g.player
    if p.yaw ~= aimYaw or p.pitch ~= aimPitch then
      aimYaw, aimPitch = p.yaw, p.pitch
      entries[#entries + 1] = { 'aim', p.yaw, p.pitch }
    end
    for i, path in ipairs(Journal.external) do
      local value = read(g, path)
      if value ~= known[i] then
        entries[#entries + 1] = { 'set', path, value }
      end
    end
    remember()
    return true
  end
  remember()
  recordings[journal] = function()
    if sync() then
      journal.final = Integrity.capture(g)
    end
  end
  sessions[g] = journal
  for _, name in ipairs(Journal.commands) do
    local method = assert(g[name], 'session has no command ' .. name)
    g[name] = function(self, ...)
      -- Only the player's own commands; a command issued by another one (an
      -- update that fires) is its consequence and replays by itself.
      if depth == 0 then
        sync()
        journal.final = nil
        local args = { ... }
        if name == 'update' then
          args[2] = copyInput(args[2])
        end
        entries[#entries + 1] = { name, args }
      end
      depth = depth + 1
      local results = { method(self, ...) }
      depth = depth - 1
      if depth == 0 then
        remember()
        -- The aim a 'look' left is already in the journal as that command.
        if name == 'look' then
          aimYaw, aimPitch = self.player.yaw, self.player.pitch
        end
      end
      return unpack(results)
    end
  end
  return journal
end
-- Remove the recording wrappers (the methods come from the metatable again).
function Journal.stop(g)
  local journal = sessions[g]
  if journal then
    Journal.flush(journal)
    observers[journal]()
    observers[journal] = nil
    recordings[journal], sessions[g] = nil, nil
  end
  for _, name in ipairs(Journal.commands) do
    g[name] = nil
  end
end
-- An 'aim' entry sets the aim the session had (a bot or a tool turned the
-- knight directly; journals before 0.25 recorded the mouse this way too);
-- a 'set' entry a field the application set between commands.
function Journal.replay(g, journal)
  local header = journal.header or {}
  if header.version then
    assert(header.version == Journal.version, 'unsupported journal format')
    assert(
      header.build == Journal.build,
      'journal belongs to another build: ' .. tostring(header.build)
    )
  end
  if header.initial then
    local difference = Integrity.difference(header.initial, Integrity.capture(g))
    assert(not difference, 'journal initial state differs: ' .. tostring(difference))
  end
  local origin = journal.header and journal.header.origin
  if origin then
    local now = Journal.origin(g)
    for key, value in pairs(origin) do
      assert(
        now[key] == value,
        'journal began at another point of its session ('
          .. key
          .. ' '
          .. tostring(value)
          .. ', here '
          .. tostring(now[key])
          .. '): replay needs a session in the same state'
      )
    end
  end
  local count = 0
  local detach = journal.receipts
    and observe(g, function(receipt)
      count = count + 1
      assert(
        journal.receipts[count] == receipt,
        'journal hit receipt '
          .. count
          .. ' differs: expected '
          .. tostring(journal.receipts[count])
          .. ', got '
          .. receipt
      )
    end)
  local ok, reason = pcall(function()
    for _, entry in ipairs(journal.entries) do
      if entry[1] == 'aim' then
        g.player.yaw, g.player.pitch = entry[2], entry[3]
      elseif entry[1] == 'set' then
        write(g, entry[2], entry[3])
      else
        local args = entry[2]
        g[entry[1]](g, unpack(args, 1, table.maxn(args)))
      end
    end
    assert(not journal.receipts or count == #journal.receipts, 'journal hit receipt count differs')
    if journal.final then
      local difference = Integrity.difference(journal.final, Integrity.capture(g))
      assert(not difference, 'journal final state differs: ' .. tostring(difference))
    end
  end)
  if detach then
    detach()
  end
  assert(ok, reason)
  return g
end
-- Export and stop both synchronize application-side mutations even when no
-- simulation tick follows the last input event. Repeated exports are idempotent.
function Journal.flush(journal)
  local sync = recordings[journal]
  if sync then
    sync()
  end
end
function Journal.encode(journal)
  Journal.flush(journal)
  return Serialize.encode(journal)
end
function Journal.decode(text)
  return Serialize.decode(text)
end
return Journal

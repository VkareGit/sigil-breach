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
local Observation = require('src.combat.observation')
local Values = require('src.session.journal_values')
local Build = require('src.core.build')
local Pools = require('src.session.world')
local finite = require('src.core.mathx').finite
local Roles = require('src.core.roles')
local Stats = require('src.session.stats')
local Execution = require('src.storage.execution')
local Modes = require('src.run.modes')
-- version: the journal's format; build: the game that recorded it (a replay
-- in another build is refused; core/build.lua, the same in every entry point).
-- Version 4 (plan v10 V5): a shot keeps only the bodies of its corridor
-- (combat/observation.lua) and unchanged body geometry is a reference.
-- Version 5 (plan v11 E3): actors. The header lists the knights the session
-- was built with (actors); commands may name the actor they are for (its
-- id, the last argument; an update's input.actors); actorJoin, actorLeave
-- and actorControl change the pool and the controlled knight. Every id is
-- checked before the replay touches the session. Journals of versions 4, 3
-- and 2 still replay (all their commands are the controlled knight's).
-- externalInputs (optional in older archives): ordered scalar facts read from
-- the profile and receipts of checkpoint writes. Replay consumes these without
-- touching disk. An old archive that needs an absent profile fact fails with
-- an explicit diagnostic; it never substitutes today's profile data.
local Journal = { version = 5, build = Build.version }
-- LuaJIT weak keys are not ephemerons: a strongly held callback that captures
-- its key (or the session) would keep abandoned sessions alive forever. The
-- active command wrappers own callbacks; these tables are lookup indexes only.
local recordings = setmetatable({}, { __mode = 'kv' })
local sessions = setmetatable({}, { __mode = 'k' })
local observers = setmetatable({}, { __mode = 'kv' })
local boundaries = setmetatable({}, { __mode = 'kv' })
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
  'actorJoin',
  'actorLeave',
  'actorControl',
}
-- Where a command names its actor (argument index; nil: the controlled one).
Journal.actorArgument = {
  look = 3,
  shoot = 2,
  cast = 2,
  reloadGun = 1,
  switchWeapon = 2,
  dash = 3,
  actorLeave = 1,
  actorControl = 1,
}
-- The ids of a session's knights, in pool order.
function Journal.actors(g)
  local ids = {}
  for i, knight in ipairs(Pools.of(g, 'knights')) do
    ids[i] = knight.id
  end
  return ids
end
-- Session fields the application sets directly, outside any command (a
-- pause, the help or the map, cleared intents). A change between two
-- commands is recorded as a 'set' entry before the next one, the way an
-- aim set by a tool is an 'aim' entry. Paths: 'field' or 'player.field'.
Journal.external = {
  'state',
  'map',
  'help',
  'player.fireBuffer',
  'player.fireCommand',
  'player.jumpBuffer',
  'player.observationGeneration',
  '_observationSession',
  '_observationGeneration',
}
-- The same fields of every other knight (a second input device buffers its
-- presses and forgets its observations outside any command): an 'actorSet'
-- entry { 'actorSet', id, field, value } before the next command (v5).
Journal.actorExternal = { 'fireBuffer', 'fireCommand', 'jumpBuffer', 'observationGeneration' }
local actorExternal = {}
for _, field in ipairs(Journal.actorExternal) do
  actorExternal[field] = true
end
-- Paths of earlier journals of this build's formats: the trigger buffer was
-- the session's until plan v11 E3 moved it to the actor.
Journal.renamed = { fireBuffer = 'player.fireBuffer', fireCommand = 'player.fireCommand' }
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
-- Where the journal began: a replay must start from the same place. A
-- session recorded from its construction matches a new one built from the
-- header; a session recorded later (a return to a paused run) does not, and
-- its replay says so instead of diverging silently.
function Journal.origin(g)
  local alive = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    alive = alive + (e.hp > 0 and 1 or 0)
  end
  return {
    elapsed = g.elapsed,
    kills = Stats.total(g, 'kills'),
    alive = alive,
    nextId = g.nextId,
    x = Roles.controlled(g).x,
    z = Roles.controlled(g).z,
  }
end
-- Each knight's observation generation (plan v11 E4), by id: a journal begun
-- after a change of control replays its observations against the same.
function Journal.actorGenerations(g)
  local out = {}
  for _, knight in ipairs(Pools.of(g, 'knights')) do
    out[knight.id] = knight.observationGeneration
  end
  return out
end
-- What rebuilds the session a journal starts from: its mode, map and origin.
function Journal.header(g)
  return {
    version = Journal.version,
    build = Journal.build,
    sourceFingerprint = Build.sourceFingerprint,
    provenance = Build.provenance,
    observationSession = Observation.session(g),
    observationGeneration = g._observationGeneration,
    actorGenerations = Journal.actorGenerations(g),
    mode = g.mode,
    options = Modes.act(g, 'construction'),
    map = g.world and g.world.mapId,
    origin = Journal.origin(g),
    initial = Integrity.capture(g),
    actors = Journal.actors(g),
  }
end
-- A fresh session as the journal's began (Game: session/game.lua).
function Journal.session(Game, journal)
  local header = journal.header or {}
  return Game.new(header.mode or 'classic', header.map, header.options)
end
-- pcall's status and results with their count: trailing nils survive.
local function outcome(...)
  return { n = select('#', ...), ... }
end
local function close(g, journal, reason)
  journal.final = Integrity.capture(g)
  journal.stopped = reason
  observers[journal]()
  observers[journal] = nil
  recordings[journal], sessions[g] = nil, nil
  boundaries[journal] = nil
  for _, name in ipairs(Journal.commands) do
    g[name] = nil
  end
end
function Journal.record(g, limits, onLimit)
  assert(not sessions[g], 'session is already being recorded')
  limits = limits or require('src.content.tuning').recording
  assert(
    finite(limits.maxBytes)
      and limits.maxBytes > 0
      and finite(limits.maxCommands)
      and limits.maxCommands > 0
      and limits.maxCommands % 1 == 0,
    'recording limits must be finite and positive; commands must be integral'
  )
  local journal = {
    entries = {},
    observations = {},
    bodies = {},
    receipts = {},
    externalInputs = {},
    header = Journal.header(g),
    budget = Observation.copy(limits),
    commands = 0,
  }
  journal.estimatedBytes = #Serialize.encode(journal)
  local function append(list, value)
    local index = #list + 1
    list[index] = value
    -- Account for the value, its numeric key and table punctuation. The final
    -- integrity snapshot is added only at a boundary, so this is an estimate.
    journal.estimatedBytes = journal.estimatedBytes
      + #Serialize.encode(value)
      + #tostring(index)
      + 4
  end
  local pack, used = Values.writer(journal, append, function(added)
    journal.estimatedBytes = journal.estimatedBytes + #Serialize.encode(added)
  end)
  local control = {}
  local detachReceipts = observe(g, function(receipt)
    append(journal.receipts, receipt)
  end)
  local detachInputs = Execution.observe(g, function(entry)
    append(journal.externalInputs, entry)
  end)
  local usage = g.bus:on('sim', 'ObservationUsed', function(event)
    used(event.observation)
  end)
  control.detach = function()
    detachReceipts()
    detachInputs()
    g.bus:off('sim', 'ObservationUsed', usage)
  end
  observers[journal] = control.detach
  local entries = journal.entries
  local depth = 0
  local pending = {}
  control.boundary = function(consume)
    if depth > 0 then
      pending[#pending + 1] = consume
    else
      consume(journal)
    end
  end
  boundaries[journal] = control.boundary
  local aimYaw, aimPitch
  local known, knownActors = {}, {}
  -- The knights other than the controlled one, in pool order.
  local function others()
    local out, controlled = {}, Roles.controlled(g)
    for _, knight in ipairs(Pools.of(g, 'knights')) do
      if knight ~= controlled then
        out[#out + 1] = knight
      end
    end
    return out
  end
  local function remember()
    for i, path in ipairs(Journal.external) do
      known[i] = read(g, path)
    end
    knownActors = {}
    for _, knight in ipairs(others()) do
      local values = {}
      for i, field in ipairs(Journal.actorExternal) do
        values[i] = knight[field]
      end
      knownActors[knight.id] = values
    end
  end
  local function sync()
    if depth > 0 then
      return false
    end
    local p = Roles.controlled(g)
    if p.yaw ~= aimYaw or p.pitch ~= aimPitch then
      aimYaw, aimPitch = p.yaw, p.pitch
      append(entries, { 'aim', p.yaw, p.pitch })
    end
    for i, path in ipairs(Journal.external) do
      local value = read(g, path)
      if value ~= known[i] then
        append(entries, { 'set', path, pack(value) })
      end
    end
    for _, knight in ipairs(others()) do
      local was = knownActors[knight.id] or {}
      for i, field in ipairs(Journal.actorExternal) do
        if knight[field] ~= was[i] then
          append(entries, { 'actorSet', knight.id, field, pack(knight[field]) })
        end
      end
    end
    remember()
    return true
  end
  local function limitReached()
    if
      journal.commands >= journal.budget.maxCommands
      or journal.estimatedBytes >= journal.budget.maxBytes
    then
      close(g, journal, 'limit')
      if onLimit then
        onLimit(journal)
      end
    end
  end
  remember()
  control.flush = function()
    if sync() then
      journal.final = Integrity.capture(g)
      limitReached()
    end
  end
  recordings[journal] = control.flush
  control.sync = sync
  sessions[g] = journal
  for _, name in ipairs(Journal.commands) do
    local method = assert(g[name], 'session has no command ' .. name)
    g[name] = function(self, ...)
      -- Only the player's own commands; a command issued by another one (an
      -- update that fires) is its consequence and replays by itself.
      if depth == 0 then
        -- A command for a knight the session does not hold is refused, not
        -- recorded: the game cannot issue it (a replay's preflight rejects it).
        local index = Journal.actorArgument[name]
        local who = index and select(index, ...)
        if who ~= nil and not (type(who) == 'string' and Pools.get(self, who)) then
          return false
        end
        control.sync()
        journal.final = nil
        local args = pack({ ... })
        append(entries, { name, args })
        journal.commands = journal.commands + 1
      end
      depth = depth + 1
      local results = outcome(pcall(method, self, ...))
      depth = depth - 1
      if not results[1] then
        -- A failed command is an incomplete transaction: the recording stops
        -- here (stopped = 'error') instead of going on behind a stuck depth,
        -- and the caller gets the same error.
        if sessions[self] == journal then
          close(self, journal, 'error')
        end
        error(results[2], 0)
      end
      if depth == 0 then
        remember()
        -- The aim a 'look' left is already in the journal as that command.
        if name == 'look' then
          aimYaw, aimPitch = Roles.controlled(self).yaw, Roles.controlled(self).pitch
        end
        -- All nested commands and their hit receipts are now complete. The
        -- boundary may exceed the estimate by one command; never truncate it.
        limitReached()
        local completed = pending
        pending = {}
        for _, consume in ipairs(completed) do
          consume(journal)
        end
      end
      return unpack(results, 2, results.n)
    end
  end
  return journal
end
-- Remove the recording wrappers (the methods come from the metatable again).
function Journal.stop(g)
  local journal = sessions[g]
  if journal then
    Journal.flush(journal)
    if sessions[g] then
      close(g, journal, 'manual')
    end
  end
end
-- Automatic telemetry can run inside a direct shot, before VolleyResolved.
-- Keep exports outside that transaction without dropping a single receipt.
function Journal.whenComplete(journal, consume)
  if boundaries[journal] then
    boundaries[journal](consume)
  else
    consume(journal)
  end
end
-- An 'aim' entry sets the aim the session had (a bot or a tool turned the
-- knight directly; journals before 0.25 recorded the mouse this way too);
-- a 'set' entry a field the application set between commands.
function Journal.replay(g, journal)
  assert(type(journal) == 'table', 'invalid journal')
  local header = journal.header or {}
  assert(type(header) == 'table', 'invalid journal header')
  if header.sourceFingerprint or Build.sourceFingerprint then
    assert(
      header.sourceFingerprint == Build.sourceFingerprint,
      'journal source fingerprint differs or this development launch is unverified'
    )
  end
  if header.version then
    assert(
      header.version == Journal.version
        or header.version == 4
        or header.version == 3
        or header.version == 2,
      'unsupported journal format'
    )
    assert(
      header.build == Journal.build,
      'journal belongs to another build: ' .. tostring(header.build)
    )
  end
  -- Preflight the entire structural contract before touching the destination.
  -- A later missing reference must not leave earlier valid commands applied.
  local permitted, external = {}, {}
  for _, name in ipairs(Journal.commands) do
    permitted[name] = true
  end
  for _, path in ipairs(Journal.external) do
    external[path] = true
  end
  for old in pairs(Journal.renamed) do
    external[old] = true
  end
  local pooled = header.version == 3 or header.version == 4 or header.version == 5
  local bodies = (header.version == 4 or header.version == 5) and journal.bodies or nil
  if header.version == 4 or header.version == 5 then
    assert(type(bodies) == 'table', 'invalid journal body pool')
  end
  local validate = Values.validator(pooled and journal.observations or nil, bodies)
  Execution.validate(journal.externalInputs)
  validate(header)
  validate(journal.final)
  validate(journal.receipts)
  assert(type(journal.entries) == 'table', 'invalid journal entries')
  local entryCount = 0
  for index, entry in pairs(journal.entries) do
    assert(
      finite(index) and index > 0 and index % 1 == 0 and type(entry) == 'table',
      'invalid journal entry'
    )
    entryCount = entryCount + 1
    validate(entry)
    if entry[1] == 'aim' then
      assert(finite(entry[2]) and finite(entry[3]), 'invalid journal aim')
    elseif entry[1] == 'set' then
      assert(external[entry[2]], 'journal cannot set ' .. tostring(entry[2]))
    elseif entry[1] == 'actorSet' then
      assert(header.version == 5, 'journal actorSet needs format 5')
      assert(
        type(entry[2]) == 'string' and actorExternal[entry[3]],
        'journal cannot set ' .. tostring(entry[3]) .. ' of an actor'
      )
    else
      assert(
        permitted[entry[1]] and type(entry[2]) == 'table',
        'unknown or invalid journal command ' .. tostring(entry[1])
      )
      for argument in pairs(entry[2]) do
        assert(
          finite(argument) and argument > 0 and argument % 1 == 0,
          'invalid journal argument index'
        )
      end
    end
  end
  assert(entryCount == #journal.entries, 'sparse journal entries')
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
  -- Actors (version 5): every id a command names is known from the header
  -- (the knights the session was built with, checked against it) or from its
  -- actorJoin, and present until its actorLeave. A dead knight that is still
  -- present takes commands without effect. Checked before any mutation.
  if header.version == 5 then
    assert(type(header.actors) == 'table', 'journal names no actors')
    local here = Journal.actors(g)
    assert(#here == #header.actors, 'journal actors differ from the session')
    local known, present = {}, {}
    for i, id in ipairs(header.actors) do
      assert(here[i] == id, 'journal actors differ from the session')
      known[id], present[id] = true, true
    end
    local function plain(value)
      return pooled and Values.expand(value, journal.observations, bodies)
        or Observation.copy(value)
    end
    local function named(id, what)
      assert(
        type(id) == 'string' and known[id] and present[id],
        'journal ' .. what .. ' names an unknown or absent actor: ' .. tostring(id)
      )
    end
    for _, entry in ipairs(journal.entries) do
      local name = entry[1]
      if name == 'actorSet' then
        named(entry[2], name)
      elseif name ~= 'aim' and name ~= 'set' then
        local args = plain(entry[2])
        local index = Journal.actorArgument[name]
        if index and args[index] ~= nil then
          named(args[index], name)
        end
        if name == 'update' and type(args[2]) == 'table' and args[2].actors ~= nil then
          assert(type(args[2].actors) == 'table', 'journal update actors')
          for id in pairs(args[2].actors) do
            named(id, 'update')
          end
        elseif name == 'actorJoin' then
          local knight, reason = Pools.knightFromRecord(g, args[1])
          assert(knight, 'journal actorJoin refused: ' .. tostring(reason))
          assert(not known[knight.id], 'journal actorJoin reuses id ' .. knight.id)
          known[knight.id], present[knight.id] = true, true
        elseif name == 'actorLeave' then
          present[args[1]] = nil
        end
      end
    end
  end
  -- Only a structurally valid, matching archive can enter this namespace.
  -- Runtime divergence is diagnostic: replay should use a disposable session.
  g._observationSession = header.observationSession
  g._observationGeneration = header.observationGeneration
  for id, generation in
    pairs(type(header.actorGenerations) == 'table' and header.actorGenerations or {})
  do
    local knight = Pools.get(g, id)
    if knight and type(generation) == 'number' then
      knight.observationGeneration = generation
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
  local finishReplay, inputsConsumed = Execution.beginReplay(g, journal.externalInputs)
  local ok, reason = pcall(function()
    local function expand(value)
      return pooled and Values.expand(value, journal.observations, bodies)
        or Observation.copy(value)
    end
    for _, entry in ipairs(journal.entries) do
      if entry[1] == 'aim' then
        assert(
          require('src.core.mathx').finite(entry[2]) and require('src.core.mathx').finite(entry[3]),
          'invalid journal aim'
        )
        Roles.controlled(g).yaw, Roles.controlled(g).pitch = entry[2], entry[3]
      elseif entry[1] == 'set' then
        assert(external[entry[2]], 'journal cannot set ' .. tostring(entry[2]))
        write(g, Journal.renamed[entry[2]] or entry[2], expand(entry[3]))
      elseif entry[1] == 'actorSet' then
        Pools.get(g, entry[2])[entry[3]] = expand(entry[4])
      else
        assert(permitted[entry[1]], 'unknown journal command ' .. tostring(entry[1]))
        local args = expand(entry[2])
        g[entry[1]](g, unpack(args, 1, table.maxn(args)))
      end
    end
    assert(not journal.receipts or count == #journal.receipts, 'journal hit receipt count differs')
    inputsConsumed()
    if journal.final then
      local difference = Integrity.difference(journal.final, Integrity.capture(g))
      assert(not difference, 'journal final state differs: ' .. tostring(difference))
    end
  end)
  finishReplay()
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

-- The observable state projection (plan v11 E0): what a session shows of its
-- actors, its mode and its world, by NAME, never by the path of a field. A
-- refactor that moves a field (the weapon in hand from the session to the
-- actor, the guardian from the session to the encounter) changes only how
-- this module reads it; the names and the values it writes stay, so the 0.33
-- reference (tests/fixtures/v033/) proves equivalence across the move.
--   periodic   every 30 steps: the whole projection, written as the names
--              whose value changed since the last sample (a delta)
--   events     at the event, only its scope: a shot (shooter and its
--              sequence counter), a volley (contacts, damage, seeds), the
--              ammunition moved by a reload, a reload stopped, a death (the
--              body, its cause, the killer's counters, healing, reward)
--   save/load  the whole projection before a save and after its load
-- Numbers are written with 17 significant digits: the same double, the same
-- text. The reference is written once from 0.33 and never regenerated.
local Weapons = require('src.content.weapons')
local Roles = require('src.core.roles')
local World = require('src.world.arena')
local Encounter = require('src.session.encounter')
local Projection = {}
local format, floor = string.format, math.floor
Projection.every = 30
local function value(v)
  if type(v) == 'number' then
    if v == floor(v) and v > -2 ^ 53 and v < 2 ^ 53 then
      return format('%d', v)
    end
    return format('%.17g', v)
  end
  if v == nil then
    return 'nil'
  end
  return tostring(v)
end
Projection.value = value
local function put(out, name, v)
  out[#out + 1] = name .. '=' .. value(v)
end
-- Every creature of the session in id order: the living pool and the remains.
local function bodies(g)
  local list = {}
  for _, e in ipairs(g.enemies or {}) do
    list[#list + 1] = e
  end
  for _, e in ipairs(g.remains or {}) do
    list[#list + 1] = e
  end
  table.sort(list, function(a, b)
    return a.id < b.id
  end)
  return list
end
local function sortedKeys(t)
  local keys = {}
  for k in pairs(t or {}) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end
-- The actor's state. In 0.33 the weapon in hand, its clocks and the counters
-- live on the session and belong to the controlled knight.
function Projection.actor(g, knight, out)
  local name = 'actor.' .. tostring(knight.id)
  put(out, name .. '.x', knight.x)
  put(out, name .. '.z', knight.z)
  put(out, name .. '.yaw', knight.yaw)
  put(out, name .. '.pitch', knight.pitch)
  put(out, name .. '.jump', knight.jump)
  put(out, name .. '.hp', knight.hp)
  put(out, name .. '.armor', knight.armor)
  for _, id in ipairs(sortedKeys(knight.arsenal)) do
    local w = knight.arsenal[id]
    put(out, name .. '.ammo.' .. id .. '.mag', w.mag)
    put(out, name .. '.ammo.' .. id .. '.reserve', w.reserve)
    put(out, name .. '.ammo.' .. id .. '.open', w.open == true)
  end
  if knight ~= Roles.controlled(g) then
    return out
  end
  -- Plan v11 E3a: the hands, the reload, the shots and the shot sequence are
  -- the actor's (same names, same values).
  put(out, name .. '.weapon', knight.weapon and Weapons.idAt(g, knight.weapon) or nil)
  put(out, name .. '.slot', knight.weapon)
  put(out, name .. '.cooldown', knight.cooldown)
  put(out, name .. '.reload.time', knight.reload)
  put(out, name .. '.reload.weapon', knight.reloadWeapon)
  put(out, name .. '.reload.stage', knight.reloadStage)
  put(out, name .. '.sequence', knight.shotSequence)
  put(out, name .. '.stats.shots', knight.shots)
  put(out, name .. '.stats.hits', knight.hits)
  put(out, name .. '.stats.kills', g.kills)
  put(out, name .. '.stats.score', g.score)
  put(out, name .. '.stats.combo', g.combo)
  put(out, name .. '.stats.comboTimer', g.comboTimer)
  put(out, name .. '.stats.damageTaken', g.damageTaken)
  return out
end
-- The mode's state: its phase and progress, the guardian and the secret.
function Projection.mode(g, out)
  put(out, 'mode.id', g.mode)
  put(out, 'mode.state', g.state)
  local run = g.run
  put(out, 'mode.phase', run and run.phase)
  put(out, 'mode.wave', run and run.wave)
  put(out, 'mode.wallet', run and run.wallet)
  put(out, 'mode.glyph', run and run.glyph)
  put(out, 'mode.score', g.score)
  -- Plan v11 E2: the seals are the world's broken seals, the guardian the
  -- encounter's record, the secret the world's (same names, same values).
  put(out, 'mode.seals', World.activeSeals(g.world))
  put(out, 'mode.guardian.spawned', Encounter.guardianSpawned(g))
  put(out, 'mode.guardian.dead', Encounter.guardianDead(g))
  put(out, 'mode.secret', g.world.secretFound)
  return out
end
-- The world: every body in id order with its health and place.
function Projection.world(g, out)
  for _, e in ipairs(bodies(g)) do
    local name = 'body.' .. e.id
    put(out, name .. '.kind', e.kind)
    put(out, name .. '.variant', e.variant)
    put(out, name .. '.hp', e.hp)
    put(out, name .. '.x', e.x)
    put(out, name .. '.z', e.z)
  end
  return out
end
-- The whole projection: name=value lines in a fixed order.
function Projection.lines(g)
  local out = {}
  for _, knight in ipairs(g.knights or { g.player }) do
    Projection.actor(g, knight, out)
  end
  Projection.mode(g, out)
  Projection.world(g, out)
  return out
end
local function controlled(g)
  return Roles.controlled(g)
end
-- Event scopes ---------------------------------------------------------------
local function shot(g, event, out)
  local p = controlled(g)
  local name = 'actor.' .. tostring(p.id)
  put(out, name .. '.x', p.x)
  put(out, name .. '.z', p.z)
  put(out, name .. '.yaw', event.command and event.command.yaw or p.yaw)
  put(out, name .. '.pitch', event.command and event.command.pitch or p.pitch)
  put(out, name .. '.weapon', Weapons.idAt(g, p.weapon))
  local w = Weapons.state(g)
  put(out, name .. '.mag', w and w.mag)
  put(out, name .. '.cooldown', p.cooldown)
  put(out, name .. '.sequence', p.shotSequence)
  put(out, name .. '.observed', event.command and event.command.observation ~= nil or false)
  return out
end
local function volley(g, event, out)
  local report = event.report
  put(out, 'shot.sequence', report.shotSerial or g.shotSerial)
  put(out, 'shot.slot', report.weapon)
  for i, ray in ipairs(report.rays or {}) do
    local name = 'ray.' .. i
    put(out, name .. '.seed', ray.seed)
    put(out, name .. '.target', ray.target)
    put(out, name .. '.part', ray.part)
    put(out, name .. '.distance', ray.distance)
  end
  for i, c in ipairs(report.contacts or {}) do
    local name = 'contact.' .. i
    put(out, name .. '.target', c.targetId)
    put(out, name .. '.zone', c.zone)
    put(out, name .. '.damage', c.damage)
    put(out, name .. '.retained', c.retained)
    put(out, name .. '.kind', c.kind)
  end
  for i, d in ipairs(report.hitTargets or {}) do
    local name = 'hit.' .. i
    put(out, name .. '.target', d.id)
    put(out, name .. '.damage', d.damage)
    put(out, name .. '.health', d.healthDamage)
    put(out, name .. '.seed', d.seed)
    put(out, name .. '.killed', d.killed)
  end
  return out
end
local function reload(g, event, out)
  local p = controlled(g)
  local name = 'actor.' .. tostring(p.id)
  put(out, 'reload.stage', event.stage)
  put(out, 'reload.mechanism', event.mechanism)
  put(out, 'reload.interrupted', event.interrupted == true)
  put(out, name .. '.reload.time', p.reload)
  put(out, name .. '.reload.stage', p.reloadStage)
  local slot = p.reloadWeapon or p.weapon
  local id = Weapons.idAt(g, slot)
  local w = p.arsenal[id]
  put(out, name .. '.reload.weapon', id)
  put(out, name .. '.ammo.' .. id .. '.mag', w and w.mag)
  put(out, name .. '.ammo.' .. id .. '.reserve', w and w.reserve)
  return out
end
-- The souls a death left on the floor (the expedition's reward pickup).
local function souls(g, enemy)
  local total = 0
  for _, a in ipairs(g.pickups or {}) do
    if a.kind == 'soul' and enemy.rewardId and a.rewardId == enemy.rewardId then
      total = total + (a.amount or 0)
    end
  end
  return total
end
function Projection.death(g, event, out)
  local e, p = event.enemy, controlled(g)
  local name = 'actor.' .. tostring(p.id)
  put(out, 'body.id', e.id)
  put(out, 'body.kind', e.kind)
  put(out, 'body.hp', e.hp)
  put(out, 'body.x', e.x)
  put(out, 'body.z', e.z)
  put(out, 'death.source', event.source)
  put(out, 'death.offBalance', event.offBalance == true)
  for _, key in ipairs(sortedKeys(event.causes)) do
    put(out, 'death.cause.' .. tostring(key), event.causes[key])
  end
  put(out, 'death.heal', event.heal)
  put(out, 'death.healed', event.healed)
  put(out, 'death.reward', event.reward)
  put(out, 'death.souls', souls(g, e))
  put(out, name .. '.hp', p.hp)
  put(out, name .. '.stats.kills', g.kills)
  put(out, name .. '.stats.score', g.score)
  put(out, name .. '.stats.combo', g.combo)
  put(out, 'mode.wallet', g.run and g.run.wallet)
  return out
end
-- The recorder ----------------------------------------------------------------
-- rate: steps per second of the run (a reload ended before its time is told
-- from one that ran out). observe(g, step) after every step, like the golden
-- recorder; event(g, kind, lines) adds a record of the caller's own (a save,
-- a load). r.text() is the reference text; r.kills the attribution entries.
function Projection.recorder(rate)
  local r = { records = {}, kills = {}, count = 0 }
  local lines = r.records
  local attached, step, previous = nil, 0, {}
  local reloadLeft, reloadStage, reloadWeapon = 0, 0, nil
  local function header(kind)
    lines[#lines + 1] = 'E ' .. step + 1 .. ' ' .. kind
    r.count = r.count + 1
  end
  local function record(kind, out)
    header(kind)
    for _, line in ipairs(out) do
      lines[#lines + 1] = line
    end
  end
  function r.event(_, kind, out)
    record(kind, out)
  end
  local function attach(g)
    attached = g
    previous = {}
    local bus = g.bus
    bus:on('sim', 'ShotFired', function(event)
      record('shot', shot(g, event, {}))
    end, 99)
    bus:on('sim', 'VolleyResolved', function(event)
      record('volley', volley(g, event, {}))
    end, 99)
    bus:on('sim', 'ReloadStage', function(event)
      record('reload', reload(g, event, {}))
    end, 99)
    bus:on('sim', 'EnemyKilled', function(event)
      record('death', Projection.death(g, event, {}))
      r.kills[#r.kills + 1] = {
        step = step + 1,
        id = event.enemy.id,
        kind = event.enemy.kind,
        source = event.source,
        offBalance = event.offBalance == true,
        healed = event.healed or 0,
        souls = souls(g, event.enemy),
        reward = event.reward or 0,
      }
    end, 99)
  end
  function r.observe(g, n)
    if attached ~= g then
      attach(g)
    end
    step = n
    -- A reload that ended with time left was stopped (a trigger pull, the
    -- shrine): no event tells it, so the step after shows it.
    local actor = controlled(g)
    local left = actor.reload or 0
    if reloadLeft > 0 and left == 0 and reloadLeft > 1 / rate + 1e-9 then
      local p = controlled(g)
      local id = Weapons.idAt(g, reloadWeapon or actor.weapon)
      local w = p.arsenal[id]
      step = n - 1
      record('reload-stop', {
        'reload.left=' .. value(reloadLeft),
        'reload.stage=' .. value(reloadStage),
        'reload.weapon=' .. value(id),
        'actor.' .. tostring(p.id) .. '.ammo.' .. id .. '.mag=' .. value(w and w.mag),
        'actor.' .. tostring(p.id) .. '.ammo.' .. id .. '.reserve=' .. value(w and w.reserve),
      })
      step = n
    end
    reloadLeft, reloadStage, reloadWeapon = left, actor.reloadStage or 0, actor.reloadWeapon
    if n % Projection.every ~= 0 then
      return
    end
    local now, seen = {}, {}
    local delta = {}
    for _, line in ipairs(Projection.lines(g)) do
      local name = line:match('^([^=]+)=')
      now[name] = line
      seen[#seen + 1] = name
      if previous[name] ~= line then
        delta[#delta + 1] = line
      end
    end
    for name in pairs(previous) do
      if not now[name] then
        delta[#delta + 1] = name .. '-'
      end
    end
    table.sort(delta)
    lines[#lines + 1] = 'P ' .. n
    for _, line in ipairs(delta) do
      lines[#lines + 1] = line
    end
    previous = now
  end
  -- The full projection as an event record (a save, a load, a fixture).
  function r.full(g, kind)
    record(kind, Projection.lines(g))
  end
  function r.text()
    return table.concat(lines, '\n') .. '\n'
  end
  return r
end
-- The first difference of two projection texts: the record (step and kind)
-- and the line where they part, or nil when they are equal.
function Projection.compare(reference, current)
  if reference == current then
    return nil
  end
  local function split(text)
    local out = {}
    for line in text:gmatch('([^\n]*)\n') do
      out[#out + 1] = line
    end
    return out
  end
  local a, b = split(reference), split(current)
  local record = '(start)'
  for i = 1, math.max(#a, #b) do
    local x, y = a[i], b[i]
    if x and (x:sub(1, 2) == 'P ' or x:sub(1, 2) == 'E ') then
      if x == y then
        record = x
      end
    end
    if x ~= y then
      return string.format(
        'after record %s, line %d: reference %s, now %s',
        record,
        i,
        tostring(x),
        tostring(y)
      )
    end
  end
  return 'texts differ in their ends'
end
return Projection

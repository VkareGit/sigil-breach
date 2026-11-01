-- Plan v10 V5: recording big fights. A shot's command keeps only the bodies
-- of its corridor; the resolver meets exactly what it met with the whole
-- view, a body outside the corridor cannot be hit, unchanged geometry is a
-- reference, an observation no shot used keeps only its header, and the
-- journal replays bit for bit (version 3 journals too).
local Fixtures = require('tests.support.fixtures')
local Observation = require('src.combat.observation')
local B = require('src.combat.ballistics')
local Weapons = require('src.content.weapons')
local Journal = require('src.session.journal')
local Values = require('src.session.journal_values')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Tests = {}
local function generator(seed)
  local state = seed
  return function()
    state = (state * 1103515245 + 12345) % 2147483648
    return state / 2147483648
  end
end
-- Every ray any weapon the knight carries can fire, at its widest spread.
local function rays(g, yaw, pitch, each)
  for _, id in ipairs(Roles.controlled(g).loadout) do
    local def = Weapons.get(id)
    -- The weapon's spread alone and under each of its glyphs.
    local base = def.fire.spread or 1
    local scales = { base }
    for _, mod in pairs(def.glyphs or {}) do
      scales[#scales + 1] = base * (mod.spread or 1)
    end
    local pellets = def.fire.pellets or 1
    for serial = 0, 1 do
      for i = 1, pellets do
        local ox, oy = 0, 0
        if pellets > 1 then
          ox, oy = B.pellet(i, serial, pellets)
        end
        for _, scale in ipairs(scales) do
          each(def, B.spreadDirection(yaw, pitch, ox * scale, oy * scale))
        end
      end
    end
  end
end
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'fight recording: ', 'fight recording: ')
  local rand = generator(5051)
  local same, fewer, outside, total, kept = true, true, true, 0, 0
  for _ = 1, 12 do
    local g = Game.new('floor')
    g.ephemeral, g.state = true, 'playing'
    local p = Roles.controlled(g)
    p.x, p.z = 10 + rand() * 12, 13 + rand() * 12
    p.yaw, p.pitch = rand() * math.pi * 2, (rand() - 0.5) * 0.5
    local kinds = { 'imp', 'armored', 'stolas', 'boss' }
    for i = 1, 40 do
      local e = g:spawn(kinds[i % #kinds + 1], 4 + rand() * 24, 4 + rand() * 24)
      e.spawnAge = 1
    end
    local shown = Observation.capture(g)
    local command = Observation.command(shown, g)
    local all = Observation.prepare(g, shown)
    local corridor = Observation.prepare(g, command.observation)
    total, kept = total + #shown.bodies, kept + #command.observation.bodies
    local inCorridor = {}
    for _, body in ipairs(command.observation.bodies) do
      inCorridor[body.id] = true
    end
    rays(g, command.yaw, command.pitch, function(def, dx, dy, dz)
      local e1, d1, _, _, _, k1, _, p1 = B.traceVector(g, dx, dy, dz, def.range, all, shown.origin)
      local e2, d2, _, _, _, k2, _, p2 =
        B.traceVector(g, dx, dy, dz, def.range, corridor, shown.origin)
      same = same and (e1 and e1.id) == (e2 and e2.id) and d1 == d2 and k1 == k2 and p1 == p2
      -- Through every body (penetration): none outside the corridor.
      for _, h in ipairs(B.traceAll(g, dx, dy, dz, def.range, all, shown.origin)) do
        outside = outside and inCorridor[h.enemy.id] == true
      end
    end)
  end
  fewer = kept < total
  check(
    'a shot meets the same body, part and distance with its corridor as with the whole view (12 scenes)',
    same
  )
  check(
    'no ray of any carried weapon reaches a body outside the corridor ('
      .. kept
      .. ' of '
      .. total
      .. ' bodies kept)',
    outside and fewer
  )

  -- A replayed shot cannot hit a body outside its corridor even when the
  -- body stands in the line at replay time.
  local g = Game.new('floor')
  g.ephemeral, g.state = true, 'playing'
  local p = Roles.controlled(g)
  p.x, p.z, p.yaw, p.pitch = 16, 24, math.pi, 0
  Pools.clear(g, 'enemies')
  local beside = g:spawn('imp', 23, 24)
  beside.spawnAge = 1
  local shown = Observation.capture(g)
  local command = Observation.command(shown, g)
  local listed = false
  for _, body in ipairs(command.observation.bodies) do
    listed = listed or body.id == beside.id
  end
  beside.x, beside.z = 16, 21
  local prepared = Observation.prepare(g, command.observation)
  local hit = B.traceVector(g, 0, 0, -1, 24, prepared, command.observation.origin)
  check(
    'a body outside the corridor is not in the command and a replayed shot cannot hit it',
    not listed and hit == nil
  )

  -- The journal: unchanged bodies are references, unused views headers only.
  local function fresh()
    local s = Game.new('floor')
    s.ephemeral, s.state = true, 'playing'
    local k = Roles.controlled(s)
    -- Beyond the shotgun's reach, within the revolver's: in every corridor,
    -- never struck by the gun in hand.
    k.x, k.z, k.yaw = 16, 28, math.pi
    Pools.clear(s, 'enemies')
    for i = 1, 6 do
      local e = s:spawn('imp', 13 + i, 3)
      -- Held still in one pose: its geometry does not change between views.
      e.spawnAge, e.dummy, e.previewFrame = 1, true, 1
    end
    return s
  end
  g = fresh()
  local journal = Journal.record(g)
  for frame = 1, 120 do
    local view = Observation.capture(g)
    for _ = 1, 2 do
      g:update(1 / 120, { shoot = frame % 30 < 20, fireCommand = Observation.command(view, g) })
    end
  end
  Journal.stop(g)
  local Serialize = require('src.core.serialize')
  local headers, whole = 0, 0
  for _, observation in ipairs(journal.observations) do
    headers = headers + (#observation.bodies == 0 and 1 or 0)
    for _, ref in ipairs(observation.bodies) do
      whole = whole + #Serialize.encode(Values.body(journal.bodies, ref._journalBody))
    end
  end
  local stored = #Serialize.encode(journal.bodies)
  check(
    'body geometry is kept as references and differences ('
      .. stored
      .. ' bytes for '
      .. whole
      .. ' bytes of whole geometry)',
    stored < whole
  )
  check(
    'a view no shot used keeps only its header ('
      .. headers
      .. ' of '
      .. #journal.observations
      .. ')',
    headers > 0 and headers < #journal.observations
  )
  local loaded = Journal.decode(Journal.encode(journal))
  local ok, problem = pcall(Journal.replay, fresh(), loaded)
  check('a version 4 journal replays its fight bit for bit', ok)
  if not ok then
    lines[#lines + 1] = 'fight recording: ' .. tostring(problem)
  end
  -- The same fight as a version 3 journal (every observation whole).
  local older = Observation.copy(loaded)
  older.header.version = 3
  older.bodies = nil
  for i in ipairs(older.observations) do
    local whole = Values.expand({ _journalObservation = i }, loaded.observations, loaded.bodies)
    older.observations[i] = whole
  end
  check('a version 3 journal still replays', pcall(Journal.replay, fresh(), older))
  return lines
end
return Tests

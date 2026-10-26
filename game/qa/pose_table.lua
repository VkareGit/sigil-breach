-- The pose table (plan v11 E0): the frame and the placement every creature
-- shows over a grid of its states (AI state x phase x front/back x motion x
-- time), with the points just before, exactly on and just after every
-- boundary a pose is chosen by (+-1e-9 in the unit of that boundary). The
-- grid holds the boundaries of both painted layouts for every creature, so a
-- creature keeps its answers whatever its sheet names. Dead bodies add the
-- settling rule (Corpse.settled, Corpse.shields) and the landing moment.
-- Written from 0.33 as the reference E1's named poses must reproduce.
local Archetypes = require('src.content.enemies')
local Anim = require('src.enemies.animation')
local Corpse = require('src.enemies.corpse')
local Idle = require('src.enemies.idle')
local T = {}
local format = string.format
local EPS = 1e-9
local ID = 7
local function num(v)
  if type(v) ~= 'number' then
    return tostring(v)
  end
  return format('%.17g', v)
end
-- b - eps, b, b + eps (the eps scaled to the boundary's unit).
local function around(list, unit)
  local out = {}
  for _, b in ipairs(list) do
    out[#out + 1] = b - EPS * (unit or 1)
    out[#out + 1] = b
    out[#out + 1] = b + EPS * (unit or 1)
  end
  return out
end
-- A creature body in a known base state; fields overrides it.
local function body(kind, fields)
  local def = Archetypes.get(kind)
  local e = {
    id = ID,
    kind = kind,
    hp = def.body.hp,
    maxHp = def.body.hp,
    x = 0,
    z = 0,
    ai = 'idle',
    phase = 0,
    stun = 0,
    walk = 0,
    walkSpeed = 0,
    facing = 0,
    awake = false,
    memory = 0,
    flinch = 0,
    flinchLean = 0,
    spawnAge = 1,
    evadeTime = 0,
    conditions = {},
  }
  for k, v in pairs(fields or {}) do
    e[k] = v
  end
  return e
end
-- The session a pose is read in: its clock and the viewer at an angle
-- (radians from the body's facing) five metres away.
local function session(time, e, angle)
  local a = (e.facing or 0) + (angle or 0)
  return { time = time or 0, player = { x = e.x + math.sin(a) * 5, z = e.z + math.cos(a) * 5 } }
end
-- The angle of the back-frame rule: cos(angle) < -0.25.
local REAR = math.acos(-0.25)
local VIEWS = { front = 0, rear = math.pi, edgeIn = REAR + EPS, edge = REAR, edgeOut = REAR - EPS }
local VIEW_ORDER = { 'front', 'rear', 'edgeIn', 'edge', 'edgeOut' }
local function row(out, kind, label, g, e)
  local frame, bounce, lean, sx, sy = Anim.pose(g, e)
  local line = kind
    .. '|'
    .. label
    .. '|'
    .. num(frame)
    .. ','
    .. num(bounce)
    .. ','
    .. num(lean)
    .. ','
    .. num(sx)
    .. ','
    .. num(sy)
  if e.hp <= 0 then
    line = line
      .. ',settled='
      .. tostring(Corpse.settled(e))
      .. ',shields='
      .. tostring(Corpse.shields(e))
  end
  out[#out + 1] = line
end
-- An action of 50 s, so the phase is an exact fraction of whole seconds.
local ACTION = 50
local function attacks(kind)
  local ids = { false }
  for _, a in ipairs(Archetypes.get(kind).attacks or {}) do
    ids[#ids + 1] = a.id
  end
  return ids
end
local function actions(out, kind)
  local spec = { id = 'table', kind = 'table', duration = ACTION }
  for _, t in ipairs(around({ 0, 0.22, 0.42, 0.6, 1 })) do
    if t >= 0 and t <= 1 then
      local e = body(kind, {
        ai = 'windup',
        windupDuration = ACTION,
        windup = ACTION - ACTION * t,
        attackSpec = spec,
      })
      row(out, kind, 'windup t=' .. num(t), session(0, e), e)
    end
  end
  for _, t in ipairs({ 0.1, 0.3, 0.5, 0.8 }) do
    local e = body(kind, {
      ai = 'windup',
      windupDuration = ACTION,
      windup = ACTION - ACTION * t,
      attackSpec = spec,
    })
    row(out, kind, 'windup t=' .. num(t), session(0, e), e)
  end
  for _, id in ipairs(attacks(kind)) do
    local named = { id = id or 'table', kind = 'table', duration = ACTION }
    for _, t in ipairs(around({ 0, 0.25, 0.5, 0.75, 1 })) do
      if t >= 0 and t <= 1 then
        local e = body(kind, {
          ai = 'strike',
          phase = ACTION * t,
          attackSpec = named,
          attackKind = id or nil,
        })
        row(out, kind, 'strike ' .. tostring(id) .. ' t=' .. num(t), session(0, e), e)
      end
    end
  end
  for _, t in ipairs(around({ 0, 0.5, 1 })) do
    if t >= 0 and t <= 1 then
      local e = body(kind, {
        ai = 'recover',
        phase = ACTION * t,
        recover = ACTION - ACTION * t,
        attackSpec = spec,
      })
      row(out, kind, 'recover t=' .. num(t), session(0, e), e)
    end
  end
end
local function pain(out, kind)
  for _, heavy in ipairs({ false, true }) do
    for _, stun in ipairs({ 0, 0.1 }) do
      for _, phase in ipairs(around({ 0, 0.05, 0.12, 0.2, 0.3 })) do
        if phase >= 0 then
          local e = body(kind, { ai = 'hurt', phase = phase, stun = stun, heavyStagger = heavy })
          row(
            out,
            kind,
            format('hurt heavy=%s stun=%s phase=%s', tostring(heavy), num(stun), num(phase)),
            session(0, e),
            e
          )
        end
      end
    end
  end
  local exposed = body(kind, { ai = 'idle', stun = 0.1, conditions = { exposed = 1 } })
  row(out, kind, 'falter exposed', session(0, exposed), exposed)
  -- Knocked down: the time since the fall (total - stun) and the time left.
  local total = 0.5
  for _, t in ipairs(around({ 0, 0.03, 0.06, 0.08, 0.1, 0.12, 0.2 })) do
    if t >= 0 then
      local e = body(kind, { ai = 'hurt', phase = 1, knockedDown = true, knockTime = total })
      e.stun = total - t
      row(out, kind, 'knockdown since=' .. num(t), session(0, e), e)
    end
  end
  for _, left in ipairs(around({ 0.03, 0.07, 0.1, 0.12, 0.15, 0.2 })) do
    local e = body(kind, { ai = 'hurt', phase = 1, knockedDown = true, knockTime = total })
    e.stun = left
    row(out, kind, 'knockdown left=' .. num(left), session(0, e), e)
  end
  local short = body(kind, { ai = 'hurt', phase = 1, knockedDown = true, stun = 0.05 })
  row(out, kind, 'knockdown untimed', session(0, short), short)
end
local function walking(out, kind)
  for _, rate in ipairs({ 4.2, 3.4 }) do
    for k = 0, 13 do
      for _, step in ipairs(around({ k })) do
        if step >= 0 then
          for _, view in ipairs(VIEW_ORDER) do
            local e = body(kind, { ai = 'move', walkSpeed = 1, walk = step / rate, facing = 0.4 })
            row(
              out,
              kind,
              format('walk rate=%s step=%s view=%s', num(rate), num(step), view),
              session(0, e, VIEWS[view]),
              e
            )
          end
        end
      end
    end
  end
  for _, speed in ipairs(around({ 0.1 })) do
    local e = body(kind, { ai = 'move', walkSpeed = speed, walk = 0.3 })
    row(out, kind, 'walk speed=' .. num(speed), session(0, e), e)
  end
end
local function quiet(out, kind)
  local entry = Idle.entries[Idle.kind(body(kind))]
  local bounds, sum = { 0 }, 0
  for _, w in ipairs(entry.weights) do
    sum = sum + w
    bounds[#bounds + 1] = sum
  end
  local offset = ID * 0.3819660112501051
  for _, b in ipairs(bounds) do
    local base = ((b - offset) % 1) * entry.period
    for _, time in ipairs(around({ base }, entry.period)) do
      if time >= 0 then
        local e = body(kind)
        row(out, kind, 'quiet time=' .. num(time), session(time, e), e)
      end
    end
  end
  for _, awake in ipairs({ false, true }) do
    for _, memory in ipairs({ 0, 1 }) do
      for _, view in ipairs(VIEW_ORDER) do
        local e = body(kind, { awake = awake, memory = memory, facing = -0.7 })
        row(
          out,
          kind,
          format('watch awake=%s memory=%s view=%s', tostring(awake), num(memory), view),
          session(1.3, e, VIEWS[view]),
          e
        )
      end
    end
  end
  -- The hovering flight: seven frames a second of world time.
  for k = 0, 13 do
    for _, time in ipairs(around({ k / 7 - ID * 0.17 + 2 }, 1 / 7)) do
      for _, view in ipairs({ 'front', 'rear' }) do
        local e = body(kind, { ai = 'move', walkSpeed = 1, walk = 0.1 })
        row(
          out,
          kind,
          format('flight time=%s view=%s', num(time), view),
          session(time, e, VIEWS[view]),
          e
        )
      end
    end
  end
end
-- The painted collapses of 0.33 (6x4: frames 14-18 at 0.11 s; 4x4: 10-12 at
-- 0.14 s; the shortest settling 0.33 s): the grid's times, fixed here so the
-- grid never follows a later change of the data it checks.
local COLLAPSES =
  { { first = 14, last = 18, frame = 0.11 }, { first = 10, last = 12, frame = 0.14 } }
local SETTLE = 0.33
local function dead(out, kind)
  local frames, settles = {}, {}
  for _, layout in ipairs(COLLAPSES) do
    for n = 0, layout.last - layout.first + 2 do
      frames[#frames + 1] = n * layout.frame
    end
    settles[#settles + 1] = (layout.last - layout.first) * layout.frame
  end
  settles[#settles + 1] = SETTLE
  for _, list in ipairs({ frames, settles }) do
    for _, time in ipairs(around(list)) do
      if time >= 0 then
        for _, fall in ipairs({ { 0, 0 }, { 0.2, -0.5 }, { 0, 0.5 }, { 0, -0.5 } }) do
          local e = body(kind, {
            hp = 0,
            deathTime = time,
            fallY = fall[1],
            fallVY = fall[2],
            deathResponse = { strength = 0.5, side = 1 },
          })
          row(
            out,
            kind,
            format('dead time=%s fallY=%s fallVY=%s', num(time), num(fall[1]), num(fall[2])),
            session(0, e),
            e
          )
        end
      end
    end
  end
  -- The landing moment, and whether the atlas paints the long (six-frame)
  -- walk of the 0.33 extended layout (plan v11 E1: read from the named pose).
  local e = body(kind)
  local extended = #Anim.posed(e, 'walk').frames == 6
  out[#out + 1] = kind
    .. '|landing|'
    .. num(Corpse.landing(e))
    .. ',extended='
    .. tostring(extended)
end
-- Placement modifiers the frame choice never reads but every pose carries.
local function modifiers(out, kind)
  local cases = {
    { 'flinch', { flinch = 0.5, flinchLean = 0.02 } },
    { 'arrival', { spawnAge = 0.3 } },
    { 'leap', { leapY = 0.4 } },
    { 'sidestep', { evadeTime = 0.1, evadeSide = -1 } },
    { 'crippled', { ai = 'move', walkSpeed = 1, walk = 0.3, conditions = { crippled = 1 } } },
    { 'wounded', { conditions = { wounded = 0.5 } } },
    {
      'leap windup',
      {
        ai = 'windup',
        windupDuration = ACTION,
        windup = ACTION / 2,
        attackSpec = { id = 'leap', kind = 'leap', duration = ACTION },
      },
    },
  }
  for _, case in ipairs(cases) do
    local e = body(kind, case[2])
    row(out, kind, 'modifier ' .. case[1], session(0.7, e), e)
  end
end
-- The creatures of 0.33 (a creature a test registers later is not part of
-- the reference).
T.creatures = { 'imp', 'stolas', 'buer', 'armored', 'boss', 'furfur' }
function T.lines()
  local out = {}
  for _, kind in ipairs(T.creatures) do
    actions(out, kind)
    pain(out, kind)
    walking(out, kind)
    quiet(out, kind)
    dead(out, kind)
    modifiers(out, kind)
  end
  return out
end
function T.text()
  return table.concat(T.lines(), '\n') .. '\n'
end
return T

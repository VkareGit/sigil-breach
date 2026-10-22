-- Real-play measurements for the playtest (plan v5). An entry is appended to
-- telemetry.txt in the game's save folder (Report.path) when the knight
-- dies, when the demons on the proving ground are all down, when a wave or
-- a wave trial ends (WaveCleared) and on F9. An entry measures the encounter
-- since the previous entry and the whole run of measurements (since the
-- proving ground was reset). It listens to the session's events ('present':
-- after the step) and never changes the session. A test session writes
-- nothing. Report.afterWrite (optional) runs after an entry (the journal).
local Telemetry = require('src.combat.telemetry')
local Presentation = require('src.session.presentation')
local Report = { file = 'telemetry.txt' }
-- Per session: the counters and totals at its last entry.
local marks = setmetatable({}, { __mode = 'k' })
local function alive(g)
  local n = 0
  for _, e in ipairs(g.enemies or {}) do
    if e.hp > 0 then
      n = n + 1
    end
  end
  return n
end
local function totals(g)
  return {
    elapsed = g.elapsed or 0,
    kills = g.kills or 0,
    damage = g.damageTaken or 0,
    shots = g.shots or 0,
    hits = g.hits or 0,
  }
end
local function summary(label, t, hp)
  return string.format(
    '%s: %.1f s; kills %d; damage taken %.0f; shots %d, hits %d; health %.0f',
    label,
    t.elapsed,
    t.kills,
    t.damage,
    t.shots,
    t.hits,
    hp
  )
end
-- The full path of the file (the save folder of this build).
function Report.path()
  local folder = love and love.filesystem and love.filesystem.getSaveDirectory()
  return (folder or '.') .. '/' .. Report.file
end
function Report.lines(g, reason)
  local mark = marks[g]
  -- A reset proving ground starts its counters anew (combat/telemetry.lua).
  if mark and mark.telemetry ~= Telemetry.get(g) then
    mark = nil
  end
  local now, before = totals(g), mark and mark.totals or {}
  local encounter = {}
  for key, value in pairs(now) do
    encounter[key] = value - (before[key] or 0)
  end
  local hp = g.player and g.player.hp or 0
  local lines = {
    os.date('%Y-%m-%d %H:%M') .. ' / ' .. reason .. ' / mode ' .. tostring(g.mode),
    summary('This encounter', encounter, hp),
  }
  for _, line in ipairs(Telemetry.lines(g, Telemetry.since(g, mark and mark.counters))) do
    lines[#lines + 1] = '  ' .. line
  end
  lines[#lines + 1] = summary('Since the measurements began', now, hp)
  for _, line in ipairs(Telemetry.lines(g)) do
    lines[#lines + 1] = '  ' .. line
  end
  return lines
end
-- Append an entry; true when it was written.
function Report.write(g, reason)
  if not g or g.testing or not (love and love.filesystem and love.filesystem.append) then
    return false
  end
  local text = table.concat(Report.lines(g, reason), '\n') .. '\n\n'
  if pcall(love.filesystem.append, Report.file, text) ~= true then
    return false
  end
  marks[g] = { telemetry = Telemetry.get(g), counters = Telemetry.copy(g), totals = totals(g) }
  if Report.afterWrite then
    Report.afterWrite(g)
  end
  return true
end
-- The listeners of a session (registered as a presentation attacher).
function Report.attach(g)
  local bus = g.bus
  bus:on('present', 'PlayerHit', function()
    if g.player.hp <= 0 then
      Report.write(g, 'death')
    end
  end)
  -- The wave trial reports itself when it ends (WaveCleared).
  bus:on('present', 'EnemyKilled', function()
    if g.testField and g.testField.station ~= 'waves' and alive(g) == 0 then
      Report.write(g, 'proving ground cleared')
    end
  end)
  bus:on('present', 'WaveCleared', function(e)
    Report.write(g, (e.trial and 'wave trial ' or 'wave ') .. tostring(e.wave))
  end)
end
Presentation.attacher(Report.attach)
return Report

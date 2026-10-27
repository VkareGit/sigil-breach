-- The proving ground's stations (0.22; plan v10 V6: run/test_field.lua split
-- by responsibility). Training dummies are real demons of the chosen tier
-- that neither move nor attack (AI 'dummy'), heal fully between shots and
-- stand up again after a lethal blow, so every number on screen is real.
-- Every function takes the field module (run/test_field.lua).
local Stats = require('src.session.stats')
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local Spawner = require('src.run.spawner')
local Telemetry = require('src.combat.telemetry')
local Roles = require('src.core.roles')
local Text = require('src.content.text')
local K = require('src.content.field')
local Placement = require('src.run.field.placement')
local Trials = {}
local function post(g, kind, x, z, label)
  local posts = g.testField.posts or {}
  g.testField.posts = posts
  local entry = { kind = kind, x = x, z = z, label = label }
  posts[#posts + 1] = entry
  return entry
end
local function raise(g, entry)
  local e = g:spawn(entry.kind, entry.x, entry.z)
  e.fieldKind, e.dummy, e.spawnAge = entry.kind, true, 1
  e.facing = math.atan2(Roles.controlled(g).x - e.x, Roles.controlled(g).z - e.z)
  e.displayName = entry.label
  entry.enemy, entry.down = e, nil
  return e
end
local function label(g, x, z, text, y)
  local labels = g.testField.labels or {}
  g.testField.labels = labels
  labels[#labels + 1] = { x = x, y = y or K.labelHeight, z = z, text = text }
end
local function station(field, g, name)
  field.reset(g)
  g.testField.station = name
  g.testField.invincible = true
  g.testField.frozen = false
end
-- Shooting range: dummies at 4/8/12/16/20 m along the nave, staggered so no
-- body hides another; read damage falloff, spread, zones and guard at range.
function Trials.range(field, g)
  if not g.testField then
    return false
  end
  station(field, g, 'range')
  local p = Roles.controlled(g)
  p.x, p.z, p.yaw, p.pitch = K.start.x, K.start.z, math.pi, 0
  for _, lane in ipairs(K.range.lanes) do
    local d, dx = lane[1], lane[2]
    local x, z = p.x + dx, p.z - math.sqrt(d * d - dx * dx)
    raise(g, post(g, 'imp', x, z, Text.get('field_range_post', { distance = d })))
    label(g, x, z, Text.get('field_range_label', { distance = d }))
  end
  field.close(g)
  field.tell(g, 'field_range')
  return true
end
-- Physics: a domino row straight ahead, a wall-slam dummy by the east wall
-- and one live thrall to trip with a leg shot during its lunge.
function Trials.physics(field, g)
  if not g.testField then
    return false
  end
  station(field, g, 'physics')
  local P = K.physics
  local p = Roles.controlled(g)
  p.x, p.z, p.yaw, p.pitch = P.stand.x, P.stand.z, math.pi, 0
  for i = 1, P.domino.count do
    raise(
      g,
      post(
        g,
        'imp',
        P.domino.x,
        P.domino.z - (i - 1) * P.domino.step,
        Text.get('field_domino_post', { index = i })
      )
    )
  end
  label(g, P.domino.x, P.domino.z, Text.get('field_domino_label'))
  raise(g, post(g, 'imp', P.slam.x, P.slam.z, Text.get('field_slam_post')))
  label(g, P.slam.x, P.slam.z, Text.get('field_slam_label'))
  local live = Placement.spawn(field, g, 'imp', 1)
  if live and live[1] then
    label(g, live[1].x, live[1].z, Text.get('field_trip_label'), P.tripLabel)
  end
  field.close(g)
  field.tell(g, 'field_physics')
  return true
end
-- Wave trial: the real spawner (portals, packs, flanks) on a wave chosen by
-- the TIER dial (the last = the Margrave), with real damage; reports time
-- and harm.
function Trials.waves(field, g)
  if not g.testField then
    return false
  end
  station(field, g, 'waves')
  g.testField.invincible = false
  local tier = g.testField.tier or 1
  local r = g.run
  r.wave = math.min(K.lastWave, tier)
  r.queueIndex, r.pending, r.spawnTimer, r.phaseTime, r.lastGate = 1, {}, 0, 0, nil
  g.testField.trial = { started = g.elapsed, damage = Stats.total(g, 'damageTaken'), wave = r.wave }
  -- Each trial is measured on its own (combat/telemetry.lua) and starts with
  -- a calm pacing director.
  Telemetry.reset(g)
  g.intensity = 0
  Roles.controlled(g).armor = K.armor
  field.close(g)
  field.tell(g, 'field_waves', { wave = r.wave })
  return true
end
-- Keep stations alive: heal dummies, raise fallen ones, run the wave trial.
function Trials.tick(field, g, dt)
  local t = g.testField
  for _, entry in ipairs(t.posts or {}) do
    local e = entry.enemy
    if e and e.hp > 0 then
      e.hp = e.maxHp
    elseif e then
      entry.down = (entry.down or 0) + dt
      if entry.down >= K.raise then
        raise(g, entry)
      end
    end
  end
  local trial = t.trial
  if not (trial and g.run.phase == 'wave') then
    -- The catalogue's portals open outside a wave trial too.
    Spawner.arrivals(g, g.run, dt, Placement.arrive)
  end
  if trial and g.run.phase == 'wave' then
    local _, done = Spawner.step(g, g.run, dt, Placement.arrive)
    if done then
      t.trial = nil
      local m = Telemetry.get(g)
      field.tell(g, 'field_trial_cleared', {
        wave = string.format('%d', trial.wave),
        seconds = string.format('%.1f', g.elapsed - trial.started),
        damage = string.format('%.0f', Stats.total(g, 'damageTaken') - trial.damage),
        control = string.format('%.0f', MathX.percent(Telemetry.uptime(g))),
        kill = string.format('%.1f', m.ttkCount > 0 and m.ttkSum / m.ttkCount or 0),
      })
      -- The measurements go to the playtest report (app/session_report.lua).
      Signal(g, 'WaveCleared', { wave = trial.wave, final = false, trial = true })
    end
  end
end
return Trials

-- Input-level whole-run diagnostic. Perfect knowledge/aim is intentional; no resource cheats.
local W = require('src.world.arena')
local B = require('src.combat.ballistics')
local Run = require('src.run.descent')
local S = {}
-- human (0.21): a human-like model for balance reports, not for pass/fail:
-- reaction time, limited turn rate, aim error and a field of view; it only
-- dodges an attack it can see. Perfect mode stays the regression baseline.
local humanModel = { reaction = 0.30, turnRate = 5.0, aimError = 0.03, fov = 1.75 }
-- skilled (plan v5 G0): a model may also time its dodges into the blow (dodge:
-- seconds of a seen wind-up left when it dashes; leapCue: the height of a
-- seen landing leap) and throw powder into a group (powder: demons within
-- powderRadius m of the target, the target between powderNear and powderFar
-- m). These skills are opt-in: the reference runs and the golden master keep
-- the 0.24 behaviour.
local skill = {
  dodge = 0.06,
  leapCue = 0.45,
  dodgeReach = 3.4,
  powder = 2,
  powderRadius = 3,
  powderNear = 4.5,
  powderFar = 9,
}
local function wrap(a)
  return (a + math.pi) % (2 * math.pi) - math.pi
end
-- The telemetry counters a segment of the run is measured by.
local segmentKeys = { 'enemyTime', 'controlTime', 'kills', 'breakKills', 'perfectDodges' }
local function counters(g)
  local t, out = require('src.combat.telemetry').get(g), {}
  for _, key in ipairs(segmentKeys) do
    out[key] = t[key] or 0
  end
  return out
end
-- A seen blow about to land within reach: the moment a skilled model dashes.
local function incoming(g, model)
  local p = g.player
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      local d = math.sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2)
      local seen = math.abs(wrap(math.atan2(e.x - p.x, e.z - p.z) - p.yaw)) < model.fov * 0.5
      local spec = e.attackSpec
      local melee = spec and (spec.kind == 'lunge' or spec.kind == 'charge')
      if
        seen
        and d < model.dodgeReach
        and e.ai == 'windup'
        and melee
        and e.windup <= model.dodge
      then
        return true
      end
      if
        seen
        and e.leaping
        and (e.leapVY or 0) < 0
        and (e.leapY or 1) < model.leapCue
        and d < 2.2
      then
        return true
      end
    end
  end
  return false
end
function S.run(G, human, observer)
  -- human: true for the reference model, or a model table (population).
  -- observer (optional): called after every simulation step (golden master).
  local population = type(human) == 'table'
  human = population and human or (human and humanModel or nil)
  local noticed, noticedFor = nil, 0
  local g = G.new('descent')
  g.testing = true
  g:start()
  if observer then
    observer(g, 0)
  end
  local field, fieldX, fieldZ, fieldAge = nil, nil, nil, 0
  local lastX, lastZ = g.player.x, g.player.z
  local stuck = 0
  local shotgun, lance, pulses, purchases = 0, 0, 0, 0
  local waveTimes = {}
  local waveDamage, damageStart = {}, 0
  local previousWave = 1
  local waveStarted = 0
  local segments, segmentStart = {}, counters(g)
  local function closeSegment()
    local now, out = counters(g), {}
    for _, key in ipairs(segmentKeys) do
      out[key] = now[key] - segmentStart[key]
    end
    segments[#segments + 1] = out
    segmentStart = now
  end
  local function pathTo(x, z)
    local tx, tz = math.floor(x + 0.5), math.floor(z + 0.5)
    if not field or tx ~= fieldX or tz ~= fieldZ or fieldAge > 0.35 then
      field = W.flow(g.world, x, z)
      fieldX, fieldZ = tx, tz
      fieldAge = 0
    end
    local p = g.player
    local cx, cz = math.floor(p.x + 0.5), math.floor(p.z + 0.5)
    if cx == tx and cz == tz then
      return x - p.x, z - p.z
    end
    if stuck > 0.2 then
      return cx - p.x, cz - p.z
    end
    local bx, bz, best = cx, cz, 1e9
    for _, o in ipairs({ { 0, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 } }) do
      local nx, nz = cx + o[1], cz + o[2]
      local d = field[nz * g.world.size + nx]
      if d and d < best and not W.solid(g.world, nx, nz, 0.22) then
        bx, bz, best = nx, nz, d
      end
    end
    return bx - p.x, bz - p.z
  end
  for tick = 1, 120 * 600 do
    if g.state == 'won' or g.state == 'dead' then
      break
    end
    local p = g.player
    local dx, dz = 0, 0
    local visible = false
    local dash = false
    if g.run.wave ~= previousWave then
      waveDamage[#waveDamage + 1] = g.damageTaken - damageStart
      damageStart = g.damageTaken
      waveTimes[#waveTimes + 1] = g.elapsed - waveStarted
      waveStarted = g.elapsed
      previousWave = g.run.wave
      closeSegment()
    end
    if g.run.phase == 'preparing' then
      dx, dz = pathTo(Run.shrine.x, Run.shrine.z)
      if g:interact() then
        if g.run.wave >= 3 and not g.run.owned.pierce and g.run.wallet >= 148 then
          if Run.buy(g, 'pierce') then
            purchases = purchases + 1
          end
        end
        g:switchWeapon(1)
        while p.arsenal.exorcist.reserve < 24 and Run.buy(g, 'ammo') do
          purchases = purchases + 1
        end
        g:switchWeapon(2)
        while p.arsenal.judge.reserve < 24 and Run.buy(g, 'ammo') do
          purchases = purchases + 1
        end
        if p.armor < 50 and Run.buy(g, 'armor') then
          purchases = purchases + 1
        end
        Run.closeShop(g)
        Run.ready(g)
      end
    elseif g.run.phase == 'wave' then
      local nearest, distance, any, anyDist = nil, 1e9, nil, 1e9
      for _, e in ipairs(g.enemies) do
        if e.hp > 0 then
          local d = math.sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2)
          if d < anyDist then
            any, anyDist = e, d
          end
          if W.visible(g.world, p.x, p.z, e.x, e.z) and d < distance then
            nearest, distance = e, d
          end
        end
      end
      local aimed = true
      if nearest and human then
        -- Turn toward the target at a finite rate; notice it only after it has
        -- been inside the field of view for the reaction time.
        local want = math.atan2(nearest.x - p.x, nearest.z - p.z)
        local off = wrap(want - p.yaw)
        local inView = math.abs(off) < human.fov * 0.5
        if noticed ~= nearest or not inView then
          noticed, noticedFor = inView and nearest or nil, 0
        else
          noticedFor = noticedFor + 1 / 120
        end
        local turn = math.max(-human.turnRate / 120, math.min(human.turnRate / 120, off))
        -- A deterministic wobble stands in for hand error.
        p.yaw = p.yaw + turn + math.sin(g.elapsed * 7.3) * human.aimError * 0.15
        aimed = noticed == nearest
          and noticedFor >= human.reaction
          and math.abs(wrap(want - p.yaw)) < human.aimError + 0.02
      end
      if nearest then
        visible = aimed
        if not human then
          p.yaw = math.atan2(nearest.x - p.x, nearest.z - p.z)
        end
        local _, eye = B.origin(g)
        p.pitch = math.atan2((nearest.kind == 'boss' and 1.75 or 1.35) - eye, distance)
        local desired = distance < 6.3
            and (p.arsenal.exorcist.mag > 0 or p.arsenal.exorcist.reserve > 0)
            and 1
          or 2
        if
          p.arsenal.judge.mag + p.arsenal.judge.reserve == 0
          and p.arsenal.exorcist.mag + p.arsenal.exorcist.reserve > 0
        then
          desired = 1
        end
        if desired ~= g.weapon and g.reload == 0 and g.cooldown == 0 then
          g:switchWeapon(desired)
        end
        if distance > 6 then
          dx, dz = pathTo(nearest.x, nearest.z)
        else
          local ux, uz =
            (nearest.x - p.x) / math.max(0.01, distance),
            (nearest.z - p.z) / math.max(0.01, distance)
          local radial = distance > 4.7 and 0.65 or (distance < 3.5 and -1 or 0)
          local side = math.sin(g.elapsed * 0.9) > 0 and 1 or -1
          dx, dz = ux * radial + uz * side * 0.8, uz * radial - ux * side * 0.8
          if W.solid(g.world, p.x + dx * 0.5, p.z + dz * 0.5, 0.22) then
            dx, dz = ux * radial - uz * side * 0.8, uz * radial + ux * side * 0.8
          end
          dash = nearest.ai == 'windup' and nearest.windup < 0.18 and distance < 3.2
          if human then
            dash = dash and noticed == nearest and noticedFor >= human.reaction
          end
        end
        local crowd = 0
        for _, e in ipairs(g.enemies) do
          if
            e.hp > 0
            and (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2 < 30
            and W.visible(g.world, p.x, p.z, e.x, e.z)
          then
            crowd = crowd + 1
          end
        end
        if
          p.abilityState.powder.uses > 0
          and distance > 5
          and distance < 8
          and crowd >= 3
          and g:cast(1)
        then
          pulses = pulses + 1
        end
        -- Skilled: powder into a group around the target, once it is noticed.
        if
          human
          and human.powder
          and aimed
          and p.abilityState.powder.uses > 0
          and distance > human.powderNear
          and distance < human.powderFar
        then
          local group = 0
          for _, e in ipairs(g.enemies) do
            if
              e.hp > 0
              and (e.x - nearest.x) ^ 2 + (e.z - nearest.z) ^ 2 < human.powderRadius * human.powderRadius
            then
              group = group + 1
            end
          end
          if group >= human.powder and g:cast(1) then
            pulses = pulses + 1
          end
        end
      elseif any then
        dx, dz = pathTo(any.x, any.z)
      end
      -- Skilled: a dash timed into a seen blow (a perfect dodge when it lands).
      if human and human.dodge then
        dash = incoming(g, human)
      end
    end
    local len = math.sqrt(dx * dx + dz * dz)
    if len > 1 then
      dx, dz = dx / len, dz / len
    end
    local shotCount = g.shots
    g:update(1 / 120, {
      forward = dx * math.sin(p.yaw) + dz * math.cos(p.yaw),
      strafe = dx * math.cos(p.yaw) - dz * math.sin(p.yaw),
      shoot = visible,
      jump = visible,
      dash = dash,
    })
    if observer then
      observer(g, tick)
    end
    if g.shots > shotCount then
      if g.weapon == 1 then
        shotgun = shotgun + 1
      else
        lance = lance + 1
      end
    end
    fieldAge = fieldAge + 1 / 120
    if math.abs(p.x - lastX) + math.abs(p.z - lastZ) < 0.001 and len > 0.1 then
      stuck = stuck + 1 / 120
    else
      stuck = 0
    end
    lastX, lastZ = p.x, p.z
  end
  waveTimes[#waveTimes + 1] = g.elapsed - waveStarted
  waveDamage[#waveDamage + 1] = g.damageTaken - damageStart
  closeSegment()
  for i, segment in ipairs(segments) do
    segment.time, segment.damage = waveTimes[i], waveDamage[i]
  end
  local result = {
    state = g.state,
    time = g.elapsed,
    hp = g.player.hp,
    damage = g.damageTaken,
    kills = g.kills,
    ammo = g.player.arsenal.exorcist.mag + g.player.arsenal.exorcist.reserve,
    shotgun = shotgun,
    lance = lance,
    pulses = pulses,
    purchases = purchases,
    wallet = g.run.wallet,
    fragment = g.run.fragment,
    wave = g.run.wave,
    telemetry = require('src.combat.telemetry').get(g),
    uptime = require('src.combat.telemetry').uptime(g),
    segments = segments,
    session = g,
  }
  local lines = {
    'FULL LIMBO WAVE INPUT SIMULATION',
    string.format(
      'Result: %s / wave %d / fragment %s',
      result.state,
      result.wave,
      tostring(result.fragment)
    ),
    string.format(
      'Time %.2f s; kills %d; health %.1f; damage %.1f; shells %d; revolver rounds %d; souls %d',
      result.time,
      result.kills,
      result.hp,
      result.damage,
      result.ammo,
      g.player.arsenal.judge.mag + g.player.arsenal.judge.reserve,
      result.wallet
    ),
    string.format(
      'Shotgun volleys %d; revolver shots %d; powder charges %d; purchases %d',
      shotgun,
      lance,
      pulses,
      purchases
    ),
  }
  for i, t in ipairs(waveTimes) do
    local segment = segments[i] or {}
    lines[#lines + 1] = string.format(
      'Segment %d: %.2f s, damage taken %.1f, control %.1f %%, break kills %d/%d (includes travel/preparation/countdown)',
      i,
      t,
      waveDamage[i] or 0,
      100 * (segment.controlTime or 0) / math.max(1e-9, segment.enemyTime or 0),
      segment.breakKills or 0,
      segment.kills or 0
    )
  end
  -- Pressure (0.21): how often demons commit, leap and evade per minute.
  local minutes = math.max(1e-6, g.elapsed / 60)
  lines[#lines + 1] = string.format(
    'Pressure: %d attacks (%.1f/min), %d leaps, %d evades',
    g.attackStarts or 0,
    (g.attackStarts or 0) / minutes,
    g.leapStarts or 0,
    g.evadeCount or 0
  )
  -- 0.24 measurements shared with real play (src/combat/telemetry.lua).
  for _, line in ipairs(require('src.combat.telemetry').lines(g)) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] =
    'Real movement, collisions, damage, physical ammunition, drops and shop transactions. No health, ammunition, currency overrides or teleportation. Perfect aim/knowledge: regression evidence, NOT human difficulty validation.'
  if human then
    lines[1] =
      'HUMAN-MODEL LIMBO WAVE SIMULATION (reaction .30 s, turn 5 rad/s, aim error .03 rad, view 100 deg)'
  end
  if population then
    return result
  end
  local f = assert(
    io.open(
      require('qa.output').path(human and 'playtest-human.txt' or 'playtest-results.txt'),
      'w'
    )
  )
  f:write(table.concat(lines, '\n'))
  f:close()
  print(table.concat(lines, '\n'))
  return result
end
-- Population (0.24): one deterministic run is chaotic (any code change moves
-- every later event), so balance is judged on five human models from slow
-- and sloppy to quick and precise. Report only; the mean and the spread.
-- The goals of the combat (plan v5, decision D7), judged on these models:
-- the share of demon lifetime under control, the share of kills that are
-- break kills, and perfect dodges per wave of the skilled models.
S.targets = { control = { 0.08, 0.12 }, breakKills = { 0.15, 0.25 }, perfectDodgesPerWave = 1 }
local function models(skilled)
  local list = {}
  for k = -2, 2 do
    local model = {
      reaction = humanModel.reaction - 0.04 * k,
      turnRate = humanModel.turnRate + 0.75 * k,
      aimError = humanModel.aimError * (1 - 0.2 * k),
      fov = humanModel.fov,
    }
    if skilled then
      for key, value in pairs(skill) do
        model[key] = value
      end
    end
    list[#list + 1] = model
  end
  return list
end
-- Five runs of one kind of model: a row each, the sums and the waves.
local function group(G, skilled, lines)
  local sums = {
    damage = 0,
    uptime = 0,
    ttk = 0,
    won = 0,
    kills = 0,
    breakKills = 0,
    perfectDodges = 0,
    charges = 0,
    waves = {},
  }
  for i, model in ipairs(models(skilled)) do
    local result = S.run(G, model)
    local m = result.telemetry or {}
    local ttk = (m.ttkCount or 0) > 0 and m.ttkSum / m.ttkCount or 0
    sums.damage = sums.damage + result.damage
    sums.uptime = sums.uptime + (result.uptime or 0)
    sums.ttk = sums.ttk + ttk
    sums.won = sums.won + (result.state == 'won' and 1 or 0)
    sums.kills = sums.kills + (m.kills or 0)
    sums.breakKills = sums.breakKills + (m.breakKills or 0)
    sums.perfectDodges = sums.perfectDodges + (m.perfectDodges or 0)
    sums.charges = sums.charges + result.pulses
    for w, segment in ipairs(result.segments) do
      local wave = sums.waves[w] or { enemyTime = 0, controlTime = 0, kills = 0, breakKills = 0 }
      sums.waves[w] = wave
      wave.perfectDodges = (wave.perfectDodges or 0) + segment.perfectDodges
      for _, key in ipairs({ 'enemyTime', 'controlTime', 'kills', 'breakKills' }) do
        wave[key] = wave[key] + segment[key]
      end
    end
    lines[#lines + 1] = string.format(
      'model %d (reaction %.2f s, turn %.2f rad/s, aim error %.3f rad): %s, damage %.1f, control %.1f %%, kill %.2f s, break kills %d/%d, perfect dodges %d, charges %d',
      i,
      model.reaction,
      model.turnRate,
      model.aimError,
      result.state,
      result.damage,
      100 * (result.uptime or 0),
      ttk,
      m.breakKills or 0,
      m.kills or 0,
      m.perfectDodges or 0,
      result.pulses
    )
  end
  local n = 5
  lines[#lines + 1] = string.format(
    'MEAN: won %d/%d, damage %.1f, control %.1f %%, time to kill %.2f s, break kills %.1f %% of kills, perfect dodges %.1f, charges %.1f',
    sums.won,
    n,
    sums.damage / n,
    100 * sums.uptime / n,
    sums.ttk / n,
    100 * sums.breakKills / math.max(1, sums.kills),
    sums.perfectDodges / n,
    sums.charges / n
  )
  for w, wave in ipairs(sums.waves) do
    lines[#lines + 1] = string.format(
      '  wave %d: control %.1f %%, break kills %.1f %% of %d kills, perfect dodges %.1f per run',
      w,
      100 * wave.controlTime / math.max(1e-9, wave.enemyTime),
      100 * wave.breakKills / math.max(1, wave.kills),
      wave.kills,
      wave.perfectDodges / n
    )
  end
  return sums
end
local function verdict(value, range)
  return value >= range[1] and value <= range[2] and 'MET' or 'NOT MET'
end
function S.population(G)
  local lines = { 'HUMAN-MODEL POPULATION / 5 models / waves 1-5 (0.24 behaviour)' }
  local sums = group(G, false, lines)
  lines[#lines + 1] = ''
  lines[#lines + 1] =
    'SKILLED POPULATION / the same 5 models + dodges timed into the blow + powder into groups'
  local skilled = group(G, true, lines)
  local T = S.targets
  local control = skilled.uptime / 5
  local breaks = skilled.breakKills / math.max(1, skilled.kills)
  local dodges = skilled.perfectDodges / 5 / math.max(1, #skilled.waves)
  lines[#lines + 1] = ''
  lines[#lines + 1] = 'TARGETS (plan v5, D7) on the skilled population:'
  lines[#lines + 1] = string.format(
    '  control %.1f %% (target %d-%d %%): %s',
    100 * control,
    100 * T.control[1],
    100 * T.control[2],
    verdict(control, T.control)
  )
  lines[#lines + 1] = string.format(
    '  break kills %.1f %% of kills (target %d-%d %%): %s',
    100 * breaks,
    100 * T.breakKills[1],
    100 * T.breakKills[2],
    verdict(breaks, T.breakKills)
  )
  lines[#lines + 1] = string.format(
    '  perfect dodges %.2f per wave (target >= %d): %s',
    dodges,
    T.perfectDodgesPerWave,
    dodges >= T.perfectDodgesPerWave and 'MET' or 'NOT MET'
  )
  local f = assert(io.open(require('qa.output').path('playtest-population.txt'), 'w'))
  f:write(table.concat(lines, '\n'))
  f:close()
  sums.skilled = skilled
  return sums
end
return S

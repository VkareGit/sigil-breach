-- Actual Judge shots aimed at interior painted head/torso points of the last
-- displayed frame. Records the contact/material/damage outcome, not merely
-- a root-position difference. This is a timing observation, not a fun score
-- score. The submitted observation is the contract for direct/held/buffered
-- hitscan; the current world and target protection still apply at resolution.
local Field = require('src.run.test_field')
local Presentation = require('src.render.presentation')
local Surface = require('src.enemies.surface')
local B = require('src.combat.ballistics')
local Damage = require('src.combat.damage')
local Weapons = require('src.content.weapons')
local Review = {}
local STEP = 1 / 120
local schedules = {
  { name = '30', dt = { 1 / 30 } },
  { name = '60', dt = { 1 / 60 } },
  { name = '120', dt = { 1 / 120 } },
  { name = '144', dt = { 1 / 144 } },
  { name = '240', dt = { 1 / 240 } },
  { name = 'jitter', dt = { 0.007, 0.033, 0.012, 0.055 } },
}
-- Select real interior pigment in the requested semantic zone. A concave
-- body's average can lie in air, so find the nearest valid texel to it.
local function interior(truth, surface, place, zone, cache)
  local key = surface.parts
  cache[key] = cache[key] or {}
  cache[key][surface.mask] = cache[key][surface.mask] or {}
  local known = cache[key][surface.mask][zone]
  if known then
    return known[1], known[2]
  end
  local _, _, _, cu, cv = Surface.locateZone(surface, zone)
  if not cu then
    return nil
  end
  local best, bu, bv = math.huge
  for y = 0, 79 do
    for x = 0, 79 do
      local u, v = (x + 0.5) / 80, (y + 0.5) / 80
      local distance = (u - cu) ^ 2 + (v - cv) ^ 2
      if distance < best and Surface.painted(surface.mask, u, v, true) then
        local part = Surface.part(surface.parts, u, v)
        if part and part.zone == zone and part.hittable ~= false then
          local class, edge = truth:classify(place, surface.mirror > 0.5 and 1 - u or u, 1 - v)
          if class == 'body' and not edge then
            best, bu, bv = distance, u, v
          end
        end
      end
    end
  end
  cache[key][surface.mask][zone] = { bu, bv }
  return bu, bv
end
function Review.run(Game, truth, output, mode)
  mode = mode or 'held'
  local rows = {
    'kind,schedule,shot,time_s,source,aimed_zone,shown_zone,actual_zone,shown_material,actual_material,shown_damage,actual_damage,shown_age_ms,root_delta_m,frame_changed,result',
  }
  local summary = {
    'kind,schedule,shots,valid_interior,misses,zone_changes,material_changes,damage_changes,excluded',
  }
  local total = {
    shots = 0,
    valid = 0,
    misses = 0,
    zones = 0,
    materials = 0,
    damage = 0,
    excluded = 0,
    cases = 0,
  }
  local cache = {}
  local sources = {}
  local differences = {}
  for _, kind in ipairs({ 'imp', 'buer', 'stolas', 'armored', 'boss', 'furfur' }) do
    for _, schedule in ipairs(schedules) do
      local g = Field.new(Game)
      g.testing, g.view.motion = true, false
      local enemy = Field.spawn(g, kind, 1)[1]
      Field.close(g)
      enemy.hp = 1000000
      g:switchWeapon(2)
      local lastSurface = Surface.prepare(g, enemy)
      local lastPlace = truth:place(g, enemy, {})
      local lastTime, expected, aimed = 0, nil, 'head'
      local lastWalk, lastPhase = enemy.walk, enemy.phase
      local pressing = false
      local input = require('src.app.input').new()
      local app = { game = g, settings = {} }
      local displayed = {}
      local function present(shown)
        input:present(g, shown)
        displayed[input.observation.sequence] = {
          surface = lastSurface,
          place = lastPlace,
          time = lastTime,
          walk = lastWalk,
          phase = lastPhase,
        }
      end
      present(g)
      local stats =
        { shots = 0, valid = 0, misses = 0, zones = 0, materials = 0, damage = 0, excluded = 0 }
      g.bus:on('sim', 'ShotFired', function(event)
        stats.shots = stats.shots + 1
        local command = assert(event.command, 'probe must submit an observation')
        local observed = assert(displayed[command.observation.sequence])
        local shownSurface, shownPlace = observed.surface, observed.place
        local ox, oy, oz = B.origin(g)
        ox, oy, oz = unpack(command.observation.origin)
        local dx, dy, dz = B.direction(command.yaw, command.pitch)
        local d, zone, contact =
          Surface.ray(shownSurface, ox, oy, oz, dx, dy, dz, Weapons.inHand(g).range)
        local t, u, v = truth.cross(shownPlace, ox, oy, oz, dx, dy, dz)
        local class, edge
        if t then
          class, edge = truth:classify(shownPlace, u, v)
        end
        local current = truth:place(g, enemy, {})
        expected = {
          source = pressing and 'immediate' or (mode == 'held' and 'held' or 'buffered'),
          zone = zone,
          contact = contact,
          valid = d and class == 'body' and not edge and zone ~= false,
          damage = contact and Damage.surface(Weapons.attack(g), enemy, d, contact) or 0,
          age = (g.elapsed - observed.time) * 1000,
          delta = math.sqrt(
            (current.x - shownPlace.x) ^ 2
              + (current.z - shownPlace.z) ^ 2
              + (current.baseY - shownPlace.baseY) ^ 2
          ),
          changed = current.key ~= shownPlace.key,
          frames = tostring(shownSurface.frame) .. ' -> ' .. tostring(current.frame),
          clocks = string.format(
            'walk %.9f -> %.9f; phase %.9f -> %.9f',
            observed.walk or 0,
            enemy.walk or 0,
            observed.phase or 0,
            enemy.phase or 0
          ),
        }
      end)
      g.bus:on('sim', 'VolleyResolved', function(event)
        local actual = event.report.contacts[1]
        local hit = actual and actual.targetId == enemy.id and actual.zone ~= false
        local result = 'excluded'
        if expected.valid then
          stats.valid = stats.valid + 1
          local missed = not hit
          local zone = hit and actual.zone ~= expected.zone
          local material = hit and actual.material ~= expected.contact.material
          local damage = math.abs((hit and actual.damage or 0) - expected.damage) > 0.01
          stats.misses = stats.misses + (missed and 1 or 0)
          stats.zones = stats.zones + (zone and 1 or 0)
          stats.materials = stats.materials + (material and 1 or 0)
          stats.damage = stats.damage + (damage and 1 or 0)
          result = missed and 'miss'
            or (zone and 'zone' or (material and 'material' or (damage and 'damage' or 'same')))
        else
          stats.excluded = stats.excluded + 1
        end
        local source = sources[expected.source] or { shots = 0, valid = 0, misses = 0, changed = 0 }
        sources[expected.source] = source
        source.shots = source.shots + 1
        source.valid = source.valid + (expected.valid and 1 or 0)
        source.misses = source.misses + (result == 'miss' and 1 or 0)
        source.changed = source.changed + (result ~= 'same' and result ~= 'excluded' and 1 or 0)
        if result ~= 'same' and result ~= 'excluded' then
          differences[#differences + 1] = string.format(
            '%s / %s / %s at %.6fs: %s, frames %s; %s; AI %s.',
            kind,
            schedule.name,
            expected.source,
            g.elapsed,
            result,
            expected.frames,
            expected.clocks,
            enemy.ai
          )
        end
        rows[#rows + 1] = string.format(
          '%s,%s,%d,%.6f,%s,%s,%s,%s,%s,%s,%.6f,%.6f,%.3f,%.6f,%s,%s',
          kind,
          schedule.name,
          stats.shots,
          g.elapsed,
          expected.source,
          aimed,
          tostring(expected.zone),
          tostring(actual and actual.zone),
          expected.contact and expected.contact.material or '',
          actual and actual.material or '',
          expected.damage,
          actual and actual.damage or 0,
          expected.age,
          expected.delta,
          tostring(expected.changed),
          result
        )
      end)
      local accumulator, wallTime, frame = 0, 0, 0
      while wallTime < 6 do
        frame = frame + 1
        aimed = stats.shots % 2 == 0 and 'head' or 'torso'
        local u, v = interior(truth, lastSurface, lastPlace, aimed, cache)
        if u then
          local x, y, z = Surface.point(lastSurface, u, v)
          local ox, oy, oz = B.origin(g)
          g.player.yaw = math.atan2(x - ox, z - oz)
          g.player.pitch = math.atan2(y - oy, math.sqrt((x - ox) ^ 2 + (z - oz) ^ 2))
        end
        -- LÖVE pumps input callbacks before Application:update. A ready-only
        -- press isolates the native immediate shot; repeated presses also
        -- exercise the existing fire buffer without a held button.
        if
          u
          and mode ~= 'held'
          and (mode == 'press-buffer' or (g.player.cooldown <= 0 and g.player.reload <= 0))
        then
          pressing = true
          input:mousepressed(app, 640, 360, 1)
          pressing = false
        end
        local dt = schedule.dt[(frame - 1) % #schedule.dt + 1]
        local heldCommand = input:command(g)
        wallTime, accumulator = wallTime + dt, math.min(0.20, accumulator + dt)
        while accumulator >= STEP do
          Presentation.capture(g)
          g:update(STEP, { shoot = mode == 'held' and u ~= nil, fireCommand = heldCommand })
          accumulator = accumulator - STEP
        end
        local shown = Presentation.sample(g, accumulator / STEP)
        lastSurface = Surface.prepare(shown, shown.enemies[1])
        lastPlace = truth:place(shown, shown.enemies[1], {})
        lastWalk, lastPhase = shown.enemies[1].walk, shown.enemies[1].phase
        lastTime = g.elapsed - STEP + accumulator
        present(shown)
      end
      assert(
        stats.shots > 0 and stats.valid > 0,
        'no interior shot observation for ' .. kind .. '/' .. schedule.name
      )
      for name, value in pairs(stats) do
        total[name] = total[name] + value
      end
      total.cases = total.cases + 1
      summary[#summary + 1] = string.format(
        '%s,%s,%d,%d,%d,%d,%d,%d,%d',
        kind,
        schedule.name,
        stats.shots,
        stats.valid,
        stats.misses,
        stats.zones,
        stats.materials,
        stats.damage,
        stats.excluded
      )
    end
  end
  local function write(name, lines)
    if mode ~= 'held' then
      name = name:gsub('hit%-outcomes', 'hit-outcomes-' .. mode)
    end
    local file = assert(io.open(output .. '/' .. name, 'w'))
    file:write(table.concat(lines, '\n') .. '\n')
    file:close()
  end
  write('hit-outcomes.csv', rows)
  write('hit-outcomes-summary.csv', summary)
  write('hit-outcomes-differences.txt', differences)
  local description = {
    'Submitted displayed observation versus actual Judge contact; 6 live creature kinds x 6 render schedules; motion off isolates pose timing.',
    'Aim alternates interior head and torso pigment; trigger mode '
      .. mode
      .. ', normal ammunition/reload, durable target; fixed simulation 120 Hz.',
    'Direct/held use the latest displayed observation. A released buffered tap retains its press-time observation and aim. Current protection and world cover remain authoritative.',
    'Expected damage uses the submitted surface and current damage rules/target protection. Actual damage comes from VolleyResolved; excluded rays do not cross interior hittable pigment.',
    'This tests the observation contract, not player enjoyment. Individual shots are in the matching hit-outcomes CSV.',
    string.format(
      'Cases %d; shots %d; valid interior %d; misses %d; zone changes %d; material changes %d; damage differences >0.01 %d; excluded %d.',
      total.cases,
      total.shots,
      total.valid,
      total.misses,
      total.zones,
      total.materials,
      total.damage,
      total.excluded
    ),
  }
  for _, name in ipairs({ 'held', 'immediate', 'buffered' }) do
    local source = sources[name]
    if source then
      description[#description + 1] = string.format(
        'Trigger %s: shots %d; valid %d; misses %d; changed outcomes %d.',
        name,
        source.shots,
        source.valid,
        source.misses,
        source.changed
      )
    end
  end
  write('hit-outcomes.txt', description)
  return total
end
return Review

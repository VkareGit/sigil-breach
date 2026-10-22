-- A creature over existing art, as data only, through the unchanged systems
-- (0.29): its own anatomy annotation of the thrall's painting (the torso cut
-- into plates, a different number per frame, all one damage zone), the
-- thrall's leap with the Star Acolyte's sidestep, and a new ballistic
-- material whose policy shots and feedback read with no condition on its
-- name. Test-only: everything is removed again; game content is unchanged.
local Fixtures = require('tests.support.fixtures')
local B = require('src.combat.ballistics')
local Surface = require('src.enemies.surface')
local AbilityPose = require('src.enemies.ability_pose')
local Anatomy = require('src.content.art.anatomy_regions')
local Materials = require('src.content.ballistic_surfaces')
local Creature = require('src.content.defs.creature')
local A = require('src.content.enemies')
local Tests = {}
-- The part of a polygon between two heights (v down the frame): clipped
-- against each horizontal line in turn (Sutherland-Hodgman).
local function clip(polygon, keep, line)
  local out = {}
  local function push(u, v)
    out[#out + 1] = u
    out[#out + 1] = v
  end
  for i = 1, #polygon, 2 do
    local j = i + 2 > #polygon and 1 or i + 2
    local au, av, bu, bv = polygon[i], polygon[i + 1], polygon[j], polygon[j + 1]
    if keep(av) then
      push(au, av)
    end
    if keep(av) ~= keep(bv) then
      push(au + (bu - au) * (line - av) / (bv - av), line)
    end
  end
  return out
end
local function band(polygon, top, bottom)
  local below = clip(polygon, function(v)
    return v >= top
  end, top)
  return clip(below, function(v)
    return v < bottom
  end, bottom)
end
-- The thrall's annotation with every torso region but the frame-wide one cut
-- into 2, 3 or 4 plates by frame; every second plate is iron.
local function plated(source, material)
  local frames, counts = {}, {}
  for index, frame in ipairs(source.frames) do
    local plates, parts = 2 + index % 3, {}
    counts[plates] = true
    for n, part in ipairs(frame.parts) do
      if n > 1 and part.zone == 'torso' and part.hittable ~= false then
        local top, bottom = math.huge, -math.huge
        for i = 2, #part.polygon, 2 do
          top, bottom = math.min(top, part.polygon[i]), math.max(bottom, part.polygon[i])
        end
        for k = 1, plates do
          local edge = top + (bottom - top) * (k - 1) / plates
          local polygon = band(part.polygon, edge, top + (bottom - top) * k / plates)
          if #polygon >= 6 then
            parts[#parts + 1] = {
              id = part.id .. '_plate' .. k,
              zone = part.zone,
              material = k % 2 == 0 and material or part.material,
              polygon = polygon,
            }
          end
        end
      else
        parts[#parts + 1] = part
      end
    end
    frames[index] = { parts = parts, anchors = frame.anchors }
  end
  return { frames = frames }, counts
end
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'creature extension: ', 'creature extension: ')
  -- A material policy is data: iron plates absorb half a wound, wear the
  -- guard twice, stop a piercing round and throw sparks.
  Materials.trial_plate = { wound = 0.5, guard = 2, penetrable = false, debris = 'metal' }
  local annotation, counts = plated(Anatomy.layouts.imp, 'trial_plate')
  Anatomy.layouts.trial_plated = annotation
  A.trial_plated = Creature.define({
    extends = A.imp,
    id = 'trial_plated',
    kind = 'imp',
    variant = 'trial_plated',
    name = 'Trial Plated Thrall',
    appearance = { regions = 'trial_plated', evadeArt = 'evade' },
    move = { evade = { speed = 6.5, time = 0.24, cooldown = 3.5 } },
  })
  local problems, distinct = {}, 0
  for index, frame in ipairs(annotation.frames) do
    for _, message in ipairs(Anatomy.problems(frame, 'trial frame ' .. index)) do
      problems[#problems + 1] = message
    end
  end
  for _ in pairs(counts) do
    distinct = distinct + 1
  end
  check(
    'the annotation passes the shipped anatomy rules ' .. table.concat(problems, '; '),
    #problems == 0 and distinct == 3
  )
  -- Every painted texel keeps its damage zone and hittability: the plates
  -- change parts and materials, never what a shot wounds.
  local same, plates = true, 0
  for index, frame in ipairs(Anatomy.layouts.imp.frames) do
    local mine = annotation.frames[index].parts
    for j = 2, 318, 4 do
      for i = 2, 318, 4 do
        local u, v = (i + 0.5) / 320, (j + 0.5) / 320
        local a, b = Surface.part(frame.parts, u, v), Surface.part(mine, u, v)
        same = same
          and (a and a.zone) == (b and b.zone)
          and (a and a.hittable) == (b and b.hittable)
        plates = plates + (b and b.id:find('_plate', 1, true) and 1 or 0)
      end
    end
  end
  check('plates of one zone: the same zone under every texel of every frame', same and plates > 0)

  -- Shots: the unchanged ballistics meet the plates of the painting as drawn.
  local function line(material)
    local g = Fixtures.arena(G)
    g.state = 'playing'
    local front = g:spawn('trial_plated', 16, 22)
    local rear = g:spawn('imp', 16, 20)
    front.spawnAge, rear.spawnAge = 1, 1
    local ox, oy, oz = B.origin(g)
    for i = 30, -30, -1 do
      for j = -20, 20 do
        local yaw, pitch = math.pi + j / 400, i / 100
        local dx, dy, dz = B.direction(yaw, pitch)
        local _, _, surface = B.body(g, front, ox, oy, oz, dx, dy, dz, 20)
        if
          surface
          and surface.shapeId:find('_plate', 1, true)
          and surface.material == material
          and B.body(g, rear, ox, oy, oz, dx, dy, dz, 20)
        then
          return g, front, rear, yaw, pitch, surface
        end
      end
    end
    error('fixture: no ray through a ' .. material .. ' plate and the body behind it')
  end
  local function fire(material)
    local g, front, rear, yaw, pitch, aimed = line(material)
    local report
    g.bus:on('sim', 'VolleyResolved', function(event)
      report = event.report
    end)
    g.weapon, g.player.yaw, g.player.pitch, g.cooldown = 2, yaw, pitch, 0
    local rearHp = rear.hp
    g:shoot()
    local first
    for _, contact in ipairs(report.contacts) do
      if contact.targetId == front.id then
        first = contact
      end
    end
    return first, aimed, rear.hp < rearHp, g, front
  end
  local iron, ironAimed, ironPierced, g, front = fire('trial_plate')
  local skin, skinAimed, skinPierced = fire('flesh')
  check(
    'the round meets the plate it was aimed at, zone torso, with its material',
    iron
      and skin
      and iron.shapeId == ironAimed.shapeId
      and skin.shapeId == skinAimed.shapeId
      and iron.zone == 'torso'
      and skin.zone == 'torso'
      and iron.material == 'trial_plate'
  )
  check(
    string.format(
      'an iron plate passes half the wound of a skin plate (%.3f / %.3f)',
      iron.damage,
      skin.damage
    ),
    math.abs(iron.damage / skin.damage - 0.5) < 0.01
  )
  check(
    "the Judge's round pierces skin to the body behind and stops at iron",
    skinPierced and not ironPierced
  )
  -- Feedback reads the same policy: what the plate absorbed throws its debris.
  g.view.particles = {}
  require('src.feedback.impact_response').body(g, front, iron.point, 0, 10, {
    dx = 0,
    dy = 0,
    dz = -1,
    normal = { 0, 0, 1 },
    material = 'trial_plate',
  })
  check(
    'an iron plate that absorbs a hit throws sparks by its material data',
    #g.view.particles > 0 and g.view.particles[1].material == 'metal'
  )

  -- An existing attack and an existing sidestep on one body: the unchanged AI
  -- uses both, each shows its own painted sheet, and a shot meets that sheet.
  local arena = Fixtures.arena(G)
  arena.state = 'playing'
  -- From 9 m it walks into the leap's range (3.5-7.5 m) under the knight's aim.
  local demon = arena:spawn('trial_plated', 16, 16)
  demon.awake, demon.memory, demon.spawnAge, demon.attack = true, 60, 1, 0
  local seen, surfaces = {}, true
  for _ = 1, 10 * 120 do
    local p = arena.player
    p.yaw = math.atan2(demon.x - p.x, demon.z - p.z)
    arena:update(1 / 120, {})
    if demon.hp <= 0 or p.hp <= 0 then
      break
    end
    local key = AbilityPose.select(arena, demon)
    local prepared = Surface.prepare(arena, demon)
    if key then
      seen[key] = true
      surfaces = surfaces
        and prepared.parts == Anatomy.abilities[key].frames[prepared.abilityFrame].parts
    else
      surfaces = surfaces and prepared.parts == annotation.frames[prepared.frame].parts
    end
  end
  check(
    string.format(
      'the AI leaps and sidesteps with one body; each shows its own sheet (leap %s, sidestep %s, %d evasions)',
      tostring(seen.leap),
      tostring(seen.evade),
      demon.evades or 0
    ),
    seen.leap and seen.evade and (demon.evades or 0) > 0
  )
  check('a shot meets the annotation of the sheet drawn now', surfaces)

  -- Everything removed again.
  A.trial_plated, Anatomy.layouts.trial_plated, Materials.trial_plate = nil, nil, nil
  check(
    'the content is back to the shipped entries',
    A.trial_plated == nil and Anatomy.layouts.trial_plated == nil and Materials.trial_plate == nil
  )
  return lines
end
return Tests

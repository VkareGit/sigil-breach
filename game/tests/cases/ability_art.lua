local Fixtures = require('tests.support.fixtures')
local Tests = {}

function Tests.run(Game, renderer)
  local Art = require('src.render.ability_art')
  local Geometry = require('src.enemies.geometry')
  local Surface = require('src.enemies.surface')
  local Pose = require('src.enemies.pose')
  local B = require('src.combat.ballistics')
  local Archetypes = require('src.content.enemies')
  local lines = {}
  local check = Fixtures.checker(lines, 'ability art: ', 'ability art: ')
  local near = Fixtures.within(1e-8, true)
  local g = Game.new('floor')
  g.ephemeral, g.state = true, 'playing'
  local e = g:spawn('imp', 16, 16)
  e.spawnAge, e.stun, e.attackKind = 1, 0, 'leap'
  e.attackSpec = Archetypes.imp.attacks[2]
  e.ai, e.windupDuration, e.windup = 'windup', 0.45, 0.45
  local key, frame = Art.select(g, e)
  check('imp gathers in a dedicated painted pose', key == 'leap' and frame == 1)
  e.windup = 0.1
  local _, gathered = Art.select(g, e)
  check('windup advances from its existing authoritative clock', gathered == 2)
  e.ai, e.leaping, e.leapFlight, e.phase, e.leapVY = 'strike', true, 0.8, 0.02, 4
  local _, launch = Art.select(g, e)
  e.phase, e.leapVY = 0.25, 1
  local _, ascent = Art.select(g, e)
  e.phase, e.leapVY = 0.6, -3
  local _, descent = Art.select(g, e)
  check(
    'launch ascent and descent have distinct authored silhouettes',
    launch == 3 and ascent == 4 and descent == 5
  )
  e.ai, e.leaping, e.didHit, e.phase, e.recover = 'recover', false, true, 0, 0.55
  local _, landed = Art.select(g, e)
  e.phase, e.recover = 0.3, 0.25
  local _, rising = Art.select(g, e)
  e.phase, e.recover = 0.5, 0.05
  local _, ready = Art.select(g, e)
  check(
    'landing rise and readiness follow the real recovery window',
    landed == 6 and rising == 7 and ready == 8
  )
  e.didHit = false
  check('an interrupted jump cannot show a successful landing', Art.select(g, e) == nil)
  e.ai, e.windup, e.didHit = 'windup', 0.1, true
  -- An Iron Thrall is its own definition (its look has no leap art).
  e.variant, e.archetype = 'armored', require('src.content.enemies').armored
  check(
    'armored creatures retain their separate identity and original art',
    Art.select(g, e) == nil
  )
  e.variant, e.archetype = nil, require('src.content.enemies').imp
  e.hp = 0
  check('death takes precedence over lingering ability state', Art.select(g, e) == nil)
  e.hp, e.ai = e.maxHp, 'hurt'
  check('a shot-down leaper retains its pain and falling-body art', Art.select(g, e) == nil)
  e.ai, e.stun = 'windup', 0.2
  check('broken guard retains the authoritative pain silhouette', Art.select(g, e) == nil)
  e.stun, e.spawnAge = 0, 0.2
  check('portal emergence cannot be overwritten by an ability preview', Art.select(g, e) == nil)
  -- The proving ground poses its gallery (its mode answers posed).
  e.spawnAge, e.previewFrame, g.mode, g.testField = 1, 9, 'field', {}
  check('explicit test-field gallery frames remain inspectable', Art.select(g, e) == nil)
  g.mode, g.testField, e.previewFrame = 'floor', nil, nil

  local owl = g:spawn('stolas', 18, 16)
  owl.ai, owl.spawnAge, owl.stun, owl.evadeSide = 'move', 1, 0, -1
  local durations = { 0, 0.10, 0.30, 0.50, 0.70, 0.85, 0.93, 0.98 }
  for expected, phase in ipairs(durations) do
    owl.evadeTime = Archetypes.stolas.move.evade.time * (1 - phase)
    local action, pose, mirror = Art.select(g, owl)
    check(
      'evasion phase ' .. expected .. ' follows its movement timer',
      action == 'evade' and pose == expected and mirror == 0
    )
  end
  owl.evadeSide = 1
  local _, _, mirrored = Art.select(g, owl)
  check('rightward evasion mirrors the authored leftward silhouette', mirrored == 1)
  owl.evadeTime = 0
  check('finished evasion returns immediately to normal locomotion', Art.select(g, owl) == nil)
  owl.evadeTime, owl.ai = 0.1, 'windup'
  check('a stale evasion timer cannot hide a committed attack', Art.select(g, owl) == nil)
  -- A creature with both a painted attack and a painted sidestep (a test-only
  -- copy, never game content): the art of its last attack, no longer running,
  -- must not hide the sidestep it is making now; the running attack wins.
  local mixed = g:spawn('imp', 20, 16)
  mixed.archetype = require('src.core.schema').copy(Archetypes.imp)
  mixed.archetype.appearance.evadeArt = 'evade'
  mixed.archetype.move.evade = require('src.core.schema').copy(Archetypes.stolas.move.evade)
  mixed.spawnAge, mixed.stun, mixed.attackKind = 1, 0, 'leap'
  mixed.attackSpec = mixed.archetype.attacks[2]
  mixed.ai, mixed.evadeSide = 'move', 1
  mixed.evadeTime = Archetypes.stolas.move.evade.time * 0.5
  local sidestep = Art.select(g, mixed)
  mixed.ai, mixed.windupDuration, mixed.windup = 'windup', 0.45, 0.45
  local gathering = Art.select(g, mixed)
  check(
    'a finished leap cannot hide the sidestep; the running leap shows its own art',
    sidestep == 'evade' and gathering == 'leap'
  )

  local loaded = renderer and renderer.abilityArt or Art.load()
  e.ai, e.windup, e.leaping, e.leapY = 'windup', 0.1, false, nil
  local before = {}
  for name, value in pairs(e) do
    before[name] = value
  end
  local rng = love.math.getRandomState()
  local poseBefore = { Geometry.pose(g, e) }
  -- What a shot meets: the prepared painted surface of the body.
  local function surfaceState(actor)
    local p = Surface.prepare(g, actor)
    return { p.baseY, p.width, p.height, p.x, p.z, p.lean, p.shift, p.parts, p.mask }
  end
  local surfaceBefore = surfaceState(e)
  local anchored = true
  for _ = 1, 40 do
    local _, hover, _, _, _, size = Geometry.pose(g, e)
    local image, region, paintX, paintY, baseY = Art.resolve(loaded, g, e)
    local action, selected = Art.select(g, e)
    anchored = anchored
      and image ~= nil
      and near(baseY + loaded[action].feet[selected] * size * paintY, hover)
      and near(paintX / region.width, paintY / region.height)
  end
  check('repeated rendering keeps pigment feet at the original body height', anchored)
  local unchanged = true
  for name, value in pairs(before) do
    unchanged = unchanged and e[name] == value
  end
  for name, value in pairs(e) do
    unchanged = unchanged and before[name] == value
  end
  local after = { Geometry.pose(g, e) }
  for index, value in ipairs(poseBefore) do
    unchanged = unchanged and after[index] == value
  end
  for index, value in ipairs(surfaceState(e)) do
    unchanged = unchanged and surfaceBefore[index] == value
  end
  check('render sampling cannot mutate AI physics or the painted hit surface', unchanged)
  check(
    'painted ability sampling consumes no gameplay randomness',
    love.math.getRandomState() == rng
  )

  local landmarkIssues = {}
  local measurements = { 'ability,pose,mirror,skull_error_m,ribcage_zone,one_source_pixel_m' }
  local function registered(actor, expected)
    local _, region, px, py, base, mirror, shift = Art.resolve(loaded, g, actor)
    local action, selected = Art.select(g, actor)
    local _, _, lean, _, _, size = Geometry.pose(g, actor)
    local yaw = math.atan2(g.player.x - actor.x, g.player.z - actor.z)
    local function landmark(point)
      local u = mirror == 1 and 1 - point[1] or point[1]
      local x = shift + (u - 0.5) * px * size + (1 - point[2]) * py * size * lean
      return actor.x + math.cos(yaw) * x,
        base + (1 - point[2]) * py * size,
        actor.z - math.sin(yaw) * x
    end
    -- The painted skull sits on the head registration of the base pose (the
    -- one anchor a sheet is scaled and placed by: enemies/pose.lua).
    local hx, hy, hz = landmark(region.head)
    local ax, ay, az = Pose.anchor(g, actor, 'head')
    local skull = math.sqrt((hx - ax) ^ 2 + (hy - ay) ^ 2 + (hz - az) ^ 2)
    check(
      action
        .. ' pose '
        .. expected
        .. ' mirror '
        .. mirror
        .. ' skull sits on the head registration',
      selected == expected and near(skull, 0)
    )
    -- A shot at the painted ribcage meets the torso of the drawn sheet.
    local tx, ty, tz = landmark(region.torso)
    local ox, oy, oz = B.origin(g)
    local dx, dy, dz = tx - ox, ty - oy, tz - oz
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    local _, zone = B.body(g, actor, ox, oy, oz, dx / length, dy / length, dz / length, 1000)
    local pixel = size * py / (loaded[action].image:getHeight() * region.rect[4])
    measurements[#measurements + 1] =
      string.format('%s,%d,%d,%.9f,%s,%.9f', action, expected, mirror, skull, tostring(zone), pixel)
    if zone ~= 'torso' then
      local message = string.format(
        '%s pose %d mirror %d ribcage meets %s',
        action,
        expected,
        mirror,
        tostring(zone)
      )
      landmarkIssues[#landmarkIssues + 1] = message
      print(message)
    end
  end
  for index = 1, 8 do
    e.phase, e.leapY, e.leaping, e.stun = 0, nil, false, 0
    if index <= 2 then
      e.ai, e.windup = 'windup', index == 1 and 0.4 or 0.1
    elseif index <= 5 then
      e.ai, e.leaping, e.leapFlight, e.leapY = 'strike', true, 0.8, 0.7
      e.phase, e.leapVY = index == 3 and 0.01 or 0.3, index == 5 and -2 or 2
    else
      e.ai, e.didHit, e.phase = 'recover', true, index == 6 and 0 or index == 7 and 0.3 or 0.5
      e.recover = 0.55 - e.phase
    end
    registered(e, index)
    for _, side in ipairs({ -1, 1 }) do
      owl.ai, owl.stun, owl.evadeSide = 'move', 0, side
      owl.evadeTime = Archetypes.stolas.move.evade.time * (1 - durations[index])
      registered(owl, index)
    end
  end
  local output = require('qa.output')
  local report = assert(io.open(output.path('ability-registration-v23.csv'), 'w'))
  report:write(table.concat(measurements, '\n') .. '\n')
  report:close()
  check('a shot at every painted ribcage meets the torso of the drawn sheet', #landmarkIssues == 0)

  for action, entry in pairs(Art.entries) do
    local data = love.image.newImageData(entry.path)
    local w, h = data:getDimensions()
    local sheet = loaded[action]
    check(
      action .. ' contains exactly eight registered action poses',
      #entry.actions == 8 and #sheet.frames == 8 and #sheet.feet == 8
    )
    for index, region in ipairs(sheet.frames) do
      local anchor = entry.anchors[index]
      local _, _, _, skullAlpha = data:getPixel(anchor[1], anchor[2])
      local _, _, _, torsoAlpha = data:getPixel(anchor[4], anchor[5])
      check(
        action .. ' pose ' .. index .. ' anatomical anchors lie on actual painted pigment',
        skullAlpha > 0.65 and torsoAlpha > 0.65
      )
      local rect = region.rect
      local left, top = math.floor(rect[1] * w + 0.5), math.floor(rect[2] * h + 0.5)
      local width, height = math.floor(rect[3] * w + 0.5), math.floor(rect[4] * h + 0.5)
      local cuts = 0
      for x = left, left + width - 1 do
        local _, _, _, a = data:getPixel(x, top)
        local _, _, _, b = data:getPixel(x, top + height - 1)
        cuts = cuts + (a > 0.65 and 1 or 0) + (b > 0.65 and 1 or 0)
      end
      for y = top, top + height - 1 do
        local _, _, _, a = data:getPixel(left, y)
        local _, _, _, b = data:getPixel(left + width - 1, y)
        cuts = cuts + (a > 0.65 and 1 or 0) + (b > 0.65 and 1 or 0)
      end
      check(action .. ' pose ' .. index .. ' has clear gutters without severed limbs', cuts < 4)
    end
    data:release()
  end
  return lines
end

return Tests

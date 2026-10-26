local Fixtures = require('tests.support.fixtures')
local Surface = require('src.enemies.surface')
local Masks = require('src.content.art.hit_masks')
local Anatomy = require('src.content.art.anatomy_regions')
local Damage = require('src.combat.damage')
local B = require('src.combat.ballistics')
local T = {}
function T.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'painted surfaces: ', '')
  local total, valid = 0, true
  for _, group in ipairs({ 'layouts', 'abilities' }) do
    for id, frames in pairs(Masks[group]) do
      local authored = Anatomy[group][id]
      valid = valid and authored and #authored.frames == #frames
      for i, mask in ipairs(frames) do
        total = total + 1
        valid = valid and #mask == Masks.grid
        local ids = {}
        for _, part in ipairs(authored.frames[i].parts) do
          assert(not ids[part.id], id .. ' frame ' .. i .. ' duplicate part id ' .. part.id)
          assert(
            require('src.content.ballistic_surfaces')[part.material],
            id .. ' unknown material ' .. tostring(part.material)
          )
          valid = valid and not ids[part.id] and #part.polygon >= 6 and #part.polygon % 2 == 0
          ids[part.id] = true
          valid = valid and require('src.content.ballistic_surfaces')[part.material] ~= nil
        end
      end
    end
  end
  check('all ' .. total .. ' baked frames have unique parts and registered materials', valid)
  -- A synthetic painted target: two independent shapes, one damage zone,
  -- one blocking object without a health zone, and decorative spell pigment.
  local mask = {}
  for row = 1, Masks.grid do
    mask[row] = string.rep('5', Masks.grid / 2)
  end
  local p = {
    mask = mask,
    x = 0,
    z = 0,
    baseY = 0,
    width = 2,
    height = 2,
    nx = 0,
    nz = 1,
    rx = 1,
    rz = 0,
    lean = 0,
    mirror = 0,
    parts = {
      {
        id = 'leg-a',
        zone = 'lower',
        material = 'flesh',
        polygon = { 0, 0, 0.4, 0, 0.4, 1, 0, 1 },
      },
      {
        id = 'leg-b',
        zone = 'lower',
        material = 'flesh',
        polygon = { 0.6, 0, 1, 0, 1, 1, 0.6, 1 },
      },
      {
        id = 'blade',
        zone = false,
        material = 'metal',
        polygon = { 0.4, 0, 0.5, 0, 0.5, 1, 0.4, 1 },
      },
      {
        id = 'glow',
        zone = false,
        material = 'effect',
        hittable = false,
        polygon = { 0.5, 0, 0.6, 0, 0.6, 1, 0.5, 1 },
      },
    },
  }
  local d, zone, c = Surface.ray(p, -0.5, 1, 3, 0, 0, -1, 4)
  check(
    'arbitrary limb ID is separate from shared damage zone',
    d == 3 and zone == 'lower' and c.shapeId == 'leg-a'
  )
  local _, _, other = Surface.ray(p, 0.5, 1, 3, 0, 0, -1, 4)
  check('second limb needs no engine special case', other.shapeId == 'leg-b')
  check(
    'aiming away from a close body cannot hit it',
    not Surface.ray(p, -0.5, 1, 0.01, 0, 0, 1, 4)
  )
  check('painted spell glow is not living flesh', not Surface.ray(p, 0.1, 1, 3, 0, 0, -1, 4))
  local bladeD, bladeZone, blade = Surface.ray(p, -0.1, 1, 3, 0, 0, -1, 4)
  local hp, _, guard = Damage.surface({ base = 20, impact = 10 }, {}, 0, blade)
  check(
    'held blade blocks without granting HP or poise damage',
    bladeD == 3 and bladeZone == false and hp == 0 and guard == 0
  )
  local bone = Damage.surface(
    { base = 20, impact = 10 },
    {},
    0,
    { zone = 'head', material = 'bone' }
  )
  local horn, _, hornGuard = Damage.surface(
    { base = 20, impact = 10 },
    {},
    0,
    { zone = 'torso', material = 'horn' }
  )
  check(
    'living skull remains vulnerable; horn transfers guard force',
    bone > 0 and horn == 0 and hornGuard == 10
  )
  local sd, _, sc = Surface.sweep(p, -0.5, 1, 3, 0, 0, -1, 4, 0.1)
  check(
    'finite projectile contacts before its centre crosses plane',
    sd < 2.9 and 2.9 - sd <= sc.tolerance + 1e-6
  )
  for _, hz in ipairs({ 60, 120, 240 }) do
    local speed, z, hit = 40, 3
    for _ = 1, hz do
      local range = speed / hz
      local t = Surface.sweep(p, -0.5, 1, z, 0, 0, -1, range, 0.1)
      if t then
        hit = 3 - z + t
        break
      end
      z = z - range
    end
    check(
      'continuous projectile at ' .. hz .. ' Hz has same first contact',
      hit and math.abs(hit - sd) < 1e-8
    )
  end
  check(
    'dead body blocks only during authored collapse',
    B.blocks({ hp = 0, deathTime = 0 }) and not B.blocks({ hp = 0, deathTime = 100 })
  )
  if G then
    local g = Fixtures.arena(G)
    local e = g:spawn('imp', 16, 22)
    e.spawnAge = 1
    g.player.pitch = 0
    local got
    g.bus:on('sim', 'VolleyResolved', function(event)
      got = event.report
    end)
    g:shoot()
    check(
      'real volley publishes individual part/material receipts',
      got and #got.contacts > 0 and got.contacts[1].shapeId and got.contacts[1].material
    )
    local sleeping = Fixtures.arena(G)
    local target = sleeping:spawn('imp', 16, 22)
    target.facing, target.awake, target.memory, target.spawnAge = math.pi, false, 0, 1
    sleeping.player.weapon, sleeping.player.pitch = 2, 0.1
    local before = Surface.prepare(sleeping, target)
    local awakenedFrame, shot
    sleeping.bus:on('sim', 'ShotFired', function()
      awakenedFrame = Surface.prepare(sleeping, target).frame
    end)
    sleeping.bus:on('sim', 'VolleyResolved', function(event)
      shot = event.report
    end)
    sleeping:shoot()
    -- This independently aimed pixel is head in front idle 27, torso in rear 19.
    -- The noise must not rotate the portrait before this shot is resolved.
    check(
      'gun noise cannot replace the visible head with the newly awakened back',
      before.frame == 27
        and awakenedFrame == 19
        and #shot.contacts == 1
        and shot.contacts[1].shapeId == 'head'
        and shot.contacts[1].zone == 'head'
    )
    local behind = Fixtures.arena(G)
    local front = behind:spawn('imp', 16, 22)
    local rear = behind:spawn('imp', 16, 20)
    front.hp, front.deathTime = 0, 0
    local ox, oy, oz = B.origin(behind)
    local direction
    for i = -30, 30 do
      local dx, dy, dz = B.direction(behind.player.yaw, i / 100)
      if
        B.body(behind, front, ox, oy, oz, dx, dy, dz, 20)
        and B.body(behind, rear, ox, oy, oz, dx, dy, dz, 20)
      then
        direction = { dx, dy, dz }
        break
      end
    end
    assert(direction, 'corpse fixture must have visibly overlapping pigment')
    local hit =
      B.traceVector(behind, direction[1], direction[2], direction[3], 20, B.prepare(behind))
    front.deathTime = 100
    local after =
      B.traceVector(behind, direction[1], direction[2], direction[3], 20, B.prepare(behind))
    check(
      'falling corpse shields a live body, settled corpse lets the same ray through',
      hit == front and after == rear
    )
  end
  return lines
end
return T

local Tests = {}
function Tests.run(G, check)
  local Field = require('src.run.test_field')
  local B = require('src.combat.ballistics')
  local Pose = require('src.enemies.pose')
  local Damage = require('src.combat.damage')
  local Weapons = require('src.content.weapons')
  local World = require('src.world.arena')
  local Run = require('src.run.descent')
  local function close(a, b)
    return math.abs(a - b) < 1e-6
  end
  local function shot(part, kind, wall)
    local g = Field.new(G)
    g.testing = true
    Field.close(g)
    g.weapon = 2
    local e = g:spawn(kind or 'imp', 16, 19.5)
    e.previewFrame = 1
    e.hp = 1000
    e.maxHp = 1000
    -- Independent skull/sternum pixels on frame 1, not collider centres.
    local marks = {
      imp = { head = { 174, 50 }, torso = { 140, 101 } },
      armored = { head = { 179, 45 }, torso = { 149, 94 } },
    }
    local point = marks[kind or 'imp'][part]
    local pose = Pose.sample(g, e)
    local source = love.image.newImageData(pose.sourcePath)
    local iw, ih = source:getDimensions()
    assert(
      select(4, source:getPixel(point[1], point[2])) > 0.65,
      'precision fixture aims at pigment'
    )
    local rect = pose.region.rect
    local u, v =
      (point[1] - rect[1] * iw) / (rect[3] * iw), (point[2] - rect[2] * ih) / (rect[4] * ih)
    source:release()
    local up = (1 - v) * pose.sy * pose.size
    local shift = (u - 0.5) * pose.sx * pose.size + up * pose.lean + pose.shift
    local x, z = e.x + math.cos(pose.yaw) * shift, e.z - math.sin(pose.yaw) * shift
    local _, eye = B.origin(g)
    local dx, dz = x - g.player.x, z - g.player.z
    g.player.yaw = math.atan2(dx, dz)
    g.player.pitch = math.atan2(pose.baseY + up - eye, math.sqrt(dx * dx + dz * dz))
    if wall then
      for x = 14, 18 do
        g.world.map[23][x] = 1
      end
      World.rebuild(g.world)
    end
    assert(g:shoot(), 'precision fixture did not fire')
    return g, e, g.view.shotReport
  end
  local torso, et, rt = shot('torso')
  local head, eh, rh = shot('head')
  check(
    'actual revolver ray identifies torso and head separately',
    rt.rays[1].part == 'torso' and rh.rays[1].part == 'head'
  )
  check(
    'head precision bonus comes from the real anatomical contact',
    rh.headHits == 1 and rh.hitTargets[1].headHits == 1 and rt.headHits == 0
  )
  local attack = Weapons.attack(head, 2)
  local expected, _, impulse = Damage.resolve(attack, eh, rh.rays[1].distance, 'head')
  check(
    'actual head shot damage agrees with the declared wound formula',
    close(rh.damage, expected) and close(1000 - eh.hp, expected)
  )
  check(
    'head precision increases injury without inventing momentum',
    -- 0.20: impact is guard damage (the head zone breaks a guard x1.25);
    -- the physical push of the round stays the same for head and torso.
    rh.damage > rt.damage * 1.3
      and close(rh.impact, impulse)
      and close(rh.impact, rt.impact * 1.25)
      and close(rh.push, rt.push)
  )
  check(
    'precision does not change ammunition or shot cadence',
    head.player.arsenal.judge.mag == torso.player.arsenal.judge.mag
      and head.cooldown == torso.cooldown
  )
  check(
    'precision marker belongs to the current confirmed shot',
    head.view.precisionHit and not torso.view.precisionHit
  )
  head:damageEnemy(eh, 5, 'powder')
  check(
    'a later non-ballistic hit cannot inherit an old head marker',
    not head.view.precisionHit and head.view.shotReport.headHits == 1
  )
  local armored, ea, ra = shot('head', 'armored')
  local armorExpected = Damage.resolve(Weapons.attack(armored, 2), ea, ra.rays[1].distance, 'head')
  check(
    'a head shot still obeys target armor and penetration',
    ra.headHits == 1
      and close(ra.damage, armorExpected)
      and ra.damage < rh.damage
      and ra.blocked > 0
  )
  local blocked, eb, rb = shot('head', 'imp', true)
  check(
    'a wall blocks precision damage and its feedback completely',
    eb.hp == 1000 and rb.targets == 0 and rb.headHits == 0 and blocked.view.hitmarker == 0
  )
  local raw, _, push = Damage.resolve(attack, {}, 8, 'head')
  local far, _, farPush = Damage.resolve(attack, {}, 30, 'head')
  check('head wound and momentum both retain distance attenuation', far < raw and farPush < push)
  local fake = Damage.resolve(attack, {}, 8, 'wing')
  local body = Damage.resolve(attack, {}, 8, 'torso')
  check('horns wings and unknown labels never become random critical hits', fake == body)
  local g = Field.new(G)
  g.testing = true
  Field.skirmish(g)
  check(
    'quick combat starts immediately in the existing arena with three live enemies',
    g.state == 'playing' and g.world.size == 31 and #g.enemies == 3 and g.testField.skirmish
  )
  check(
    'quick combat enables real damage and regular ammunition',
    not g.testField.invincible
      and not g.testField.frozen
      and g.player.hp == 100
      and g.player.armor == 40
      and g.player.arsenal.exorcist.mag == 2
      and g.player.arsenal.exorcist.reserve == 28
  )
  local legal = true
  for _, e in ipairs(g.enemies) do
    legal = legal
      and e.hp > 0
      and not World.solid(g.world, e.x, e.z, 0.45)
      and World.visible(g.world, g.player.x, g.player.z, e.x, e.z)
      and (e.x - g.player.x) ^ 2 + (e.z - g.player.z) ^ 2 >= 9
  end
  check(
    'quick combat targets begin visible with clearance and reaction time',
    legal and g.enemies[1].attack >= 1
  )
  check(
    'quick combat never owns an expedition snapshot',
    Run.snapshot(g) == nil and not Run.save(g)
  )
  g.player.armor = 0
  g.player.invuln = 0
  g:damagePlayer(1000)
  check(
    'quick combat death offers a real isolated retry',
    g.state == 'dead'
      and require('src.ui.test_field').controls(g)[1].id == 'field_skirmish'
      and not g.run.echo
  )
  Field.skirmish(g)
  check(
    'retry rebuilds exactly three targets with a fresh physical state',
    #g.enemies == 3 and g.player.hp == 100 and g.player.jump == 0 and g.state == 'playing'
  )
  local taken, absorbed, overkill = Damage.player(20, 100, 40)
  check(
    'player armor intercepts 55 percent with exact health conservation',
    taken == 9 and absorbed == 11 and overkill == 0 and taken + absorbed == 20
  )
  taken, absorbed, overkill = Damage.player(20, 100, 3)
  check(
    'depleted player armor only absorbs its remaining points',
    taken == 17 and absorbed == 3 and overkill == 0
  )
  taken, absorbed, overkill = Damage.player(200, 10, 40)
  check(
    'lethal player damage separates real health loss from overkill',
    taken == 10 and absorbed == 40 and overkill == 150
  )
  local valid = true
  for _, bad in ipairs({ -1, 0 / 0, math.huge }) do
    local a, b, c = Damage.player(bad, 100, 40)
    valid = valid and a == 0 and b == 0 and c == 0
  end
  check('invalid player damage cannot create healing or invalid health values', valid)
  local function hitsToDeath(armor)
    local f = Field.new(G)
    f.testing = true
    Field.skirmish(f)
    f.player.armor = armor
    local n = 0
    repeat
      f.player.invuln = 0
      f:damagePlayer(27)
      n = n + 1
    until f.state == 'dead' or n == 20
    return n, f
  end
  local unarmored = hitsToDeath(0)
  local protected, dead = hitsToDeath(40)
  check(
    '40 armor buys two additional 27-point contacts without permanent invulnerability',
    unarmored == 4 and protected == 6 and dead.player.hp == 0 and dead.player.armor == 0
  )
  g = Field.new(G)
  g.testing = true
  Field.skirmish(g)
  g:damagePlayer(20)
  local receipt = g.playerDamageReport
  g:damagePlayer(20)
  check(
    'one invulnerability window cannot consume health or armor twice',
    g.player.hp == 91 and g.player.armor == 29 and g.playerDamageReport == receipt
  )
  local foe = g.enemies[1]
  local kills = g.kills
  g:damageEnemy(foe, 10000, 'weapon')
  g:damageEnemy(foe, 10000, 'weapon')
  check(
    'enemy HP stops at zero and lethal overkill cannot award a second kill',
    foe.hp == 0 and g.kills == kills + 1
  )
  g = G.new('descent')
  g.testing = true
  g:start()
  assert(Run.ready(g))
  local first, visible, warning
  for i = 1, 480 do
    g:update(1 / 120, {})
    if #g.run.pending > 0 then
      warning = warning or i / 120
    end
    if #g.enemies > 0 then
      first = i / 120
      local e = g.enemies[1]
      visible = World.visible(g.world, g.player.x, g.player.z, e.x, e.z)
      break
    end
  end
  check(
    'first wave contact arrives promptly while retaining a visible spawn warning',
    first and first < 2.6 and warning and first - warning >= 1.19 and visible
  )
end
return Tests

local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local D = require('src.combat.damage')
  local W = require('src.content.weapons')
  local Reload = require('src.combat.reload')
  local Run = require('src.run.descent')
  local Save = require('src.storage.run_save')
  local Field = require('src.run.test_field')
  local E = require('src.run.economy')
  local B = require('src.combat.ballistics')
  local X = require('src.combat.explosives')
  local M = require('src.combat.melee')
  local Pose = require('src.enemies.pose')
  local T = require('src.content.tuning')
  local lines = {}
  local check = Fixtures.checker(lines, 'v09 ', '')
  local near = Fixtures.within(1e-6, true)
  local function fresh()
    local g = Field.new(G)
    Field.close(g)
    g.testing = true
    g.testField.invincible = false
    g.player.armor = 0
    g.player.yaw = math.pi
    return g
  end
  local function tick(g, seconds, input)
    for _ = 1, math.ceil(seconds * 120) do
      g:update(1 / 120, input or {})
    end
  end
  local function regular()
    local g = G.new('descent')
    g.testing = true
    g:start()
    return g
  end
  local g = fresh()
  local p = g.player
  g.weapon = 2
  local attack = W.attack(g, 2)
  local damage, blocked, impact = D.resolve(attack, { armorRating = 60 }, 3)
  check(
    'revolver is physical with independently defined damage, armor penetration and impulse',
    attack.damageType == 'physical'
      and near(damage, 70 / 1.3)
      and near(blocked, 70 - 70 / 1.3)
      and near(impact, 44)
  )
  check(
    'revolver keeps close power and loses energy continuously over its long range',
    near(D.resolve(attack, {}, 12), 70)
      and near(D.resolve(attack, {}, 36), 45.5)
      and D.resolve(attack, {}, 24) < 70
      and D.resolve(attack, {}, 24) > 45.5
  )
  check(
    'physical revolver is unaffected by a purely astral resistance',
    near(D.resolve(attack, { resistances = { astral = 0.6 } }, 3), 70)
  )
  for _, field in ipairs({ 'base', 'power', 'zone', 'upgrade', 'impact', 'penetration' }) do
    local bad = { base = 70, impact = 44 }
    bad[field] = 0 / 0
    local a, b, c = D.resolve(bad, {}, 3)
    check('NaN ' .. field .. ' cannot poison combat state', a == 0 and b == 0 and c == 0)
  end
  check(
    'nonfinite distance and armor return finite harmless results',
    D.resolve(attack, {}, math.huge) == 0
      and D.resolve(attack, { armorRating = 0 / 0 }, 2) == 0
      and D.resolve(attack, {}, 0 / 0) == 0
  )
  check(
    'negative damage factors never heal or impart negative knockback',
    D.resolve({ base = -10, impact = 10 }, {}, 0) == 0
      and D.resolve({ base = 10, power = -2 }, {}, 0) == 0
      and D.resolve({ base = 10, zone = -2 }, {}, 0) == 0
  )
  check(
    'negative distance is bounded to contact and negative armor cannot amplify damage',
    near(D.resolve(attack, { armorRating = -20 }, -3), 70)
  )
  local foe = g:spawn('imp', 16, 24)
  foe.hp = 10
  -- The ordinary reticle crosses the painted torso of this standing target.
  -- The retired cylinder centre sat below that flesh region.
  p.pitch, p.yaw = 0, math.pi
  check(
    'revolver consumes one physical round when it fires',
    g:shoot()
      and p.arsenal.judge.mag == 5
      and p.arsenal.exorcist.mag == 2
      and p.arsenal.judge.reserve == 72
  )
  check(
    'shot feedback separates health loss, overkill, armor and impact',
    near(g.view.shotReport.healthDamage, 10)
      and near(g.view.shotReport.damage, 70)
      and near(g.view.shotReport.overkill, 60)
      and g.view.shotReport.blocked == 0
      and near(g.view.shotReport.impact, 44)
      and g.view.lastDamage == 10
      and near(g.view.hitWeight, 0.1)
      and g.view.lastKill
  )
  check(
    'per-target report preserves hit segment and nearest actual impact distance',
    #g.view.shotReport.hitTargets == 1
      and g.view.shotReport.hitTargets[1].id == foe.id
      and g.view.shotReport.hitTargets[1].healthDamage == 10
      and g.view.shotReport.rays[1].part ~= nil
      and near(g.view.shotReport.distanceMin, g.view.shotReport.rays[1].distance)
  )
  g.elapsed = 0.1
  g:switchWeapon(1)
  g:switchWeapon(2)
  g.cooldown = 0
  check(
    'switching weapons cannot bypass the revolver firing interval',
    not g:shoot() and p.arsenal.judge.mag == 5
  )
  g.elapsed = 0.39
  g.cooldown = 0
  g.player.pitch = 0.9
  g:shoot()
  check(
    'a subsequent miss clears the previous kill and hit feedback',
    g.view.shotReport.targets == 0
      and g.view.lastDamage == 0
      and not g.view.lastKill
      and g.view.hitmarker == 0
      and g.view.shotReport.distanceMin == nil
  )
  g = fresh()
  g.weapon = 2
  p = g.player
  p.arsenal.judge.mag = 1
  p.arsenal.judge.reserve = 9
  check(
    'manual reload starts the complete physical cylinder timeline',
    g:reloadGun() and near(g.reloadDuration, 1.85) and g.reloadWeapon == 2
  )
  Reload.update(g, 1.15)
  check(
    'reserve ammunition is untouched before insertion',
    p.arsenal.judge.mag == 1 and p.arsenal.judge.reserve == 9 and p.arsenal.judge.open
  )
  Reload.update(g, 0.02)
  check(
    'insertion transfers only missing rounds once',
    p.arsenal.judge.mag == 6 and p.arsenal.judge.reserve == 4
  )
  g:switchWeapon(1)
  g:switchWeapon(2)
  check(
    'interrupting after insertion resumes closure without duplicating ammunition',
    p.arsenal.judge.mag + p.arsenal.judge.reserve == 10
      and g.reloadWeapon == 2
      and near(g.reloadOffset, 1.16)
      and g.reload > 0
      and not g:shoot()
  )
  Reload.update(g, 2)
  check(
    'closure leaves a usable full cylinder and exact conserved reserve',
    g.reload == 0
      and not p.arsenal.judge.open
      and p.arsenal.judge.mag == 6
      and p.arsenal.judge.reserve == 4
  )
  g = fresh()
  g.weapon = 2
  p = g.player
  p.arsenal.judge.mag = 0
  p.arsenal.judge.reserve = 3
  g:reloadGun()
  Reload.update(g, 0.5)
  g:switchWeapon(1)
  check(
    'interrupting before insertion neither removes reserve nor grants rounds',
    p.arsenal.judge.mag == 0 and p.arsenal.judge.reserve == 3 and p.arsenal.judge.open
  )
  g:switchWeapon(2)
  Reload.update(g, 2)
  check(
    'returning to an empty open cylinder loads a partial reserve without inventing rounds',
    p.arsenal.judge.mag == 3 and p.arsenal.judge.reserve == 0 and not p.arsenal.judge.open
  )
  g = fresh()
  g.weapon = 2
  p = g.player
  p.arsenal.judge.mag = 3
  p.arsenal.judge.reserve = 24
  g:reloadGun()
  Reload.update(g, 0.5)
  -- 0.25 (D3): a pull here would snap the cylinder shut and fire later
  -- (tests/cases/fight_feel.lua); the weapon API alone still refuses.
  check(
    'an open partially full cylinder cannot fire through the weapon API',
    p.arsenal.judge.open and not W.canFire(g)
  )
  g:switchWeapon(1)
  g:switchWeapon(2)
  check(
    'interrupting before insertion resumes loading even when old live rounds remain',
    near(g.reloadOffset, 0.68)
      and not p.arsenal.judge.loaded
      and p.arsenal.judge.mag == 3
      and p.arsenal.judge.reserve == 24
  )
  Reload.update(g, 2)
  check(
    'resumed partial-cylinder reload completes the missing rounds exactly once',
    p.arsenal.judge.mag == 6
      and p.arsenal.judge.reserve == 21
      and not p.arsenal.judge.open
      and not p.arsenal.judge.loaded
      and W.canFire(g)
  )
  g = fresh()
  g.weapon = 2
  p = g.player
  p.arsenal.judge.mag = 0
  p.arsenal.judge.reserve = 0
  local shots = g.shots
  check(
    'an empty revolver cannot fire or regenerate ammunition over time',
    not g:shoot()
      and (function()
        tick(g, 4)
        return p.arsenal.judge.mag == 0 and p.arsenal.judge.reserve == 0 and g.shots == shots
      end)()
  )
  for _, bad in ipairs({ -1, 7, 0.5, math.huge, 0 / 0 }) do
    g = fresh()
    g.weapon = 2
    g.player.arsenal.judge.mag = bad
    check(
      'invalid cylinder value ' .. tostring(bad) .. ' cannot fire or reload',
      not g:shoot() and not g:reloadGun() and g.shots == 0
    )
  end
  g = fresh()
  g.weapon = 2
  g.player.arsenal.judge.mag = 0
  g.player.arsenal.judge.reserve = 6
  g:reloadGun()
  local frames = {}
  for _ = 1, 230 do
    frames[Reload.frame(g)] = true
    g.view.shotAge = g.view.shotAge + 1 / 120
    Reload.update(g, 1 / 120)
  end
  local complete = true
  for frame = 5, 16 do
    complete = complete and frames[frame]
  end
  check(
    'revolver reload traverses all twelve authored loading frames without a firing flash',
    complete
      and not frames[2]
      and not frames[3]
      and not frames[4]
      and g.player.arsenal.judge.mag == 6
      and g.player.arsenal.judge.reserve == 0
  )
  g = regular()
  Run.openShop(g)
  g:switchWeapon(2)
  p = g.player
  p.arsenal.judge.reserve = 71
  local name = E.describe(g, 'ammo')
  local oldShells = p.arsenal.exorcist.reserve
  local money = g.run.wallet
  check(
    'revolver partial purchase names and charges exactly the one missing round',
    name == '1 ROUND / JUDGE'
      and E.quote(g, 'ammo') == 3
      and Run.buy(g, 'ammo')
      and p.arsenal.judge.reserve == 72
      and p.arsenal.exorcist.reserve == oldShells
      and g.run.wallet == money - 3
  )
  money = g.run.wallet
  check(
    'full revolver reserve rejects repeat purchases without charging',
    not Run.buy(g, 'fill') and g.run.wallet == money
  )
  p.abilityState.powder.uses = 2
  check(
    'charge purchase adds one finite item at its advertised price',
    Run.buy(g, 'charge') and p.abilityState.powder.uses == 3 and g.run.wallet == money - 30
  )
  money = g.run.wallet
  check(
    'full charge capacity cannot consume more currency',
    not Run.buy(g, 'charge') and g.run.wallet == money
  )
  g.run.wallet = 0 / 0
  local before = p.arsenal.judge.reserve
  check(
    'a nonfinite wallet cannot contaminate an economy transaction',
    not Run.buy(g, 'ammo') and p.arsenal.judge.reserve == before
  )
  -- Old saves still load: SIGIL06 is migrated into the arsenal by weapon id.
  g = regular()
  g.run.wallet = 313
  g.run.wave = 3
  g.run.owned.pierce = true
  g.run.glyph = 'pierce'
  p = g.player
  p.arsenal.judge.mag = 2
  p.arsenal.judge.reserve = 9
  p.abilityState.powder.uses = 1
  local function signed(payload)
    local a, b = 1, 0
    for i = 1, #payload do
      a = (a + payload:byte(i)) % 65521
      b = (b + a) % 65521
    end
    return 'SIGIL06\n7\n' .. tostring(b * 65536 + a) .. '\n' .. payload
  end
  -- The current format (SIGIL07) and the same state as 0.23 wrote it (SIGIL06).
  local encoded = Save.encode(Run.snapshot(g), 7)
  local legacy = require('tests.support.legacy_save').encode06(Run.snapshot(g), 7)
  local payload = assert(legacy:match('^SIGIL06\n%d+\n%d+\n(.*)$'))
  local old = {}
  for line in payload:gmatch('[^\n]+') do
    if
      not (
        line:match('^revolver=')
        or line:match('^checkrevolver=')
        or line:match('^charges=')
        or line:match('^checkcharges=')
      )
    then
      old[#old + 1] = line
    end
  end
  local decoded = assert(Save.decode(signed(table.concat(old, '\n'))))
  local restored = regular()
  Run.load(restored, decoded)
  check(
    'an actual SIGIL06 payload without new records keeps progress and gains safe physical defaults',
    restored.run.wallet == 313
      and restored.run.wave == 3
      and restored.run.owned.pierce
      and restored.run.glyph == 'pierce'
      and restored.player.arsenal.judge.mag == 6
      and restored.player.arsenal.judge.reserve == 24
      and restored.player.abilityState.powder.uses == 2
      and Save.prefix == 'descent-v06'
  )
  decoded = assert(Save.decode(encoded))
  check(
    'new optional ammunition records round-trip without altering old inventory fields',
    decoded.inventory.weapons.judge.mag == 2
      and decoded.inventory.weapons.judge.reserve == 9
      and decoded.inventory.abilities.powder == 1
      and decoded.inventory.weapons.exorcist.reserve == 28
      and decoded.wallet == 313
  )
  for _, value in ipairs({ '-1,9', '7,9', '2,73', 'nan,9', '2,1.5' }) do
    check(
      'checksummed invalid revolver inventory ' .. value .. ' is rejected',
      Save.decode(signed(payload:gsub('revolver=2,9', 'revolver=' .. value, 1))) == nil
    )
  end
  check(
    'checksummed invalid charge capacity is rejected',
    Save.decode(signed(payload:gsub('charges=1', 'charges=4', 1))) == nil
  )
  g = regular()
  g.player.arsenal.judge.mag, g.player.arsenal.judge.reserve, g.player.abilityState.powder.uses =
    2, 9, 1
  Run.ready(g)
  g.run.phase = 'wave'
  g.player.arsenal.judge.mag, g.player.arsenal.judge.reserve, g.player.abilityState.powder.uses =
    0, 0, 0
  g.player.invuln = 0
  g:damagePlayer(1000)
  local saved = assert(Save.decode(Save.encode(Run.snapshot(g), 9)))
  restored = regular()
  Run.load(restored, saved)
  Run.retry(restored)
  check(
    'death save and retry restore the exact entry cylinder, reserve and charge count',
    restored.player.arsenal.judge.mag == 2
      and restored.player.arsenal.judge.reserve == 9
      and restored.player.abilityState.powder.uses == 1
      and restored.run.phase == 'preparing'
  )
  -- Blast geometry and timing are physical and use the same damage resolver.
  g = fresh()
  p = g.player
  p.hp = 70
  local bullets = g.bullets
  g.bullets[1] = { x = 7, y = 1, z = 7, vx = 0, vy = 0, vz = 0, life = 9 }
  check(
    'Q throws a finite world object without healing or erasing hostile projectiles',
    g:cast(1)
      and p.abilityState.powder.uses == 2
      and #g.charges == 1
      and p.hp == 70
      and g.bullets == bullets
      and #g.bullets == 1
  )
  check(
    'Q cannot spend all charges on one repeated input frame',
    not g:cast(1) and p.abilityState.powder.uses == 2 and #g.charges == 1
  )
  tick(g, 0.975)
  check(
    'the full fuse warning precedes the first explosion',
    #g.charges == 1 and g.explosionReport == nil
  )
  tick(g, 0.04)
  check(
    'the charge explodes exactly once after its fuse',
    #g.charges == 0 and g.explosionReport ~= nil
  )
  g = fresh()
  p = g.player
  p.hp = 80
  p.armor = 0
  X.explode(g, { x = p.x, y = 1, z = p.z })
  check(
    'a point-blank blast has bounded real self-damage and no life steal',
    near(p.hp, 35) and near(g.explosionReport.selfDamage, 45)
  )
  g = fresh()
  g.player.z = 30
  foe = g:spawn('imp', 11, 25)
  X.explode(g, { x = 13, y = 1, z = 25 })
  check(
    'a solid pillar blocks blast damage even inside the nominal radius',
    foe.hp == foe.maxHp and g.explosionReport.targets == 0
  )
  g = fresh()
  g.player.z = 30
  local nearEnemy = g:spawn('imp', 16, 24)
  local farEnemy = g:spawn('imp', 16, 21)
  nearEnemy.hp = 1000
  farEnemy.hp = 1000
  X.explode(g, { x = 16, y = 1.1, z = 24 })
  check(
    'blast falloff rewards proximity and cannot reach beyond four metres',
    1000 - nearEnemy.hp > 1000 - farEnemy.hp and farEnemy.hp < 1000 and nearEnemy.hp == 820
  )
  local charges = g.player.abilityState.powder.uses
  g:damageEnemy(nearEnemy, 2000, 'charge')
  check(
    'kills cannot refund charges, grant energy or heal the player',
    g.player.abilityState.powder.uses == charges and g.player.souls == 0 and g.player.hp == 100
  )
  g = fresh()
  g.charges = { { x = 13, y = 1, z = 25, vx = -12, vy = 0, vz = 0, fuse = 1, spin = 0 } }
  X.update(g, 0.1)
  check(
    'fast thrown charge sweeps into the pillar and bounces on its near side',
    g.charges[1].x > 12.5 and g.charges[1].vx > 0
  )
  g = fresh()
  g.charges = { { x = 16, y = 0.08, z = 27, vx = 1, vy = -12, vz = 0, fuse = 1, spin = 0 } }
  X.update(g, 0.1)
  check(
    'falling charge cannot tunnel below the floor',
    g.charges[1].y >= 0.025 and g.charges[1].vy >= 0
  )
  -- Direct contacts probe geometry independently of AI choice and animation timing.
  g = fresh()
  p = g.player
  p.x, p.z = 16, 27
  check(
    'swept claw catches a stationary body only on its finite path',
    M.contact(g, 16, 26.4, 16, 27.4, 0.94, 0.18)
      and not M.contact(g, 17, 26.4, 17, 27.4, 0.94, 0.18)
  )
  p.jump = 1.5
  check('a jump clears a low claw volume', not M.contact(g, 16, 26.4, 16, 27.4, 0.94, 0.18))
  p.jump = 0
  p.x = 17
  check(
    'relative sweep catches a fast player crossing the claw between ticks',
    M.contact(g, 16, 27, 16, 27, 0.94, 0.18, { x = 15, z = 27, jump = 0, crouch = 0 })
  )
  p.x, p.z = 11, 25
  check('melee sweep cannot pass through a pillar', not M.contact(g, 13, 25, 10, 25, 0.94, 0.18))
  local World = require('src.world.arena')
  check(
    'a large collision footprint includes the solid centre cell between its empty corners',
    World.solid(g.world, 12, 25, 0.55) and World.solid(g.world, 13, 25, 0.55)
  )
  check(
    'the circular player footprint clears empty diagonal space and blocks the actual pillar corner',
    not World.solid(g.world, 13, 25, 0.22)
      and not World.solid(g.world, 12.71, 25.71, 0.22)
      and not World.solid(g.world, 12.52, 25.52, 0.22)
      and World.solid(g.world, 12.45, 25.45, 0.22)
  ) -- 0.14 round pillar r .46
  local function furfur(count)
    local trial = fresh()
    local e = trial:spawn('furfur', 16, 21)
    e.awake = true
    e.attack = 0
    e.attackCount = count or 0
    tick(trial, 0.02)
    return trial, e
  end
  g, foe = furfur(0)
  local aimX, aimZ = foe.aimX, foe.aimZ
  check(
    'Furfur starts a readable charge windup without early contact damage',
    foe.ai == 'windup'
      and foe.attackKind == 'charge'
      and foe.windup > 0.8
      and g.player.hp == 100
      and not foe.armored
  )
  g.player.x = 19
  tick(g, 1.8)
  check(
    'sidestepping a committed charge avoids it without retargeting',
    g.player.hp == 100 and foe.aimX == aimX and foe.aimZ == aimZ and math.abs(foe.x - 16) < 0.1
  )
  g, foe = furfur(0)
  tick(g, 1.65)
  check('remaining in the committed charge lane takes one real hit', g.player.hp == 72)
  g, foe = furfur(1)
  check(
    'Furfur lightning exposes its fixed impact footprint before damage',
    foe.attackKind == 'lightning'
      and #g.hazards == 1
      and g.hazards[1].kind == 'lightning'
      and g.hazards[1].delay > 1
      and g.player.hp == 100
  )
  g.player.x = 19
  tick(g, 1.4)
  check('leaving the marked lightning circle avoids the strike', g.player.hp == 100)
  g, foe = furfur(1)
  tick(g, 1.4)
  check('a lightning circle deals one hit rather than repeated frame damage', g.player.hp == 70)
  g, foe = furfur(1)
  foe.hp = 0
  tick(g, 1.4)
  check(
    'killing the caster cancels its pending lightning hazard',
    g.player.hp == 100 and #g.hazards == 0
  )
  g = fresh()
  g.player.x, g.player.z = 11, 25
  foe = g:spawn('furfur', 13, 25)
  foe.ai = 'strike'
  foe.attackKind = 'charge'
  foe.phase = 0
  foe.chargeTime = 0.85
  foe.lungeX, foe.lungeZ = -1, 0
  foe.aimX, foe.aimZ = 11, 25
  foe.awake = true
  tick(g, 0.8)
  check(
    'Furfur charge stops at solid geometry without an automatic hit behind it (x='
      .. foe.x
      .. ', hp='
      .. g.player.hp
      .. ')',
    foe.x > 12.5
      and not require('src.world.arena').solid(g.world, foe.x, foe.z, 0.25)
      and g.player.hp == 100
  )
  g = fresh()
  Field.action(g, 'field_hitboxes')
  local enabled = g.testField.hitboxes
  Field.action(g, 'field_hitboxes')
  check(
    'sandbox can toggle the actual registered collision-volume overlay',
    enabled and not g.testField.hitboxes
  )
  g = fresh()
  foe = g:spawn('imp', 16, 24)
  foe.previewFrame = 1
  local pose = Pose.sample(g, foe)
  local source = love.image.newImageData(pose.sourcePath)
  local iw, ih = source:getDimensions()
  local rect = pose.region.rect
  -- Independent source pixels: empty plaster left of the skull and the sternum.
  -- Neither comes from the retired cylinders or the new collision mask.
  local function paintedRay(px, py)
    local u = (px - rect[1] * iw) / (rect[3] * iw)
    local v = (py - rect[2] * ih) / (rect[4] * ih)
    local up = (1 - v) * pose.sy * pose.size
    local lateral = (u - 0.5) * pose.sx * pose.size + up * pose.lean + pose.shift
    local x = foe.x + math.cos(pose.yaw) * lateral
    local z = foe.z - math.sin(pose.yaw) * lateral
    return B.body(g, foe, x, pose.baseY + up, z + 3, 0, 0, -1, 10)
  end
  local airAlpha = select(4, source:getPixel(90, 35))
  local torsoAlpha = select(4, source:getPixel(140, 101))
  check(
    'a ray beside the painted head misses the independently measured empty source pixel',
    airAlpha < 0.1 and paintedRay(90, 35) == nil
  )
  local bodyHit, bodyZone = paintedRay(140, 101)
  check(
    'the painted sternum remains hittable as torso',
    torsoAlpha > 0.65 and bodyHit ~= nil and bodyZone == 'torso'
  )
  source:release()
  local hp = g.player.hp
  local time = g.time
  g:damagePlayer(-10)
  g:damagePlayer(0 / 0)
  g:update(0 / 0, {})
  g:update(-1, {})
  check(
    'invalid damage and time inputs cannot heal or corrupt the live simulation',
    g.player.hp == hp and g.time == time
  )
  foe.hp = 7
  g:damageEnemy(foe, 180, 'charge')
  check(
    'explosive hit feedback reports actual remaining health rather than overkill',
    foe.hp <= 0 and g.view.lastDamage == 7 and g.view.lastKill
  )
  for _, bad in ipairs({ -1, 4, 0.5, math.huge, 0 / 0 }) do
    g = fresh()
    g.player.abilityState.powder.uses = bad
    check(
      'invalid charge inventory ' .. tostring(bad) .. ' cannot create physical ordnance',
      not g:cast(1) and #g.charges == 0
    )
  end
  for _, line in ipairs(require('tests.cases.render').run(G, renderer)) do
    lines[#lines + 1] = line
  end
  for _, line in ipairs(require('tests.cases.audio').run()) do
    lines[#lines + 1] = line
  end
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests

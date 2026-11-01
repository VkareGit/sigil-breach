-- Exercise the production sandbox, including its persistence boundaries.
-- No testing flag is used to make sandbox writes disappear.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
-- Headless as well as part of the field suite: reset is a combat boundary,
-- distinct from resupply, and must not depend on a rendered frame to settle.
function Tests.resetTrial(G)
  local Field = require('src.run.test_field')
  local Rules = require('src.combat.rules')
  local Effects = require('src.combat.effects')
  local Capabilities = require('src.session.capabilities')
  local Snapshot = require('src.session.snapshot')
  local Journal = require('src.session.journal')
  local Integrity = require('src.session.integrity')
  local lines = {}
  local check = Fixtures.checker(lines, 'test field reset ', '')
  local near = Fixtures.within(1e-9, true)
  local g = Field.new(G)
  local p = g.player
  g.testField.invincible = false
  Field.close(g)
  p.armor = 0
  local source = g:spawn('imp', p.x + 2, p.z)
  g:damagePlayer(
    { base = 35, impact = require('src.content.characters').standard().body.poise + 1 },
    source.x,
    source.z,
    nil,
    source
  )
  p.invuln = 0
  g:damagePlayer({ base = 1, impact = 9 }, source.x, source.z, nil, source)
  Effects.apply(g, p, {
    {
      id = 'field-reset-burn',
      kind = 'periodic',
      duration = 2,
      interval = 0.01,
      stacking = 'replace',
      packet = { base = 1, damageType = 'fire' },
    },
  }, source)
  check(
    'a real blow leaves wounds, stagger, guard damage, momentum and world hit-stop',
    Rules.has(p, 'wounded')
      and Rules.has(p, 'staggered')
      and p.poise == 9
      and p.guardQuiet == 0
      and (p.pushX or 0) ~= 0
      and Capabilities.held(g)
      and p.effectState
  )
  local conditions, effects, push = p.conditions, p.effectState, p.pushX
  Field.refill(g)
  check(
    'resupply preserves an ongoing fight and is not a full trial reset',
    p.hp == require('src.content.characters').standard().body.hp
      and p.conditions == conditions
      and p.effectState == effects
      and p.poise == 9
      and p.guardQuiet == 0
      and p.pushX == push
      and Capabilities.held(g)
      and #g.enemies == 1
  )
  p.slamLock, p.pushOwner = 0.4, source.id
  p.airCap, p.level = 14, 3
  p.dashX, p.dashZ, p.perfectUsed, p.dodgeFromX, p.dodgeFromZ = 1, 0, true, p.x - 1, p.z
  p.slideX, p.slideZ = 0, -1
  p.faction, p.resist = 'knight', { fire = 0.2 }
  g.frame = { supportLift = 2, supportLifts = { [p.id] = 2 } }
  g.lastSlam = { x = p.x, z = p.z, speed = 12, player = true }
  g.collisions, g.slams = 4, 2
  g.cancelledAttacks, g.evadeCount, g.retargets, g.attackStarts, g.leapStarts = 1, 2, 3, 4, 5
  g.testField.hitboxes = true
  g.view.motion = false
  g.view.damageNumbers, g.view.numberSerial = { { value = 35, age = 0 } }, 7
  g.view.staggerFlash, g.view.killPunch, g.view.breakKill, g.view.perfectDodge = 0.2, 0.3, 0.4, 0.5
  g.view.markClocks = { slide = 0.1 }
  g:look(0.1, 0)
  local id, loadout, arsenal = p.id, p.loadout, p.arsenal
  local abilities, abilityState, resist = p.abilities, p.abilityState, p.resist
  local clock, nextId, rng = g.time, g.nextId, g.rng
  local generation = g._observationGeneration
  local stalePresentation = 0
  g.bus:on('present', 'PlayerStaggered', function()
    stalePresentation = stalePresentation + 1
  end)
  g.bus:beginStep()
  g.bus:emit('PlayerStaggered', { time = 0.2, actor = p.id })
  local initial = Snapshot.capture(g)
  local stage = Field.new(G)
  Snapshot.restore(stage, initial)
  require('src.session.encounter').clearStage(stage)
  check(
    "clearing a wave still preserves the knight's conditions, guard and ongoing exposure",
    Rules.has(stage.player, 'wounded')
      and Rules.has(stage.player, 'staggered')
      and stage.player.poise == 9
      and stage.player.effectState
      and Capabilities.held(stage)
  )
  local recording = Journal.record(g)
  assert(g:act('catalog', 'field_reset'))
  Journal.stop(g)
  check(
    'reset cancels wounds, stagger, periodic exposure, guard damage and every shove',
    p.conditions == nil
      and p.effectState == nil
      and (p.poise or 0) == 0
      and p.guardQuiet == nil
      and (p.pushX or 0) == 0
      and (p.pushZ or 0) == 0
      and p.pushOwner == nil
      and (p.slamLock or 0) == 0
      and not Capabilities.held(g)
  )
  check(
    'reset forgets the previous floor, air cap, dodge and slide direction latches',
    p.level == nil
      and p.airCap == nil
      and p.dashX == nil
      and p.dashZ == nil
      and p.perfectUsed == nil
      and p.dodgeFromX == nil
      and p.dodgeFromZ == nil
      and p.slideX == nil
      and p.slideZ == nil
  )
  check(
    'reset discards old support snapshots, contact receipts and encounter counters',
    g.frame == nil
      and g.lastSlam == nil
      and (g.intensity or 0) == 0
      and (g.collisions or 0) == 0
      and (g.slams or 0) == 0
      and (g.cancelledAttacks or 0) == 0
      and (g.evadeCount or 0) == 0
      and (g.retargets or 0) == 0
      and (g.attackStarts or 0) == 0
      and (g.leapStarts or 0) == 0
  )
  g.bus:flush()
  check(
    'no old damage numbers, flashes or queued hit presentation escape into the next trial',
    stalePresentation == 0
      and not g.view.damageNumbers
      and not g.view.numberSerial
      and not g.view.markClocks
      and (g.view.staggerFlash or 0) == 0
      and (g.view.killPunch or 0) == 0
      and (g.view.breakKill or 0) == 0
      and (g.view.perfectDodge or 0) == 0
  )
  check(
    'reset preserves actor identity, equipment, configuration and lifetime identities',
    g.player == p
      and p.id == id
      and p.loadout == loadout
      and p.arsenal == arsenal
      and p.abilities == abilities
      and p.abilityState == abilityState
      and p.resist == resist
      and p.faction == 'knight'
      and g.time == clock
      and g.nextId == nextId
      and g.rng == rng
      and g._observationGeneration > generation
      and g.testField.hitboxes
      and not g.testField.invincible
      and not g.view.motion
  )
  local replay = Field.new(G)
  Snapshot.restore(replay, initial)
  Journal.replay(replay, Journal.decode(Journal.encode(recording)))
  local difference = Integrity.difference(recording.final, Integrity.capture(replay))
  check(
    'a reset command replays exactly from a wounded mid-fight snapshot: ' .. (difference or 'equal'),
    difference == nil
  )
  Field.close(g)
  local clean = Field.new(G)
  clean.testField.invincible = false
  clean.player.resist = { fire = 0.2 }
  Field.close(clean)
  -- Cross multiple old pulse intervals and accelerate beyond the wounded
  -- speed cap; one short step at rest could hide both residual effects.
  for _ = 1, 12 do
    g:update(1 / 120, { forward = 1 })
    clean:update(1 / 120, { forward = 1 })
  end
  check(
    'resumed movement matches a fresh trial across old pulse intervals without damage or world hold',
    near(p.x, clean.player.x)
      and near(p.z, clean.player.z)
      and near(p.vx, clean.player.vx)
      and near(p.vz, clean.player.vz)
      and p.hp == clean.player.hp
      and Rules.speedScale(p) == 1
      and Rules.recoveryScale(p) == 1
      and Capabilities.missilesFly(g)
  )
  g:damagePlayer({ base = 1, impact = 9 }, p.x + 2, p.z)
  clean:damagePlayer({ base = 1, impact = 9 }, clean.player.x + 2, clean.player.z)
  check(
    'the next blow starts from clean guard and has the same result as a fresh trial',
    p.poise == clean.player.poise
      and p.hp == clean.player.hp
      and p.armor == clean.player.armor
      and near(p.pushX, clean.player.pushX)
      and near(p.pushZ, clean.player.pushZ)
      and not Rules.has(p, 'staggered')
  )
  return lines
end
function Tests.run(G, renderer)
  local Field = require('src.run.test_field')
  local Modes = require('src.run.modes')
  local Save = require('src.storage.save')
  local World = require('src.world.arena')
  local Definitions = require('src.content.enemy_catalog')
  local Animation = require('src.enemies.animation')
  local lines = {}
  local check = Fixtures.checker(lines, 'test field ', '')
  local near = Fixtures.within(1e-6, true)
  local writes = {}
  local oldWrite, oldFileWrite = Save.write, love.filesystem.write
  Save.write = function(...)
    writes[#writes + 1] = 'Save.write'
    return false, 'Unexpected sandbox save'
  end
  love.filesystem.write = function(name, ...)
    writes[#writes + 1] = name
    return false
  end
  local ok, problem = xpcall(function()
    for _, line in ipairs(Tests.resetTrial(G)) do
      lines[#lines + 1] = line
    end
    local chapel = G.new('floor')
    chapel.ephemeral = true
    chapel:start()
    chapel.run.wallet = 317
    chapel.run.owned = { pierce = true }
    chapel.run.glyph = 'pierce'
    local function fresh()
      local g = Field.new(G)
      g.ephemeral = false
      return g
    end
    local g = fresh()
    check(
      'sandbox opens a separate empty arena without owning an chapel save',
      g ~= chapel
        and g.world ~= chapel.world
        and g.run ~= chapel.run
        and g.run.owned ~= chapel.run.owned
        and g.testField
        and g.state == 'field_catalog'
        and g.world.size == 31
        and #g.enemies == 0
        and #g.pickups == 0
        and g.availableSave == nil
    )
    check(
      'sandbox catalog exposes every current enemy, both weapons and three named seals',
      #Field.catalog.enemies == 6 and #Field.weapons(g) == 2 and #Field.catalog.seals == 3
    )
    for _, kind in ipairs({ 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }) do
      g = fresh()
      local created = assert(Field.spawn(g, kind, 1))
      local e = created[1]
      local d = Definitions[kind]
      check(
        kind .. ' sandbox target uses the real health, armor, speed and resistances',
        #created == 1
          and #g.enemies == 1
          and e.hp == d.hp
          and e.maxHp == d.hp
          and e.armorRating == d.armor
          and e.speed == d.speed
          and e.resistances == d.resistances
          and e.variant == d.variant
      )
      local distance = math.sqrt((e.x - g.player.x) ^ 2 + (e.z - g.player.z) ^ 2)
      check(
        kind .. ' sandbox target spawns visible, clear of walls and outside the player',
        not World.solid(g.world, e.x, e.z, kind == 'boss' and 0.7 or 0.45)
          and distance >= 3
          and World.visible(g.world, g.player.x, g.player.z, e.x, e.z)
      )
      Field.pose(g, 1)
      local frame = Animation.pose(g, e)
      Field.pose(g, -1)
      local first = Animation.pose(g, e)
      Field.pose(g, -1)
      local last = Animation.pose(g, e)
      local frames = Animation.frameCount(kind)
      check(
        kind .. ' pose controls wrap through the authored atlas while AI is frozen',
        g.testField.frozen and frame == 2 and first == 1 and last == frames
      )
      Field.toggleFreeze(g)
      check(
        kind .. ' returns from pose inspection to normal animation',
        not g.testField.frozen and e.previewFrame == nil
      )
    end
    g = fresh()
    local batch = assert(Field.spawn(g, 'imp', 3))
    local spaced = true
    for i, a in ipairs(batch) do
      for j = 1, i - 1 do
        local b = batch[j]
        spaced = spaced and (a.x - b.x) ^ 2 + (a.z - b.z) ^ 2 >= 1.8 ^ 2
      end
    end
    check(
      'three-target batch reserves three distinct usable positions',
      #batch == 3 and #g.enemies == 3 and spaced
    )
    local before = #g.enemies
    check(
      'unknown targets and unsupported batch sizes do not partially spawn',
      Field.spawn(g, 'unknown', 1) == nil
        and Field.spawn(g, 'imp', 2) == nil
        and #g.enemies == before
    )
    -- The catalogue (F2) summons through portals: gates glow, then the
    -- demons step out with the portal's arrival, set on the knight.
    g = fresh()
    local glow = require('src.content.field').gates.glow
    local gates = assert(Field.summon(g, 'imp', 3))
    Field.close(g)
    local waiting = #gates == 3 and #g.run.pending == 3 and #g.enemies == 0
    for _ = 1, math.floor(glow * 120) - 2 do
      g:update(1 / 120, {})
    end
    local stillWaiting = #g.enemies == 0
    for _ = 1, 6 do
      g:update(1 / 120, {})
    end
    local stepped, facing = #g.enemies == 3 and #g.run.pending == 0, true
    for _, e in ipairs(g.enemies) do
      local toward = math.atan2(g.player.x - e.x, g.player.z - e.z)
      facing = facing
        and e.fieldKind == 'imp'
        and e.spawnAge < 0.6
        and e.awake
        and math.abs(math.atan2(math.sin(e.facing - toward), math.cos(e.facing - toward))) < 0.6
    end
    check(
      'a catalogue summons opens portals that glow before the demons step out, set on the knight',
      waiting and stillWaiting and stepped and facing
    )
    g = fresh()
    for _ = 1, 6 do
      assert(Field.summon(g, 'imp', 3))
    end
    check(
      'portals still opening count toward the limit of live demons',
      Field.summon(g, 'imp', 3) == nil and #g.run.pending == 18 and Field.spawn(g, 'imp', 3) == nil
    )
    for slot = 1, 2 do
      g = fresh()
      local target = assert(Field.spawn(g, 'armored', 1))[1]
      Field.close(g)
      g.player.weapon = slot
      target.x, target.z = 16, 24
      g.player.yaw = math.pi
      g.player.pitch = 0
      local normal = G.new('floor')
      normal.ephemeral = true
      normal:start()
      normal.enemies = {}
      normal.player.weapon = slot
      normal.player.yaw = math.pi
      normal.player.pitch = 0
      local control = normal:spawn('armored', 16, 24)
      -- The sandbox deliberately faces an alert target toward the knight.
      -- Match its posture as well as its combat stats in this equivalence test.
      control.facing, control.awake, control.memory = target.facing, target.awake, target.memory
      local fired = g:shoot()
      local controlFired = normal:shoot()
      check(
        'weapon ' .. slot .. ' uses the same real hits, armor damage and ammunition in the sandbox',
        fired
          and controlFired
          and target.hp < target.maxHp
          and near(target.hp, control.hp)
          and g.view.shotReport.pellets == normal.view.shotReport.pellets
          and near(g.view.shotReport.blocked, normal.view.shotReport.blocked)
          and g.player.arsenal.exorcist.mag == normal.player.arsenal.exorcist.mag
          and g.player.arsenal.judge.mag == normal.player.arsenal.judge.mag
      )
    end
    g = fresh()
    local target = assert(Field.spawn(g, 'imp', 1))[1]
    Field.close(g)
    Field.toggleFreeze(g)
    local ex, ez, attack = target.x, target.z, target.attack
    local px, pz = g.player.x, g.player.z
    g.bullets = {
      {
        x = 16,
        y = 1.2,
        z = 25.5,
        vx = 0,
        vy = 0,
        vz = 200,
        life = 2,
        color = {
          1,
          0.2,
          0.1,
        },
        big = false,
      },
    }
    for _ = 1, 30 do
      g:update(1 / 120, { forward = 1 })
    end
    check(
      'frozen AI leaves targets and hostile projectiles stationary while the player can move',
      near(target.x, ex)
        and near(target.z, ez)
        and near(target.attack, attack)
        and #g.bullets == 1
        and near(g.bullets[1].z, 25.5)
        and (g.player.x - px) ^ 2 + (g.player.z - pz) ^ 2 > 0.25
    )
    g.player.x, g.player.z, g.player.vx, g.player.vz, g.player.armor, g.player.invuln =
      16, 27.5, 0, 0, 0, 0
    Field.toggleGod(g)
    Field.toggleFreeze(g)
    g:update(1 / 30, {})
    check(
      'unfreezing resumes enemy AI and resolves a previously stopped projectile',
      not g.testField.frozen and target.attack < attack and #g.bullets == 0 and g.player.hp == 86
    )
    g = fresh()
    Field.close(g)
    g.player.invuln = 0
    g:damagePlayer(30)
    check(
      'invincibility protects both health and armor without consuming resources',
      g.player.hp == 100 and g.player.armor == 100
    )
    Field.toggleGod(g)
    g:damagePlayer(30)
    check(
      'disabling invincibility restores normal health and armor damage',
      g.player.hp < 100
        and g.player.armor < 100
        and require('src.session.stats').total(g, 'damageTaken') == 30
    )
    g = fresh()
    Field.close(g)
    g.testField.frozen = true
    g:shoot()
    local emptied = g.player.arsenal.exorcist.mag == 0 and g.player.reload > 0
    for _ = 1, 180 do
      g:update(1 / 120, {})
    end
    check(
      'sandbox shotgun completes its real reload and spends reserve ammunition',
      emptied
        and g.player.reload == 0
        and g.player.arsenal.exorcist.mag == 2
        and g.player.arsenal.exorcist.reserve == 70
    )
    g.player.hp, g.player.armor, g.player.arsenal.exorcist.reserve, g.player.abilityState.powder.uses, g.player.dash =
      12, 0, 0, 0, 0
    g.player.arsenal.judge.mag, g.player.arsenal.judge.reserve = 0, 0
    Field.refill(g)
    check(
      'refill clears reload while restoring both firearm inventories and physical charges',
      g.player.hp == 100
        and g.player.armor == 100
        and g.player.arsenal.exorcist.mag == 2
        and g.player.arsenal.exorcist.reserve == 72
        and g.player.abilityState.powder.uses == 3
        and g.player.dash == 2
        and g.player.arsenal.judge.mag == 6
        and g.player.arsenal.judge.reserve == 72
        and g.player.reload == 0
        and not g.player.arsenal.exorcist.open
    )
    g.player.arsenal.exorcist.mag = 0
    g:reloadGun()
    local reloading = g.player.reload > 0
    g.player.jump, g.player.jumpV, g.player.jumpBuffer, g.player.slideTimer, g.player.crouch, g.player.vx, g.player.vz =
      0.7, 3, 0.1, 0.3, 0.4, 2, 4
    Field.reset(g)
    check(
      'reset during reload, jump and slide clears movement momentum and weapon transients',
      reloading
        and g.player.reload == 0
        and g.player.weapon == 1
        and g.player.jump == 0
        and g.player.jumpV == 0
        and g.player.jumpBuffer == 0
        and g.player.slideTimer == 0
        and g.player.crouch == 0
        and g.player.vx == 0
        and g.player.vz == 0
        and not g.player.arsenal.exorcist.open
        and g.player.reloadStage == 0
        and g.player.reloadDuration == 0
    )
    g.bullets = { {} }
    g.hazards = { {} }
    g.view.effects = { {} }
    g.pickups = { {} }
    g.view.traces = { {} }
    g.view.particles = { {} }
    g.view.decals = { {} }
    g.view.shells = { {} }
    Field.spawn(g, 'boss', 1)
    require('src.session.encounter').guardianFell(g)
    Field.reset(g)
    local clean = true
    for _, name in ipairs({
      'enemies',
      'bullets',
      'hazards',
      'effects',
      'pickups',
      'traces',
      'particles',
      'decals',
      'shells',
    }) do
      clean = clean and #Fixtures.field(g, name) == 0
    end
    check(
      'reset removes targets, projectiles and combat residue and clears completion flags',
      clean
        and not require('src.session.encounter').guardianSpawned(g)
        and not require('src.session.encounter').guardianDead(g)
        and not g.run.fragment
        and g.state == 'field_catalog'
        and not World.solid(g.world, g.player.x, g.player.z, 0.22)
    )
    for _, entry in ipairs(Field.catalog.seals) do
      check(
        entry.id .. ' visit presents the matching existing seal from a legal clear viewpoint',
        Field.visitSeal(g, entry.id)
          and not World.solid(g.world, g.player.x, g.player.z, 0.22)
          and (function()
            for _, seal in ipairs(g.world.seals) do
              if seal.id == entry.id then
                return World.visible(g.world, g.player.x, g.player.z, seal.x, seal.z)
                  and near(g.player.z - seal.z, 3)
              end
            end
          end)()
      )
    end
    Field.reset(g)
    local blocker = g:spawn('boss', 7, 20)
    local visited = Field.visitSeal(g, 'asmoday')
    check(
      'seal inspection finds a safe alternate viewpoint when its default point is occupied',
      visited
        and (g.player.x - blocker.x) ^ 2 + (g.player.z - blocker.z) ^ 2 >= 2.2 ^ 2
        and not World.solid(g.world, g.player.x, g.player.z, 0.22)
        and World.visible(g.world, g.player.x, g.player.z, 7, 17)
    )
    Field.reset(g)
    local candidates = {}
    for z = 2, 30 do
      for x = 2, 30 do
        if not World.solid(g.world, x, z, 0.45) then
          candidates[#candidates + 1] = { x = x, z = z, d = (x - 7) ^ 2 + (z - 17) ^ 2 }
        end
      end
    end
    table.sort(candidates, function(a, b)
      return a.d < b.d
    end)
    for _, spot in ipairs(candidates) do
      local free = (spot.x - g.player.x) ^ 2 + (spot.z - g.player.z) ^ 2 >= 9
      for _, enemy in ipairs(g.enemies) do
        free = free and (spot.x - enemy.x) ^ 2 + (spot.z - enemy.z) ^ 2 >= 1.8 ^ 2
      end
      if free and #g.enemies < 20 then
        g:spawn('imp', spot.x, spot.z)
      end
    end
    local oldX, oldZ, oldYaw = g.player.x, g.player.z, g.player.yaw
    visited = Field.visitSeal(g, 'asmoday')
    local safe = true
    for _, enemy in ipairs(g.enemies) do
      safe = safe and (g.player.x - enemy.x) ^ 2 + (g.player.z - enemy.z) ^ 2 >= 2.2 ^ 2
    end
    check(
      'twenty-target seal inspection either finds full clearance or leaves the player in place',
      #g.enemies == 20
        and (
          (visited and safe and not World.solid(g.world, g.player.x, g.player.z, 0.28))
          or (not visited and g.player.x == oldX and g.player.z == oldZ and g.player.yaw == oldYaw)
        )
    )
    check(
      'full sandbox rejects additional targets atomically at the live-enemy cap',
      Field.spawn(g, 'boss', 1) == nil and #g.enemies == 20
    )
    Field.reset(g)
    Field.close(g)
    for _ = 1, 240 do
      g:update(1 / 30, {})
    end
    check(
      'an empty live sandbox neither schedules waves nor advances progression',
      #g.enemies == 0 and #g.run.pending == 0 and g.state == 'playing'
    )
    local wallet
    Field.shop(g)
    g.player.arsenal.exorcist.reserve = 71
    local purchased = Modes.act(g, 'buy', 'ammo')
    check(
      'sandbox shop exercises real partial prices using only its local wallet',
      purchased
        and g.player.arsenal.exorcist.reserve == 72
        and g.run.wallet == 997
        and chapel.run.wallet == 317
    )
    Modes.act(g, 'ready')
    check(
      'leaving the sandbox shop returns to free combat without starting a wave countdown',
      g.state == 'playing' and #(g.run.pending or {}) == 0
    )
    g.player.armor = 0
    g.player.hp = 1
    g.player.invuln = 0
    g.testField.invincible = false
    wallet = g.run.wallet
    g:damagePlayer(1000)
    check(
      'sandbox death keeps chapel souls and retry progression untouched',
      g.state == 'dead' and g.run.wallet == wallet and g.run.echo == nil and g.run.deaths == 0
    )
    Field.reset(g)
    check(
      'sandbox actions never call a persistence writer even with testing disabled',
      #writes == 0
    )
  end, debug.traceback)
  Save.write, love.filesystem.write = oldWrite, oldFileWrite
  love.mouse.setRelativeMode(false)
  assert(ok, problem)
  return lines
end
return Tests

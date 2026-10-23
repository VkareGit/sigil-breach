-- Exercise the production sandbox, including its persistence boundaries.
-- No testing flag is used to make sandbox writes disappear.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Field = require('src.run.test_field')
  local Run = require('src.run.descent')
  local Modes = require('src.run.modes')
  local Save = require('src.storage.run_save')
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
    local expedition = G.new('descent')
    expedition.testing = true
    expedition:start()
    expedition.run.wallet = 317
    expedition.run.owned = { pierce = true }
    expedition.run.glyph = 'pierce'
    local originalSnapshot = Run.snapshot(expedition)
    local originalBytes = Save.encode(originalSnapshot, 1)
    local function fresh()
      local g = Field.new(G)
      g.testing = false
      return g
    end
    local g = fresh()
    check(
      'sandbox opens a separate empty arena without owning an expedition save',
      g ~= expedition
        and g.world ~= expedition.world
        and g.run ~= expedition.run
        and g.run.owned ~= expedition.run.owned
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
    local glow = require('src.content.waves').portal.glow
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
      g.weapon = slot
      target.x, target.z = 16, 24
      g.player.yaw = math.pi
      g.player.pitch = 0
      local normal = G.new('descent')
      normal.testing = true
      normal:start()
      normal.run.phase = 'wave'
      normal.enemies = {}
      normal.weapon = slot
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
      g.player.hp < 100 and g.player.armor < 100 and g.damageTaken == 30
    )
    g = fresh()
    Field.close(g)
    g.testField.frozen = true
    g:shoot()
    local emptied = g.player.arsenal.exorcist.mag == 0 and g.reload > 0
    for _ = 1, 180 do
      g:update(1 / 120, {})
    end
    check(
      'sandbox shotgun completes its real reload and spends reserve ammunition',
      emptied
        and g.reload == 0
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
        and g.reload == 0
        and not g.player.arsenal.exorcist.open
    )
    g.player.arsenal.exorcist.mag = 0
    g:reloadGun()
    local reloading = g.reload > 0
    g.player.jump, g.player.jumpV, g.player.jumpBuffer, g.player.slideTimer, g.player.crouch, g.player.vx, g.player.vz =
      0.7, 3, 0.1, 0.3, 0.4, 2, 4
    Field.reset(g)
    check(
      'reset during reload, jump and slide clears movement momentum and weapon transients',
      reloading
        and g.reload == 0
        and g.weapon == 1
        and g.player.jump == 0
        and g.player.jumpV == 0
        and g.player.jumpBuffer == 0
        and g.player.slideTimer == 0
        and g.player.crouch == 0
        and g.player.vx == 0
        and g.player.vz == 0
        and not g.player.arsenal.exorcist.open
        and g.reloadStage == 0
        and g.reloadDuration == 0
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
    g.bossDead = true
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
        and not g.bossSpawned
        and not g.bossDead
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
              if seal.name:lower() == entry.id then
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
      #g.enemies == 0
        and #g.run.pending == 0
        and g.run.phase == 'wave'
        and g.run.wave == 1
        and g.state == 'playing'
    )
    local wallet = g.run.wallet
    g.run.wave = 5
    Run.finishWave(g)
    check(
      'explicit wave completion cannot award a fragment or currency in the sandbox',
      g.run.phase == 'wave'
        and not g.run.fragment
        and g.run.wallet == wallet
        and g.state == 'playing'
    )
    Field.shop(g)
    g.player.arsenal.exorcist.reserve = 71
    local purchased = Modes.act(g, 'buy', 'ammo')
    check(
      'sandbox shop exercises real partial prices using only its local wallet',
      purchased
        and g.player.arsenal.exorcist.reserve == 72
        and g.run.wallet == 997
        and expedition.run.wallet == 317
    )
    Modes.act(g, 'ready')
    check(
      'leaving the sandbox shop returns to free combat without starting a wave countdown',
      g.state == 'playing' and g.run.phase == 'wave' and #(g.run.pending or {}) == 0
    )
    g.player.armor = 0
    g.player.hp = 1
    g.player.invuln = 0
    g.testField.invincible = false
    wallet = g.run.wallet
    g:damagePlayer(1000)
    check(
      'sandbox death keeps expedition souls and retry progression untouched',
      g.state == 'dead'
        and g.run.wallet == wallet
        and g.run.echo == nil
        and g.run.deaths == 0
        and not g.run.fragment
    )
    Field.reset(g)
    local originalRun = g.run
    local originalState = g.state
    local snapshot = Run.snapshot(g)
    local saved = Run.save(g)
    local loaded = Run.load(g, originalSnapshot)
    check(
      'sandbox refuses explicit snapshot, save and expedition-load entry points',
      snapshot == nil
        and not saved
        and not loaded
        and g.run == originalRun
        and g.state == originalState
        and g.testField ~= nil
    )
    check(
      'sandbox actions never call a persistence writer even with testing disabled',
      #writes == 0
    )
    check(
      'the original expedition remains byte-for-byte identical after sandbox use',
      Save.encode(Run.snapshot(expedition), 1) == originalBytes
    )
  end, debug.traceback)
  Save.write, love.filesystem.write = oldWrite, oldFileWrite
  love.mouse.setRelativeMode(false)
  assert(ok, problem)
  return lines
end
return Tests

local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local D = require('src.combat.damage')
  local Run = require('src.run.descent')
  local E = require('src.run.economy')
  local Save = require('src.storage.run_save')
  local Weapons = require('src.content.weapons')
  local U = require('src.ui.interface')
  local Waves = require('src.content.waves')
  local lines = {}
  local check = Fixtures.checker(lines, '', '')
  local near = Fixtures.within(0.0001, true)
  local function fresh()
    return Fixtures.expedition(G)
  end
  local function active(g)
    g.player.yaw = math.pi
    g.run.phase = 'wave'
    g.run.queueIndex = #Waves[g.run.wave].queue + 1
    g.run.pending = {}
    g.run.spawnTimer = 100
    g.run.phaseTime = 0
  end
  local g = fresh()
  check(
    'descent starts at a safe shrine with separate soul wallet',
    g.run.wallet == 100 and g.player.abilityState.powder.uses == 2 and #g.enemies == 0
  )
  check('preparation blocks weapons and charges', not g:shoot() and (function()
    g:cast(1)
    return g.player.abilityState.powder.uses == 2
  end)())
  g:damagePlayer(1000)
  check('preparation is safe', g.player.hp == 100)
  local a = {
    base = 12,
    damageType = 'physical',
    penetration = 0.1,
    falloffStart = 4,
    falloffEnd = 18,
    minPower = 0.4,
  }
  check(
    'armor formula has explicit predictable result',
    near(D.resolve(a, { armorRating = 60 }, 3), 12 / 1.54)
  )
  local previous = math.huge
  for _, armor in ipairs({ 0, 30, 60, 100 }) do
    local damage = D.resolve(a, { armorRating = armor }, 6)
    check('armor ' .. armor .. ' does not increase damage', damage <= previous)
    previous = damage
  end
  a.penetration = 0.6
  check('penetration increases physical damage', D.resolve(a, { armorRating = 60 }, 3) > 12 / 1.54)
  a.penetration = 0.1
  check(
    'distance curve is continuous at start and end',
    near(D.resolve(a, {}, 4), 12) and near(D.resolve(a, {}, 18), 4.8)
  )
  check(
    'astral damage bypasses physical armor but respects resistance',
    near(
      D.resolve(
        { base = 24, damageType = 'astral' },
        { armorRating = 100, resistances = { astral = 0.25 } },
        5
      ),
      18
    )
  )
  check(
    'extreme resistance is bounded',
    near(D.resolve({ base = 10 }, { resistances = { physical = 100 } }, 0), 4)
  )
  check('invalid damage curve is rejected', not pcall(D.falloff, 1, 5, 5, 0.4))
  active(g)
  local foe = g:spawn('armored', 16, 23.5)
  g.player.z = 27.5
  g.view.motion = false
  g:shoot()
  check(
    'armored variant has armor and a distinct identity',
    foe.kind == 'imp' and foe.variant == 'armored' and foe.armorRating == 60
  )
  check(
    'shotgun reports armor reduction independently of impact',
    g.view.shotReport.blocked > 0 and foe.stun > 0
  )
  check(
    'damage reports distinguish overkill from actual health loss',
    g.view.shotReport.healthDamage <= foe.maxHp
      and g.view.shotReport.healthDamage <= g.view.shotReport.damage
  )
  g = fresh()
  active(g)
  g.player.x, g.player.z, g.player.pitch = 16, 27, 0.04
  local first = g:spawn('imp', 15.65, 23.5)
  local second = g:spawn('imp', 16.35, 23.5)
  g:shoot()
  check('new damage system preserves adjacent double kills', first.hp <= 0 and second.hp <= 0)
  g = fresh()
  active(g)
  for i = 1, 3 do
    local e = g:spawn('imp', 16, 25 - i * 0.4)
    e.rewardId = '1_' .. i
  end
  g:cast(1)
  require('src.combat.explosives').explode(
    g,
    { action = require('src.content.abilities'):get('powder').action, x = 16, y = 1, z = 25.5 }
  )
  check(
    'charge kills cannot refund their own ammunition',
    g.player.abilityState.powder.uses == 1 and require('src.session.stats').total(g, 'kills') == 3
  )
  check(
    'charge kills still create the ordinary soul drops',
    #g.pickups == 3 and g.pickups[1].kind == 'soul' and g.run.wallet == 100
  )
  local drop = g.pickups[1]
  Run.collectSoul(g, drop)
  local money = g.run.wallet
  Run.collectSoul(g, drop)
  check('collecting the same soul is idempotent', money == 104 and g.run.wallet == money)
  g = fresh()
  active(g)
  g.player.weapon = 2
  for i = 1, 6 do
    g.elapsed = g.elapsed + 0.38
    g.player.cooldown = 0
    check('revolver cylinder shot ' .. i, g:shoot())
  end
  g.elapsed = g.elapsed + 0.38
  g.player.cooldown = 0
  check(
    'empty cylinder waits for a physical reload',
    not g:shoot() and g.player.arsenal.judge.mag == 0 and g.player.reload > 0
  )
  g:switchWeapon(1)
  g:switchWeapon(2)
  g.player.cooldown = 0
  check(
    'weapon switching cannot refill an empty cylinder',
    not g:shoot() and g.player.arsenal.judge.mag == 0
  )
  require('src.combat.reload').update(g, 1.86)
  g.player.cooldown = 0
  check(
    'revolver reload spends its reserve ammunition',
    g:shoot() and g.player.arsenal.judge.reserve == 18 and g.player.arsenal.judge.mag == 5
  )
  g = fresh()
  check('shop requires the shrine', Run.openShop(g))
  local before = g.player.arsenal.exorcist.reserve
  check(
    'small ammo purchase commits cost and quantity',
    Run.buy(g, 'ammo') and g.player.arsenal.exorcist.reserve == before + 4 and g.run.wallet == 88
  )
  g.player.arsenal.exorcist.reserve = 71
  local price = E.quote(g, 'ammo')
  check(
    'partial ammo purchases charge only missing rounds',
    price == 3 and Run.buy(g, 'ammo') and g.player.arsenal.exorcist.reserve == 72
  )
  money = g.run.wallet
  check(
    'full ammo purchase is refused without charge',
    not Run.buy(g, 'fill') and g.run.wallet == money
  )
  g.player.armor = 99.5
  check(
    'partial shield repair rounds price up consistently',
    E.quote(g, 'armor') == 1 and Run.buy(g, 'armor') and g.player.armor == 100
  )
  money = g.run.wallet
  check(
    'unaffordable glyph leaves state unchanged',
    not Run.buy(g, 'choke') and g.run.wallet == money and g.run.glyph == 'none'
  )
  g.run.wallet = 250
  check(
    'glyph purchase registers ownership',
    Run.buy(g, 'choke') and g.run.glyph == 'choke' and g.run.wallet == 150
  )
  check('second glyph can be owned', Run.buy(g, 'pierce') and g.run.wallet == 50)
  check('owned glyph switches without a second payment', Run.buy(g, 'choke') and g.run.wallet == 50)
  check(
    'duplicate equipped glyph cannot consume currency',
    not Run.buy(g, 'choke') and g.run.wallet == 50
  )
  Run.closeShop(g)
  check('purchases outside shop are refused', not Run.buy(g, 'ammo'))
  check(
    'ready starts exactly one countdown',
    Run.ready(g) and not Run.ready(g) and g.run.phase == 'countdown'
  )
  check('countdown includes all queued enemies', Run.remaining(g) == 7 and not g:shoot())
  for _ = 1, math.ceil((require('src.content.tuning').waveCountdown + 0.04) * 120) do
    g:update(1 / 120, {})
  end
  check(
    'wave starts after countdown and telegraphs first spawn',
    g.run.phase == 'wave' and #g.run.pending > 0 and #g.enemies == 0
  )
  for _ = 1, 170 do
    g:update(1 / 120, {})
  end
  check(
    'telegraphed enemy spawns after the warning',
    #g.enemies > 0 and g.enemies[1].rewardId == '1_1'
  )
  local living = 0
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      living = living + 1
    end
  end
  check(
    'living enemies and pending spawns respect the cap',
    living + #g.run.pending <= Waves[1].cap
  )
  -- A moved player must not be struck by a body appearing inside the warning.
  g = fresh()
  active(g)
  g.run.pending = { { x = 16, z = 27.5, kind = 'imp', rewardId = '1_1', delay = 0.01 } }
  g.run.queueIndex = 2
  Run.update(g, 0.02)
  check('spawn is deferred if player enters its portal', #g.enemies == 0 and #g.run.pending == 1)
  -- Death ledger survives rollback, but currency moves rather than being copied.
  g = fresh()
  Run.ready(g)
  active(g)
  g.run.wallet = 144
  g.run.claimed['1_1'] = true
  g.player.arsenal.exorcist.reserve = 2
  g.player.x = 15
  g.player.z = 20
  g:damagePlayer(1000, 16, 20)
  check(
    'death moves carried souls into one echo',
    g.state == 'dead' and g.run.wallet == 0 and g.run.echo.amount == 144 and g.run.echo.wave == 1
  )
  check(
    'retry restores entry inventory and retains collected IDs',
    Run.retry(g) and g.player.arsenal.exorcist.reserve == 28 and g.run.claimed['1_1']
  )
  g.player.x = 15
  g.player.z = 20
  Run.update(g, 0.01)
  check('echo cannot be collected before the retry begins', g.run.wallet == 0 and g.run.echo ~= nil)
  active(g)
  local guard = g:spawn('imp', 7, 17)
  local world = require('src.world.arena')
  local visible = world.visible
  world.visible = function()
    return false
  end
  Run.update(g, 0.01)
  world.visible = visible
  check('echo cannot be recovered through an obstruction', g.run.echo ~= nil and g.run.wallet == 0)
  Run.update(g, 0.01)
  check('echo is recoverable during the live retry', g.run.wallet == 144 and not g.run.echo)
  guard.rewardId = '1_1'
  g:damageEnemy(guard, 1000, 'weapon')
  check('replayed paid enemy does not mint another soul drop', #g.pickups == 0)
  g.player.invuln = 0
  g:damagePlayer(1000)
  Run.retry(g)
  active(g)
  g:spawn('imp', 7, 17)
  g.player.invuln = 0
  g:damagePlayer(1000)
  check(
    'dying again with an empty wallet destroys the old echo',
    g.run.echo == nil and g.run.wallet == 0
  )
  -- A finished wave drains hazards, collects loose souls, and pays only once.
  g = fresh()
  active(g)
  g.pickups = { { kind = 'soul', x = 7, z = 17, amount = 4, rewardId = '1_1' } }
  g.hazards = { { life = 2 } }
  g.bullets = { { life = 2 } }
  g.player.hp = 20
  Run.update(g, 0.01)
  check(
    'clear pays bonus and gathers unclaimed soul drops',
    g.run.phase == 'preparing' and g.run.wave == 2 and g.run.wallet == 164
  )
  check(
    'trader phase clears hazards and restores health',
    #g.bullets == 0 and #g.hazards == 0 and g.player.hp == 100
  )
  Run.update(g, 0.01)
  check('clear bonus is not paid twice', g.run.wallet == 164)
  check(
    'duplicate direct clear cannot advance another wave',
    not Run.finishWave(g) and g.run.wallet == 164 and g.run.wave == 2
  )
  -- Serialize every supported boundary and detect damaged saves without executing input.
  local data = Run.snapshot(g)
  local encoded = Save.encode(data, 7)
  local decoded, seq = Save.decode(encoded)
  check(
    'save round trip keeps ledger and next wave',
    decoded and seq == 7 and decoded.wallet == 164 and decoded.claimed['1_1'] and decoded.wave == 2
  )
  check('truncated save is rejected', Save.decode(encoded:sub(1, -8)) == nil)
  check(
    'edited payload fails checksum',
    Save.decode((encoded:gsub('%["wallet"%]=164', '["wallet"]=999'))) == nil
      and encoded:find('["wallet"]=164', 1, true) ~= nil
  )
  check('save does not execute Lua text', Save.decode('return os.execute("test")') == nil)
  data.wallet = -1
  check(
    'invalid domain value is rejected even with valid checksum',
    Save.decode(Save.encode(data, 8)) == nil
  )
  data.wallet = 164
  local prefix = 'qa-v06-generation'
  local file = Save.file(prefix)
  local function clean()
    for _, path in ipairs({
      file,
      file .. '.tmp',
      file .. '.previous',
      prefix .. '.a',
      prefix .. '.b',
    }) do
      love.filesystem.remove(path)
    end
  end
  clean()
  check('first save writes and verifies', Save.write(data, prefix))
  data.wallet = 200
  check('second save writes and verifies, the first kept beside it', Save.write(data, prefix))
  love.filesystem.write(file, 'interrupted')
  local recovered, sequence, damaged = Save.read(prefix)
  check(
    'a damaged latest save falls back to the previous complete save',
    recovered and recovered.wallet == 164 and sequence == 1 and damaged
  )
  clean()
  local loaded = fresh()
  Run.load(loaded, decoded)
  check(
    'loading a boundary restores a playable preparation',
    loaded.state == 'playing'
      and loaded.run.wave == 2
      and loaded.player.hp == 100
      and loaded.run.wallet == 164
  )
  g = fresh()
  Run.ready(g)
  active(g)
  g.player.x = 14
  g.player.z = 20
  g:damagePlayer(1000)
  decoded = assert(Save.decode(Save.encode(Run.snapshot(g), 1)))
  loaded = fresh()
  Run.load(loaded, decoded)
  check(
    'death save preserves echo and retry equipment',
    loaded.state == 'dead'
      and loaded.run.echo.amount == 100
      and loaded.run.checkpoint.weapons.exorcist.reserve == 28
  )
  g = fresh()
  g.run.wave = 5
  g.run.echo = { amount = 144, x = 7, z = 17, wave = 5 }
  active(g)
  Run.update(g, 0.01)
  check(
    'boss clear ends Limbo with exactly one fragment',
    g.state == 'won' and g.run.fragment and g.run.phase == 'complete'
  )
  check('victory returns the echo before exploration ends', g.run.wallet == 344 and not g.run.echo)
  decoded = assert(Save.decode(Save.encode(Run.snapshot(g), 1)))
  loaded = fresh()
  Run.load(loaded, decoded)
  check('completed circle reloads as completed', loaded.state == 'won' and loaded.run.fragment)
  check(
    'nine circles exist but only Limbo is marked playable',
    #require('src.content.circles') == 9 and not require('src.content.circles')[2].available
  )
  g = fresh()
  Run.openShop(g)
  local controls = U.controls(g, {})
  local actions = {}
  for _, b in ipairs(controls) do
    actions[b.id] = true
  end
  check(
    'shop exposes both weapons, six offers, ready and return with keyboard navigation',
    actions.shop_weapon_1
      and actions.shop_weapon_2
      and actions.buy_charge
      and actions.ready
      and actions.shop_back
  )
  for _, b in ipairs(controls) do
    check(
      'shop button ' .. b.id .. ' stays inside logical viewport',
      b.x >= 0 and b.y >= 0 and b.x + b.w <= 1280 and b.y + b.h <= 720
    )
  end
  local result = require('qa.scenarios.playtest').run(G, false, nil, { projectiles = true })
  local living = {}
  for _, body in ipairs(result.session.enemies) do
    if body.hp > 0 then
      living[#living + 1] = body.kind .. ':' .. body.hp .. '/phase:' .. tostring(body.phaseIndex)
    end
  end
  check(
    'full wave trial completes through real movement and weapons ('
      .. table.concat(living, ', ')
      .. ')',
    result.state == 'won' and result.fragment
  )
  -- Balance report only (no pass/fail on difficulty): a human-like player.
  local humanRun = require('qa.scenarios.playtest').run(G, true)
  check(
    'human-model wave simulation runs to an outcome',
    humanRun.state == 'won' or humanRun.state == 'dead' or humanRun.time > 0
  )
  -- Population of five human models (report only): mean and spread.
  local population = require('qa.scenarios.playtest').population(G)
  check('the human-model population runs five complete simulations', population.damage >= 0)
  check(
    'the skilled population times dodges and throws powder (plan v5 G0)',
    population.skilled and #population.skilled.waves > 0
  )
  -- AI behaviour audit (report only): loops, cancels, orbits, stuck bodies.
  require('qa.scenarios.ai_audit').run(G)
  require('qa.scenarios.balance').write()
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests

-- The gardener's visible deliveries, exercised through the real combat clocks.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local Actions = require('src.enemies.actions')
  local Enemies = require('src.content.enemies')
  local World = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Snapshot = require('src.session.snapshot')
  local specs = {}
  for _, spec in ipairs(Enemies.buer.attacks) do
    specs[spec.id] = spec
  end
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'gardener: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local function actor(distance)
    local g = F.arena(Game)
    for z = 8, 30 do
      for x = 8, 24 do
        World.setCell(g.world, x, z, Tiles.floor)
      end
    end
    g.player.armor, g.player.z = 0, 20 + distance
    local e = g:spawn('buer', 16, 20)
    e.target, e.awake, e.visible, e.memory, e.spawnAge, e.sense, e.facing =
      g.player.id, true, true, 60, 2, 10, 0
    return g, e
  end
  local function trial(distance, rate, scenario)
    local g, e = actor(distance)
    local hp, first, peak = g.player.hp, nil, 0
    Actions.begin(g, e, distance, specs['root-brace'])
    for i = 1, rate * 3 do
      local time = (i - 1) / rate
      e.attack, e.answered = 99, { hugging = 99, reloading = 99 }
      if scenario == 'wall' then
        World.setCell(g.world, 16, 21, Tiles.wall)
      end
      if scenario == 'side' and time >= 0.72 then
        g.player.x = 20
      end
      if scenario == 'behind' and time >= 0.72 then
        g.player.z = 18
      end
      if scenario == 'interrupt' and time >= 0.7 and e.ai == 'windup' then
        require('src.combat.action_kinds').abandon(e)
        e.ai, e.stun = 'move', 10
      end
      if scenario == 'restore' and i == math.floor(rate * 1.05) then
        Snapshot.restore(g, Snapshot.capture(g))
        e = g.enemies[1]
      end
      g:update(1 / rate, {})
      if g.player.hp < hp and not first then
        first = i / rate
      end
      peak = math.max(peak, #g.hazards)
    end
    return hp - g.player.hp, first, peak
  end
  for _, rate in ipairs({ 60, 120, 240 }) do
    local loss, first, peak = trial(3, rate)
    check('retch reaches its visible front at 3 m / ' .. rate .. ' Hz', loss > 0)
    check(
      'retch contact occurs during the exhale / ' .. rate .. ' Hz',
      first and first >= 0.8 and first < 1.4
    )
    check('retch does not create unrelated rooting pools / ' .. rate .. ' Hz', peak == 0)
    check('side exit clears the locked exhale / ' .. rate .. ' Hz', trial(3, rate, 'side') == 0)
    check('the back is safe / ' .. rate .. ' Hz', trial(3, rate, 'behind') == 0)
    check('stone blocks the exhale / ' .. rate .. ' Hz', trial(3, rate, 'wall') == 0)
    check('interrupt cancels the exhale / ' .. rate .. ' Hz', trial(3, rate, 'interrupt') == 0)
    check(
      'Continue preserves its one contact / ' .. rate .. ' Hz',
      trial(3, rate, 'restore') == loss
    )
  end
  do
    local g, e = actor(6)
    Actions.begin(g, e, 6, specs.spore)
    Actions.execute(g, e)
    check('spit leaves no pool before its projectile lands', #g.hazards == 0 and #g.bullets == 1)
  end
  do
    local g, e = actor(6)
    Actions.begin(g, e, 6, specs['seed-ring'])
    Actions.execute(g, e)
    check(
      'sowing releases three seeds before any ground patch',
      #g.hazards == 0 and #g.bullets == 3
    )
  end
  do
    local g, e = actor(6)
    check(
      'harvest cannot begin without its own mature garden',
      not Actions.begin(g, e, 6, specs['late-bloom'])
    )
  end
  check('health remains 520', Enemies.buer.body.hp == 520)
  do
    local g, e = actor(6)
    e.attack, e.answered = 99, { hugging = 99, reloading = 99 }
    g.player.z = 14
    for _ = 1, 24 do
      g:update(1 / 120, {})
    end
    local turn = math.abs(math.atan2(math.sin(e.facing), math.cos(e.facing)))
    check('the heavy body cannot reverse its facing within one reaction beat', turn < math.pi / 4)
  end
  local Projectiles = require('src.combat.projectiles')
  do
    local g, e = actor(3)
    Actions.begin(g, e, 3, specs['root-brace'])
    e.ai, e.phase = 'strike', 0
    Actions.execute(g, e)
    local s = require('src.combat.stream').shape(g, e, specs['root-brace'])
    local toX, toZ = e.aimX - s.x, e.aimZ - s.z
    check(
      'the painted mouth aims through the committed target, not parallel beside it',
      math.abs(toX * s.dz - toZ * s.dx) < 1e-6
    )
  end
  local Hazards = require('src.enemies.hazards')
  local Deposits = require('src.combat.deposits')
  local Spawn = require('src.session.spawn')
  local Pools = require('src.session.world')
  local Save = require('src.storage.save')
  local Integrity = require('src.session.integrity')
  local function release(g, e, id)
    Actions.begin(g, e, 6, specs[id])
    e.ai, e.phase = 'strike', 0
    Actions.execute(g, e)
  end
  local function fly(g, rate)
    for _ = 1, rate * 3 do
      Projectiles.update(g, 1 / rate)
    end
  end
  for _, rate in ipairs({ 60, 120, 240 }) do
    local g, e = actor(6)
    release(g, e, 'spore')
    g.player.x = 22
    fly(g, rate)
    check(
      'missed spit deposits once on actual ground / ' .. rate,
      #g.hazards == 1 and #g.bullets == 0
    )
    if g.hazards[1] then
      check(
        'landing remains at the released aim / ' .. rate,
        math.abs(g.hazards[1].x - 16) < 0.06 and math.abs(g.hazards[1].z - 26) < 0.06
      )
      check(
        'landing keeps owner and side / ' .. rate,
        g.hazards[1].owner == e.id and g.hazards[1].side == 'demons'
      )
    end
    g, e = actor(6)
    release(g, e, 'spore')
    local hp = g.player.hp
    fly(g, rate)
    check('the visible spit strikes a stationary body / ' .. rate, g.player.hp < hp)
    check('body impact never teleports a pool beyond it / ' .. rate, #g.hazards == 0)
    g, e = actor(6)
    release(g, e, 'seed-ring')
    g.player.x = 22
    fly(g, rate)
    check(
      'three landed seeds respect capacity / ' .. rate,
      #g.hazards == 3 and Deposits.count(g, e.id, 'rot') == 3
    )
    check(
      'full garden cannot start another sow / ' .. rate,
      not Actions.begin(g, e, 6, specs['seed-ring'])
    )
    g, e = actor(6)
    release(g, e, 'spore')
    g.player.x = 22
    for x = 8, 24 do
      World.setCell(g.world, x, 23, Tiles.wall)
    end
    fly(g, rate)
    check(
      'stone stops spit and prevents a remote deposit / ' .. rate,
      #g.hazards == 0 and #g.bullets == 0
    )
  end
  local function patch(g, e, x, z, age, life)
    local d = specs.spore.deposit
    return Spawn.make(g, 'hazard', {
      kind = 'pool',
      garden = 'rot',
      x = x,
      z = z,
      radius = d.radius,
      delay = -(age or 1),
      maxDelay = d.delay,
      life = life or 5,
      interval = d.pulse,
      pulse = 0,
      packet = d.packet,
      volume = d.volume,
      owner = e.id,
      side = 'demons',
    })
  end
  do
    local g, e = actor(6)
    local other = g:spawn('buer', 20, 20)
    local owned = patch(g, e, 16, 26)
    local foreign = patch(g, other, 19, 26)
    local young = patch(g, e, 13, 26, 0)
    local dying = patch(g, e, 16, 24, 1, 0.5)
    check('mature own garden enables harvest', Actions.begin(g, e, 6, specs['late-bloom']))
    check(
      'warning binds only a mature durable owned patch',
      owned.harvest and not foreign.harvest and not young.harvest and not dying.harvest
    )
    check(
      'warning already states the entire eruption radius',
      owned.harvest and owned.harvest.radius == specs['late-bloom'].radius
    )
    require('src.combat.action_kinds').abandon(e)
    e.ai = 'move'
    Hazards.update(g, 0.01)
    check(
      'interruption cancels eruption and preserves ordinary garden',
      not owned.harvest and not owned.erupting and owned.life > 0
    )
  end
  for _, rate in ipairs({ 60, 120, 240 }) do
    local g, e = actor(6)
    local h = patch(g, e, 16, 26)
    Actions.begin(g, e, 6, specs['late-bloom'])
    e.ai, e.phase = 'strike', 0
    Actions.execute(g, e)
    local hp = g.player.hp
    for _ = 1, rate do
      Hazards.update(g, 1 / rate)
    end
    check(
      'harvest consumes its patch and strikes once / '
        .. rate
        .. ' (loss='
        .. (hp - g.player.hp)
        .. ', patches='
        .. #g.hazards
        .. ')',
      #g.hazards == 0 and math.abs(hp - g.player.hp - specs['late-bloom'].packet.base) < 1e-6
    )
    g, e = actor(6)
    patch(g, e, 16, 26)
    Actions.begin(g, e, 6, specs['late-bloom'])
    e.hp = 0
    Hazards.update(g, 1 / rate)
    check('caster death cancels a pending harvest / ' .. rate, not g.hazards[1].harvest)
  end
  -- A file save resolves definitions and entity ids, unlike an in-memory snapshot.
  for _, moment in ipairs({ 'flight', 'garden', 'harvest' }) do
    local g, e = actor(6)
    if moment == 'flight' then
      release(g, e, 'seed-ring')
      Projectiles.update(g, 0.1)
    else
      patch(g, e, 16, 26)
      if moment == 'harvest' then
        Actions.begin(g, e, 6, specs['late-bloom'])
      end
    end
    local before = Integrity.capture(g)
    local section = Save.section('pools')
    section.restore(g, section.unpack(section.pack(g)))
    check(
      'file Continue preserves ' .. moment,
      not Integrity.difference(before, Integrity.capture(g))
    )
  end
  do
    -- The pool kind no creature carries now still delivers its bolt and pool.
    local g, e = actor(6)
    Actions.begin(g, e, 6, require('tests.support.pool_attack'))
    Actions.execute(g, e)
    check('a pool cast still delivers its bolt and its pool', #g.hazards == 1 and #g.bullets == 1)
  end
  for _, line in ipairs(require('tests.cases.plague_gardener_edges').run(Game)) do
    lines[#lines + 1] = line
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T

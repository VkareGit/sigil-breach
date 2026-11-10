-- E11: the extension points hold. A new demon, a new kind of attack, a new
-- mode and a new screen are added as data and registry entries only, used by
-- the unchanged systems, and removed again (content stays as it was).
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'extension: ', 'extension: ')
  local A = require('src.content.enemies')
  local Action = require('src.content.defs.action')
  local Creature = require('src.content.defs.creature')
  local packet = require('src.content.defs.packet').new
  local Attacks = require('src.enemies.actions')
  local Modes = require('src.run.modes')
  local Screens = require('src.app.screens')
  local Input = require('src.app.input')

  -- A new delivery kind: a slam around the body at release.
  local slams = 0
  Action.defineKind('trial_slam', {
    reach = { type = 'number', min = 0, desc = 'radius of the slam (m)' },
  }, { 'reach', 'packet' })
  Attacks.kinds.trial_slam = {
    execute = function(g, e, atk)
      slams = slams + 1
      local p = g.player
      if math.sqrt((p.x - e.x) ^ 2 + (p.z - e.z) ^ 2) < atk.reach then
        g:damagePlayer(atk.packet.base, e.x, e.z, atk.packet, e)
      end
    end,
  }
  -- A new demon: a thrall variant that slams instead of clawing.
  Fixtures.words({ trial_thrall = 'Trial Thrall' })
  A.register(Creature.define({
    extends = A.imp,
    id = 'trial',
    kind = 'imp',
    variant = 'trial',
    name = 'trial_thrall',
    -- Its look is data too: a green portal and a dark stain, and its wind-up
    -- glows like a spell.
    appearance = { portal = { 0.2, 0.9, 0.4 }, stain = { 0.05, 0.1, 0.05 }, casts = { all = true } },
    attacks = {
      Action.trial_slam({
        id = 'slam',
        range = 2.4,
        windup = 0.4,
        cooldown = 0.8,
        reach = 2.6,
        packet = packet(10, 30),
      }),
    },
  }))
  check(
    'a creature defined from its parent keeps the parent body',
    A.trial.body.hp == A.imp.body.hp and A.trial.attacks[1].kind == 'trial_slam'
  )
  local g = Fixtures.arena(G)
  local demon = g:spawn('trial', 16, 23)
  demon.awake, demon.memory, demon.spawnAge = true, 60, 1
  local before = g.player.hp + g.player.armor
  for _ = 1, 6 * 120 do
    g:update(1 / 120, {})
  end
  check('the unchanged AI commits the new attack', slams > 0)
  check('the new attack hurts through the shared rules', g.player.hp + g.player.armor < before)
  check(
    'its look comes from its definition (portal, stain, spell glow) and the parent fills the rest',
    require('src.render.portals').color('trial') == A.trial.appearance.portal
      and A.look(demon).stain == A.trial.appearance.stain
      and A.look(demon).casts.all
      and A.look(demon).atlas == 'imp'
      and require('src.enemies.animation').posed(demon, 'walk').rate == 4.2
  )

  -- A new mode, entered by name: its own progression runs in the world system.
  local progressed = 0
  Modes:register('trial', {
    session = { map = require('src.content.maps.index').default },
    start = function(session)
      session.state = 'playing'
    end,
    progress = function()
      progressed = progressed + 1
    end,
  })
  local hub = Fixtures.arena(G)
  hub.mode = 'trial'
  check('a named mode is the session mode', Modes.of(hub) == Modes:get('trial'))
  for _ = 1, 10 do
    hub:update(1 / 120, {})
  end
  check('the mode progresses once per step', progressed == 10)

  -- A new screen: its keys reach the commands without touching input.lua.
  Screens:register('trial_screen', { keys = { x = 'trial_command' } })
  local issued
  local app = {
    game = hub,
    settings = {},
    action = function(_, command)
      issued = command
    end,
  }
  hub.state = 'trial_screen'
  Input.new():keypressed(app, 'x')
  check('a new screen maps its keys to commands', issued == 'trial_command')
  local Views = require('src.ui.views')
  local drawn = false
  Views:register('trial_screen', {
    draw = function()
      drawn = true
    end,
    controls = function()
      return { { id = 'trial_command', label = 'TRIAL', x = 0, y = 0, w = 100, h = 40 } }
    end,
  })
  Views.of(hub).draw(hub, {}, require('src.ui.interface'))
  local buttons = require('src.ui.interface').controls(hub, {})
  check(
    'a new screen draws and offers its buttons through the view registry',
    drawn and #buttons == 1 and buttons[1].id == 'trial_command'
  )
  Views:unregister('trial_screen')

  -- A third weapon from data alone: it is drawn, fires, reloads and saves.
  local Weapons = require('src.content.weapons')
  local judge = Weapons.get('judge')
  Fixtures.words({
    trial_carbine = 'TRIAL CARBINE',
    trial_carbine_kind = 'CARBINE',
    trial_carbine_draw = 'trial carbine',
  })
  local carbine = Weapons.define({
    id = 'trial_carbine',
    name = 'trial_carbine',
    art = 'judge',
    hud = {
      title = 'trial_carbine',
      kind = 'trial_carbine_kind',
      tab = 'trial_carbine_kind',
      draw = 'trial_carbine_draw',
    },
    ammo = { kind = 'magazine', capacity = 5, startReserve = 10, maxReserve = 20, packSize = 5 },
    cycle = 0.3,
    range = 30,
    reload = { mechanism = 'cylinder' },
    fire = judge.fire,
    attack = { base = 40, impact = 30, falloffStart = 10, falloffEnd = 30, minPower = 0.5 },
    weight = judge.weight,
  })
  local armed = Fixtures.arena(G)
  local slot = Weapons.give(armed, 'trial_carbine')
  check(
    'a weapon given takes the next slot of the loadout',
    slot == 3 and Weapons.count(armed) == 3
  )
  check(
    'the third weapon is drawn by its number',
    armed:switchWeapon(3) and armed.player.weapon == 3
  )
  local target = armed:spawn('imp', 16, 21)
  target.awake = false
  armed.player.yaw = math.atan2(target.x - armed.player.x, target.z - armed.player.z)
  armed.player.cooldown = 0
  armed.elapsed = armed.elapsed + 1
  local state = Weapons.state(armed)
  check('the third weapon fires through the shared combat', armed:shoot() and state.mag == 4)
  check('its rounds hit with its own attack', target.hp < target.maxHp)
  state.mag = 0
  armed.player.cooldown = 0
  check('it reloads by its mechanism', armed:reloadGun())
  for _ = 1, 400 do
    armed:update(1 / 120, {})
  end
  check('the reload moves rounds from its own reserve', state.mag == 5 and state.reserve == 5)
  -- The fire's arsenal lists every weapon declared for the shop, in its
  -- declared place (PLAN F2): a new one edits neither the shop nor its commands.
  local FireShop = require('src.ui.fire_shop')
  Weapons.define({ extends = carbine, id = 'trial_shop_carbine', shop = { order = 3 } })
  local market = Fixtures.arena(G)
  local cards = {}
  for _, control in ipairs(FireShop.controls(market)) do
    cards[#cards + 1] = control.id:match('^shop_card_(.+)$')
  end
  check(
    'the arsenal shows every weapon declared for the shop in its place',
    table.concat(cards, ',') == 'judge,exorcist,trial_shop_carbine'
  )
  require('src.app.commands').dispatch(
    { game = market, saveSettings = function() end },
    'shop_card_trial_shop_carbine'
  )
  check(
    'its card is chosen by the shared shop command',
    market.view.shopSelection == 'trial_shop_carbine'
  )
  local unsold = {}
  for _, offer in ipairs(require('src.content.shop').offers) do
    if offer.weapon and not (Weapons.has(offer.weapon) and Weapons.get(offer.weapon).shop) then
      unsold[#unsold + 1] = offer.id
    end
  end
  check(
    'every weapon offer belongs to a weapon declared for the shop: ' .. table.concat(unsold, ', '),
    #unsold == 0
  )
  local uncarded = {}
  for _, id in ipairs(Weapons.onShop()) do
    if not pcall(require('src.ui.skin').cardCell, id) then
      uncarded[#uncarded + 1] = id
    end
  end
  check(
    'every weapon on the shop has a card on the sheet: ' .. table.concat(uncarded, ', '),
    #uncarded == 0
  )
  Weapons.registry:unregister('trial_shop_carbine')
  -- A weapon is a profile given to the engine (PLAN E6): the hands carry a
  -- third, trial weapon by its own numbers, and a profile naming a motion the
  -- hands do not have is refused when the weapon is defined.
  local Motion = require('src.feedback.weapon_motion')
  Weapons.define({
    extends = Weapons.get('exorcist'),
    id = 'trial_long_gun',
    hands = { lower = { dash = 11 }, aim = { reachX = 2 } },
  })
  local function dashLower(id)
    local carried = Fixtures.arena(G)
    carried.player.weapon = Weapons.give(carried, id)
    Motion.init(carried)
    carried.player.dashTimer = 1
    for _ = 1, 240 do
      Motion.update(carried, 1 / 120, 0, 0, 0)
    end
    return carried.view.weaponLower
  end
  local long, shotgun = dashLower('trial_long_gun'), dashLower('exorcist')
  check(
    'a weapon carries its own hand profile, the others keep the shared one',
    math.abs(long - 11) < 0.01 and math.abs(shotgun - 4) < 0.01
  )
  check('a hand profile naming no motion of the hands is refused', not pcall(Weapons.define, {
    extends = Weapons.get('exorcist'),
    id = 'trial_bad_hands',
    hands = { lower = { dahs = 11 } },
  }) and not Weapons.has('trial_bad_hands'))
  Weapons.registry:unregister('trial_long_gun')
  -- Its reload sounds as its own bank: a weapon on a shared mechanism names
  -- its own voice for a stage, and the others keep the mechanism's.
  local voiced = Weapons.define({
    extends = Weapons.get('exorcist'),
    id = 'trial_rebored',
    reload = { mechanism = 'breech', voices = { load = 'roundsIn' } },
  })
  local Audio = require('src.audio.audio')
  local Reload = require('src.combat.reload')
  local function loadVoices(id)
    local heard, play, playAt = {}, Audio.play, Audio.playAt
    Audio.play = function(name)
      heard[name] = true
    end
    Audio.playAt = function(name)
      heard[name] = true
    end
    local ok, reason = pcall(function()
      local armed = Fixtures.arena(G)
      armed.player.weapon = Weapons.give(armed, id)
      local state = armed.player.arsenal[id]
      state.mag, state.reserve = 0, 4
      assert(Reload.start(armed, false))
      for _ = 1, 2 * 120 do
        armed:update(1 / 120, {})
      end
    end)
    Audio.play, Audio.playAt = play, playAt
    assert(ok, reason)
    return heard
  end
  local own, shared = loadVoices('trial_rebored'), loadVoices('exorcist')
  check(
    'a weapon reloads with its own voice where it names one, the mechanism elsewhere',
    voiced.reload.voices.load == 'roundsIn'
      and own.roundsIn
      and not own.shellIn
      and own.breakOpen
      and shared.shellIn
      and not shared.roundsIn
  )
  Weapons.registry:unregister('trial_rebored')
  -- A spell from data alone: a bolt on the second ability slot, cast by the
  -- shared caster, flying through the shared projectile system into a demon.
  local Abilities = require('src.content.abilities')
  Fixtures.words({
    trial_spark = 'TRIAL SPARK',
    trial_spark_tag = 'SPARK',
    trial_spark_empty = 'No sparks left.',
  })
  local spark = Abilities.define({
    id = 'trial_spark',
    name = 'trial_spark',
    tag = 'trial_spark_tag',
    capacity = 2,
    start = 2,
    empty = 'trial_spark_empty',
    action = Action.bolt({
      id = 'trial_spark',
      range = 20,
      windup = 0,
      cooldown = 0.2,
      speed = 30,
      packet = packet(60, 40, 'astral'),
    }),
  })
  local caster = Fixtures.arena(G)
  check(
    'equipment is given by id without changing the knight',
    Abilities.give(caster, spark.id) == 2
  )
  local mark = caster:spawn('imp', 16, 21)
  mark.awake = false
  caster.player.yaw = math.atan2(mark.x - caster.player.x, mark.z - caster.player.z)
  caster.player.pitch = 0
  check(
    'the spell is cast from its slot and spends a use',
    caster:cast(2) and caster.player.abilityState.trial_spark.uses == 1
  )
  check('a spell is not cast again before its cooldown', not caster:cast(2))
  for _ = 1, 60 do
    caster:update(1 / 120, {})
  end
  check(
    'its bolt flies through the shared projectile system into the demon',
    mark.hp < mark.maxHp and #caster.bullets == 0
  )
  check(
    'the powder charge on Q is untouched by the spell',
    caster.player.abilityState.powder.uses == 2
  )
  check(
    'the last use goes off, then none',
    caster:cast(2) and not caster:cast(2) and caster.player.abilityState.trial_spark.uses == 0
  )
  check(
    'giving already equipped equipment keeps its slot and spent uses',
    Abilities.give(caster, spark.id) == 2 and caster.player.abilityState.trial_spark.uses == 0
  )
  require('tests.cases.ability_extension').run(G, check, spark)
  Abilities:unregister('trial_spark')

  -- Maps are data: Limbo built from its file is the original grid, and a
  -- second map builds, seats the knight and names its zones.
  local Arena = require('src.world.arena')
  local Maps = require('src.content.maps.index')
  local limbo = Arena.new('floor')
  local sum, open, pillars = 0, 0, 0
  for z = 1, limbo.size do
    for x = 1, limbo.size do
      local cell = limbo.map[z][x]
      sum = sum + cell * (z * 31 + x)
      open = open + (cell == 0 and 1 or 0)
      pillars = pillars + (cell == 2 and 1 or 0)
    end
  end
  check(
    'Limbo from its data file is the original grid (cells, floor, pillars)',
    limbo.size == 31 and sum == 207290 and open == 588 and pillars == 16
  )
  Maps:register('trial_cell', {
    id = 'trial_cell',
    size = 12,
    rooms = { { 2, 2, 11, 11 } },
    pillars = { { 6, 6 } },
    portal = { x = 10, z = 3 },
    spawn = { x = 3, z = 10, yaw = 0 },
    ember = { x = 10, z = 10 },
    gates = { { x = 3, z = 3 } },
    lamps = { { 4, 4 } },
    lampHeight = 1.18,
    emberClear = 2,
    zones = { { name = 'CELL WEST', xBelow = 6 }, { name = 'CELL EAST' } },
  })
  local cell = G.new('floor', 'trial_cell')
  cell.ephemeral = true
  local w = cell.world
  check(
    'a second map builds from data (walls, floor, pillar, gates, braziers)',
    w.mapId == 'trial_cell'
      and w.size == 12
      and w.map[1][1] == 1
      and w.map[3][3] == 0
      and w.map[6][6] == 2
      and #w.gates == 1
      and #w.lamps == 1
      and #cell.enemies == 0
  )
  check(
    'the knight starts at the map spawn and its paths and sight work',
    cell.player.x == 3
      and cell.player.z == 10
      and Arena.flow(w, 3, 10)[3 * 12 + 10] ~= nil
      and Arena.visible(w, 3, 10, 10, 10)
  )
  check(
    'its zones are named by its own data',
    Arena.zone(w, 3, 10) == 'CELL WEST' and Arena.zone(w, 9, 4) == 'CELL EAST'
  )
  cell:start()
  for _ = 1, 60 do
    cell:update(1 / 120, { forward = 1 })
  end
  check(
    'a session plays on it (zone banner, movement)',
    cell.zone == 'CELL WEST' and cell.player.z ~= 10
  )
  Maps:unregister('trial_cell')

  -- A new mechanic made only of the engine's blocks (PLAN F3): a rain of
  -- ground marks let go one after another where the target stands, a series
  -- of deposits. The kind declares no state and no clock of its own.
  local ActionKinds = require('src.combat.action_kinds')
  Action.defineKind('trial_rain', {
    count = { type = 'number', min = 1 },
    interval = { type = 'number', min = 0 },
    delay = { type = 'number', min = 0 },
    radius = { type = 'number', min = 0 },
    life = { type = 'number', min = 0 },
  }, { 'count', 'interval', 'delay', 'radius', 'life', 'packet' })
  local blocks, Mechanics = pcall(require, 'src.enemies.mechanics')
  local fell = {}
  if blocks then
    local function fall(world, e, atk, t)
      fell[#fell + 1] = e.phase
      Mechanics.deposit(world, e, t.x, t.z, t.level, atk.delay, atk.radius, atk.life, {
        packet = atk.packet,
        pulse = atk.interval,
      })
    end
    ActionKinds:register('trial_rain', {
      state = Mechanics.series.state,
      unseen = true,
      execute = function(_, e)
        Mechanics.series.start(e)
      end,
      strike = function(world, e, atk)
        Mechanics.series.step(world, e, atk, fall)
      end,
      duration = Mechanics.series.duration,
    })
  end
  Fixtures.words({ trial_rainer = 'Trial Rainer' })
  A.register(Creature.define({
    extends = A.imp,
    id = 'trial_rainer',
    kind = 'imp',
    variant = 'trial_rainer',
    name = 'trial_rainer',
    attacks = {
      Action.trial_rain({
        id = 'rain',
        range = 9,
        windup = 0.3,
        cooldown = 1,
        count = 3,
        interval = 0.25,
        delay = 0.4,
        radius = 1,
        life = 0.6,
        packet = packet(5, 10),
      }),
    },
  }))
  local rained = Fixtures.arena(G)
  local rainer = rained:spawn('trial_rainer', 16, 21)
  rainer.awake, rainer.memory, rainer.spawnAge = true, 60, 1
  local marks, counted = 0, {}
  for _ = 1, 4 * 120 do
    rained:update(1 / 120, {})
    for _, h in ipairs(rained.hazards) do
      if h.owner == rainer.id and not counted[h] then
        counted[h], marks = true, marks + 1
      end
    end
  end
  check(
    'a kind made of a series and a deposit lets its marks go in turn at the target',
    blocks
      and #fell >= 3
      and marks >= 3
      and math.abs(fell[2] - fell[1] - 0.25) < 0.01
      and math.abs(fell[3] - fell[2] - 0.25) < 0.01
  )
  if blocks then
    ActionKinds:unregister('trial_rain')
  end
  A.unregister('trial_rainer')
  Action.kinds:unregister('trial_rain')
  Action.trial_rain = nil
  -- A sigil from data alone (PLAN G2): its effect is a kind of the sigil
  -- registry, hooked to the moments of a fight; the interpreter names no sigil.
  local SigilRules = require('src.content.sigils')
  local Sigils = require('src.combat.sigils')
  local registry, SigilKinds = pcall(require, 'src.combat.sigil_kinds')
  if registry then
    SigilKinds:register('trial_keen', {
      shot = function(_, _, rank, def, _, _, out)
        return { bonus = def.bonus[rank] }
      end,
      contact = function(payload)
        return payload.bonus, 1
      end,
    })
  end
  SigilRules.trial_keen = { costs = { 1 }, effect = 'trial_keen', bonus = { 0.2 } }
  SigilRules.order[#SigilRules.order + 1] = 'trial_keen'
  local bearer = { sigilRanks = { trial_keen = 1 } }
  local keen = Sigils.shot({ elapsed = 0 }, bearer, 'judge', { base = 50, impact = 20 }, 1)
  local struck = Sigils.contact(keen, { id = 3 }, 'torso')
  SigilRules.order[#SigilRules.order] = nil
  SigilRules.trial_keen = nil
  if registry then
    SigilKinds:unregister('trial_keen')
  end
  check(
    'a sigil from data alone sharpens a shot through its own kind of effect',
    registry and math.abs(struck.base - 60) < 1e-9
  )
  -- A new painted style from a painter alone (PLAN G3): the painters claim
  -- what they paint by its data, and the places that draw ask the registry,
  -- never a painter by name.
  local painted, Painters = pcall(require, 'src.render.painters')
  local strokes = 0
  if painted then
    Painters:register('trial_marks', {
      hazards = {
        pool = {
          ground = function(_, _, h)
            if h.art ~= 'trial_mark' then
              return false
            end
            strokes = strokes + 1
            return true
          end,
        },
      },
    })
  end
  local HazardKinds = require('src.render.hazard_kinds')
  local markedPool = { kind = 'pool', art = 'trial_mark', delay = 0, radius = 1 }
  local drew = pcall(HazardKinds:get('pool').ground, nil, {}, markedPool)
  if painted then
    Painters:unregister('trial_marks')
  end
  local named = {}
  for _, file in ipairs({
    'src/render/hazard_kinds.lua',
    'src/render/effects.lua',
    'src/render/cast_accents.lua',
    'src/render/passes/projectiles.lua',
  }) do
    local text = love.filesystem.read(file) or ''
    for style in text:gmatch("'src%.render%.(%w+)_art'") do
      if style ~= 'hazard' and style ~= 'impact' and style ~= 'weapon' then
        named[#named + 1] = file .. ': ' .. style
      end
    end
  end
  check(
    'a painter registered alone paints its style, and drawing names no painter: '
      .. table.concat(named, ', '),
    painted and drew and strokes == 1 and #named == 0
  )
  -- A deed is heard through its event (PLAN G5): the simulation announces a
  -- dodge, the presentation chooses its sound (content/event_cues.lua).
  local Audio = require('src.audio.audio')
  local heard, play = {}, Audio.play
  Audio.play = function(sound, volume)
    heard[#heard + 1] = sound
    return play(sound, volume)
  end
  local dodging = Fixtures.arena(G)
  for _ = 1, 30 do
    dodging:update(1 / 120, {})
  end
  dodging:update(1 / 120, { strafe = 1, dash = true })
  Audio.play = play
  local dashed = false
  for _, sound in ipairs(heard) do
    dashed = dashed or sound == require('src.content.event_cues').Dashed.sound
  end
  check('a dodge is heard through its event, its sound named in content', dashed)
  -- A new kind of marked ground (PLAN Z7) is entries of registries only: the state it
  -- keeps on its mark with its version, what it does, how it looks and where it is heard
  -- from. Its state is carried by every mark it makes, blended in the image as it declares,
  -- kept by a save, and a mark of its older shape is brought up to the new.
  do
    local HazardDefs = require('src.content.hazards')
    local HazardSteps = require('src.enemies.hazards')
    local HazardArt = require('src.render.hazard_kinds')
    local FieldVoices = require('src.audio.field_voices')
    local Components = require('src.session.components')
    local Presentation = require('src.render.presentation')
    local Pools = require('src.session.world')
    local Save = require('src.storage.save')
    local Spawn = require('src.session.spawn')
    local Volumes = require('src.content.defs.area')
    local Copy = require('src.core.schema').copy
    local heard = 0
    local declared = pcall(function()
      HazardDefs:register('trial_drift', {
        volume = 'pool',
        version = 2,
        migrations = {
          [1] = function(h)
            h.drift, h.speedX = h.speedX, nil
          end,
        },
        state = { drift = { desc = 'how fast it slides along x (m/s)', smooth = 'linear' } },
      })
      HazardSteps.kinds:register('trial_drift', {
        step = function(_, h, dt)
          h.x, h.life = h.x + h.drift * dt, h.life - dt
        end,
      })
      HazardArt:register('trial_drift', { ground = function() end })
      FieldVoices.points:register('trial_drift', function(h, _, out)
        heard = heard + 1
        out.x, out.z = h.x, h.z
      end)
    end)
    check('a kind of marked ground is declared by registries alone', declared)
    check(
      'no entry is taken for a kind that is not declared',
      not pcall(HazardArt.register, HazardArt, 'trial_nothing', { ground = function() end })
    )
    local smoothed = false
    for _, field in ipairs(Components.smoothed('hazards')) do
      smoothed = smoothed or field == 'drift'
    end
    check('the image blends what the new kind declares it moves', smoothed)
    local ok, problem = pcall(function()
      local g = G.new('pilgrimage')
      g:act('start')
      g.state = 'playing'
      local p = g.player
      local mark = Spawn.make(g, 'hazard', {
        kind = 'trial_drift',
        x = p.x + 3,
        z = p.z,
        level = p.level,
        delay = 0,
        maxDelay = 0,
        radius = 1,
        life = 5,
        pulse = 0,
        volume = Copy(Volumes.defaults.pool),
        drift = 1.5,
      })
      local from = mark.x
      Presentation.capture(g)
      for _ = 1, 12 do
        g:update(1 / 120, {})
      end
      check('its mark keeps its own state and goes as its kind does', mark.x > from + 0.1)
      -- The field voices ask its kind where it is heard from, as they ask a wave.
      local played = heard
      local out = {}
      FieldVoices.points:get('trial_drift')(mark, p, out)
      check('and it is heard from where its kind says', played > 0 and out.x == mark.x)
      local section = Save.section('pools')
      local packed = section.pack(g)
      check('a save records the version of its state', (packed.hazardKinds or {}).trial_drift == 2)
      section.restore(g, section.unpack(packed))
      local back = Pools.of(g, 'hazards')[1]
      check(
        'and takes its mark up as it was',
        back and back.kind == 'trial_drift' and back.drift == 1.5
      )
      -- A mark as the kind's first version kept it: its speed under another name.
      rawset(back, 'speedX', back.drift)
      back.drift = nil
      packed = section.pack(g)
      packed.hazardKinds = { trial_drift = 1 }
      section.restore(g, section.unpack(packed))
      back = Pools.of(g, 'hazards')[1]
      check(
        'a mark of its older shape is brought up to the new',
        back and back.drift == 1.5 and rawget(back, 'speedX') == nil
      )
      Pools.clear(g, 'hazards')
    end)
    check('the new kind of marked ground holds' .. (ok and '' or ': ' .. tostring(problem)), ok)
    FieldVoices.points:unregister('trial_drift')
    HazardArt:unregister('trial_drift')
    HazardSteps.kinds:unregister('trial_drift')
    HazardDefs:unregister('trial_drift')
    smoothed = false
    for _, field in ipairs(Components.smoothed('hazards')) do
      smoothed = smoothed or field == 'drift'
    end
    check('and is gone again', not smoothed and not HazardDefs:has('trial_drift'))
  end
  -- The world is one map divided into areas (PLAN G4): an area with bounds is
  -- carved out of the map's own; its garrison stands from the start, asleep,
  -- and walking in is a step, not a journey.
  local Way = require('src.content.pilgrimage')
  local Pilgrimage = require('src.run.pilgrimage')
  local Pools = require('src.session.world')
  local carved = pcall(function()
    Way.areas:register('trial_annex', {
      id = 'trial_annex',
      map = Way.start().map,
      bounds = { { 6, 26, 13, 31 } },
      first = 'trial_annex_fire',
      fires = { { id = 'trial_annex_fire', name = 'fire_narthex', x = 9.5, z = 30 } },
      garrison = { { id = 'trial_annex_post', creature = 'imp', x = 9.5, z = 28.5, yaw = 0 } },
    })
  end)
  local walked, asleep, woke, entered = false, false, false, nil
  if carved then
    local way = G.new('pilgrimage')
    Pilgrimage.forget(way)
    way:act('start')
    local annexed
    for _, e in ipairs(Pools.of(way, 'enemies')) do
      if e.post == 'trial_annex_post' then
        annexed = e
      end
    end
    asleep = annexed ~= nil and annexed.dormant == true and way.run.area ~= 'trial_annex'
    way.bus:on('present', 'AreaEntered', function(e)
      entered = e.area
    end)
    local world = way.world
    local p = way.player
    p.x, p.z = 9.5, 27.2
    way:update(1 / 120, {})
    walked = way.run.area == 'trial_annex' and way.world == world
    woke = annexed ~= nil and not annexed.dormant
    Way.areas:unregister('trial_annex')
  end
  check(
    'an area carved out of the one map wakes its garrison as the knight walks in',
    carved and asleep and walked and woke and entered == 'trial_annex'
  )
  -- A kind of attack says what the rest of the game may ask of it by its traits (PLAN A4):
  -- nothing asks for it by name. This one leaves its release to settle on the floor, as a
  -- tear does, and has no voice of its own at its release.
  do
    local Audio = require('src.audio.audio')
    local Spawn = require('src.session.spawn')
    local Volumes = require('src.content.defs.area')
    local Copy = require('src.core.schema').copy
    Action.defineKind('trial_tear', {}, { 'packet' }, {
      traits = { settles = true, silent = true },
    })
    Attacks.kinds.trial_tear = {
      execute = function(g, e, atk, a)
        Spawn.make(g, 'hazard', {
          kind = 'sweepline',
          owner = e.id,
          side = 'demons',
          x = e.x,
          z = e.z,
          level = e.level,
          delay = 0.2,
          maxDelay = 0.2,
          radius = 3,
          width = 0.4,
          angle = a,
          spin = 1,
          volume = Copy(Volumes.defaults.beam),
          life = 0.5,
          packet = atk.packet,
        })
      end,
    }
    A.register(Creature.define({
      extends = A.imp,
      id = 'trial_tearer',
      kind = 'imp',
      variant = 'trial_tearer',
      name = 'trial_thrall',
      attacks = {
        Action.trial_tear({
          id = 'tear',
          range = 6,
          windup = 0.4,
          cooldown = 5,
          sound = 'ember_claw',
          packet = packet(1, 1),
        }),
      },
    }))
    local g = Fixtures.arena(G)
    local demon = g:spawn('trial_tearer', 16, 23)
    demon.awake, demon.memory, demon.spawnAge = true, 60, 1
    local released, voices = 0, {}
    g.bus:on('present', 'AttackReleased', function()
      released = released + 1
    end)
    local playAt = Audio.playAt
    Audio.playAt = function(name, ...)
      voices[name] = true
      return playAt(name, ...)
    end
    local ok, problem = pcall(function()
      for _ = 1, 4 * 120 do
        g:update(1 / 120, {})
        if released > 0 then
          break
        end
      end
    end)
    Audio.playAt = playAt
    A.unregister('trial_tearer')
    Attacks.kinds.trial_tear = nil
    Action.kinds:unregister('trial_tear')
    Action.trial_tear, Action.hooks.trial_tear = nil, nil
    check(
      'a kind with traits of its own is released' .. (ok and '' or ': ' .. tostring(problem)),
      ok and released == 1
    )
    check(
      'a kind whose release settles leaves its painting on the floor',
      #(g.view.riteBursts or {}) == 1
    )
    check('a kind silent at its release has no release voice', not voices.ember_claw)
  end
  -- Everything removed again: the content and registries are as they were.
  Screens:unregister('trial_screen')
  Modes:unregister('trial')
  A.unregister('trial')
  Attacks.kinds.trial_slam = nil
  Action.kinds:unregister('trial_slam')
  Action.trial_slam = nil
  check(
    'the registries are back to the shipped entries',
    not Screens:has('trial_screen')
      and not Modes:has('trial')
      and not Action.kinds:has('trial_slam')
  )
  return lines
end
return Tests

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
  cell.testing = true
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

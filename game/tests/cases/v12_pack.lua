-- The final proof of plan v12: one whole content pack through public registries,
-- played from a start through a fight, a save, a replay and a frame, and gone
-- again. If this needs a change in game/src, the foundation is not finished.
local F = require('tests.support.fixtures')
local Proof = require('tests.support.extension.proof')
local Abilities = require('src.content.abilities')
local A = require('src.content.enemies')
local Ammo = require('src.content.ammo.index')
local Action = require('src.content.defs.action')
local Characters = require('src.content.characters')
local Conditions = require('src.content.conditions')
local Creature = require('src.content.defs.creature')
local Deliveries = require('src.combat.weapon_delivery')
local Delivery = require('src.content.defs.delivery')
local Entities = require('src.session.entities')
local Glyphs = require('src.content.glyphs')
local Integrity = require('src.session.integrity')
local Journal = require('src.session.journal')
local Maps = require('src.content.maps.index')
local Packet = require('src.content.defs.packet')
local Pools = require('src.session.world')
local Save = require('src.storage.session_save')
local Schema = require('src.core.schema')
local Tiles = require('src.core.tiles')
local Types = require('src.content.damage_types')
local Volley = require('src.combat.volley')
local Weapons = require('src.content.weapons')
local T = {}
local none = {
  schema = Schema:new('pack hands', { kind = { type = 'string', required = true } }),
  newState = function()
    return {}
  end,
  valid = function()
    return true
  end,
  canFire = function()
    return true
  end,
  full = function()
    return true
  end,
  stocked = function()
    return false
  end,
  spend = function(_, _, count)
    return count
  end,
  pending = function()
    return 0
  end,
  load = function()
    return 0
  end,
  room = function()
    return 0
  end,
  refill = function()
    return 0
  end,
  fill = function() end,
  clear = function() end,
  restock = function() end,
  left = function()
    return 1
  end,
  meter = function()
    return 1, 0, 1
  end,
  offer = function()
    return 0, 0, 0
  end,
  pack = function()
    return {}
  end,
  list = function()
    return {}
  end,
  unpack = function()
    return {}
  end,
}
local function load()
  Types.define('pack_frost', { armored = false, color = { 0.6, 0.8, 1 } })
  Conditions.register('pack_chill', { speed = 0.7, modifiers = { armor = { mul = 0.8 } } })
  Tiles.define('pack_ice', { walkable = true, speed = 0.7 })
  Ammo:register('pack_none', none)
  Delivery.defineKind('pack_reach', {})
  Deliveries:register('pack_reach', {
    fire = function(g, shot)
      local volley = Volley.new(g, shot.profile, shot.attack, 1, shot.shooter)
      volley.origin, volley.sequence = shot.origin, shot.sequence
      for _, e in ipairs(Pools.of(g, 'enemies')) do
        local d = math.sqrt((e.x - shot.shooter.x) ^ 2 + (e.z - shot.shooter.z) ^ 2)
        if d < 3 then
          volley:contact(e, d, e.x, 1, e.z, { 0, 1, 0 }, 'torso', 1, 0, 0, 1)
        end
      end
      volley:apply()
    end,
  })
  local blade = Schema.copy(Weapons.get('judge'))
  blade.id, blade.art, blade.reload = 'pack_blade', 'judge', nil
  blade.ammo, blade.delivery = { kind = 'pack_none' }, { kind = 'pack_reach' }
  blade.glyphs = { pack_rune = { scale = { base = 2 } } }
  Weapons.define(blade)
  local double = Schema.copy(Weapons.get('judge'))
  double.id, double.art = 'pack_double', 'judge'
  double.secondary = { cycle = 1 }
  Weapons.define(double)
  Glyphs:register('pack_rune', { icon = 'ring' })
  Abilities.define({
    id = 'pack_shard',
    name = 'ability_powder',
    tag = 'ability_powder_tag',
    empty = 'ability_powder_empty',
    capacity = 1,
    start = 1,
    cost = { mana = 20 },
    action = {
      kind = 'bolt',
      id = 'pack_shard',
      range = 11,
      windup = 0.3,
      speed = 12,
      cooldown = 0.2,
      packet = Packet.new(30, 0, 'pack_frost'),
    },
  })
  local warden = Schema.copy(Characters.standard())
  warden.id, warden.name = 'pack_warden', nil
  warden.resources = { mana = { max = 100, start = 100, regen = 5 } }
  warden.kit = { weapons = { 'pack_blade', 'pack_double' }, abilities = { 'pack_shard' } }
  Characters.define(warden)
  A.register(Creature.define({
    extends = A.imp,
    id = 'pack_wight',
    kind = 'imp',
    variant = 'pack_wight',
    name = 'creature_imp',
    catalog = { field = 9 },
    body = { hp = 5000 },
    attacks = {
      Action.bolt({
        id = 'pack_chill',
        range = 11,
        windup = 0.5,
        speed = 9,
        recover = 0.4,
        cooldown = 0.8,
        packet = Packet.new(10, 0, 'pack_frost'),
      }),
    },
  }))
  Entities.define({
    id = 'pack_turret',
    health = 500,
    hittable = true,
    system = {
      after = 'demons',
      step = function(_, e, dt)
        e.state.age = (e.state.age or 0) + dt
      end,
    },
  })
  local cell = Schema.copy(Maps:get('floor'))
  cell.id = 'pack_cell'
  Maps:register('pack_cell', cell)
end
local function unload()
  Maps:unregister('pack_cell')
  Entities.undefine('pack_turret')
  A.unregister('pack_wight')
  Characters.unregister('pack_warden')
  Abilities:unregister('pack_shard')
  Glyphs:unregister('pack_rune')
  Weapons.registry:unregister('pack_double')
  Weapons.registry:unregister('pack_blade')
  Deliveries:unregister('pack_reach')
  Delivery.kinds:unregister('pack_reach')
  Ammo:unregister('pack_none')
  if Tiles.codes.pack_ice then
    Tiles.undefine('pack_ice')
  end
  Conditions.unregister('pack_chill')
  Types:unregister('pack_frost')
end
local function start(Game)
  local g = Game.new('floor')
  g.testing, g.state = true, 'playing'
  local p = g.player
  p.character = 'pack_warden'
  p.resources = { mana = 100 }
  Weapons.give(g, 'pack_blade', p)
  Weapons.give(g, 'pack_double', p)
  Abilities.give(g, 'pack_shard', p)
  p.weapon = Weapons.slotOf(g, 'pack_blade', p)
  g.run.glyphs = { 'pack_rune' }
  local x, z = p.x, p.z
  local e = g:spawn('pack_wight', x + 2, z)
  e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, p.id
  Entities.spawn(g, 'pack_turret', x - 2, z)
  g:setCell(math.floor(x + 0.5), math.floor(z + 0.5), Tiles.pack_ice)
  return g
end
function T.run(Game, renderer)
  local lines = {}
  local check = F.checker(lines, 'v12 pack: ', 'v12 pack: ')
  Proof.with({ unload }, function()
    load()
    local g = start(Game)
    check('a pack starts a session', g.state == 'playing' and #Pools.of(g, 'entities') == 1)
    local record = Journal.record(g)
    local slot = #g.player.abilities
    g:cast(slot)
    for i = 1, 240 do
      g:update(1 / 120, { shoot = i % 40 == 0 })
    end
    Journal.stop(g)
    check('its spell is paid from its mana', g.player.resources.mana < 100)
    check('its blade needs no rounds', g.player.shots > 2)
    local e = Pools.of(g, 'enemies')[1]
    check('its creature fights and bleeds', e and e.hp < e.maxHp)
    check('its turret ticks', Pools.of(g, 'entities')[1].state.age > 1)
    local replay = start(Game)
    Journal.replay(replay, Journal.decode(Journal.encode(record)))
    check(
      'a journal replays all of it',
      not Integrity.difference(Integrity.capture(g), Integrity.capture(replay))
    )
    local copy = start(Game)
    Save.restore(copy, assert(Save.decode(Save.encode(g))))
    check(
      'a save keeps all of it',
      copy.player.character == 'pack_warden'
        and copy.player.resources.mana == g.player.resources.mana
        and #Pools.of(copy, 'entities') == 1
    )
    if renderer then
      renderer:resize(640, 360)
      renderer:draw(g, 640, 360)
      check('a frame draws it', true)
    end
  end)
  check('nothing of it stays', not A.pack_wight and not Maps:has('pack_cell'))
  return lines
end
return T

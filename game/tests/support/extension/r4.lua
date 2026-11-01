-- Plan v12 R4: abilities of any actor, what they cost, how long they take and
-- one execution of an action, through the public registries alone.
local Proof = require('tests.support.extension.proof')
local Abilities = require('src.content.abilities')
local Action = require('src.content.defs.action')
local Attributes = require('src.combat.attributes')
local Cast = require('src.combat.abilities')
local Caster = require('src.combat.caster')
local Characters = require('src.content.characters')
local Conditions = require('src.content.conditions')
local Contracts = require('src.session.content_contracts')
local Kinds = require('src.combat.action_kinds')
local Packet = require('src.content.defs.packet')
local Pools = require('src.session.world')
local Reaction = require('src.content.defs.reaction')
local Rules = require('src.combat.rules')
local Schema = require('src.core.schema')
local Weapons = require('src.content.weapons')
local R = {}
local function spell(id, changes)
  local def = {
    id = id,
    name = 'ability_powder',
    tag = 'ability_powder_tag',
    empty = 'ability_powder_empty',
    capacity = 1,
    start = 1,
    cost = { mana = 30 },
    action = {
      kind = 'bolt',
      id = id,
      range = 11,
      windup = 2,
      speed = 12,
      cooldown = 0.1,
      packet = Packet.new(5, 0, 'astral'),
    },
  }
  for key, value in pairs(changes or {}) do
    def[key] = value
  end
  return def
end
local function mage()
  local def = Schema.copy(Characters.standard())
  def.id, def.name = 'trial_mage', nil
  def.resources = { mana = { max = 100, start = 100, regen = 10 } }
  return def
end
local function steps(g, seconds)
  for _ = 1, math.floor(seconds * 120 + 0.5) do
    g:update(1 / 120, {})
  end
end
local function missiles(g)
  return #Pools.of(g, 'projectiles')
end
local function actor(g, id)
  return g.ecs:create('knight', {
    id = id,
    character = 'trial_mage',
    x = 8,
    z = 20,
    yaw = 0,
    loadout = {},
    arsenal = {},
    abilities = {},
    abilityState = {},
  })
end
function R.run(Game, check, session)
  check(
    'an unknown cost is refused',
    not pcall(Abilities.define, spell('proof_wrong', { cost = { gold = 3 } }))
  )
  check('a character with an unknown resource is refused', not pcall(function()
    local def = mage()
    def.resources = { gold = { max = 1, start = 1 } }
    Characters.define(def)
  end))
  check('the knight has no mana', session(Game).player.resources.mana == nil)
  local ids = { 'proof_lance', 'proof_beam', 'proof_aura', 'proof_shell', 'proof_strike' }
  Proof.with({
    function()
      for _, id in ipairs(ids) do
        Abilities:unregister(id)
      end
      Characters.unregister('trial_mage')
      Conditions.unregister('proof_silence')
      Reaction.unbind('proof_silence')
      if Weapons.registry:has('proof_star') then
        Weapons.registry:unregister('proof_star')
      end
    end,
  }, function()
    Characters.define(mage())
    Conditions.register('proof_silence', { forbids = { 'cast' } })
    Abilities.define(spell('proof_lance'))
    Abilities.define(spell('proof_strike', {
      action = {
        kind = 'lunge',
        id = 'proof_strike',
        range = 2,
        windup = 0,
        lungeSpeed = 8,
        lungeTime = 0.2,
        packet = Packet.new(5, 0),
      },
    }))
    check(
      'a kind of action that cannot be cast is refused at composition',
      not pcall(Contracts.ability, Abilities:get('proof_strike'))
    )
    Abilities:unregister('proof_strike')
    local g = session(Game)
    local first, second = actor(g, 'mage1'), actor(g, 'mage2')
    check('an actor starts with its resources', first.resources.mana == 100)
    Abilities.give(g, 'proof_lance', first)
    Abilities.give(g, 'proof_lance', second)
    check('and its own abilities', first.abilities[1] == 'proof_lance')
    -- A two-second spell, paid at release.
    check('a spell begins', Cast.cast(g, 1, 'mage1'))
    check('it takes time', first.casting ~= nil and missiles(g) == 0)
    steps(g, 1)
    check('nothing is paid during the windup', first.resources.mana > 99)
    steps(g, 1.1)
    check('its missile leaves at release', missiles(g) == 1 and not first.casting)
    check('then it is paid ' .. first.resources.mana, first.resources.mana < 75)
    check('the other actor keeps its own mana', second.resources.mana == 100)
    -- Too little to pay.
    first.resources.mana = 10
    local state = first.abilityState.proof_lance
    state.readyAt = 0
    check('without the mana it does not begin', not Cast.cast(g, 1, 'mage1') and not first.casting)
    -- An interrupted cast is free.
    first.resources.mana = 100
    Cast.cast(g, 1, 'mage1')
    steps(g, 0.5)
    Rules.addCondition(first, 'proof_silence', 1)
    check('the condition forbids it', Attributes.forbids(first, 'cast'))
    steps(g, 0.1)
    check('a condition stops a cast', not first.casting)
    check('and it cost nothing ' .. first.resources.mana, first.resources.mana == 100)
    check('nor can it begin', not Cast.cast(g, 1, 'mage1'))
    -- A channel: pulses through its time.
    Abilities.define(spell('proof_beam', {
      cost = { mana = 5 },
      channel = { time = 1, every = 0.25 },
      action = {
        kind = 'bolt',
        id = 'proof_beam',
        range = 11,
        windup = 0,
        speed = 12,
        cooldown = 0,
        packet = Packet.new(5, 0, 'astral'),
      },
    }))
    local g2 = session(Game)
    local caster = actor(g2, 'mage3')
    Abilities.give(g2, 'proof_beam', caster)
    Cast.cast(g2, 1, 'mage3')
    local mana = caster.resources.mana
    steps(g2, 1.2)
    check('a channel pulses ' .. missiles(g2), missiles(g2) >= 3 and missiles(g2) <= 4)
    check('and pays each pulse', caster.resources.mana < mana)
    check('it ends by itself', not caster.casting)
    -- A toggle: until cast again.
    Abilities.define(spell('proof_aura', {
      cost = { mana = 1 },
      toggle = { every = 0.5 },
      action = {
        kind = 'bolt',
        id = 'proof_aura',
        range = 11,
        windup = 0,
        speed = 12,
        cooldown = 0,
        packet = Packet.new(1, 0, 'astral'),
      },
    }))
    local g3 = session(Game)
    local aura = actor(g3, 'mage4')
    Abilities.give(g3, 'proof_aura', aura)
    Cast.cast(g3, 1, 'mage4')
    steps(g3, 1.1)
    check('a toggle runs', aura.casting ~= nil)
    Cast.cast(g3, 1, 'mage4')
    check('and stops when cast again', not aura.casting)
    -- One action for a creature, an actor and a place.
    local bolt = require('src.content.creatures.stolas').attacks[1]
    Abilities.define(spell('proof_shell', {
      cost = { uses = 0 },
      action = Schema.copy(bolt),
    }))
    local g4 = session(Game)
    local shooter = g4.player
    Abilities.give(g4, 'proof_shell', shooter)
    shooter.abilityState.proof_shell.readyAt = 0
    local slot = #shooter.abilities
    local windup = bolt.windup
    Cast.cast(g4, slot)
    steps(g4, windup + 0.05)
    local shot = Pools.of(g4, 'projectiles')[1]
    check("a demon's own bolt leaves a knight", shot ~= nil and shot.side == 'knight')
    check(
      'with its speed',
      shot and math.abs(math.sqrt(shot.vx ^ 2 + shot.vy ^ 2 + shot.vz ^ 2) - bolt.speed) < 1e-6
    )
    local place = Caster.point(g4, shooter, 12, 1, 12)
    check('and from a point', Kinds:get('bolt').cast(g4, bolt, place) and place.mx == 12)
    local reaction = Reaction.build(
      { { on = 'shot', effect = { kind = 'action', action = Action.build(Schema.copy(bolt)) } } },
      'proof'
    )
    local gun = Schema.copy(Weapons.get('judge'))
    gun.id, gun.art, gun.reactions = 'proof_star', 'judge', reaction
    Weapons.define(gun)
    Contracts.weapon(Weapons.get('proof_star'))
    local g5 = session(Game)
    local p = g5.player
    Weapons.give(g5, 'proof_star', p)
    p.weapon = Weapons.slotOf(g5, 'proof_star', p)
    p.cooldown = 0
    require('src.combat.combat').shoot(g5, nil, p.id)
    check('a reaction performs an action', missiles(g5) == 1)
  end)
  check('its spells leave with it', not Abilities:has('proof_lance'))
  check('an action kind without an executor fails', not pcall(function()
    Action.defineKind('proof_nothing', {})
    local ok, why = pcall(Kinds.get, Kinds, 'proof_nothing')
    Action.kinds:unregister('proof_nothing')
    Action.proof_nothing = nil
    error(ok and '' or why)
  end))
end
return R

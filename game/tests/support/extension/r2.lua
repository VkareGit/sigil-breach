-- Plan v12 R2: a new way of hitting, a debuff, a kind of harm and what a shot
-- sets off, each through the public registries alone.
local Proof = require('tests.support.extension.proof')
local Attributes = require('src.combat.attributes')
local Ballistics = require('src.combat.ballistics')
local Conditions = require('src.content.conditions')
local Damage = require('src.combat.damage')
local Deliveries = require('src.combat.weapon_delivery')
local Delivery = require('src.content.defs.delivery')
local Hit = require('src.combat.hit')
local Payload = require('src.content.defs.payload')
local Reaction = require('src.content.defs.reaction')
local Rules = require('src.combat.rules')
local Schema = require('src.core.schema')
local Types = require('src.content.damage_types')
local Volley = require('src.combat.volley')
local Weapons = require('src.content.weapons')
local R = {}
local function gun(id, changes)
  local def = Schema.copy(Weapons.get('judge'))
  def.id, def.art = id, 'judge'
  for key, value in pairs(changes) do
    def[key] = value
  end
  return def
end
local function armed(g, id)
  local p = g.player
  Weapons.give(g, id, p)
  p.weapon = Weapons.slotOf(g, id, p)
  p.yaw, p.pitch, p.cooldown, p.reload = 0, 0, 0, 0
  p.x, p.z = 10, 20
  return p
end
-- A body straight ahead of the knight, in the line he fires along.
local function ahead(g, p, distance, kind)
  local dx, _, dz = Ballistics.spreadDirection(p.yaw, p.pitch, 0, 0)
  local e = g:spawn(kind or 'imp', p.x + dx * distance, p.z + dz * distance)
  e.awake = false
  return e
end
local function fire(g)
  local p = g.player
  p.cooldown = 0
  Weapons.state(g, nil, p).readyAt = 0
  return require('src.combat.combat').shoot(g, nil, p.id)
end
local function steps(g, count)
  for _ = 1, count do
    g:update(1 / 120, {})
  end
end
local function damageTypes(check)
  check('a misspelt damage type is refused at once', not pcall(Payload.build, Payload, {
    base = 1,
    impact = 0,
    damageType = 'fyre',
  }))
  check('and in a weapon', not pcall(function()
    local attack = Schema.copy(Weapons.get('judge').attack)
    attack.damageType = 'fyre'
    Weapons.define(gun('proof_typo', { attack = attack }))
  end))
  check('and as a resistance', Types.keysProblem({ fyre = 0.5 }) ~= nil)
  Proof.with({
    function()
      Types:unregister('frost')
    end,
  }, function()
    Types.define('frost', { armored = true, color = { 0.6, 0.8, 1 } })
    local attack = { base = 40, impact = 0, damageType = 'frost' }
    check('a new kind of harm is one entry', not Types.problem('frost'))
    local armored = Damage.resolve(attack, { armorRating = 20 }, 0)
    local bare = Damage.resolve(attack, { armorRating = 0 }, 0)
    check('armour stops what is armoured ' .. armored .. ' < ' .. bare, armored < bare)
  end)
  check('it leaves with its proof', not Types:has('frost'))
end
local function conditions(Game, check, session)
  check('an unknown attribute is refused', not pcall(Conditions.register, 'proof_wrong', {
    modifiers = { armour = { mul = 0.5 } },
  }))
  Proof.with({
    function()
      Conditions.unregister('proof_sundered')
    end,
  }, function()
    Conditions.register('proof_sundered', {
      modifiers = { armor = { mul = 0.25 } },
      forbids = { 'fire' },
    })
    local g = session(Game)
    local body = { armorRating = 40, conditions = { proof_sundered = 3 } }
    check('a condition lowers armour by data', math.abs(Damage.rating(body) - 10) < 1e-9)
    local p = g.player
    Rules.addCondition(p, 'proof_sundered', 1)
    check('and forbids what it names', Attributes.forbids(p, 'fire') and not fire(g))
    p.conditions.proof_sundered = nil
  end)
end
local function deliveries(Game, check, session)
  local ids = { 'proof_beam', 'proof_ricochet', 'proof_needle' }
  Proof.with({
    function()
      for _, id in ipairs(ids) do
        if Weapons.registry:has(id) then
          Weapons.registry:unregister(id)
        end
      end
      for _, id in ipairs({ 'proof_beam', 'proof_ricochet' }) do
        Deliveries:unregister(id)
        Delivery.kinds:unregister(id)
      end
    end,
  }, function()
    -- A beam: every body along the line, through the public volley.
    Delivery.defineKind('proof_beam', {})
    Deliveries:register('proof_beam', {
      fire = function(g, shot)
        local volley = Volley.new(g, shot.profile, shot.attack, 1, shot.shooter)
        volley.origin, volley.sequence = shot.origin, shot.sequence
        local bodies = Ballistics.prepare(g, shot.shooter)
        local dx, dy, dz = Ballistics.spreadDirection(shot.yaw, shot.pitch, 0, 0)
        for _, h in
          ipairs(Ballistics.traceAll(g, dx, dy, dz, shot.profile.range, bodies, volley.origin))
        do
          volley:contact(
            h.enemy,
            h.distance,
            h.x,
            h.y,
            h.z,
            { 0, 1, 0 },
            h.part,
            1,
            dx,
            dy,
            dz,
            h.contact
          )
        end
        volley:apply()
      end,
    })
    Weapons.define(gun('proof_beam', { delivery = { kind = 'proof_beam' } }))
    local g = session(Game)
    local p = armed(g, 'proof_beam')
    local first, second = ahead(g, p, 3), ahead(g, p, 5)
    local a, b = first.hp, second.hp
    check('a beam fires', fire(g))
    check('and reaches every body on its line', first.hp < a and second.hp < b)
    -- A ricochet: a ray, then a ray from where it ended.
    local traced = {}
    Delivery.defineKind('proof_ricochet', {})
    Deliveries:register('proof_ricochet', {
      fire = function(g2, shot)
        local volley = Volley.new(g2, shot.profile, shot.attack, 2, shot.shooter)
        volley.origin, volley.sequence = shot.origin, shot.sequence
        local bodies = Ballistics.prepare(g2, shot.shooter)
        local dx, dy, dz = Ballistics.spreadDirection(shot.yaw, shot.pitch, 0, 0)
        volley:ray(1, dx, dy, dz, 0, 0, bodies)
        local ray = volley.report.rays[1]
        local n = ray.normal or { 0, 0, -1 }
        local dot = dx * n[1] + dy * n[2] + dz * n[3]
        local rx, ry, rz = dx - 2 * dot * n[1], dy - 2 * dot * n[2], dz - 2 * dot * n[3]
        volley.origin = { ray.x + rx * 0.01, ray.y + ry * 0.01, ray.z + rz * 0.01 }
        volley:ray(2, rx, ry, rz, 0, 0, bodies)
        volley:apply()
        traced = volley.report.rays
      end,
    })
    Weapons.define(gun('proof_ricochet', { delivery = { kind = 'proof_ricochet' } }))
    local g2 = session(Game)
    local shooter = armed(g2, 'proof_ricochet')
    check('a ricochet fires', fire(g2) and shooter.shots > 0)
    check(
      'and goes on from where its first ray ended',
      #traced == 2 and traced[2].distance > 0 and traced[1].dz == -traced[2].dz
    )
    -- A finite round that goes through bodies.
    local attack = Schema.copy(Weapons.get('judge').attack)
    attack.pierce = { bodies = 1, retain = 0.8, armorCost = 0, minRetain = 0.1 }
    Weapons.define(gun('proof_needle', {
      delivery = { kind = 'projectile', speed = 60 },
      attack = attack,
    }))
    local g3 = session(Game)
    local needle = armed(g3, 'proof_needle')
    local near, middle, far = ahead(g3, needle, 3), ahead(g3, needle, 5), ahead(g3, needle, 7)
    local n, m, f = near.hp, middle.hp, far.hp
    check('a piercing round fires', fire(g3))
    steps(g3, 60)
    check('it wounds the first body', near.hp < n)
    check('then the next, with less', middle.hp < m and m - middle.hp < n - near.hp)
    check('and stops after its bodies', far.hp == f)
  end)
  check('new deliveries leave with their proof', Deliveries:find('proof_beam') == nil)
end
local function reactions(Game, check, session)
  check(
    'an unknown event is refused',
    not pcall(Reaction.build, { { on = 'wave', effect = { kind = 'heal', amount = 1 } } }, 'proof')
  )
  check('a reaction cannot carry a reaction', not pcall(Reaction.build, {
    {
      on = 'kill',
      effect = {
        kind = 'heal',
        amount = 1,
        reactions = { { on = 'kill', effect = { kind = 'heal', amount = 1 } } },
      },
    },
  }, 'proof'))
  check('a shot strikes nobody', not pcall(Reaction.build, {
    { on = 'shot', target = 'struck', effect = { kind = 'heal', amount = 1 } },
  }, 'proof'))
  local blast = Schema.copy(require('src.content.abilities'):get('powder').action.blast)
  Proof.with({
    function()
      for _, id in ipairs({ 'proof_leech', 'proof_bomb' }) do
        if Weapons.registry:has(id) then
          Weapons.registry:unregister(id)
        end
      end
    end,
  }, function()
    Weapons.define(gun('proof_leech', {
      reactions = { { on = 'shot', effect = { kind = 'heal', amount = 7 } } },
    }))
    local g = session(Game)
    local p = armed(g, 'proof_leech')
    p.hp = 50
    fire(g)
    check('a weapon heals on its shot', p.hp == 57)
    Weapons.define(gun('proof_bomb', {
      reactions = {
        { on = 'kill', effect = { kind = 'blast', radius = 3, blast = blast } },
      },
    }))
    local g2 = session(Game)
    local p2 = armed(g2, 'proof_bomb')
    local victim, neighbour = ahead(g2, p2, 4), ahead(g2, p2, 5)
    victim.hp = 1
    local before = neighbour.hp
    local kills = {}
    g2.bus:on('sim', 'EnemyKilled', function(event)
      kills[#kills + 1] = event.weapon
    end)
    fire(g2)
    check('a kill names the weapon', kills[1] == 'proof_bomb')
    check('a weapon explodes on a kill', victim.hp <= 0 and neighbour.hp < before)
    local chain = ahead(g2, p2, 4.5)
    chain.hp = 1
    neighbour.hp = 1
    local far = ahead(g2, p2, 7.6)
    local whole = far.hp
    Hit.wound(g2, chain, 1, 'weapon', nil, p2.id, 'proof_bomb')
    check('what a reaction kills sets off no reaction', neighbour.hp <= 0 and far.hp == whole)
  end)
  check('production has no reactions', Weapons.get('judge').reactions == nil)
  -- Every event, every source, in their order.
  Proof.with({
    function()
      Reaction.unbind('wounded')
      if Weapons.registry:has('proof_tally') then
        Weapons.registry:unregister('proof_tally')
      end
    end,
  }, function()
    local function gain(on, amount)
      return { on = on, effect = { kind = 'heal', amount = amount } }
    end
    Weapons.define(gun('proof_tally', {
      reactions = { gain('miss', 1), gain('surface', 2), gain('hit', 4), gain('reload', 8) },
    }))
    check('a reaction on an unknown condition is refused', not pcall(Reaction.bind, 'nothing', {}))
    Reaction.bind('wounded', { gain('shot', 16) })
    local g = session(Game)
    local p = armed(g, 'proof_tally')
    p.hp = 10
    fire(g)
    check('a shot at a wall is a miss and a surface ' .. p.hp, p.hp == 13)
    p.hp = 10
    local e = ahead(g, p, 3)
    fire(g)
    check('a shot at a body is a hit ' .. p.hp, e.hp < e.maxHp and p.hp == 14)
    p.hp = 10
    Rules.addCondition(p, 'wounded', 1)
    fire(g)
    check('a condition reacts for its bearer ' .. p.hp, p.hp >= 26)
  end)
  check('its binding leaves with it', Reaction.ofCondition.wounded == nil)
end
function R.run(Game, check, session)
  damageTypes(check)
  conditions(Game, check, session)
  deliveries(Game, check, session)
  reactions(Game, check, session)
end
return R

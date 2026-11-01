-- The one way a blow lands on a creature, whatever delivered it: measure it,
-- wound the body, then let the body answer. Sums (a volley's pellets) are made
-- by the caller between measure and land, so an order of pellets can never open
-- a hole through a body an earlier one killed.
local Corpse = require('src.enemies.corpse')
local Damage = require('src.combat.damage')
local Rules = require('src.combat.rules')
local Signal = require('src.session.signal')
local Hit = {}
-- Pure: what a contact would do. Returns dealt, absorbed, impact, push.
-- surface (optional): the painted surface met; part: the hit zone otherwise.
function Hit.measure(attack, target, distance, part, surface)
  if surface then
    return Damage.surface(attack, target, distance, surface)
  end
  return Damage.resolve(attack, target, distance, part)
end
-- The wound alone (combat/rules/hit_response.lua).
Hit.wound = Rules.wound
-- The body's answer alone (rules, corpse), announced with BlowResolved.
-- number (optional): { value, kill, head } shown where a single blow landed;
-- a volley's numbers come with VolleyResolved.
function Hit.answer(g, target, impact, strong, point, contact, health, extra, number)
  local result = Rules.react(
    g,
    target,
    impact,
    strong,
    point,
    health or (contact and contact.healthDamage),
    extra
  )
  Corpse.struck(g, target, impact, strong, point, contact)
  Signal(g, 'BlowResolved', {
    target = target,
    result = result,
    impact = impact,
    point = point,
    contact = contact,
    number = number,
  })
  return result
end
-- A whole single blow. tally: { damage, impact }; blow: { source, payload,
-- owner, weapon, strong, point, extra, numbered, head, label }. Returns the
-- health it took.
function Hit.land(g, target, tally, blow)
  local health = math.min(target.hp, tally.damage)
  Hit.wound(g, target, tally.damage, blow.source, blow.payload, blow.owner, blow.weapon)
  local number = blow.numbered
    and { value = health, kill = target.hp <= 0, head = blow.head, source = blow.label }
  Hit.answer(
    g,
    target,
    tally.impact,
    blow.strong,
    blow.point,
    nil,
    health,
    blow.extra,
    number or nil
  )
  return health
end
return Hit

-- What every attack kind shares when it meets a body (plan v10 V6:
-- enemies/actions.lua split by responsibility): the body the attack is for
-- (enemies/target.lua) and its swept points, the blow that lands, the blow
-- a perfect dodge spends, the rush that carries the attacker.
local Melee = require('src.combat.melee')
local BodyContact = require('src.combat.body_contact')
local Dodge = require('src.combat.dodge')
local Rules = require('src.combat.rules')
local Bodies = require('src.combat.bodies')
local Target = require('src.enemies.target')
local Contact = {}
local sin, cos = math.sin, math.cos
Contact.victim = Target.of
-- Where the body stood when the step began and where it stands now (plan
-- v10 V2). The controlled knight's step start is the one the session passes
-- down (given); any other body's comes from Bodies.previous.
local sweepFrom, sweepTo = {}, {}
function Contact.previous(g, t, given)
  if t == Bodies.controlled(g) then
    return given
  end
  return Bodies.sweep(g, Bodies.previous(g, t), sweepFrom)
end
function Contact.point(g, t)
  return Bodies.sweep(g, t, sweepTo)
end
-- The controlled knight at the end of a sub-step: the body a moving demon
-- meets (combat/body_contact.lua: moveEnemy). For the target it is the same
-- point the contact uses.
function Contact.knightAt(g, t, current, given, step, dt)
  local k = Bodies.controlled(g)
  if t == k then
    return current
  end
  return step < dt and Melee.playerAt(given or k, k, step / dt, nil, g.world) or k
end
function Contact.hurt(g, e, atk, t, contact)
  local packet = Rules.packet(e, atk.packet)
  if contact then
    contact.kind, contact.id, contact.owner, contact.target = 'melee', atk.id, e.id, t.id
  end
  g:damageBody(t, packet.base, e.x, e.z, packet, e, contact and { contact = contact })
  e.didHit = true
end
-- A blow that missed the dodging knight but met his afterimage (where the
-- dodge began) is spent on it: a perfect dodge (session/damage_outcomes.lua).
function Contact.dodged(g, e, atk, t)
  e.didHit = true
  Dodge.perfect(g, Rules.packet(e, atk.packet), e, t)
end
-- Move the body along its rush; a blow that met the rush scales it.
function Contact.rush(g, e, speed, step, previous, current)
  local s = speed * (e.rushScale or 1)
  e.rushVX, e.rushVZ = e.lungeX * s, e.lungeZ * s
  BodyContact.moveEnemy(g, e, e.rushVX * step, e.rushVZ * step, previous, current)
end
-- Turn the attack toward its aim angle a.
function Contact.face(_, e, _, a)
  e.lungeX, e.lungeZ = sin(a), cos(a)
end
return Contact

-- The knight's dodge as a defence (0.24 perfect dodge, 0.25 afterimage).
-- A blow that lands while the knight is mid-dodge — on him, or on the
-- afterimage he left where the dodge began (so it would have met him) — is
-- a perfect dodge. Once per dodge: the charge comes back, the demons freeze
-- for a beat and a melee attacker within reach takes its own blow on its
-- guard. Attack kinds, missiles and marked strikes test their contact with
-- Dodge.afterimage when they miss the knight himself; the damage path calls
-- Dodge.perfect for a blow on him during the dodge.
-- Emits PerfectDodge (session/event_catalog.lua).
local Signal = require('src.session.signal')
local Capabilities = require('src.session.capabilities')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local Roles = require('src.core.roles')
local Dodge = {}
-- While the knight dodges and its perfect dodge is unspent: the body he left
-- where the dodge began, at his present height (one shared record).
local ghost = {}
-- knight (optional): whose afterimage (default the controlled knight). A body
-- that is no knight leaves none.
function Dodge.afterimage(g, knight)
  local p = knight or Roles.controlled(g)
  if p.dashTimer == nil then
    return nil
  end
  if (p.dashTimer or 0) <= 0 or not p.dodgeFromX or p.perfectUsed then
    return nil
  end
  ghost.x, ghost.z, ghost.jump, ghost.crouch = p.dodgeFromX, p.dodgeFromZ, p.jump, p.crouch
  return ghost
end
-- A blow (its packet) dodged perfectly; source: the demon whose own body
-- delivered it (nil for a missile or a marked strike); knight (optional):
-- who dodged (default the controlled knight). True when granted.
function Dodge.perfect(g, packet, source, knight)
  local player, rule = knight or Roles.controlled(g), Rules.playerBody().perfectDodge
  if
    not rule
    or player.perfectUsed
    or not packet
    or (packet.impact or 0) <= 0
    or g.state ~= 'playing'
    or not Capabilities.vulnerable(g)
  then
    return false
  end
  player.perfectUsed = true
  player.dash = math.min(Tuning.knight.dashCharges, player.dash + rule.refund)
  g.impactSlow = math.max(g.impactSlow or 0, rule.freeze)
  local returned
  if
    source
    and source.hp > 0
    and math.sqrt((source.x - player.x) ^ 2 + (source.z - player.z) ^ 2) < rule.reach
  then
    local broke, heavy = Rules.guard(source, packet.impact * rule.guardReturn)
    returned = { staggered = broke, heavy = heavy }
  end
  Signal(g, 'PerfectDodge', { packet = packet, source = source, returned = returned })
  return true
end
return Dodge

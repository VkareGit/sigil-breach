-- The knight under the same rules: a blow on the player and a wall slam.
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local Capabilities = require('src.session.capabilities')
local Signal = require('src.session.signal')
local Archetypes = require('src.content.enemies')
local Damage = require('src.combat.damage')
local defaults = Archetypes.defaults
local sqrt, max = math.sqrt, math.max
return function(R)
  -- The player under the same rules: damage type and resistance first, then the
  -- consumable shield pool, then guard (poise), stagger, wound and shove.
  -- packet: {base, impact, push?, damageType}. Returns health lost, absorbed,
  -- overkill, amount and the events of the blow.
  function R.hitPlayer(g, packet, x, z)
    local p = g.player
    local b = Archetypes.player.body
    if type(packet) == 'number' then
      packet = { base = packet, impact = 0 }
    end
    local amount = packet.base or 0
    if type(amount) ~= 'number' or amount ~= amount or amount <= 0 or amount == math.huge then
      return 0, 0, 0
    end
    local kind = packet.damageType or 'physical'
    amount = amount * (1 - Damage.resistance(p.resist or b.resist, kind))
    local lost, absorbed, overkill = Damage.player(amount, p.hp, p.armor, b.shieldShare)
    p.armor = p.armor - absorbed
    p.hp = p.hp - lost
    local impact = packet.impact or 0
    local events = { impact = impact }
    if impact > 0 then
      local dx, dz = x and p.x - x or 0, z and p.z - z or 0
      local d = sqrt(dx * dx + dz * dz)
      if d > defaults.sameSpot then
        -- The same impulse law as every demon (R.shove), the knight's mass.
        local speed = R.shove(packet.push or impact, b.mass)
        R.addPush(p, dx / d, dz / d, speed, b.mass)
      end
      p.guardQuiet = 0
      p.poise = (p.poise or 0) + impact
      if p.poise >= b.poise then
        local stagger = R.staggerTime(p.poise, b.poise, b)
        p.poise = 0
        R.addCondition(p, 'staggered', stagger)
        Signal(g, 'PlayerStaggered', { time = stagger })
        events.staggered = true
        events.staggerTime = stagger
      end
    end
    if lost >= b.woundAt * b.hp then
      R.addCondition(p, 'wounded', b.woundFor)
      events.wounded = true
    end
    return lost, absorbed, overkill, amount, events
  end
  -- The player shoved into a wall: the same slam rule, through the same
  -- player resolution (shield, guard), without a new shove.
  function R.slamPlayer(g, speed, sourceX, sourceZ)
    local p = g.player
    local over = speed - defaults.slamSpeed
    if over <= 0 or (p.slamLock or 0) > 0 or g.state ~= 'playing' then
      return 0
    end
    p.slamLock = defaults.slamLock
    local recorded = false
    if Capabilities.vulnerable(g) then
      local previousHP = p.hp
      local packet = {
        base = over * defaults.slamDamage * R.playerBody().slamShare,
        impact = over * defaults.slamPoise,
        damageType = 'physical',
      }
      local lost, absorbed, overkill, incoming, events = R.hitPlayer(g, packet)
      -- Preserve the nonlethal wall rule without healing a player below .5 HP.
      if p.hp <= 0 then
        p.hp = math.min(previousHP, 0.5)
        lost = previousHP - p.hp
        overkill = math.max(0, incoming - absorbed - lost)
      end
      if g.recordPlayerDamage then
        g:recordPlayerDamage({
          amount = incoming,
          requested = packet.base,
          lost = lost,
          absorbed = absorbed,
          overkill = overkill,
          impact = packet.impact,
          damageType = 'physical',
          source = 'wall',
          x = sourceX,
          z = sourceZ,
          staggered = events and events.staggered,
          wounded = events and events.wounded,
        })
        recorded = true
      end
    end
    g.lastSlam = { x = p.x, z = p.z, speed = speed, player = true }
    Signal(g, 'WallSlam', { body = p, speed = speed, player = true })
    return over, recorded
  end
end

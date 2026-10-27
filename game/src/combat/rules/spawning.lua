-- Spawning: a fresh body from its archetype, the wave tier, the attack slots
-- of a tier and the damage packet as this body delivers it.
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local Archetypes = require('src.content.enemies')
local defaults = Archetypes.defaults
return function(R)
  -- Copy the body of an archetype onto a fresh enemy record.
  function R.equip(e, archetype)
    local b = archetype.body
    e.archetype = archetype
    e.hp = b.hp
    e.maxHp = b.hp
    e.armorRating = b.armor
    e.resistances = b.resist
    e.immune = b.immune
    e.soak = b.soak
    e.locationArmor = b.locationArmor
    e.zones = b.zones or defaults.zones
    e.mass = b.mass
    e.boss = b.boss or false
    e.speed = archetype.move.speed
    e.rewardSouls = archetype.souls
    e.displayName = archetype.name
    e.conditions = {}
    return e
  end
  -- Wave tier (Risk of Rain 2 style coefficient), applied once at spawn.
  -- Telegraphs never shorten: only speed, damage, health and aggression grow,
  -- and aim lead unlocks. Tier 1 is the calibrated base of every archetype.
  function R.applyTier(e, tier)
    local T = defaults.tiers
    tier = math.max(1, math.floor(tier or 1))
    local k = tier - 1
    e.tier = tier
    e.tierSpeed = 1 + T.speed * k
    e.tierDamage = 1 + T.damage * k
    e.tierPace = 1 + T.aggression * k
    e.tierLead = T.lead[math.min(#T.lead, tier)] or 1
    if k > 0 then
      e.hp = math.floor(e.hp * (1 + T.health * k) + 0.5)
      e.maxHp = e.hp
    end
    if R.archetype(e).phases then
      e.phaseBaseHp = e.maxHp
    end
    return e
  end
  -- How many demons of this tier may attack at once (bosses keep their own).
  function R.maxAttackers(e)
    local own = R.archetype(e).maxAttackers
    if own then
      return own
    end
    local list = defaults.tiers.attackers
    return list[math.min(#list, e.tier or 1)] or 2
  end
  -- The damage packet of an attack as this demon delivers it (tier damage).
  -- Packets are shared data; scaled copies are cached per body.
  function R.packet(e, packet)
    local scale = e and e.tierDamage or 1
    if not packet or scale == 1 then
      return packet
    end
    e.packetCache = e.packetCache or {}
    local scaled = e.packetCache[packet]
    if not scaled then
      scaled = {}
      for k, v in pairs(packet) do
        scaled[k] = v
      end
      scaled.base = (packet.base or 0) * scale
      e.packetCache[packet] = scaled
    end
    return scaled
  end
end

-- Pure combat math. Ratings are not a second health pool.
local MathX = require('src.core.mathx')
local Defaults = require('src.content.combat_defaults')
local Materials = require('src.content.ballistic_surfaces')
local Attributes = require('src.combat.attributes')
local DamageTypes = require('src.content.damage_types')
local D = {}
local clamp = MathX.clamp
-- The armour rating that halves physical damage (Warhammer-style points).
D.armorScale = Defaults.damage.armorScale
local finite = MathX.finite
-- An attack table may be partial (tests, area blasts, wall slams): a missing
-- field takes its neutral value, so it changes nothing.
D.neutral = {
  base = 0,
  power = 1,
  zone = 1,
  upgrade = 1,
  falloffStart = 0,
  falloffEnd = 1,
  minPower = 1,
  penetration = 0,
  headMultiplier = 1,
  damageType = DamageTypes.fallback,
}
-- Bounds of every resistance (D&D): vulnerable to -25 %, resistant to 60 %.
D.resistMin, D.resistMax = Defaults.damage.resistMin, Defaults.damage.resistMax
local neutral = D.neutral
local function field(attack, key)
  local v = attack[key]
  if v == nil then
    return neutral[key]
  end
  return v
end
-- Resistance to a damage type, the same bounds for every body (D&D: below 0
-- a vulnerability, at most -25 %; resistance at most 60 %).
function D.resistance(table_, kind)
  local r = type(table_) == 'table' and table_[kind or DamageTypes.fallback] or 0
  if not finite(r) then
    return 0
  end
  return clamp(r, D.resistMin, D.resistMax)
end
local function curve(start, finish, floor)
  return finite(start)
    and finite(finish)
    and finite(floor)
    and start >= 0
    and finish > start
    and floor >= 0
    and floor <= 1
end
function D.falloff(distance, start, finish, floor)
  assert(curve(start, finish, floor), 'invalid damage curve')
  if not finite(distance) then
    return 0
  end
  return 1 - (1 - floor) * clamp((math.max(0, distance) - start) / (finish - start), 0, 1)
end
-- Returns dealt, absorbed, impact (guard damage), push (physical impulse).
function D.resolve(attack, target, distance, part)
  if type(attack) ~= 'table' or type(target) ~= 'table' then
    return 0, 0, 0, 0
  end
  local dealt, absorbed, impact, push = D.core(attack, target, distance, part)
  -- Immunity (D&D) removes the wound but not the shove of the blow.
  local kind = field(attack, 'damageType')
  if type(target.immune) == 'table' and target.immune[kind] then
    return 0, absorbed + dealt, impact, push
  end
  -- Flat soak (Warhammer Toughness) after armour: many weak pellets lose more
  -- than one heavy slug. Zero for every archetype unless its data sets it.
  local soak = tonumber(target.soak) or 0
  if finite(soak) and soak > 0 and dealt > 0 then
    local cut = math.min(dealt, soak)
    return dealt - cut, absorbed + cut, impact, push
  end
  return dealt, absorbed, impact, push
end
-- One contact policy for hitscan rounds and finite missiles. Shape IDs never
-- select damage; the authored zone and material do. A held weapon has no zone.
function D.surface(attack, target, distance, contact)
  local dealt, absorbed, impact, push = D.resolve(attack, target, distance, contact.zone)
  if contact.zone == false then
    return 0, absorbed + dealt, 0, 0
  end
  local material = assert(Materials[contact.material], 'unknown ballistic surface')
  return dealt * material.wound,
    absorbed + dealt * (1 - material.wound),
    impact * material.guard,
    push
end
-- Hit zone of a body (CoD-style location table). Zones scale the wound and
-- the guard damage, never the physical push: a shot in the legs unbalances
-- the body, it does not throw it further. Missing data means 1.
local function zoneOf(target, part)
  local zones = type(target.zones) == 'table' and target.zones or nil
  return zones and part and zones[part] or nil
end
D.zoneOf = zoneOf
-- The armour rating a blow on this part meets: the part's own (Warhammer
-- location armour) when the body defines it, else its one rating, as its
-- conditions change it (a boss whose guard just broke keeps half of it).
function D.rating(target, part)
  local located = type(target.locationArmor) == 'table' and part and target.locationArmor[part]
  local rating = located or target.armorRating or 0
  if target.conditions then
    rating = rating * Attributes.scale(target, 'armor')
  end
  return rating
end
function D.core(attack, target, distance, part)
  local start, finish, floor =
    field(attack, 'falloffStart'), field(attack, 'falloffEnd'), field(attack, 'minPower')
  if not curve(start, finish, floor) then
    return 0, 0, 0, 0
  end
  local base, power, zone, upgrade =
    field(attack, 'base'), field(attack, 'power'), field(attack, 'zone'), field(attack, 'upgrade')
  local location = zoneOf(target, part)
  local zoneDamage = location and location.damage or 1
  local zoneGuard = location and location.guard or 1
  local rating, penetration = D.rating(target, part), field(attack, 'penetration')
  local kind = field(attack, 'damageType')
  local resistance = D.resistance(target.resistances, kind)
  local impulse = attack.impact or base
  local wound = part == 'head' and field(attack, 'headMultiplier') or 1
  if
    not (
      finite(base)
      and finite(power)
      and finite(zone)
      and finite(upgrade)
      and finite(rating)
      and finite(penetration)
      and finite(resistance)
      and finite(impulse)
      and finite(wound)
    )
  then
    return 0, 0, 0, 0
  end
  if base < 0 or power < 0 or zone < 0 or upgrade < 0 or impulse < 0 then
    return 0, 0, 0, 0
  end
  local falloff = D.falloff(distance or 0, start, finish, floor)
  local scale = math.max(0, power) * falloff * math.max(0, zone) * math.max(0, upgrade)
  -- A deliberate hit on the anatomical head changes the wound, not the
  -- projectile's momentum. No random critical roll or invisible aim assist.
  local raw = math.max(0, base) * scale * clamp(wound, 0, 2) * math.max(0, zoneDamage)
  local armored = DamageTypes.entries[kind]
  armored = armored and armored.armored
  local armor = armored and math.max(0, rating) * (1 - clamp(penetration, 0, 1)) or 0
  local dealt = raw * D.armorScale / (D.armorScale + armor) * (1 - resistance)
  -- impact: guard (poise) damage; push: physical impulse. A weapon may set
  -- them apart (the Judge breaks a guard more than it throws a body).
  local impact = math.max(0, impulse) * scale * math.max(0, zoneGuard)
  local push = math.max(0, attack.push or impulse) * scale
  if not finite(dealt) or not finite(impact) or not finite(push) then
    return 0, 0, 0, 0
  end
  return dealt, math.max(0, raw - dealt), impact, push
end
-- Player armor is a consumable protection pool, unlike enemy armor rating.
-- share: the fraction of each hit the pool intercepts (the knight's body data,
-- shieldShare 0.55). Report actual health loss
-- separately from incoming force and lethal overkill.
function D.player(amount, hp, armor, share)
  if not (finite(amount) and finite(hp) and finite(armor)) or amount <= 0 then
    return 0, 0, 0
  end
  local absorbed = math.min(math.max(0, armor), amount * (share or Defaults.damage.armorShare))
  local remaining = amount - absorbed
  local lost = math.min(math.max(0, hp), remaining)
  return lost, absorbed, math.max(0, remaining - lost)
end
-- Health a blow keeps after distance and zone, before armour.
function D.retained(attack, distance, part)
  local raw = D.resolve(attack, {}, distance, part)
  return raw
end
-- The part of it a target's armour takes (the shot report's armour line):
-- the same rating the wound met (D.rating), so a bare skull shows none.
function D.armorLoss(attack, target, distance, part)
  local kind = DamageTypes.entries[attack.damageType or DamageTypes.fallback]
  if not (kind and kind.armored) then
    return 0
  end
  local rating = math.max(0, D.rating(target, part)) * (1 - clamp(attack.penetration or 0, 0, 1))
  return D.retained(attack, distance, part) * rating / (D.armorScale + rating)
end
return D

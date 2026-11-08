-- How the hands carry the weapon in hand (PLAN E6): the shared hand motion
-- (content/hand_motion.lua) with the weapon's own profile (its hands field)
-- laid over it. A weapon without one is carried by the shared numbers.
local Context = require('src.session.context')
local Weapons = require('src.content.weapons')
local HandMotion = require('src.content.hand_motion')
local H = {}
local function over(shared, own)
  if own == nil then
    return shared
  end
  local out = {}
  for key, value in pairs(shared) do
    out[key] = value
  end
  for key, value in pairs(own) do
    local base = shared[key]
    out[key] = type(base) == 'table' and type(value) == 'table' and #base == 0 and over(base, value)
      or value
  end
  return out
end
local made = setmetatable({}, { __mode = 'k' })
-- The hand profile of a weapon definition.
function H.of(def)
  if not def or not def.hands then
    return HandMotion
  end
  local profile = made[def]
  if not profile then
    profile = over(HandMotion, def.hands)
    made[def] = profile
  end
  return profile
end
-- The hand profile of the weapon the viewed actor holds.
function H.current(g)
  local actor = Context.actor(g)
  return H.of(Weapons.inHand(g, nil, actor) or Weapons.profile(1, g, actor))
end
return H

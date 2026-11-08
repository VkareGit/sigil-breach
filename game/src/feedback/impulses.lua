-- One place where view impulses meet (PLAN E5). An event answers through a
-- profile of content/view_reactions.lua; answers of many events sum within one
-- shared limit per channel, and a weaker peak never lowers a stronger one.
local Kinematics = require('src.physics.kinematics')
local ViewReactions = require('src.content.view_reactions')
local MathX = require('src.core.mathx')
local Impulses = {}
local channels = ViewReactions.channels
function Impulses.shake(view, amount)
  view.shake = math.max(view.shake, amount)
end
-- A spring impulse given age s ago: the spring is linear, so the impulse
-- moves on by itself and adds to what the channel already holds.
function Impulses.kick(view, key, velocity, spring, age)
  local x, v = Kinematics.spring(0, velocity, 0, spring[1], spring[2], age)
  local rate = key .. 'V'
  view[key], view[rate] = view[key] + x, view[rate] + v
end
-- How much of a profile reaches distance m: all of it within near, far of it
-- at reach, nothing from reach on. nil: it does not reach.
local function falloff(profile, distance)
  local reach = profile.reach
  if not reach or not distance then
    return 1
  end
  if distance >= reach then
    return nil
  end
  local near, far = profile.near or 0, profile.far or 0
  local fade = math.min(1, math.max(0, (distance - near) / (reach - near)))
  return 1 - (1 - far) * fade
end
local function amountOf(spec, strength)
  if spec.saturate then
    return spec.gain * (1 - math.exp(-strength / spec.saturate))
  end
  local amount = (spec.base or 0) + (spec.gain or 0) * math.min(strength, spec.upTo or strength)
  return spec.cap and math.min(spec.cap, amount) or amount
end
local function weightOf(spec, side, ahead)
  if not (spec.flat or spec.side or spec.ahead or spec.across or spec.along or spec.front) then
    return 1
  end
  local weight = spec.flat or 0
  if spec.side then
    weight = weight + side * spec.side
  end
  if spec.ahead then
    weight = weight + ahead * spec.ahead
  end
  if spec.across then
    weight = weight + math.abs(side) * spec.across
  end
  if spec.along then
    weight = weight + math.abs(ahead) * spec.along
  end
  if spec.front then
    weight = weight + math.max(0, ahead) * spec.front
  end
  return weight
end
-- An event of the given strength, from direction side/ahead in the viewer's
-- frame, distance m away. profile: a name in content/view_reactions.lua or a
-- profile table.
function Impulses.react(view, profile, strength, side, ahead, distance)
  if type(profile) == 'string' then
    profile = assert(ViewReactions.profiles[profile], 'unknown reaction profile ' .. profile)
  end
  local share = falloff(profile, distance)
  if not share then
    return
  end
  strength, side, ahead = strength or 0, side or 0, ahead or 0
  for key, spec in pairs(profile) do
    local channel = type(spec) == 'table'
      and assert(channels[key], 'reaction channel ' .. key .. ' is not declared')
    if channel and not (channel.motion and view.motion == false) then
      local answer = amountOf(spec, strength) * share * weightOf(spec, side, ahead)
      if channel.peak then
        view[key] = math.max(view[key], answer)
      else
        local value = view[key] + answer
        if channel.limits then
          value = MathX.clamp(value, channel.limits[1], channel.limits[2])
        end
        view[key] = value
      end
    end
  end
end
return Impulses

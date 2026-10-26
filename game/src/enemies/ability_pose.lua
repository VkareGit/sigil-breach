-- Read ability animation phases from simulation clocks; never advance them.
-- Returns source-art keys and frame indices, without images or hit geometry.
local MathX = require('src.core.mathx')
local Animation = require('src.enemies.animation')
local Capabilities = require('src.session.capabilities')
local Archetypes = require('src.content.enemies')
local AbilityArt = require('src.content.ability_art')
local Timing = AbilityArt.timing
local AbilityPose = {}
local samples = {}
AbilityPose.samplers = samples
function AbilityPose.register(id, sampler)
  assert(
    type(id) == 'string' and type(sampler) == 'function',
    'ability sampler needs an id and function'
  )
  assert(samples[id] == nil, 'ability sampler already registered: ' .. id)
  samples[id] = sampler
end
function AbilityPose.unregister(id)
  local sampler = samples[id]
  samples[id] = nil
  return sampler
end
function samples.leap(e)
  if e.ai == 'windup' then
    return Animation.actionPhase(e) < Timing.coil and 1 or 2, 0
  elseif e.ai == 'strike' and e.leaping then
    local phase = (e.phase or 0) / math.max(Timing.minimumFlight, e.leapFlight or 1)
    return phase < Timing.launch and 3 or ((e.leapVY or 0) >= 0 and 4 or 5), 0
  elseif e.ai == 'recover' and e.didHit and e.leaping == false then
    local phase = Animation.actionPhase(e)
    return phase < Timing.land and 6 or (phase < Timing.rise and 7 or 8), 0
  end
end
function samples.evade(e)
  if e.ai ~= 'move' or (e.evadeTime or 0) <= 0 then
    return nil
  end
  local duration = Archetypes.of(e).move.evade.time
  local phase = MathX.clamp01(1 - e.evadeTime / duration)
  local frame = #Timing.evade + 1
  for index, boundary in ipairs(Timing.evade) do
    if phase < boundary then
      frame = index
      break
    end
  end
  return frame, (e.evadeSide or 1) > 0 and 1 or 0
end
function AbilityPose.select(g, e)
  if
    e.hp <= 0
    or e.ai == 'hurt'
    or (e.stun or 0) > 0
    or (e.spawnAge or 1) < Timing.arrival
    or (e.previewFrame and Capabilities.posed(g))
  then
    return nil
  end
  -- Each sampler answers only for its own active state and clock (an attack
  -- in wind-up, strike or recovery; a sidestep while it lasts). The art of an
  -- attack that is not running says nothing, so it never hides a sidestep.
  local look = Archetypes.look(e)
  local sequence = look.art and look.art[e.attackKind]
  for _, key in ipairs({ sequence or false, look.evadeArt or false }) do
    if key then
      local entry = AbilityArt.get(key)
      local sampler = assert(
        samples[entry.sampler],
        'ability artwork ' .. key .. ': missing sampler ' .. entry.sampler
      )
      local frame, mirror = sampler(e)
      if frame then
        assert(
          type(frame) == 'number' and frame % 1 == 0 and entry.frames[frame],
          'ability artwork ' .. key .. ': sampler returned unknown frame ' .. tostring(frame)
        )
        return key, frame, mirror
      end
    end
  end
end
return AbilityPose

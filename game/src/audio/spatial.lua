-- Playback positions and envelopes belong to presentation, never to a saved body.
local Arena = require('src.world.arena')
local Context = require('src.session.context')
local Mix = require('src.content.audio_mix')
local S = {}
local voices = setmetatable({}, { __mode = 'k' })
local mixGains = {}
local obstructionPeriod, obstructionRate = 0.08, 18
local function position(source, entry, listener)
  local origin = entry.emitter or entry
  local dx, dz = origin.x - listener.x, origin.z - listener.z
  local distance = math.sqrt(dx * dx + dz * dz)
  local divisor = math.max(1, distance)
  local side = (dx * math.cos(listener.yaw) - dz * math.sin(listener.yaw)) / divisor
  local forward = (dx * math.sin(listener.yaw) + dz * math.cos(listener.yaw)) / divisor
  source:setPosition(side * 0.8, 0, -forward * 0.8)
  entry.distance = distance
  return origin
end
function S.begin(source, base, category, capped, recipe, level)
  source:setFilter()
  voices[source] =
    { base = base, category = category or 'effects', capped = capped, recipe = recipe, raw = level }
end
function S.attach(source, x, z, listener, world, emitter, attenuation)
  local entry = voices[source]
  entry.base = entry.base / attenuation
  entry.x, entry.z, entry.listener, entry.world, entry.emitter = x, z, listener, world, emitter
  entry.obstruction = world and not Arena.visible(world, x, z, listener.x, listener.z) and 0.38 or 1
  entry.target = entry.obstruction
  entry.probe = obstructionPeriod
  position(source, entry, listener)
  if entry.obstruction < 1 then
    source:setFilter({ type = 'lowpass', volume = 1, highgain = 0.4 })
  end
end
function S.fade(source, seconds)
  local entry = voices[source]
  if not entry or seconds <= 0 then
    return false
  end
  if not entry.fade then
    entry.fade, entry.remaining = seconds, seconds
  end
  return true
end
function S.rise(source, seconds)
  local entry = voices[source]
  if entry then
    entry.rise, entry.risen = seconds, 0
    entry.raw = 0
    source:setVolume(0)
  end
end
function S.remove(source)
  voices[source] = nil
end
function S.isWorld(source)
  local entry = voices[source]
  return entry and entry.listener ~= nil
end
function S.emits(source, emitter)
  local entry = voices[source]
  return entry and entry.emitter == emitter
end
function S.reset()
  voices = setmetatable({}, { __mode = 'k' })
  mixGains = {}
end
function S.loudness(source)
  local entry = voices[source]
  return entry and entry.raw or source:getVolume()
end
function S.mix(sources, dt)
  local totals = {}
  for _, source in ipairs(sources) do
    local entry = voices[source]
    local group = entry and not entry.paused and entry.recipe.mixGroup
    if group then
      totals[group] = (totals[group] or 0) + entry.raw
    end
  end
  for group, budget in pairs(Mix.groups) do
    local total = totals[group] or 0
    local target = total > budget and budget / total or 1
    local previous = mixGains[group] or 1
    mixGains[group] = total == 0 and 1
      or target < previous and target
      or previous + (target - previous) * (1 - math.exp(-dt / Mix.release))
  end
  for _, source in ipairs(sources) do
    local entry = voices[source]
    local group = entry and not entry.paused and entry.recipe.mixGroup
    if group then
      source:setVolume(entry.raw * mixGains[group])
    end
  end
end
function S.update(source, dt, g, levels, muted)
  local entry = voices[source]
  if not entry then
    return source:isPlaying()
  end
  local level = entry.base
  if entry.listener then
    if g and entry.world and g.world ~= entry.world then
      source:stop()
      return false
    end
    local paused = g and (g.state ~= 'playing' or g.map or g.help)
    if paused then
      if entry.fade then
        source:stop()
        return false
      end
      if not entry.paused then
        entry.paused = source:isPlaying()
        if entry.paused then
          source:pause()
        end
      end
      return entry.paused or false
    elseif entry.paused then
      entry.paused = false
      source:play()
    end
    local listener = g and Context.viewer(g) or entry.listener
    local origin = position(source, entry, listener)
    entry.probe = entry.probe - dt
    if entry.world and entry.probe <= 0 then
      entry.probe = obstructionPeriod
      local target = Arena.visible(entry.world, origin.x, origin.z, listener.x, listener.z) and 1
        or 0.38
      if target ~= entry.target then
        entry.target = target
        source:setFilter({ type = 'lowpass', volume = 1, highgain = target < 1 and 0.4 or 1 })
      end
    end
    entry.obstruction = entry.obstruction
      + (entry.target - entry.obstruction) * (1 - math.exp(-dt * obstructionRate))
    level = entry.distance > 32 and 0
      or level * entry.obstruction / (1 + entry.distance * (entry.recipe.falloff or 0.13))
  end
  if entry.capped then
    level = math.min(1, level)
  end
  if entry.rise then
    entry.risen = math.min(entry.rise, entry.risen + dt)
    level = level * entry.risen / entry.rise
    if entry.risen == entry.rise then
      entry.rise = nil
    end
  end
  if entry.fade then
    entry.remaining = math.max(0, entry.remaining - dt)
    if entry.remaining == 0 then
      source:stop()
      return false
    end
    level = level * (entry.remaining / entry.fade) ^ 2
  end
  entry.raw = muted and 0 or level * (levels[entry.category] or 1)
  source:setVolume(entry.raw)
  return source:isPlaying()
end
return S

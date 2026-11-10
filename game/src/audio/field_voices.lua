-- One audible beat per caster/material; independent rites never silence one another.
local Mix = require('src.content.audio_mix')
local Context = require('src.session.context')
local Pools = require('src.session.world')
local Profiles = require('src.audio.creature_profiles')
local V = {}
local sessions = setmetatable({}, { __mode = 'k' })
local defaults = { fire = 'ash_eruption', lightning = 'thunder' }
local function point(hazard, listener, out)
  out.x, out.z = hazard.x, hazard.z
  if hazard.kind == 'wave' then
    local dx, dz = listener.x - hazard.x, listener.z - hazard.z
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance > 0 then
      out.x, out.z =
        hazard.x + dx / distance * hazard.radius, hazard.z + dz / distance * hazard.radius
    end
  elseif hazard.kind == 'sweepline' then
    local dx, dz = math.sin(hazard.angle or 0), math.cos(hazard.angle or 0)
    local along = math.max(
      0,
      math.min(hazard.radius, (listener.x - hazard.x) * dx + (listener.z - hazard.z) * dz)
    )
    out.x, out.z = hazard.x + dx * along, hazard.z + dz * along
  end
end
-- The marks of the live session, never of a drawn sample (PLAN Z4: the image smooths
-- them; a field's voice is keyed by the mark itself).
local function live(g)
  return Pools.of(g._contextRoot or g, 'hazards')
end
function V.reset()
  for _, state in pairs(sessions) do
    for _, entry in pairs(state.fields) do
      if entry.source then
        state.audio.stopVoice(entry.source, entry.ticket)
      end
    end
  end
  sessions = setmetatable({}, { __mode = 'k' })
end
local function stop(audio, entry)
  if entry.source then
    audio.stopVoice(entry.source, entry.ticket, Mix.field.fade)
  end
  entry.source, entry.ticket = nil, nil
end
local function finish(audio, g, entry, cancelled)
  if cancelled or (entry.profile and entry.profile.sustain) then
    stop(audio, entry)
  end
  if not cancelled and entry.profile and entry.profile.finish and entry.started then
    audio.playAt(
      entry.profile.finish,
      entry.x,
      entry.z,
      Context.viewer(g),
      Mix.field.finish,
      0,
      g.world
    )
  end
  entry.ended = true
end
local function stateOf(audio, g)
  local root = g._contextRoot or g
  local state = sessions[root]
  if state and state.world ~= g.world then
    for _, entry in pairs(state.fields) do
      stop(audio, entry)
    end
    state = nil
  end
  if not state then
    state = { world = g.world, audio = audio, fields = {}, beats = {} }
    sessions[root] = state
  end
  return state
end
local function activate(audio, g, state, hazard)
  local profile, listener = Profiles.field(g, hazard), Context.viewer(g)
  local entry = { profile = profile, present = true, retry = Mix.field.retry }
  point(hazard, listener, entry)
  state.fields[hazard] = entry
  local voice = (profile and profile.sustain and profile.active)
    or hazard.impactSound
    or (profile and profile.active)
    or defaults[hazard.packet and hazard.packet.damageType]
  local key = tostring(hazard.owner or '')
    .. '/'
    .. tostring(hazard.kind or 'pool')
    .. '/'
    .. tostring(hazard.art or '')
    .. '/'
    .. tostring(voice)
  entry.grouped = voice and state.beats[key] ~= nil
  if voice and not state.beats[key] then
    entry.source, entry.ticket = audio.playAt(
      voice,
      entry.x,
      entry.z,
      listener,
      Mix.field.volume,
      Mix.field.rank,
      g.world,
      nil,
      entry
    )
    entry.started = true
    if entry.source and profile and profile.sustain and audio.loopVoice then
      audio.loopVoice(entry.source, entry.ticket)
    end
    state.beats[key] = Mix.field.beat
  end
  return entry
end
function V.struck(audio, g, hazard)
  local state = stateOf(audio, g)
  -- A short contact may begin and end within one simulation step.
  if not state.fields[hazard] and not hazard.cancelled then
    activate(audio, g, state, hazard)
  end
end
function V.ended(audio, g, hazard)
  local state = sessions[g._contextRoot or g]
  local entry = state and state.fields[hazard]
  if entry and not entry.ended then
    finish(audio, g, entry, hazard.cancelled)
  end
end
function V.update(audio, g, dt)
  local listener = Context.viewer(g)
  local state = stateOf(audio, g)
  for key, time in pairs(state.beats) do
    state.beats[key] = time > dt and time - dt or nil
  end
  for _, entry in pairs(state.fields) do
    entry.present = false
  end
  for _, hazard in ipairs(live(g)) do
    local entry = state.fields[hazard]
    if entry then
      entry.present = true
      if not entry.ended then
        point(hazard, listener, entry)
        if hazard.cancelled or hazard.life <= 0 then
          finish(audio, g, entry, hazard.cancelled)
        elseif
          entry.profile
          and entry.profile.sustain
          and not entry.grouped
          and audio.ownsVoice
          and not audio.ownsVoice(entry.source, entry.ticket)
        then
          entry.retry = (entry.retry or 0) - dt
          if entry.retry <= 0 then
            entry.retry = Mix.field.retry
            entry.source, entry.ticket = audio.playAt(
              entry.profile.active,
              entry.x,
              entry.z,
              listener,
              Mix.field.volume,
              Mix.field.rank,
              g.world,
              nil,
              entry
            )
            if entry.source then
              entry.started = true
              audio.loopVoice(entry.source, entry.ticket, math.max(0, -(hazard.delay or 0)))
            end
          end
        end
      end
    elseif
      hazard.delay <= 0
      and hazard.life > 0
      and not hazard.cancelled
      and not hazard.waitForCast
    then
      activate(audio, g, state, hazard)
    end
  end
  for hazard, entry in pairs(state.fields) do
    if not entry.present then
      if not entry.ended then
        finish(audio, g, entry, hazard.cancelled)
      end
      state.fields[hazard] = nil
    end
  end
end
function V.restored(audio, g)
  local state = { world = g.world, audio = audio, fields = {}, beats = {} }
  sessions[g._contextRoot or g] = state
  for _, hazard in ipairs(live(g)) do
    if hazard.delay <= 0 and not hazard.waitForCast then
      -- Active ambience may resume, but the impact happened before the save.
      local profile = Profiles.field(g, hazard)
      local entry = { profile = profile, present = true }
      point(hazard, Context.viewer(g), entry)
      state.fields[hazard] = entry
      if profile and profile.sustain and hazard.life > 0 and not hazard.cancelled then
        entry.source, entry.ticket = audio.playAt(
          profile.active,
          entry.x,
          entry.z,
          Context.viewer(g),
          Mix.field.volume,
          Mix.field.rank,
          g.world,
          nil,
          entry
        )
        entry.started = true
        if audio.loopVoice then
          audio.loopVoice(entry.source, entry.ticket, math.max(0, -(hazard.delay or 0)))
        end
      end
    end
  end
end
return V

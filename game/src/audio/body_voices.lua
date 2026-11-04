-- Creature presence belongs to presentation, never to a save or simulation RNG.
local Context = require('src.session.context')
local Bodies = require('src.combat.bodies')
local Enemies = require('src.content.enemies')
local K = require('src.content.audio_presence')
local V = {}
local sessions = setmetatable({}, { __mode = 'k' })
local function stop(audio, entry)
  if entry.source then
    audio.stopVoice(entry.source, entry.ticket)
  end
  entry.source, entry.ticket, entry.role = nil, nil, nil
end
function V.reset()
  sessions = setmetatable({}, { __mode = 'k' })
end
local function stateOf(audio, g)
  local root = g._contextRoot or g
  local state = sessions[root]
  if state and state.world ~= g.world then
    for _, entry in pairs(state.bodies) do
      stop(audio, entry)
    end
    state = nil
  end
  if not state then
    state = { world = g.world, gap = 0, bodies = setmetatable({}, { __mode = 'k' }) }
    sessions[root] = state
  end
  return state
end
local function entryOf(state, e)
  local entry = state.bodies[e]
  if not entry then
    entry = { remaining = 0.8 + ((e.id or 0) % 7) / 7 * K.stagger, alternate = false }
    state.bodies[e] = entry
  end
  return entry
end
function V.interrupt(audio, g, e)
  local sounds = Enemies.of(e).sounds
  if not sounds.breath and not sounds.hurt then
    return
  end
  local entry = entryOf(stateOf(audio, g), e)
  stop(audio, entry)
  entry.remaining = math.max(entry.remaining, K.resumeDelay)
end
function V.hurt(audio, g, e)
  local voice = Enemies.of(e).sounds.hurt
  if not voice or e.hp <= 0 then
    return
  end
  local entry = entryOf(stateOf(audio, g), e)
  if (entry.hurtAt or -math.huge) + K.hurtGap > g.elapsed then
    return
  end
  V.interrupt(audio, g, e)
  entry.hurtAt = g.elapsed
  entry.source, entry.ticket =
    audio.playAt(voice, e.x, e.z, Context.viewer(g), K.hurtGain, 1, g.world)
  entry.role = 'hurt'
end
function V.update(audio, g, dt)
  local p = Context.viewer(g)
  if not p or not g.world then
    return
  end
  local state = stateOf(audio, g)
  if g.state ~= 'playing' or p.hp <= 0 or g.map or g.help then
    for _, entry in pairs(state.bodies) do
      stop(audio, entry)
    end
    return
  end
  state.gap = math.max(0, state.gap - dt)
  for e, entry in pairs(state.bodies) do
    if e.hp <= 0 then
      stop(audio, entry)
    end
  end
  Bodies.eachCreature(g, function(e)
    local sounds = Enemies.of(e).sounds
    if sounds.breath then
      local entry = entryOf(state, e)
      local nearby = e.hp > 0 and (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2 < K.reach ^ 2
      local quiet = nearby and e.ai ~= 'windup' and e.ai ~= 'strike' and e.ai ~= 'hurt'
      if not quiet then
        if not nearby or entry.role ~= 'hurt' then
          stop(audio, entry)
        end
        entry.remaining = math.max(entry.remaining, K.resumeDelay)
      else
        entry.remaining = entry.remaining - dt
        if entry.remaining <= 0 and state.gap <= 0 then
          stop(audio, entry)
          local voice = entry.alternate and sounds.murmur or sounds.breath
          entry.source, entry.ticket =
            audio.playAt(voice or sounds.breath, e.x, e.z, p, K.gain, 0, g.world)
          entry.role = 'breath'
          entry.alternate = not entry.alternate
          entry.remaining = K.interval + ((e.id or 0) % 5) / 5 * K.stagger
          state.gap = K.gap
        end
      end
    end
  end)
end
return V

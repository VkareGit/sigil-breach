-- Creature presence belongs to presentation, never to a save or simulation RNG.
local Context = require('src.session.context')
local Bodies = require('src.combat.bodies')
local Archetypes = require('src.content.enemies')
local AudioPresence = require('src.content.audio_presence')
local Recipes = require('src.audio.recipes')
local V = {}
local sessions = setmetatable({}, { __mode = 'k' })
local function stop(audio, entry)
  if entry.source then
    audio.stopVoice(entry.source, entry.ticket, 0.02)
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
    entry = { remaining = 0.8 + ((e.id or 0) % 7) / 7 * AudioPresence.stagger, alternate = false }
    state.bodies[e] = entry
  end
  return entry
end
function V.interrupt(audio, g, e)
  local sounds = Archetypes.of(e).sounds
  if not sounds.breath and not sounds.hurt then
    return
  end
  local entry = entryOf(stateOf(audio, g), e)
  stop(audio, entry)
  entry.remaining = math.max(entry.remaining, AudioPresence.resumeDelay)
end
function V.hurt(audio, g, e)
  local voice = Archetypes.of(e).sounds.hurt
  if not voice or e.hp <= 0 then
    return
  end
  local entry = entryOf(stateOf(audio, g), e)
  if (entry.hurtAt or -math.huge) + AudioPresence.hurtGap > g.elapsed then
    return
  end
  V.interrupt(audio, g, e)
  entry.hurtAt = g.elapsed
  entry.source, entry.ticket =
    audio.playAt(voice, e.x, e.z, Context.viewer(g), AudioPresence.hurtGain, 1, g.world, nil, e)
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
    local sounds = Archetypes.of(e).sounds
    if sounds.breath then
      local entry = entryOf(state, e)
      local contexts = Recipes[sounds.breath] and Recipes[sounds.breath].presence
      if contexts and e.ai == 'recover' and entry.pose ~= 'recover' then
        entry.remaining = math.min(entry.remaining, AudioPresence.resumeDelay)
      end
      entry.pose = e.ai
      local nearby = e.hp > 0 and (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2 < AudioPresence.reach ^ 2
      local quiet = nearby and e.ai ~= 'windup' and e.ai ~= 'strike' and e.ai ~= 'hurt'
      if not quiet then
        if not nearby or entry.role ~= 'hurt' then
          stop(audio, entry)
        end
        entry.remaining = math.max(entry.remaining, AudioPresence.resumeDelay)
      else
        entry.remaining = entry.remaining - dt
        if entry.remaining <= 0 and state.gap <= 0 then
          stop(audio, entry)
          local voice = entry.alternate and sounds.murmur or sounds.breath
          if contexts then
            if e.ai == 'recover' then
              voice = contexts.recover or voice
            elseif (e.walkSpeed or 0) > AudioPresence.movingSpeed then
              voice = contexts.move or voice
            end
          end
          entry.source, entry.ticket = audio.playAt(
            voice or sounds.breath,
            e.x,
            e.z,
            p,
            AudioPresence.gain,
            0,
            g.world,
            nil,
            e
          )
          entry.role = 'breath'
          entry.alternate = not entry.alternate
          entry.remaining = AudioPresence.interval + ((e.id or 0) % 5) / 5 * AudioPresence.stagger
          state.gap = AudioPresence.gap
        end
      end
    end
  end)
end
return V

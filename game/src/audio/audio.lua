-- The sound effects: each recipe (audio/recipes.lua) rendered once at start,
-- then played from a pool of voices; the score is audio/soundscape.lua.
local Synth = require('src.audio.synth')
local Recipes = require('src.audio.recipes')
local A = {
  sources = {},
  live = {},
  muted = false,
  pool = {},
  pooled = 0,
  voiceNames = {},
  priorities = {},
}
A.rate = 44100
local tickets, serial = setmetatable({}, { __mode = 'k' }), 0
-- Every sound has its own seeded noise (Synth.seed of its name), so the order
-- of rendering decides nothing and a new recipe changes no other sound.
function A.release()
  for _, source in pairs(A.sources) do
    source:stop()
    source:release()
  end
  for _, source in ipairs(A.live) do
    source:stop()
    source:release()
  end
  for _, list in pairs(A.pool) do
    for _, source in ipairs(list) do
      source:stop()
      source:release()
    end
  end
  A.sources, A.live, A.pool, A.voiceNames, A.pooled = {}, {}, {}, {}, 0
  A.priorities = {}
  A.warningHold = 0
  tickets = setmetatable({}, { __mode = 'k' })
  require('src.audio.world_cues').reset()
  require('src.audio.soundscape').release()
end
function A.init(checkpoint)
  require('src.audio.contracts').validate()
  A.release()
  local names = {}
  for name in pairs(Recipes) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local recipe = Recipes[name]
    local voice = recipe.voice or recipe.make(A.rate)
    local data = Synth.effect(recipe.duration, A.rate, Synth.seed(name), voice)
    A.sources[name] = love.audio.newSource(data, 'static')
    data:release()
    if checkpoint then
      checkpoint('sound ' .. name)
    end
  end
  require('src.audio.soundscape').init(checkpoint)
end
-- Reuse finished voices instead of allocating a new Source on every pellet,
-- step and impact. Both active voices and the idle cache have strict caps.
local function recycle(s)
  s:stop()
  local name = A.voiceNames[s]
  A.voiceNames[s] = nil
  A.priorities[s] = nil
  tickets[s] = nil
  if name and A.pooled < 28 then
    A.pool[name] = A.pool[name] or {}
    local list = A.pool[name]
    list[#list + 1] = s
    A.pooled = A.pooled + 1
  else
    s:release()
  end
end
function A.play(name, volume, priority)
  if A.muted or not A.sources[name] then
    return
  end
  priority = priority or Recipes[name].priority or 1
  if #A.live >= 28 then
    local victim = 1
    for i = 2, #A.live do
      if (A.priorities[A.live[i]] or 0) < (A.priorities[A.live[victim]] or 0) then
        victim = i
      end
    end
    -- A drip/footfall cannot steal an attack warning or the player's shot.
    if (A.priorities[A.live[victim]] or 0) > priority then
      return
    end
    recycle(table.remove(A.live, victim))
  end
  local list = A.pool[name]
  local s
  if list and #list > 0 then
    s = table.remove(list)
    A.pooled = A.pooled - 1
  else
    s = A.sources[name]:clone()
  end
  A.voiceNames[s] = name
  A.priorities[s] = priority
  if priority >= 3 then
    A.warningHold = 0.65
  end
  s:setVolume(volume or 0.65)
  s:setPitch(1)
  s:setRelative(true)
  s:setPosition(0, 0, 0)
  s:setRolloff(0)
  local jitter = Recipes[name].jitter
  if jitter then
    s:setPitch(1 - jitter + love.math.random() * 2 * jitter)
  end
  s:play()
  A.live[#A.live + 1] = s
  serial = serial + 1
  tickets[s] = serial
  return s, serial
end
-- A Source may have been recycled for another voice since its caller held it.
-- The playback ticket prevents cancelling that unrelated sound.
function A.stopVoice(source, ticket)
  if source and ticket and tickets[source] == ticket then
    source:stop()
  end
end
function A.playAt(name, x, z, p, volume, priority, world)
  local dx, dz = x - p.x, z - p.z
  local d = math.sqrt(dx * dx + dz * dz)
  if d > 32 then
    return
  end
  local gain = (volume or 0.6) / (1 + d * 0.13)
  if world and not require('src.world.arena').visible(world, x, z, p.x, p.z) then
    gain = gain * 0.38
  end
  local s, ticket = A.play(name, gain, priority)
  if s then
    local side =
      math.max(-1, math.min(1, (dx * math.cos(p.yaw) - dz * math.sin(p.yaw)) / math.max(1, d)))
    s:setRelative(true)
    s:setPosition(side * 0.8, 0, -0.6)
    s:setRolloff(0)
  end
  return s, ticket
end
function A.update(dt, g)
  A.warningHold = math.max(0, (A.warningHold or 0) - dt)
  if g then
    require('src.audio.soundscape').update(A, dt, g)
  end
  for i = #A.live, 1, -1 do
    if not A.live[i]:isPlaying() then
      recycle(table.remove(A.live, i))
    end
  end
  if g and dt > 0 then
    require('src.audio.world_cues').update(A, g, dt)
  end
end
function A.toggle()
  A.muted = not A.muted
  love.audio.setVolume(A.muted and 0 or 0.7)
end
return A

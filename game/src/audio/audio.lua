-- The sound effects: each recipe (audio/recipes.lua) rendered once at start,
-- then played from a pool of voices; the score is audio/soundscape.lua.
local Synth = require('src.audio.synth')
local Recipes = require('src.audio.recipes')
local A = { sources = {}, live = {}, muted = false, pool = {}, pooled = 0, voiceNames = {} }
A.rate = 44100
-- Every sound has its own seeded noise (Synth.seed of its name), so the order
-- of rendering decides nothing and a new recipe changes no other sound.
function A.init()
  for name, recipe in pairs(Recipes) do
    local voice = recipe.voice or recipe.make(A.rate)
    local data = Synth.effect(recipe.duration, A.rate, Synth.seed(name), voice)
    A.sources[name] = love.audio.newSource(data, 'static')
    data:release()
  end
  require('src.audio.soundscape').init(A)
end
-- Reuse finished voices instead of allocating a new Source on every pellet,
-- step and impact. Both active voices and the idle cache have strict caps.
local function recycle(s)
  s:stop()
  local name = A.voiceNames[s]
  A.voiceNames[s] = nil
  if name and A.pooled < 28 then
    A.pool[name] = A.pool[name] or {}
    local list = A.pool[name]
    list[#list + 1] = s
    A.pooled = A.pooled + 1
  else
    s:release()
  end
end
function A.play(name, volume)
  if A.muted or not A.sources[name] then
    return
  end
  while #A.live >= 28 do
    recycle(table.remove(A.live, 1))
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
  return s
end
function A.playAt(name, x, z, p, volume)
  local dx, dz = x - p.x, z - p.z
  local d = math.sqrt(dx * dx + dz * dz)
  local s = A.play(name, (volume or 0.6) / (1 + d * 0.13))
  if s then
    local side =
      math.max(-1, math.min(1, (dx * math.cos(p.yaw) - dz * math.sin(p.yaw)) / math.max(1, d)))
    s:setRelative(true)
    s:setPosition(side * 0.8, 0, -0.6)
    s:setRolloff(0)
  end
  return s
end
function A.update(dt, g)
  if g then
    require('src.audio.soundscape').update(A, dt, g)
  end
  for i = #A.live, 1, -1 do
    if not A.live[i]:isPlaying() then
      recycle(table.remove(A.live, i))
    end
  end
end
function A.toggle()
  A.muted = not A.muted
  love.audio.setVolume(A.muted and 0 or 0.7)
end
return A

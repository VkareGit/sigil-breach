-- The sound effects: each recipe (audio/recipes.lua) rendered once at start,
-- then played from a pool of voices; the score is audio/soundscape.lua.
local Contracts = require('src.audio.contracts')
local Soundscape = require('src.audio.soundscape')
local WorldCues = require('src.audio.world_cues')
local Arena = require('src.world.arena')
local VoiceData = require('src.audio.voice_data')
local Recipes = require('src.audio.recipes')
local Sets = require('src.content.sound_sets')
local A = {
  sources = {},
  live = {},
  muted = false,
  pool = {},
  pooled = 0,
  voiceNames = {},
  priorities = {},
  -- Recorded takes by set and cue (content/sound_sets.lua), and the set in use (0.43, D02).
  takes = {},
  set = Sets.default,
  lastTake = {},
}
A.rate = 44100
-- Its own stream: the take a cue plays never moves the rolls of the fight.
local takeRolls = love and love.math and love.math.newRandomGenerator(43)
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
  for _, cues in pairs(A.takes) do
    for _, list in pairs(cues) do
      for _, source in ipairs(list) do
        source:stop()
        source:release()
      end
    end
  end
  A.takes, A.lastTake = {}, {}
  A.priorities = {}
  A.warningHold = 0
  tickets = setmetatable({}, { __mode = 'k' })
  WorldCues.reset()
  Soundscape.release()
end
function A.init(checkpoint)
  Contracts.validate()
  A.release()
  local names = {}
  for name in pairs(Recipes) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local recipe = Recipes[name]
    local data = VoiceData.render(name, recipe, A.rate)
    A.sources[name] = love.audio.newSource(data, 'static')
    data:release()
    if checkpoint then
      checkpoint('sound ' .. name)
    end
  end
  -- The recorded sets (0.43, D02): a cue whose takes are missing stays synthesised.
  for set, prefix in pairs(Sets.prefix) do
    A.takes[set] = {}
    for cue, spec in pairs(Sets.cues) do
      local list = {}
      for take = 1, Sets.takes do
        local path = Sets.root .. spec.event .. '/' .. prefix .. '-' .. take .. '.wav'
        if love.filesystem.getInfo(path, 'file') then
          list[#list + 1] = love.audio.newSource(path, 'static')
        end
      end
      A.takes[set][cue] = #list > 0 and list or nil
    end
  end
  Soundscape.init(checkpoint)
end
-- The set of sounds in use: classic (synthesis) or a recorded one.
function A.useSet(set)
  A.set = Sets.prefix[set] and set or Sets.default
  return A.set
end
-- Whether a shot's own takes carry its thump and hall (feedback/weight.lua leaves them out).
function A.baked(name)
  local spec = Sets.cues[name]
  return spec ~= nil
    and spec.baked == true
    and A.takes[A.set] ~= nil
    and A.takes[A.set][name] ~= nil
end
-- The recorded take of a cue in the set in use, never the same twice running: its source,
-- the pool key and the gain; nothing for a cue the set does not replace.
local function takeOf(name)
  local list = A.takes[A.set] and A.takes[A.set][name]
  if not list then
    return nil
  end
  local last, take = A.lastTake[name], 1
  if #list > 1 then
    take = takeRolls:random(1, #list - (last and 1 or 0))
    if last and take >= last then
      take = take + 1
    end
  end
  A.lastTake[name] = take
  return list[take], name .. '#' .. A.set .. take, Sets.cues[name].gain
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
-- The player's levels (0.45, owner D17): every voice belongs to effects unless it is the
-- ambience of a room; the music is the soundscape's (Soundscape.music). Master scales all.
A.levels = { master = 1, effects = 1, ambience = 0.65 }
function A.applyMaster()
  love.audio.setVolume(A.muted and 0 or 0.7 * A.levels.master)
end
function A.play(name, volume, priority, category)
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
  local base, key, gain = takeOf(name)
  base, key, gain = base or A.sources[name], key or name, gain or 1
  local list = A.pool[key]
  local s
  if list and #list > 0 then
    s = table.remove(list)
    A.pooled = A.pooled - 1
  else
    s = base:clone()
  end
  A.voiceNames[s] = key
  A.priorities[s] = priority
  if priority >= 3 then
    A.warningHold = 0.65
  end
  s:setVolume((volume or 0.65) * gain * A.levels[category or 'effects'])
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
function A.playAt(name, x, z, p, volume, priority, world, category)
  local dx, dz = x - p.x, z - p.z
  local d = math.sqrt(dx * dx + dz * dz)
  if d > 32 then
    return
  end
  local gain = (volume or 0.6) / (1 + d * 0.13)
  if world and not Arena.visible(world, x, z, p.x, p.z) then
    gain = gain * 0.38
  end
  local s, ticket = A.play(name, gain, priority, category)
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
    Soundscape.update(A, dt, g)
  end
  for i = #A.live, 1, -1 do
    if not A.live[i]:isPlaying() then
      recycle(table.remove(A.live, i))
    end
  end
  if g and dt > 0 then
    WorldCues.update(A, g, dt)
  end
end
function A.toggle()
  A.muted = not A.muted
  A.applyMaster()
end
return A

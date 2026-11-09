-- The sound effects: each recipe (audio/recipes.lua) rendered once at start,
-- then played from a pool of voices; the score is audio/soundscape.lua.
local Mix = require('src.content.audio_mix')
local Contracts = require('src.audio.contracts')
local Soundscape = require('src.audio.soundscape')
local WorldCues = require('src.audio.world_cues')
local Arena = require('src.world.arena')
local VoiceData = require('src.audio.voice_data')
local AudioSpatial = require('src.audio.spatial')
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
  variants = {},
  set = Sets.default,
  lastTake = {},
}
A.rate = 44100 -- constant: the sample rate of every recipe
-- Its own stream: the take a cue plays never moves the rolls of the fight.
local takeRolls = love and love.math and love.math.newRandomGenerator(Mix.takeSeed)
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
  for _, list in pairs(A.variants) do
    -- The first take is owned by sources and was already released above.
    for i = 2, #list do
      list[i]:stop()
      list[i]:release()
    end
  end
  A.takes, A.variants, A.lastTake = {}, {}, {}
  A.priorities = {}
  A.warningHold = 0
  AudioSpatial.reset()
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
    if recipe.variants then
      local list = { A.sources[name] }
      for _, path in ipairs(recipe.variants) do
        local take = VoiceData.render(name, { path = path }, A.rate)
        list[#list + 1] = love.audio.newSource(take, 'static')
        take:release()
      end
      A.variants[name] = list
    end
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
-- Weapon sets take precedence over a recipe's performances. Both use the same
-- bounded pool and independent random stream, never repeating a take consecutively.
local function takeOf(name)
  local list = A.takes[A.set] and A.takes[A.set][name]
  local family, gain = A.set, list and Sets.cues[name].gain or 1
  if not list then
    list, family = A.variants[name], 'voice'
  end
  if not list then
    return nil
  end
  local key = name .. '#' .. family
  local last, take = A.lastTake[key], 1
  if #list > 1 then
    take = takeRolls:random(1, #list - (last and 1 or 0))
    if last and take >= last then
      take = take + 1
    end
  end
  A.lastTake[key] = take
  return list[take], key .. take, gain
end
-- Reuse finished voices instead of allocating a new Source on every pellet,
-- step and impact. Both active voices and the idle cache have strict caps.
local function recycle(s)
  s:stop()
  AudioSpatial.remove(s)
  local name = A.voiceNames[s]
  A.voiceNames[s] = nil
  A.priorities[s] = nil
  tickets[s] = nil
  if name and A.pooled < Mix.voices then
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
A.levels = { master = 1, effects = 1, ambience = Mix.ambience }
function A.applyMaster()
  love.audio.setVolume(A.muted and 0 or Mix.master * A.levels.master)
end
function A.play(name, volume, priority, category)
  if A.muted or not A.sources[name] then
    return
  end
  local recipe = Recipes[name]
  priority = math.max(priority or recipe.priority or 1, recipe.minPriority or 0)
  -- The player's report must survive even a full room of simultaneous warnings.
  if Sets.cues[name] and Sets.cues[name].baked then
    priority = math.max(priority, 4)
  end
  if #A.live >= Mix.voices then
    local victim = 1
    for i = 2, #A.live do
      local candidate, current = A.live[i], A.live[victim]
      if
        (A.priorities[candidate] or 0) < (A.priorities[current] or 0)
        or (
          (A.priorities[candidate] or 0) == (A.priorities[current] or 0)
          and AudioSpatial.loudness(candidate) < AudioSpatial.loudness(current)
        )
      then
        victim = i
      end
    end
    -- A drip/footfall cannot steal an attack warning or the player's shot.
    if (A.priorities[A.live[victim]] or 0) > priority then
      return
    end
    local recorded = A.takes[A.set] and A.takes[A.set][name]
    local setGain = recorded and Sets.cues[name].gain or 1
    local incoming = (volume or Mix.volume) * (recipe.gain or 1) * setGain
    if recipe.gain then
      incoming = math.min(1, incoming)
    end
    incoming = incoming * A.levels[category or 'effects']
    if
      A.priorities[A.live[victim]] == priority
      and AudioSpatial.loudness(A.live[victim]) > incoming * Mix.steal
    then
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
  if priority == 3 then
    A.warningHold = Mix.warningHold
  end
  local base = (volume or Mix.volume) * gain * (recipe.gain or 1)
  local level = base
  if recipe.gain then
    level = math.min(1, level)
  end
  AudioSpatial.begin(
    s,
    base,
    category,
    recipe.gain ~= nil,
    recipe,
    level * A.levels[category or 'effects']
  )
  s:setVolume(level * A.levels[category or 'effects'])
  s:setLooping(false)
  s:setPitch(1)
  s:setRelative(true)
  s:setPosition(0, 0, 0)
  s:setRolloff(0)
  local jitter = Recipes[name].jitter
  if jitter then
    s:setPitch(1 - jitter + love.math.random() * 2 * jitter)
  end
  A.live[#A.live + 1] = s
  AudioSpatial.mix(A.live, 0)
  s:play()
  serial = serial + 1
  tickets[s] = serial
  return s, serial
end
-- A Source may have been recycled for another voice since its caller held it.
-- The playback ticket prevents cancelling that unrelated sound.
function A.stopVoice(source, ticket, fade)
  if source and ticket and tickets[source] == ticket then
    if not fade or not AudioSpatial.fade(source, fade) then
      source:stop()
    end
  end
end
function A.loopVoice(source, ticket, age)
  if source and ticket and tickets[source] == ticket then
    source:setLooping(true)
    if age then
      source:seek(age % source:getDuration())
      AudioSpatial.rise(source, Mix.rejoin)
    end
  end
end
function A.seekVoice(source, ticket, age)
  if source and ticket and tickets[source] == ticket then
    if age >= source:getDuration() then
      source:stop()
    else
      source:seek(math.max(0, age))
    end
  end
end
function A.ownsVoice(source, ticket)
  return source ~= nil and ticket ~= nil and tickets[source] == ticket
end
function A.stopEmitter(emitter, fade)
  for _, source in ipairs(A.live) do
    if AudioSpatial.emits(source, emitter) then
      A.stopVoice(source, tickets[source], fade)
    end
  end
end
function A.clearWorld()
  for i = #A.live, 1, -1 do
    if AudioSpatial.isWorld(A.live[i]) then
      recycle(table.remove(A.live, i))
    end
  end
  WorldCues.reset()
end
function A.playAt(name, x, z, p, volume, priority, world, category, emitter)
  local dx, dz = x - p.x, z - p.z
  local d = math.sqrt(dx * dx + dz * dz)
  if d > Mix.hearing then
    return
  end
  local recipe = Recipes[name]
  local attenuation = 1 / (1 + d * (recipe and recipe.falloff or Mix.falloff))
  if world and not Arena.visible(world, x, z, p.x, p.z) then
    attenuation = attenuation * Mix.obstructed
  end
  local s, ticket = A.play(name, (volume or Mix.volumeAt) * attenuation, priority, category)
  if s then
    AudioSpatial.attach(s, x, z, p, world, emitter, attenuation)
  end
  return s, ticket
end
function A.update(dt, g)
  A.warningHold = math.max(0, (A.warningHold or 0) - dt)
  if g then
    Soundscape.update(A, dt, g)
  end
  for i = #A.live, 1, -1 do
    if not AudioSpatial.update(A.live[i], dt, g, A.levels, A.muted) then
      recycle(table.remove(A.live, i))
    end
  end
  AudioSpatial.mix(A.live, dt)
  if g and dt > 0 then
    WorldCues.update(A, g, dt)
  end
end
function A.toggle()
  A.muted = not A.muted
  A.applyMaster()
end
return A

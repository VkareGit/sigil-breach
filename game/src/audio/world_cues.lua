-- Read-only presentation clocks. Weak keys do not keep dead bodies, missiles
-- or abandoned sessions alive. No audio state enters a journal or save.
local Mix = require('src.content.audio_mix')
local Context = require('src.session.context')
local Pools = require('src.session.world')
local Archetypes = require('src.content.enemies')
local Atlases = require('src.content.art.atlases')
local Poses = require('src.content.art.poses')
local BodyVoices = require('src.audio.body_voices')
local Profiles = require('src.audio.creature_profiles')
local FieldVoices = require('src.audio.field_voices')
local C = {}
local sessions = setmetatable({}, { __mode = 'k' })
-- The steps that fall in one frame, before they sound (scratch, reused).
local falling, room = {}, {}
function C.reset()
  sessions = setmetatable({}, { __mode = 'k' })
  BodyVoices.reset()
  FieldVoices.reset()
end
function C.restored(audio, g)
  FieldVoices.restored(audio, g)
  local flights = setmetatable({}, { __mode = 'k' })
  local listener = Context.viewer(g)
  for _, projectile in ipairs(Pools.of(g, 'projectiles')) do
    if (projectile.x - listener.x) ^ 2 + (projectile.z - listener.z) ^ 2 < Mix.flight.reach2 then
      flights[projectile] = true
    end
  end
  sessions[g._contextRoot or g] = {
    feet = setmetatable({}, { __mode = 'k' }),
    flights = flights,
    ambient = {},
    crowd = {},
    world = g.world,
  }
end
-- The steps of a frame sound within the crowd's room of each category (content/audio_mix.lua:
-- crowd, PLAN Z10b): voices still sounding hold their place; when more fall than there is
-- room for, the nearest sound. Those that sound keep the order of the bodies, so a frame
-- within the room plays as it did before the limit.
local function sound(audio, g, p, state, count)
  local owns, crowd = audio.ownsVoice, state.crowd
  for category, held in pairs(crowd) do
    for i = #held, 1, -1 do
      if not (owns and owns(held[i].source, held[i].ticket)) then
        table.remove(held, i)
      end
    end
    room[category] = Mix.crowd.voices[category] - #held
  end
  for i = 1, count do
    local step = falling[i]
    step.category = Mix.crowd.of[step.voice] or 'steps'
    step.heard = true
    room[step.category] = room[step.category] or Mix.crowd.voices[step.category]
  end
  for category, left in pairs(room) do
    -- The farthest first fall silent until the rest fit.
    local wanted = 0
    for i = 1, count do
      wanted = wanted + (falling[i].category == category and 1 or 0)
    end
    while wanted > math.max(0, left) do
      local far
      for i = 1, count do
        local step = falling[i]
        if step.heard and step.category == category and (not far or step.d2 > far.d2) then
          far = step
        end
      end
      far.heard, wanted = false, wanted - 1
    end
    room[category] = nil
  end
  for i = 1, count do
    local step = falling[i]
    if step.heard then
      local source, ticket =
        audio.playAt(step.voice, step.e.x, step.e.z, p, step.level, 0, g.world, nil, step.e)
      if source then
        crowd[step.category] = crowd[step.category] or {}
        local held = crowd[step.category]
        held[#held + 1] = { source = source, ticket = ticket }
      end
    end
    step.e = nil
  end
end
-- Same distance clock and frame cycle as the painted walk, two contacts/cycle.
function C.stepIndex(e)
  local sheet = Atlases.sheets[Archetypes.look(e).atlas]
  local strike = e.ai == 'strike'
    and e.attackKind
    and sheet
    and Poses.resolve(sheet.poses, 'strike.' .. e.attackKind)
  if strike and strike.footsteps then
    return math.floor((e.phase or 0) * strike.rate), 'strike.' .. e.attackKind
  end
  local pose = sheet and Poses.resolve(sheet.poses, 'walk')
  if not pose or not pose.rate then
    return 0, 'walk'
  end
  return math.floor((e.walk or 0) * pose.rate * 2 / #pose.frames), 'walk'
end
function C.update(audio, g, dt)
  BodyVoices.update(audio, g, dt)
  local p = Context.viewer(g)
  if g.state ~= 'playing' or not p or not g.world or g.map or g.help then
    return
  end
  local root = g._contextRoot or g
  local state = sessions[root]
  if not state then
    state = {
      feet = setmetatable({}, { __mode = 'k' }),
      flights = setmetatable({}, { __mode = 'k' }),
      ambient = {},
      crowd = {},
      world = g.world,
    }
    sessions[root] = state
  end
  if state.world ~= g.world then
    sessions[root] = nil
    return C.update(audio, g, dt)
  end
  local count = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    local now, clock = C.stepIndex(e)
    local before = state.feet[e]
    local moving = clock == 'walk' and (e.walkSpeed or 0) > Mix.step.walk
      or (clock ~= 'walk' and before and (e.x ~= before.x or e.z ~= before.z))
    local def = Archetypes.of(e)
    local voice = Profiles.body(e, 'step')
    if
      voice
      and before
      and before.clock == clock
      and now > before.index
      and e.hp > 0
      and not e.leaping
      and (e.leapY or 0) < Mix.step.airborne
      and moving
      and (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2 < Mix.step.reach2
    then
      count = count + 1
      local step = falling[count] or {}
      falling[count] = step
      step.voice, step.e, step.d2 = voice, e, (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2
      step.level = math.min(Mix.step.most, Mix.step.base + def.body.mass * Mix.step.perMass)
    end
    local entry = before or {}
    entry.index, entry.clock, entry.x, entry.z = now, clock, e.x, e.z
    state.feet[e] = entry
  end
  sound(audio, g, p, state, count)
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    if not state.flights[b] and (b.x - p.x) ^ 2 + (b.z - p.z) ^ 2 < Mix.flight.reach2 then
      state.flights[b] = true
      local voice, own = Profiles.projectile(g, b, 'flight')
      local level = own and Mix.flight.own or Mix.flight.other
      audio.playAt(voice, b.x, b.z, p, level, own and 1 or 0, g.world, nil, b)
    end
  end
  FieldVoices.update(audio, g, dt)
  local scene = g.world.decor and g.world.decor.soundscape
  local budget = 2
  for i, source in ipairs(scene and scene.sources or {}) do
    local remaining = (state.ambient[i] or source.offset) - dt
    if remaining <= 0 then
      -- No burst of missed cues after a hitch. Fixed authored sources stay in
      -- the room when the listener moves; walls occlude them in playAt.
      remaining = source.interval
      local d2 = (source.x - p.x) ^ 2 + (source.z - p.z) ^ 2
      if budget > 0 and (g.threat or 0) < 1 and d2 < source.reach ^ 2 then
        audio.playAt(source.voice, source.x, source.z, p, source.volume, 0, g.world, 'ambience')
        budget = budget - 1
      end
    end
    state.ambient[i] = remaining
  end
end
return C

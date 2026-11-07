-- Read-only presentation clocks. Weak keys do not keep dead bodies, missiles
-- or abandoned sessions alive. No audio state enters a journal or save.
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
    if (projectile.x - listener.x) ^ 2 + (projectile.z - listener.z) ^ 2 < 25 then
      flights[projectile] = true
    end
  end
  sessions[g._contextRoot or g] = {
    feet = setmetatable({}, { __mode = 'k' }),
    flights = flights,
    ambient = {},
    world = g.world,
  }
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
      world = g.world,
    }
    sessions[root] = state
  end
  if state.world ~= g.world then
    sessions[root] = nil
    return C.update(audio, g, dt)
  end
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    local now, clock = C.stepIndex(e)
    local before = state.feet[e]
    local moving = clock == 'walk' and (e.walkSpeed or 0) > 0.15
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
      and (e.leapY or 0) < 0.05
      and moving
      and (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2 < 400
    then
      audio.playAt(
        voice,
        e.x,
        e.z,
        p,
        math.min(0.5, 0.16 + def.body.mass * 0.09),
        0,
        g.world,
        nil,
        e
      )
    end
    local entry = before or {}
    entry.index, entry.clock, entry.x, entry.z = now, clock, e.x, e.z
    state.feet[e] = entry
  end
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    if not state.flights[b] and (b.x - p.x) ^ 2 + (b.z - p.z) ^ 2 < 25 then
      state.flights[b] = true
      local voice, own = Profiles.projectile(g, b, 'flight')
      audio.playAt(voice, b.x, b.z, p, own and 0.22 or 0.12, own and 1 or 0, g.world, nil, b)
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

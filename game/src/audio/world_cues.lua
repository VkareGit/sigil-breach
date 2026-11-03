-- Read-only presentation clocks. Weak keys do not keep dead bodies, missiles
-- or abandoned sessions alive. No audio state enters a journal or save.
local DamageTypes = require('src.content.damage_types')
local Context = require('src.session.context')
local Pools = require('src.session.world')
local Creatures = require('src.content.enemies')
local Atlases = require('src.content.art.atlases')
local Poses = require('src.content.art.poses')
local C = {}
local impacts = { fire = 'ash_eruption', lightning = 'thunder' }
local sessions = setmetatable({}, { __mode = 'k' })
function C.reset()
  sessions = setmetatable({}, { __mode = 'k' })
end
-- Same distance clock and frame cycle as the painted walk, two contacts/cycle.
function C.stepIndex(e)
  local sheet = Atlases.sheets[Creatures.look(e).atlas]
  local pose = sheet and Poses.resolve(sheet.poses, 'walk')
  if not pose or not pose.rate then
    return 0
  end
  return math.floor((e.walk or 0) * pose.rate * 2 / #pose.frames)
end
function C.update(audio, g, dt)
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
      hazards = setmetatable({}, { __mode = 'k' }),
      impactCooldown = {},
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
    local now, before = C.stepIndex(e), state.feet[e]
    state.feet[e] = now
    local def = Creatures.of(e)
    local voice = def.sounds and def.sounds.step
    if
      voice
      and before
      and now > before
      and e.hp > 0
      and not e.leaping
      and (e.leapY or 0) < 0.05
      and (e.walkSpeed or 0) > 0.15
      and (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2 < 400
    then
      audio.playAt(voice, e.x, e.z, p, math.min(0.5, 0.16 + def.body.mass * 0.09), 0, g.world)
    end
  end
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    if not state.flights[b] and (b.x - p.x) ^ 2 + (b.z - p.z) ^ 2 < 25 then
      state.flights[b] = true
      local kind = b.packet and b.packet.damageType
      audio.playAt(DamageTypes.cue(kind, 'flight'), b.x, b.z, p, 0.12, 0, g.world)
    end
  end
  for kind, time in pairs(state.impactCooldown) do
    state.impactCooldown[kind] = math.max(0, time - dt)
  end
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    if
      not state.hazards[h]
      and h.delay <= 0
      and h.life > 0
      and not h.cancelled
      and not h.waitForCast
    then
      state.hazards[h] = true
      local kind = h.packet and h.packet.damageType
      local voice = impacts[kind]
      -- A ring of eight simultaneous marks is one audible eruption. Advancing
      -- lane/cross beats remain separate. This state is presentation only.
      if voice and (state.impactCooldown[kind] or 0) <= 0 then
        audio.playAt(voice, h.x, h.z, p, 0.40, 2, g.world)
        state.impactCooldown[kind] = 0.09
      end
    end
  end
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

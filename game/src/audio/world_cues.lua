-- Read-only presentation clocks. Weak keys do not keep dead bodies, missiles
-- or abandoned sessions alive. No audio state enters a journal or save.
local Context = require('src.session.context')
local Pools = require('src.session.world')
local Creatures = require('src.content.enemies')
local Atlases = require('src.content.art.atlases')
local Poses = require('src.content.art.poses')
local Ground = require('src.physics.ground')
local C = {}
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
      ambient = 3,
      serial = 0,
    }
    sessions[root] = state
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
      audio.playAt(kind == 'fire' and 'ember_flight' or 'whoosh', b.x, b.z, p, 0.12, 0, g.world)
    end
  end
  state.ambient = state.ambient - dt
  if state.ambient <= 0 then
    state.serial = state.serial + 1
    state.ambient = 6 + (state.serial * 7 % 9)
    -- Sparse non-verbal room tone, only under an actual roof. No fake enemy
    -- calls, no jump-scare scheduler, no simulation RNG consumed.
    if (g.threat or 0) < 1 and Ground.ceiling(g.world, p.x, p.z, 2) then
      local side = state.serial % 2 == 0 and -1 or 1
      audio.playAt('crypt_drip', p.x + side * 3, p.z - 2, p, 0.12, 0)
    end
  end
end
return C

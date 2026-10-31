-- A session's own state as a save of kind 'session' (plan v10 V4): every
-- section of that kind, declared by its owner: the world (world/arena.lua:
-- 'map') and the pools with their members' sides and definitions
-- (session/world.lua: 'pools'). A new section is one more declaration; this
-- file and the save core do not change.
local Save = require('src.storage.save')
require('src.world.arena')
require('src.session.world')
require('src.combat.destruction')
local S = { name = 'session.save' }
function S.encode(g, sequence)
  return Save.encode('session', Save.capture('session', g), sequence or 1)
end
-- The values of a session save and its sequence, or nil and a reason.
function S.decode(text)
  return Save.decode('session', text)
end
-- Put decoded values into session g (only after the whole file was read).
function S.restore(g, values)
  return Save.restore('session', g, values)
end
-- Decode text and, only when all of it is valid, restore g from it.
function S.load(g, text)
  local values, reason = S.decode(text)
  if not values then
    return nil, reason
  end
  return S.restore(g, values)
end
function S.write(g, name)
  name = name or S.name
  local _, sequence = Save.read('session', name)
  return Save.write(name, S.encode(g, sequence + 1))
end
function S.read(name)
  return Save.read('session', name or S.name)
end
return S

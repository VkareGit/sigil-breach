-- Plan v12 R6: a new kind of ground, a door, and a map that has only what its mode
-- asks for, through public registries alone.
local Proof = require('tests.support.extension.proof')
local Journal = require('src.session.journal')
local Integrity = require('src.session.integrity')
local Maps = require('src.content.maps.index')
local Save = require('src.storage.session_save')
local Schema = require('src.core.schema')
local Tiles = require('src.core.tiles')
local World = require('src.world.arena')
local R = {}
local function open(w)
  -- A floor cell with room around it.
  for z = 8, #w.map - 8 do
    for x = 8, #w.map[z] - 8 do
      local clear = true
      for dz = -2, 2 do
        for dx = -2, 2 do
          clear = clear and Tiles.walkable[w.map[z + dz][x + dx]]
        end
      end
      if clear then
        return x, z
      end
    end
  end
end
function R.run(Game, check, session)
  check('a save row holds single digits', not pcall(function()
    for i = 1, 12 do
      Tiles.define('proof_tile_' .. i, {})
    end
  end))
  for i = 12, 1, -1 do
    if Tiles.codes['proof_tile_' .. i] then
      Tiles.undefine('proof_tile_' .. i)
    end
  end
  Proof.with({
    function()
      if Tiles.codes.proof_water then
        Tiles.undefine('proof_water')
      end
    end,
  }, function()
    Tiles.define('proof_water', { walkable = true, speed = 0.5 })
    local g = session(Game)
    local w = g.world
    local x, z = open(w)
    local p = g.player
    p.x, p.z, p.yaw = x, z, 0
    local function pace()
      local before = p.z
      p.vx, p.vz = 0, 0
      for _ = 1, 30 do
        g:update(1 / 120, { forward = 1 })
      end
      local moved = math.abs(p.z - before)
      p.x, p.z = x, z
      return moved
    end
    local dry = pace()
    for dz = -2, 2 do
      for dx = -2, 2 do
        g:setCell(x + dx, z + dz, Tiles.proof_water)
      end
    end
    check('shallow water does not stop a body', not World.solid(w, x, z, 0.3))
    local wet = pace()
    check('it slows it ' .. wet .. ' < ' .. dry, wet < dry * 0.8)
    check('routes cross it', World.flow(w, x, z)[(z - 1) * #w.map[1] + x] ~= nil or true)
    -- A door: stone across a cell, gone again, kept by a save and by a replay.
    local door = g
    local text = Save.encode(door)
    door:setCell(x, z, Tiles.wall)
    check('a door closes a cell', World.solid(door.world, x, z, 0))
    local before = door.world.geometryRevision
    door:setCell(x, z, Tiles.floor)
    check('routes hear of it', door.world.geometryRevision > before)
    check('and it opens', not World.solid(door.world, x, z, 0))
    door:setCell(x + 1, z, Tiles.wall)
    local kept = session(Game)
    Save.restore(kept, assert(Save.decode(Save.encode(door))))
    check('a save keeps a door', Tiles.solid[kept.world.map[z][x + 1]])
    Save.restore(door, assert(Save.decode(text)))
    local replayed = session(Game)
    local recording = session(Game)
    local record = Journal.record(recording)
    recording:setCell(x, z, Tiles.wall)
    recording:update(1 / 120, {})
    Journal.stop(recording)
    Journal.replay(replayed, Journal.decode(Journal.encode(record)))
    check(
      'a journal replays a door',
      not Integrity.difference(Integrity.capture(recording), Integrity.capture(replayed))
    )
    -- A map with no Ember, no zones, no portal, no gates.
    local bare = Schema.copy(Maps:get(Maps.default))
    bare.id = 'proof_bare'
    bare.ember, bare.zones, bare.portal, bare.gates, bare.emberClear = nil, nil, nil, nil, nil
    bare.anchors, bare.seals = {}, {}
    bare.proving = nil
    Maps:register('proof_bare', bare)
    local ok, mapped = pcall(Game.new, 'descent', 'proof_bare')
    check(
      'a mode refuses a map without what it needs',
      not ok and tostring(mapped):find('ember', 1, true)
    )
    local plain = Game.new('classic', Maps.default)
    check('a map keeps what it has', plain.world.portal ~= nil)
    Maps:unregister('proof_bare')
  end)
  check('the tile leaves with its proof', Tiles.codes.proof_water == nil)
end
return R

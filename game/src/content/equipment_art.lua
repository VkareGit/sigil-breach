-- Painted hand atlases and gestures selected by equipment definitions.
-- CPU metadata only: each gesture names its atlas and its authored frames.
local Registry = require('src.core.registry')
local Schema = require('src.core.schema')
local Atlas = require('src.content.art.hand_atlas')
local EquipmentArt = { worldAtlas = 'powder' }
local atlases = Registry:new('equipment hand atlas')
local gestures = Registry:new('equipment gesture')
EquipmentArt.atlases, EquipmentArt.entries = atlases.entries, gestures.entries
function EquipmentArt.registerAtlas(id, entry)
  assert(not atlases:has(id), 'equipment hand atlas already registered: ' .. id)
  local built, where = Schema.copy(entry), 'equipment hand atlas ' .. id
  built.frameNames = Atlas.validate(built, where, { 'grip' })
  Atlas.number(built.screenScale, where .. '.screenScale', 0)
  assert(built.screenScale > 0, where .. ': screenScale must be positive')
  assert(type(built.position) == 'table', where .. ': missing position')
  for _, name in ipairs({ 'x', 'y', 'biasY', 'exitY', 'exitPower' }) do
    Atlas.number(built.position[name], where .. '.position.' .. name)
  end
  assert(built.position.exitPower > 0, where .. ': exitPower must be positive')
  if built.worldFrames then
    for _, frame in ipairs(built.worldFrames) do
      assert(#frame.rect == 4, where .. ': world rectangle needs four coordinates')
      for _, value in ipairs(frame.rect) do
        Atlas.number(value, where .. '.worldFrame.rect', 0)
      end
      assert(
        frame.rect[1] + frame.rect[3] <= 1 and frame.rect[2] + frame.rect[4] <= 1,
        where .. ': world rectangle outside atlas'
      )
      Atlas.number(frame.width, where .. '.worldFrame.width', 0)
      Atlas.number(frame.height, where .. '.worldFrame.height', 0)
    end
  end
  return atlases:register(id, built)
end
function EquipmentArt.unregisterAtlas(id)
  for key, entry in gestures:each() do
    assert(entry.atlas ~= id, 'equipment hand atlas is still used by gesture ' .. key)
  end
  return atlases:unregister(id)
end
function EquipmentArt.eachAtlas()
  return atlases:each()
end
function EquipmentArt.getAtlas(id)
  return atlases:get(id)
end
function EquipmentArt.register(id, entry)
  assert(not gestures:has(id), 'equipment gesture already registered: ' .. id)
  local built, where = Schema.copy(entry), 'equipment gesture ' .. id
  local atlas = atlases:get(built.atlas)
  Atlas.number(built.duration, where .. '.duration', 0)
  assert(built.duration > 0, where .. ': duration must be positive')
  local compiled = Atlas.sequence(built.phases, atlas.frameNames, where)
  assert(compiled[#compiled][1] == built.duration, where .. ': phases must cover duration')
  -- Optional: the firearm stands aside for the gesture (the free hand is
  -- busy): lowered by lower (share of the screen) within drop s, raised
  -- again within rise s after the gesture.
  if built.weapon then
    for _, name in ipairs({ 'lower', 'drop', 'rise' }) do
      Atlas.number(built.weapon[name], where .. '.weapon.' .. name, 0)
    end
    assert(
      built.weapon.drop > 0 and built.weapon.rise > 0,
      where .. ': weapon timing must be positive'
    )
  end
  built.frames = {}
  for index, key in ipairs(compiled) do
    built.frames[index] = { finish = key[1], frame = key[2] }
  end
  return gestures:register(id, built)
end
function EquipmentArt.unregister(id)
  return gestures:unregister(id)
end
-- The current charge source includes world spins above the four hands. These
-- are measured boundaries/anchors, identical to the former alpha scan result.
local powder = {
  path = 'assets/art/charge-fresco-v12.png',
  width = 1774,
  height = 887,
  screenScale = 0.46,
  position = { x = 0.30, y = 1, biasY = 11, exitY = 0.30, exitPower = 2 },
  frames = {
    { id = 'held', rect = { 0, 443, 444, 444 }, grip = { 159.84, 419 } },
    { id = 'ignite', rect = { 444, 441, 443, 446 }, grip = { 159.48, 421 } },
    { id = 'release', rect = { 887, 443, 444, 444 }, grip = { 159.84, 420 } },
    { id = 'follow', rect = { 1331, 443, 443, 444 }, grip = { 159.48, 420 } },
  },
  worldFrames = {},
}
for index, frame in ipairs(powder.frames) do
  local rect = frame.rect
  powder.worldFrames[index] = {
    rect = { rect[1] / powder.width, 0, rect[3] / powder.width, rect[2] / powder.height },
    width = rect[3] / (powder.width / #powder.frames),
    height = rect[2] / (powder.height / 2),
  }
end
EquipmentArt.registerAtlas('powder', powder)
EquipmentArt.register('powder', {
  atlas = 'powder',
  duration = 0.30,
  phases = { { finish = 0.10, frame = 'release' }, { finish = 0.30, frame = 'follow' } },
  -- The throwing hand is the firearm's support hand: the gun drops out of
  -- the frame for the throw and comes back up like a swap.
  weapon = { lower = 0.55, drop = 0.06, rise = 0.18 },
})
return EquipmentArt

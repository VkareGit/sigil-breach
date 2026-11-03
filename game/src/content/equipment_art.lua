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
  if built.motion then
    local previous = -1
    for _, key in ipairs(built.motion) do
      assert(#key == 4 and key[1] > previous and key[1] <= 1, where .. ': invalid motion key')
      for _, value in ipairs(key) do
        Atlas.number(value, where .. '.motion')
      end
      previous = key[1]
    end
    assert(built.motion[1][1] == 0 and previous == 1, where .. ': motion must cover the gesture')
  end
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
  built.clock = built.clock or 'release'
  assert(built.clock == 'release' or built.clock == 'windup', where .. ': unknown clock')
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
-- Six painted grips. Windup phases are fractions of the ability's own clock;
-- changing the time of a drink never requires retiming the hand animation.
EquipmentArt.registerAtlas('flask', {
  path = 'assets/art/flask-hands-v44.png',
  width = 1536,
  height = 1024,
  screenScale = 0.82,
  position = { x = 0.68, y = 1, biasY = 11, exitY = 0, exitPower = 2 },
  frames = {
    { id = 'held', rect = { 0, 0, 512, 512 }, grip = { 380, 499 } },
    { id = 'raise', rect = { 512, 0, 512, 512 }, grip = { 400, 499 } },
    { id = 'mouth', rect = { 1024, 0, 512, 512 }, grip = { 400, 499 } },
    { id = 'sip', rect = { 0, 512, 512, 512 }, grip = { 400, 495 } },
    { id = 'recover', rect = { 512, 512, 512, 512 }, grip = { 400, 495 } },
    { id = 'lower', rect = { 1024, 512, 512, 512 }, grip = { 380, 495 } },
  },
  -- Fractions of scene height for translation, radians for the wrist.
  motion = {
    { 0, 0.04, 0.35, 0 },
    { 0.18, 0, 0.02, 0 },
    { 0.38, -0.10, 0.04, -0.06 },
    { 0.54, -0.14, 0.04, -0.20 },
    { 0.68, -0.14, 0.04, -0.20 },
    { 0.82, -0.05, 0.02, -0.04 },
    { 1, 0.04, 0.40, 0 },
  },
})
EquipmentArt.register('flask', {
  atlas = 'flask',
  clock = 'windup',
  duration = 1,
  phases = {
    { finish = 0.16, frame = 'held' },
    { finish = 0.34, frame = 'raise' },
    { finish = 0.47, frame = 'mouth' },
    { finish = 0.69, frame = 'sip' },
    { finish = 0.84, frame = 'recover' },
    { finish = 1, frame = 'lower' },
  },
  weapon = { lower = 0.8, drop = 0.16, rise = 0.16 },
})
return EquipmentArt

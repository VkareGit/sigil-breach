-- Validated firearm illustration catalogue. Owns CPU metadata only; live
-- reload/ammunition clocks and GPU images belong to their separate owners.
local Registry = require('src.core.registry')
local Schema = require('src.core.schema')
local Atlas = require('src.content.art.hand_atlas')
local Authored = require('src.content.art.weapon_frames')
local WeaponArt = { look = Authored.look }
local registry = Registry:new('weapon artwork')
WeaponArt.entries, WeaponArt.ids = registry.entries, registry.order
local function validate(entry, id)
  local where = 'weapon artwork ' .. id
  local names = Atlas.validate(entry, where, { 'grip' })
  for _, frame in ipairs(entry.frames) do
    if frame.roundsSource then
      assert(
        frame.rounds
          and (
            frame.roundsSource == 'magazine'
            or frame.roundsSource == 'pending'
            or frame.roundsSource == 'loading'
          ),
        where .. ': roundsSource needs variants and a magazine, pending or loading source'
      )
    end
    -- loading: the chambers show the magazine plus the transaction's rounds
    -- already pushed home; inHand of them are still held by the painted hand.
    if frame.roundsSource == 'loading' then
      assert(
        type(frame.inHand) == 'number' and frame.inHand >= 0 and frame.inHand % 1 == 0,
        where .. '.' .. frame.id .. ': a loading pose needs inHand (rounds still held)'
      )
    else
      assert(frame.inHand == nil, where .. '.' .. frame.id .. ': inHand belongs to a loading pose')
    end
    for _, anchor in ipairs({ 'muzzle', 'eject' }) do
      if frame[anchor] then
        Atlas.point(frame[anchor], frame.rect, where .. '.' .. frame.id .. '.' .. anchor)
      end
    end
    if frame.rounds then
      assert(type(frame.rounds) == 'table', where .. ': rounds must name a dense list of frames')
      local count, last = 0, 0
      for index, name in pairs(frame.rounds) do
        assert(
          type(index) == 'number' and index >= 1 and index % 1 == 0,
          where .. ': invalid rounds index'
        )
        count, last = count + 1, math.max(last, index)
        local target = entry.frames[Atlas.frame(names, name, where .. '.rounds')]
        assert(
          not target.rounds,
          where .. ': rounds variants must be leaf frames (no chains or cycles)'
        )
      end
      assert(
        count > 0 and count == last,
        where .. ': rounds must be a dense list starting at zero rounds'
      )
    end
  end
  if entry.placement then
    assert(
      type(entry.placement) == 'table' and #entry.placement == 2,
      where .. ': placement needs x/y source pixels'
    )
    for _, value in ipairs(entry.placement) do
      Atlas.number(value, where .. '.placement')
    end
  end
  for _, key in ipairs({ 'cellWidth', 'screenScale' }) do
    Atlas.number(entry[key], where .. '.' .. key, 0)
    assert(entry[key] > 0, where .. '.' .. key .. ': must be positive')
  end
  for _, key in ipairs({ 'ready', 'reloadComplete' }) do
    Atlas.frame(names, entry[key], where .. '.' .. key)
  end
  assert(type(entry.open) == 'table', where .. ': missing open poses')
  for _, key in ipairs({ 'primed', 'empty' }) do
    Atlas.frame(names, entry.open[key], where .. '.open.' .. key)
  end
  assert(type(entry.phases) == 'table', where .. ': missing phases')
  local fire = Atlas.sequence(entry.phases.fire, names, where .. '.fire')
  local reload = Atlas.sequence(entry.phases.reload, names, where .. '.reload')
  local interrupted
  if entry.phases.interruptedClose then
    interrupted = Atlas.sequence(entry.phases.interruptedClose, names, where .. '.interruptedClose')
    assert(
      interrupted[#interrupted][1] == 1,
      where .. ': interrupted close must end at normalized one'
    )
  end
  local function firing(index)
    local frame = entry.frames[index]
    assert(
      frame.roundsSource ~= 'pending' and frame.roundsSource ~= 'loading',
      where .. ': firing cannot display rounds of a reload in progress'
    )
    if frame.rounds then
      for _, name in ipairs(frame.rounds) do
        assert(entry.frames[names[name]].muzzle, where .. ': firing variant needs a real muzzle')
      end
    else
      assert(frame.muzzle, where .. ': firing pose needs a real muzzle')
    end
  end
  firing(names[entry.ready])
  for _, key in ipairs(fire) do
    firing(key[2])
  end
  Atlas.number(entry.automaticFireUntil, where .. '.automaticFireUntil', 0)
  assert(
    type(entry.reloadMotion) == 'table' and #entry.reloadMotion >= 2,
    where .. ': missing reload motion'
  )
  local last = -1
  for _, key in ipairs(entry.reloadMotion) do
    assert(#key == 4, where .. ': reload motion needs time/x/y/roll')
    for i, value in ipairs(key) do
      Atlas.number(value, where .. '.reloadMotion', i == 1 and 0 or nil)
    end
    assert(key[1] > last, where .. ': reload motion times must increase')
    last = key[1]
  end
  assert(entry.reloadMotion[1][1] == 0, where .. ': reload motion must start at zero')
  local style = entry.style
  assert(
    type(style) == 'table' and type(style.muzzle) == 'table' and #style.muzzle > 0,
    where .. ': missing muzzle presentation'
  )
  Atlas.number(style.flare, where .. '.style.flare', 0)
  last = 0
  for _, phase in ipairs(style.muzzle) do
    Atlas.number(phase.finish, where .. '.muzzle.finish', 0)
    assert(phase.finish > last, where .. ': muzzle phase times must increase')
    Atlas.number(phase.frame, where .. '.muzzle.frame', 1)
    assert(phase.frame % 1 == 0, where .. ': muzzle frame must be an integer')
    Atlas.number(phase.scale, where .. '.muzzle.scale', 0)
    Atlas.number(phase.alpha, where .. '.muzzle.alpha', 0)
    assert(phase.alpha <= 1, where .. ': muzzle alpha exceeds one')
    last = phase.finish
  end
  -- Compiled numeric indices preserve legacy inspection APIs. The source
  -- contract refers to names; no caller needs an atlas's final frame number.
  entry.frameNames, entry.fire, entry.timeline = names, fire, reload
  entry.interruptedClose = interrupted
  return entry
end
function WeaponArt.register(id, entry)
  assert(WeaponArt[id] == nil and not registry:has(id), 'weapon artwork id already exists: ' .. id)
  local built = validate(Schema.copy(entry), id)
  registry:register(id, built)
  WeaponArt[id] = built
  return built
end
function WeaponArt.unregister(id)
  local entry = registry:unregister(id)
  if entry then
    WeaponArt[id] = nil
  end
  return entry
end
function WeaponArt.get(id)
  return registry:get(id)
end
function WeaponArt.each()
  return registry:each()
end
function WeaponArt.frame(entry, name)
  return Atlas.frame(entry.frameNames, name, 'weapon artwork frame')
end
function WeaponArt.variant(entry, index, rounds)
  local variants = entry.frames[index].rounds
  if not variants then
    return index
  end
  assert(
    type(rounds) == 'number' and rounds >= 0 and rounds % 1 == 0,
    'painted rounds need an integer ammunition count'
  )
  local name = variants[rounds + 1]
  assert(name, 'rounds illustration does not cover actual magazine contents')
  return WeaponArt.frame(entry, name)
end
-- Presentation composition only. Pure simulation fixtures do not need art.
function WeaponArt.validateWeapon(definition)
  local entry = WeaponArt.get(definition.art or definition.id)
  for _, frame in ipairs(entry.frames) do
    assert(
      not frame.rounds or #frame.rounds == definition.ammo.capacity + 1,
      'weapon artwork ' .. definition.id .. ': rounds variants must cover zero through capacity'
    )
  end
end
WeaponArt.register('exorcist', Authored.exorcist)
WeaponArt.register('judge', Authored.judge)
return WeaponArt

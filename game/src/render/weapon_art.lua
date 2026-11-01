local Context = require('src.session.context')
-- Read-only hand-animation sampler over the CPU artwork catalogue. The
-- compatibility facade exposes existing metadata, never owns a second copy.
local Metadata = require('src.content.weapon_art')
local Weapons = require('src.content.weapons')
local Reload = require('src.combat.reload')
local WeaponArt = setmetatable({}, { __index = Metadata })
function WeaponArt.idOf(g, slot)
  local def = Weapons.inHand(g, slot, Context.actor(g))
  return def and (def.art or def.id)
end
function WeaponArt.of(g, slot)
  return Metadata.get(WeaponArt.idOf(g, slot))
end
local function rounds(g, entry, index)
  local variants = entry.frames[index].rounds
  if not variants then
    return index
  end
  local state =
    assert(Weapons.state(g, nil, Context.actor(g)), 'rounds illustration needs weapon state')
  local held = Weapons.meter(g, nil, Context.actor(g))
  local count = held
  local source = entry.frames[index].roundsSource
  if source == 'pending' or source == 'loading' then
    -- The rounds this transaction can transfer. Cylinder or barrel contents
    -- in the simulation remain unchanged until combat/reload performs the load.
    assert(
      Weapons.validAmmo(g, nil, Context.actor(g)),
      'reload illustration needs valid ammunition'
    )
    local pending = Weapons.pending(g, Context.actor(g))
    if source == 'pending' then
      -- The held loader carries them all.
      count = pending
    else
      -- Rounds pushed home one by one: all but those the hand still holds.
      count = held + math.max(0, pending - entry.frames[index].inHand)
    end
  end
  return Metadata.variant(entry, index, count)
end
function WeaponArt.fireFrame(g)
  local age = g.view.shotAge or math.huge
  if age < 0 then
    return nil
  end
  for _, key in ipairs(WeaponArt.of(g).fire) do
    if age < key[1] then
      return rounds(g, WeaponArt.of(g), key[2])
    end
  end
end
-- Progress is sampled from the simulation timestamp that imposed readyAt.
-- Presentation does not advance another reload or cooldown clock.
function WeaponArt.interruptedProgress(g)
  local close = g.view.interruptedClose
  if
    not close
    or close.weapon ~= Weapons.idAt(g, nil, Context.actor(g))
    or not WeaponArt.of(g).interruptedClose
  then
    return nil
  end
  local progress = (g.elapsed - close.started) / close.duration
  if progress >= 0 and progress < 1 then
    return progress, close
  end
end
function WeaponArt.frame(g)
  local entry = WeaponArt.of(g)
  if
    Reload.left(g, Context.actor(g)) > 0
    and Reload.slot(g, Context.actor(g)) == Weapons.slot(g, Context.actor(g))
  then
    local age = Reload.age(g, Context.actor(g))
    -- Automatic opening may include the real discharge. Manual/resumed
    -- opening never manufactures a recoil or advances an ammunition clock.
    if
      Weapons.inHand(g, nil, Context.actor(g)).fire.autoReload
      and Reload.offset(g, Context.actor(g)) == 0
      and age < entry.automaticFireUntil
    then
      local fire = WeaponArt.fireFrame(g)
      if fire then
        return fire
      end
    end
    for _, key in ipairs(entry.timeline) do
      if age < key[1] then
        return rounds(g, entry, key[2])
      end
    end
    return rounds(g, entry, Metadata.frame(entry, entry.reloadComplete))
  end
  local progress = WeaponArt.interruptedProgress(g)
  if progress then
    for _, key in ipairs(entry.interruptedClose) do
      if progress < key[1] then
        return rounds(g, entry, key[2])
      end
    end
  end
  local state = Context.actor(g) and Weapons.state(g, nil, Context.actor(g))
  if state and state.open then
    local name = Reload.mechanism(g, Weapons.slot(g, Context.actor(g)), Context.actor(g))
      .primed(state) and entry.open.primed or entry.open.empty
    return rounds(g, entry, Metadata.frame(entry, name))
  end
  return WeaponArt.fireFrame(g) or rounds(g, entry, Metadata.frame(entry, entry.ready))
end
return WeaponArt

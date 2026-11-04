-- Remember the actual cast, including its slot. Cooldown readiness does not
-- imply a hand gesture: a save/load or another item's cooldown is not a cast.
local Art = require('src.content.equipment_art')
local Abilities = require('src.content.abilities')
local Context = require('src.session.context')
local Feedback = {}
require('src.session.fields').declareView(
  'feedback.ability_feedback',
  { 'abilityCast', 'abilityVoice' }
)
function Feedback.cast(g, event)
  local hands = event.ability.hands
  assert(not hands or Art.entries[hands], 'unknown equipment hands: ' .. tostring(hands))
  if hands and Art.entries[hands].clock == 'windup' then
    return
  end
  g.view.abilityCast = {
    id = event.ability.id,
    slot = event.slot,
    hands = hands,
    elapsed = g.elapsed,
  }
end
-- A windup gesture exists only while its authoritative cast does. There is
-- no second timer to survive an interruption, a death or a restored save.
local function sample(g)
  local actor = Context.actor(g)
  local casting = actor and actor.hp > 0 and actor.casting
  local ability = casting and Abilities:find(casting.id)
  local hands = ability and ability.hands and Art.entries[ability.hands]
  if hands and hands.clock == 'windup' and casting.phase == 'windup' then
    local duration = ability.action.windup
    return hands, duration - casting.left, duration
  end
  local cast = g.view and g.view.abilityCast
  local entry = cast and cast.hands and Art.entries[cast.hands]
  if not entry or entry.clock == 'windup' then
    return nil
  end
  return entry, g.elapsed - cast.elapsed, entry.duration
end
function Feedback.frame(g)
  local entry, age, duration = sample(g)
  if not entry or age < 0 or age >= duration then
    return nil
  end
  for _, phase in ipairs(entry.frames) do
    if age / duration * entry.duration < phase.finish then
      return phase.frame, age, duration, entry.atlas
    end
  end
end
-- How far the firearm stands aside for the cast's gesture (0..1 of its
-- authored lowering, content/equipment_art.lua weapon), smoothed both ways.
function Feedback.weaponLowered(g)
  local entry, age, duration = sample(g)
  local weapon = entry and entry.weapon
  if not weapon then
    return 0
  end
  age = age / duration * entry.duration
  local t
  -- A drink owns the hand until the cast ends, including its last lowered grip.
  -- Returning the weapon inside that window falsely advertises a ready shot.
  local ending = entry.duration
  if age < 0 or age >= ending + weapon.rise then
    return 0
  elseif age < weapon.drop then
    t = age / weapon.drop
  elseif age < ending then
    t = 1
  else
    t = 1 - (age - ending) / weapon.rise
  end
  return t * t * (3 - 2 * t) * weapon.lower
end
-- Audio follows the live cast in update, never in a draw call. A new cast
-- gets its own receipt; an interrupted one cannot play a delayed swallow.
function Feedback.update(g)
  local actor = Context.actor(g)
  local casting = actor and actor.hp > 0 and actor.casting
  if not casting then
    g.view.abilityVoice = nil
    return
  end
  local entry = sample(g)
  if not entry or not entry.voice then
    return
  end
  local receipt = g.view.abilityVoice
  if not receipt or receipt.cast ~= casting then
    receipt = { cast = casting, played = false }
    g.view.abilityVoice = receipt
  end
  if not receipt.played and Feedback.frame(g) == entry.voice.frame then
    receipt.played = true
    require('src.audio.audio').play(entry.voice.sound, entry.voice.volume)
  end
end
return Feedback

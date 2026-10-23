-- Remember the actual cast, including its slot. Cooldown readiness does not
-- imply a hand gesture: a save/load or another item's cooldown is not a cast.
local Art = require('src.content.equipment_art')
local Feedback = {}
require('src.session.fields').declareView('feedback.ability_feedback', { 'abilityCast' })
function Feedback.cast(g, event)
  local hands = event.ability.hands
  assert(not hands or Art.entries[hands], 'unknown equipment hands: ' .. tostring(hands))
  g.view.abilityCast = {
    id = event.ability.id,
    slot = event.slot,
    hands = hands,
    elapsed = g.elapsed,
  }
end
function Feedback.frame(g)
  local cast = g.view and g.view.abilityCast
  local entry = cast and cast.hands and Art.entries[cast.hands]
  if not entry then
    return nil
  end
  local age = g.elapsed - cast.elapsed
  if age < 0 or age >= entry.duration then
    return nil
  end
  for _, phase in ipairs(entry.frames) do
    if age < phase.finish then
      return phase.frame, age, entry.duration, entry.atlas
    end
  end
end
return Feedback

-- What a body does about what it sees: a creature lists answers, an event and the
-- blow it meets it with (content/defs/creature.lua: answers). An answer comes
-- before the body's own choice and needs no pause since its last blow; each has its
-- own rest. A new event is a new entry here.
local Reload = require('src.combat.reload')
local MathX = require('src.core.mathx')
local Archetypes = require('src.content.enemies')
local AttackSelection = require('src.enemies.attack_selection')
local Answers = {}
local angle = MathX.wrapAngle
local Events = {}
Answers.events = Events
-- The knight has his hands full with a flask or a long cast.
function Events.drinking(_, _, p)
  return p.casting ~= nil
end
function Events.reloading(g, _, p)
  return Reload.left(g, p) > 0
end
-- The knight stands where the body does not face.
function Events.behind(_, e, p, d, answer)
  return d < answer.within
    and math.abs(angle(math.atan2(p.x - e.x, p.z - e.z) - e.facing)) > answer.off
end
-- The knight has been within reach for a while without being struck.
function Events.hugging(_, e, _, d, answer)
  return d < answer.within and (e.closeFor or 0) >= answer.after
end
-- The knight dodged in the beat of a string: the body was waiting for it. The dodge counts
-- while it moves him and while its safety lasts (dodgeEnds, where a dodge is paid for).
function Events.dodged(g, e, p, d, answer)
  return e.chain ~= nil
    and ((p.dashTimer or 0) > 0 or (p.dodgeEnds or 0) > g.elapsed)
    and d < answer.within
end
-- A shot from far away has just landed.
function Events.sniped(_, e, _, d, answer)
  return (e.hit or 0) > 0 and d > answer.within
end
local function attackOf(e, id)
  for _, atk in ipairs(Archetypes.of(e).attacks) do
    if atk.id == id then
      return atk
    end
  end
end
-- The blow this body answers with now, if any.
function Answers.pick(g, e, p, d)
  local list = Archetypes.of(e).answers
  for _, answer in ipairs(list or {}) do
    local until_ = e.answered and e.answered[answer.when]
    if not (until_ and until_ > g.elapsed) and Events[answer.when](g, e, p, d, answer) then
      local atk = attackOf(e, answer.attack)
      if atk and d <= atk.range and d >= atk.minRange and AttackSelection.available(g, e, atk) then
        e.answered = e.answered or {}
        e.answered[answer.when] = g.elapsed + answer.rest
        return atk
      end
    end
  end
end
return Answers

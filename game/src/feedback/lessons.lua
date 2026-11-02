-- What the game teaches once, after it first happens (audit L04): the first golden ring, the
-- first broken guard, the first chain, the first rounds taken. Each waits in its view until no
-- creature hunts the knight (systems/clocks starts it), then stands as the hint for a while
-- (ui/hud), never twice in a session. Lessons are view state: a player is taught what he saw.
local Lessons = {}
function Lessons.note(view, id)
  if not view then
    return
  end
  local lessons = view.lessons or { seen = {}, queue = {} }
  view.lessons = lessons
  if not lessons.seen[id] then
    lessons.seen[id] = true
    lessons.queue[#lessons.queue + 1] = id
  end
end
-- The lesson standing now, as a text key, or nil.
function Lessons.showing(view)
  local lessons = view.lessons
  return lessons and lessons.showing and ('lesson_' .. lessons.showing) or nil
end
return Lessons

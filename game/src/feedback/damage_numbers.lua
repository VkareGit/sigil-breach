-- Floating damage numbers (presentation): the rules' figures shown where the
-- blow landed. A volley adds one per body it reached (feedback/shot_feedback),
-- a missile or a blast one per blow (BlowResolved with a number). Drawn by
-- render/numbers.lua; aged by feedback/transients.lua.
local Numbers = { limit = 24 }
-- broke: the hit broke the guard (gold); wound: a major wound (deep red).
function Numbers.add(g, pt, value, kill, head, armor, broke, wound, counter, crippled)
  if value <= 0 and not armor then
    return
  end
  g.view.damageNumbers = g.view.damageNumbers or {}
  local list = g.view.damageNumbers
  if #list >= Numbers.limit then
    table.remove(list, 1)
  end
  g.view.numberSerial = (g.view.numberSerial or 0) + 1
  list[#list + 1] = {
    x = pt[1],
    y = pt[2] + 0.15,
    z = pt[3],
    value = math.floor(value + 0.5),
    age = 0,
    kill = kill,
    head = head,
    armor = armor,
    broke = broke,
    wound = wound,
    counter = counter,
    crippled = crippled,
    side = g.view.numberSerial % 2 == 0 and 1 or -1,
  }
end
return Numbers

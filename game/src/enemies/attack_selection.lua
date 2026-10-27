-- Deterministic policies. No input reading, RNG or mutation of definitions.
local A = require('src.content.enemies')
local Selection = {}
local function usable(e, attack, distance, now)
  if distance > attack.range or distance < attack.minRange then
    return false
  end
  local until_ = e.restUntil and e.restUntil[attack.id]
  return not (until_ and now and now < until_)
end
local function ordered(e, distance, now, list)
  for _, attack in ipairs(list) do
    if usable(e, attack, distance, now) then
      if attack.maxRange then
        if distance < attack.maxRange then
          return attack
        end
      elseif not attack.every or e.attackCount % attack.every == 0 then
        return attack
      end
    end
  end
  local last = list[#list]
  return last and usable(e, last, distance, now) and last or nil
end
local function context(e, distance, now, list, tactics)
  local chosen, best
  for _, choice in ipairs(tactics.moves) do
    if
      (e.tier or 1) >= choice.fromTier
      and distance >= choice.min
      and (not choice.max or distance <= choice.max)
    then
      for _, attack in ipairs(list) do
        if attack.id == choice.attack and usable(e, attack, distance, now) then
          -- A metre of mismatch halves utility. Weight/history choose among
          -- usable moves; they never expand their damage geometry.
          local score = choice.weight / (1 + math.abs(distance - choice.ideal))
          if e.lastAttack == attack.id then
            score = score * tactics.repeatPenalty ^ (e.attackRepeats or 1)
          end
          if not best or score > best then
            chosen, best = attack, score
          end
        end
      end
    end
  end
  return chosen
end
function Selection.choose(e, distance, now)
  local def = A.of(e)
  local stage = A.phase(e)
  local tactics = stage and stage.tactics or def.tactics
  if tactics and tactics.policy == 'context' then
    return context(e, distance, now, def.attacks, tactics)
  end
  return ordered(e, distance, now, def.attacks)
end
function Selection.committed(e, attack)
  local def, stage = A.of(e), A.phase(e)
  if not (def.tactics or (stage and stage.tactics)) then
    return
  end
  e.attackRepeats = e.lastAttack == attack.id and (e.attackRepeats or 0) + 1 or 1
  e.lastAttack = attack.id
end
function Selection.pace(e)
  local stage = A.phase(e)
  return (e.tierPace or 1) * (stage and stage.pace or 1)
end
return Selection

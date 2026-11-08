-- Sigils modify a real discharge/contact. A miss spends a first-shot charge;
-- pellets share one frozen payload and a volley advances a verdict only once.
-- The interpreter of the moments of a fight (PLAN G2): it calls the kind of
-- effect of each sigil worn (combat/sigil_kinds.lua) in catalogue order and
-- names no sigil.
local SigilRules = require('src.content.sigils')
local Copy = require('src.core.schema').copy
local Kinds = require('src.combat.sigil_kinds')
local S = {}
function S.rank(p, id)
  return p and p.sigilRanks and p.sigilRanks[id] or 0
end
function S.reset(p)
  p.sigilState = nil
end
-- each(id, rank, def, kind) for every sigil worn, in catalogue order.
local function worn(p, each)
  for _, id in ipairs(SigilRules.order) do
    local rank = S.rank(p, id)
    if rank > 0 then
      local def = SigilRules[id]
      each(id, rank, def, Kinds:get(def.effect))
    end
  end
end
-- each(kind) for every kind of effect, worn or not, in registry order.
local function every(each)
  for _, id in ipairs(Kinds:ids()) do
    each(Kinds:get(id))
  end
end
-- A hit is seen once by each sigil, through either of its moments.
local function first(event, id)
  event.sigilsSeen = event.sigilsSeen or {}
  local seen = event.sigilsSeen[id]
  event.sigilsSeen[id] = true
  return not seen
end
function S.dodgeCost(p, base)
  local cost = base
  worn(p, function(_, rank, def, kind)
    if kind.dodgeCost then
      cost = cost + kind.dodgeCost(rank, def)
    end
  end)
  return cost
end
function S.perfect(g, p)
  worn(p, function(_, rank, def, kind)
    if kind.perfect then
      kind.perfect(g, p, rank, def)
    end
  end)
end
function S.flask(p, heal)
  local less = 0
  worn(p, function(_, rank, def, kind)
    if kind.flask then
      less = less + kind.flask(rank, def)
    end
  end)
  return math.max(0, heal - less)
end
function S.reloadStart(p, id, empty)
  local shorter = 0
  worn(p, function(_, rank, def, kind)
    if kind.reloadStart then
      shorter = shorter + kind.reloadStart(p, rank, def, id, empty)
    end
  end)
  return shorter
end
function S.reloadCancel(p)
  local state = p.sigilState
  if state then
    every(function(kind)
      if kind.reloadCancel then
        kind.reloadCancel(state)
      end
    end)
  end
end
function S.reloaded(p, id, loaded)
  local state = p.sigilState
  if state then
    every(function(kind)
      if kind.reloaded then
        kind.reloaded(state, id, loaded)
      end
    end)
  end
  S.reloadCancel(p)
end
function S.shot(g, p, id, attack, pellets)
  if not p.sigilRanks or not next(p.sigilRanks) then
    return attack
  end
  local state, out = Kinds.state(p), Copy(attack)
  local carried = {}
  worn(p, function(sigil, rank, def, kind)
    if kind.shot then
      carried[sigil] = kind.shot(g, p, rank, def, state, id, out, attack, pellets)
    end
  end)
  out.sigil = carried
  every(function(kind)
    if kind.spent then
      kind.spent(state, id)
    end
  end)
  return out
end
function S.contact(attack, target, part)
  local carried = attack.sigil
  if not carried then
    return attack
  end
  local bonus, factor = 0, 1
  for _, id in ipairs(SigilRules.order) do
    local payload, def = carried[id], SigilRules[id]
    local kind = payload and Kinds:get(def.effect)
    if kind and kind.contact then
      local more, times = kind.contact(payload, def, target, part)
      bonus, factor = bonus + more, factor * times
    end
  end
  local out = Copy(attack)
  out.base = attack.base * (1 + math.min(SigilRules.damageCap, bonus))
  if factor ~= 1 then
    out.base = out.base * factor
  end
  return out
end
function S.resolved(p, attack, report)
  local carried = attack.sigil
  if not carried then
    return
  end
  for _, id in ipairs(SigilRules.order) do
    local payload, def = carried[id], SigilRules[id]
    local kind = payload and Kinds:get(def.effect)
    if kind and kind.resolved and not payload.counted then
      payload.counted = true
      kind.resolved(p, payload, def, report)
    end
  end
end
function S.hurt(p, event)
  worn(p, function(id, rank, def, kind)
    if kind.hurt and first(event, id) then
      kind.hurt(p, rank, def, event)
    end
  end)
end
-- True when a sigil owns the rally of this hit, including a spent or expired
-- reprisal: the ordinary rate must not award a second recovery alongside it.
function S.rally(p, event)
  local owned = false
  worn(p, function(id, rank, def, kind)
    if kind.rally then
      owned = true
      if first(event, id) then
        kind.rally(p, rank, def, event)
      end
    end
  end)
  return owned
end
return S

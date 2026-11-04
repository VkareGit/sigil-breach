-- Sigils modify a real discharge/contact. A miss spends a first-shot charge;
-- pellets share one frozen payload and a volley advances a verdict only once.
local K = require('src.content.sigils')
local Copy = require('src.core.schema').copy
local Characters = require('src.content.characters')
local S = {}
function S.rank(p, id)
  return p and p.sigilRanks and p.sigilRanks[id] or 0
end
local function state(p)
  p.sigilState = p.sigilState or {}
  return p.sigilState
end
function S.reset(p)
  p.sigilState = nil
end
function S.dodgeCost(p, base)
  return base + (S.rank(p, 'sigil_furfur') > 0 and K.sigil_furfur.stamina or 0)
end
function S.perfect(g, p)
  if S.rank(p, 'sigil_furfur') > 0 then
    state(p).furfurUntil = g.elapsed + K.sigil_furfur.window
  end
end
function S.flask(p, heal)
  return math.max(0, heal - (S.rank(p, 'sigil_buer') > 0 and K.sigil_buer.flask or 0))
end
function S.reloadStart(p, id, empty)
  if S.rank(p, 'sigil_paimon') <= 0 then
    return 0
  end
  state(p).reloadEmpty = empty and id or nil
  return K.sigil_paimon.reload
end
function S.reloadCancel(p)
  if p.sigilState then
    p.sigilState.reloadEmpty = nil
  end
end
function S.reloaded(p, id, loaded)
  local s = p.sigilState
  if s and s.reloadEmpty == id and loaded then
    s.paimon = s.paimon or {}
    s.paimon[id] = true
  end
  S.reloadCancel(p)
end
function S.shot(g, p, id, attack, pellets)
  if not p.sigilRanks or not next(p.sigilRanks) then
    return attack
  end
  local s, out = state(p), Copy(attack)
  local stolas = id == K.sigil_stolas.weapon and S.rank(p, 'sigil_stolas') or 0
  local furfur = (s.furfurUntil or 0) > g.elapsed and S.rank(p, 'sigil_furfur') or 0
  local paimon = s.paimon and s.paimon[id] and S.rank(p, 'sigil_paimon') or 0
  out.sigil = {
    stolas = stolas,
    target = s.verdictReady and s.verdictTarget or nil,
    bonus = K.sigil_furfur.bonus[furfur] or 0,
  }
  if paimon > 0 then
    local extra = K.sigil_paimon.impact[paimon] / math.max(1, pellets)
    out.impact = (out.impact or out.base) + extra
    -- Impetus adds guard damage, without inventing extra health damage or shove.
    out.push = attack.push or attack.impact or attack.base
  end
  s.furfurUntil = nil
  if s.paimon then
    s.paimon[id] = nil
  end
  return out
end
function S.contact(attack, target, part)
  local sigil = attack.sigil
  if not sigil then
    return attack
  end
  local bonus = sigil.bonus
  if sigil.stolas > 0 and part == 'head' and sigil.target == target.id then
    bonus = bonus + K.sigil_stolas.bonus[sigil.stolas]
  end
  local out = Copy(attack)
  out.base = attack.base * (1 + math.min(K.damageCap, bonus))
  if sigil.stolas > 0 and part == 'torso' then
    out.base = out.base * K.sigil_stolas.torso
  end
  return out
end
function S.resolved(p, attack, report)
  local sigil = attack.sigil
  if not sigil or sigil.counted or sigil.stolas <= 0 then
    return
  end
  sigil.counted = true
  local first = report.hitTargets[1]
  if not first or first.healthDamage <= 0 then
    return
  end
  local s = state(p)
  if sigil.target == first.id and first.headHits > 0 then
    s.verdictHits, s.verdictReady = 0, nil
  else
    if s.verdictTarget ~= first.id then
      s.verdictHits, s.verdictReady = 0, nil
    end
    s.verdictHits = math.min(K.sigil_stolas.hits, (s.verdictHits or 0) + 1)
    s.verdictReady = s.verdictHits >= K.sigil_stolas.hits or nil
  end
  s.verdictTarget = first.id
end
function S.hurt(p, event)
  if S.rank(p, 'sigil_buer') <= 0 or event.sigilBuerProcessed then
    return
  end
  event.sigilBuerProcessed = true
  if (event.info.lost or 0) > 0 then
    state(p).buerReady = true
  end
end
-- Returns true when Buer owns rally for this hit, including a spent/expired
-- reprisal. The ordinary rate must not award a second recovery alongside it.
function S.rally(p, event)
  local rank = S.rank(p, 'sigil_buer')
  if rank <= 0 then
    return false
  end
  if event.sigilBuerProcessed then
    return true
  end
  event.sigilBuerProcessed = true
  local s, e = state(p), event.enemy
  if not s.buerReady or not e or (event.health or 0) <= 0 then
    return true
  end
  if (p.x - e.x) ^ 2 + (p.z - e.z) ^ 2 > K.sigil_buer.reach ^ 2 then
    return true
  end
  s.buerReady = nil
  local back =
    math.max(0, math.min(p.rally or 0, K.sigil_buer.heal[rank], Characters.maxHp(p) - p.hp))
  p.hp, p.rally = p.hp + back, math.max(0, (p.rally or 0) - back)
  return true
end
return S

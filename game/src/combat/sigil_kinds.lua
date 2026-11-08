-- What each kind of sigil effect does (PLAN G2). A sigil is data
-- (content/sigils.lua: its costs, its effect kind and that kind's numbers); a
-- kind is hooked to the moments of a fight, and combat/sigils.lua calls the
-- kinds of the sigils worn. A new sigil names a kind; a new kind is one entry
-- here and names no sigil. Every hook is optional; rank is the copies worn,
-- def the sigil's own data:
--   dodgeCost(rank, def)              stamina added to a dodge
--   perfect(g, p, rank, def)          a perfect dodge
--   flask(rank, def)                  health taken from a flask's heal
--   reloadStart(p, rank, def, weapon, empty)  seconds the reload is shorter
--   reloadCancel(state)               a reload stopped (every kind)
--   reloaded(state, weapon, loaded)   a reload finished (every kind)
--   shot(g, p, rank, def, state, weapon, out, attack, pellets)
--                                     a trigger pull: may change out, and
--                                     returns what the pellets carry for it
--   spent(state, weapon)              after every pull (every kind)
--   contact(payload, def, target, part)  a pellet lands: bonus to add to the
--                                     shared damage bonus and a factor
--   resolved(p, payload, def, report) the volley is resolved
--   hurt(p, rank, def, event)         the bearer is struck
--   rally(p, rank, def, event)        the bearer strikes back; a kind with
--                                     this hook owns the rally of the hit
-- The state of every kind lives in the bearer's sigilState under its own
-- keys (a save keeps it).
local Registry = require('src.core.registry')
local Characters = require('src.content.characters')
local Kinds = Registry:new('sigil effects')
-- The bearer's sigil state, made when a kind first writes it.
function Kinds.state(p)
  p.sigilState = p.sigilState or {}
  return p.sigilState
end
-- Verdict: hits on one demon ready the judgement; the next head shot on it is
-- worth more, the torso a little less while it is worn.
Kinds:register('verdict', {
  shot = function(_, _, rank, def, state, weapon)
    if weapon ~= def.weapon then
      return nil
    end
    return { rank = rank, target = state.verdictReady and state.verdictTarget or nil }
  end,
  contact = function(payload, def, target, part)
    local bonus = part == 'head' and payload.target == target.id and def.bonus[payload.rank] or 0
    return bonus, part == 'torso' and def.torso or 1
  end,
  resolved = function(p, payload, def, report)
    local first = report.hitTargets[1]
    if not first or first.healthDamage <= 0 then
      return
    end
    local s = Kinds.state(p)
    if payload.target == first.id and first.headHits > 0 then
      s.verdictHits, s.verdictReady = 0, nil
    else
      if s.verdictTarget ~= first.id then
        s.verdictHits, s.verdictReady = 0, nil
      end
      s.verdictHits = math.min(def.hits, (s.verdictHits or 0) + 1)
      s.verdictReady = s.verdictHits >= def.hits or nil
    end
    s.verdictTarget = first.id
  end,
})
-- Riposte: a dodge costs more; a perfect one makes the next pull within the
-- window stronger.
Kinds:register('riposte', {
  dodgeCost = function(_, def)
    return def.stamina
  end,
  perfect = function(g, p, _, def)
    Kinds.state(p).furfurUntil = g.elapsed + def.window
  end,
  shot = function(g, _, rank, def, state)
    if (state.furfurUntil or 0) > g.elapsed then
      return { bonus = def.bonus[rank] }
    end
  end,
  contact = function(payload)
    return payload.bonus, 1
  end,
  spent = function(state)
    state.furfurUntil = nil
  end,
})
-- Reprisal: a flask heals less; health lost to a blow is won back by striking
-- the one close by.
Kinds:register('reprisal', {
  flask = function(_, def)
    return def.flask
  end,
  hurt = function(p, _, _, event)
    if (event.info.lost or 0) > 0 then
      Kinds.state(p).buerReady = true
    end
  end,
  rally = function(p, rank, def, event)
    local s, e = Kinds.state(p), event.enemy
    if not s.buerReady or not e or (event.health or 0) <= 0 then
      return
    end
    if (p.x - e.x) ^ 2 + (p.z - e.z) ^ 2 > def.reach ^ 2 then
      return
    end
    s.buerReady = nil
    local back = math.max(0, math.min(p.rally or 0, def.heal[rank], Characters.maxHp(p) - p.hp))
    p.hp, p.rally = p.hp + back, math.max(0, (p.rally or 0) - back)
  end,
})
-- Impetus: a reload is slower; one begun empty and finished charges the first
-- pull of that weapon with guard damage.
Kinds:register('impetus', {
  reloadStart = function(p, _, def, weapon, empty)
    Kinds.state(p).reloadEmpty = empty and weapon or nil
    return def.reload
  end,
  reloadCancel = function(state)
    state.reloadEmpty = nil
  end,
  reloaded = function(state, weapon, loaded)
    if state.reloadEmpty == weapon and loaded then
      state.paimon = state.paimon or {}
      state.paimon[weapon] = true
    end
  end,
  shot = function(_, _, rank, def, state, weapon, out, attack, pellets)
    if not (state.paimon and state.paimon[weapon]) then
      return nil
    end
    out.impact = (out.impact or out.base) + def.impact[rank] / math.max(1, pellets)
    -- Impetus adds guard damage, without inventing extra health damage or shove.
    out.push = attack.push or attack.impact or attack.base
  end,
  spent = function(state, weapon)
    if state.paimon then
      state.paimon[weapon] = nil
    end
  end,
})
return Kinds

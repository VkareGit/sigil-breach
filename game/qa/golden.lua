-- Golden master (0.24 / E0): a digest of the SIMULATION state of a session.
-- Refactors must reproduce it bit for bit; only a deliberate balance change
-- may move it (then tests/golden/baseline.lua is updated on purpose).
-- Presentation (particles, sounds, camera, numbers) is not part of it.
local bit = require('bit')
local Serialize = require('src.core.serialize')
local Golden = {}
local format = string.format
local function num(v)
  if type(v) ~= 'number' then
    return tostring(v)
  end
  return format('%.10g', v)
end
local function append(out, ...)
  for i = 1, select('#', ...) do
    out[#out + 1] = num(select(i, ...))
  end
end
-- Every creature of the session in id order: the living pool and the
-- remains (plan v10 V1), so where a body is stored never moves the digest.
local function creatures(g)
  local list = {}
  for _, e in ipairs(g.enemies) do
    list[#list + 1] = e
  end
  for _, e in ipairs(g.remains or {}) do
    list[#list + 1] = e
  end
  table.sort(list, function(a, b)
    return a.id < b.id
  end)
  return list
end
-- The simulation-relevant fields of a session, in a fixed order.
-- Digest v2 (plan v10 V1): a dead body's state clock (phase) is left out.
-- Nothing reads it, and a retired corpse is no longer stepped.
function Golden.describe(g)
  local out = {}
  local p = g.player
  -- The weapon in hand is the actor's since plan v11 E3 (the same value).
  -- The counters are the actors' ledger since plan v11 E3d (sums, the same values).
  local Stats = require('src.session.stats')
  append(
    out,
    g.elapsed,
    Stats.total(g, 'kills'),
    Stats.total(g, 'damageTaken'),
    Stats.total(g, 'score'),
    p.weapon,
    g.state
  )
  append(
    out,
    p.x,
    p.z,
    p.yaw,
    p.hp,
    p.armor,
    p.arsenal.exorcist.mag,
    p.arsenal.exorcist.reserve,
    p.arsenal.judge.mag
  )
  append(out, p.arsenal.judge.reserve, p.dash, p.jump, p.poise or 0, p.pushX or 0, p.pushZ or 0)
  for _, e in ipairs(creatures(g)) do
    local phase = e.hp > 0 and (e.phase or 0) or 'dead'
    append(out, e.id, e.kind, e.x, e.z, e.hp, e.poise or 0, e.stun or 0, e.ai, phase)
    append(out, e.pushX or 0, e.pushZ or 0, e.windup or 0, e.recover or 0, e.attack or 0)
    if e.phaseIndex or e.lastAttack then
      append(out, 'encounter', e.phaseIndex or 1, e.phaseBaseHp, e.lastAttack, e.attackRepeats)
    end
    if e.finishedAttack then
      append(out, 'follow-up', e.finishedAttack, e.finishedAt, e.finishedTarget)
    end
  end
  for _, b in ipairs(g.bullets) do
    append(out, b.x, b.y, b.z, b.life)
  end
  for _, h in ipairs(g.hazards or {}) do
    append(out, h.x, h.z, h.delay, h.life)
  end
  for _, a in ipairs(g.pickups or {}) do
    append(out, a.kind, a.x, a.z)
  end
  if g.run then
    append(out, g.run.wave, g.run.phase, g.run.wallet, g.run.queueIndex)
  end
  return table.concat(out, ',')
end
-- FNV-1a 32-bit over the description, as 8 hex digits.
function Golden.hash(text)
  local h = 2166136261
  for i = 1, #text do
    h = bit.bxor(h, text:byte(i))
    -- h * 16777619 = (h << 24) + h * 403, exact in doubles before wrapping.
    h = bit.tobit(bit.lshift(h, 24) + h * 403)
  end
  return bit.tohex(h)
end
function Golden.digest(g)
  return Golden.hash(Golden.describe(g))
end
-- A running digest: folds the state every `every` steps (default 60), so
-- a divergence is caught near the step where it appeared.
function Golden.recorder(every)
  every = every or 60
  local r = { value = '', samples = 0, contacts = '', contactCount = 0 }
  local attached
  function r.observe(g, step)
    if attached ~= g then
      attached = g
      g.bus:on('sim', 'VolleyResolved', function(event)
        for _, contact in ipairs(event.report.contacts or {}) do
          r.contacts = Golden.hash(r.contacts .. Serialize.encode(contact))
          r.contactCount = r.contactCount + 1
        end
      end)
    end
    if step % every == 0 then
      r.value = Golden.hash(r.value .. Golden.describe(g))
      r.samples = r.samples + 1
    end
  end
  return r
end
return Golden

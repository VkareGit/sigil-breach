-- 0.24 content schema: every demon, attack, weapon and wave is checked
-- against the rules that read it, so new content fails here, not in play.
local Tests = {}
function Tests.run(_, check)
  local A = require('src.content.enemies')
  local Attacks = require('src.enemies.actions')
  local Weapons = require('src.content.weapons')
  local Waves = require('src.content.waves')
  local Rules = require('src.combat.rules')
  local T = require('src.content.tuning')
  local D = A.defaults
  local function positive(v)
    return type(v) == 'number' and v == v and v > 0 and v < math.huge
  end
  local function packetOk(p)
    return type(p) == 'table'
      and type(p.base) == 'number'
      and p.base >= 0
      and type(p.impact) == 'number'
      and p.impact >= 0
      and (p.damageType == nil or type(p.damageType) == 'string')
  end
  local problems = {}
  local function bad(text)
    problems[#problems + 1] = text
  end
  local creatures = 0
  -- Every creature-like table is in the registry, and the registry is complete.
  local listed = {}
  for id in A.each() do
    listed[id] = true
  end
  for key, a in pairs(A) do
    if type(a) == 'table' and a.body and a.move and not listed[key] then
      bad(key .. ' is a creature missing from A.creatures')
    end
  end
  local Styles = require('src.enemies.ai').styles
  for key, a in A.each() do
    if not Styles[a.move.style or 'keep'] then
      bad(key .. '.move.style ' .. tostring(a.move.style) .. ' is not a movement style')
    end
    do
      creatures = creatures + 1
      local b = a.body
      for _, field in ipairs({ 'hp', 'mass', 'poise', 'radius', 'woundAt' }) do
        if not positive(b[field]) then
          bad(key .. '.body.' .. field)
        end
      end
      if (b.woundAt or 0) > 1 then
        bad(key .. '.body.woundAt > 1')
      end
      if b.stability ~= nil and not positive(b.stability) then
        bad(key .. '.body.stability')
      end
      if not positive(a.move.speed) then
        bad(key .. '.move.speed')
      end
      -- Design rule (0.21): every demon, even at the top tier, walks slower
      -- than the running knight.
      local top = a.move.speed * (1 + D.tiers.speed * (#D.tiers.attackers - 1))
      if not b.boss and top >= T.moveSpeed then
        bad(key .. ' outruns the knight at the top tier')
      end
      if type(a.attacks) ~= 'table' or #a.attacks == 0 then
        bad(key .. '.attacks empty')
      end
      local ids = {}
      for i, atk in ipairs(a.attacks or {}) do
        local name = key .. '.attacks[' .. i .. ']'
        local kind = Attacks.kinds[atk.kind]
        if not kind then
          bad(name .. ' unknown kind ' .. tostring(atk.kind))
        end
        if type(atk.id) ~= 'string' or ids[atk.id] then
          bad(name .. ' id missing or repeated')
        end
        ids[atk.id or i] = true
        if not positive(atk.windup) or not positive(atk.range) then
          bad(name .. ' windup/range')
        end
        if (atk.minRange or 0) >= atk.range then
          bad(name .. ' minRange >= range')
        end
        for _, p in ipairs({
          atk.packet,
          atk.pool and atk.pool.packet,
          atk.bolt and atk.bolt.packet,
        }) do
          if not packetOk(p) then
            bad(name .. ' packet')
          end
        end
        if atk.hyper ~= nil and not (positive(atk.hyper) and atk.hyper >= 1) then
          bad(name .. ' hyper')
        end
      end
    end
  end
  -- Player body: the same rules read the same fields.
  local knight = A.player.body
  for _, field in ipairs({
    'hp',
    'mass',
    'poise',
    'iframes',
    'dashIframes',
    'drag',
    'airDrag',
    'shieldShare',
  }) do
    if not positive(knight[field]) then
      bad('player.body.' .. field)
    end
  end
  -- Every damage type a demon resists must be something an attack can deal.
  local Deliveries = require('src.combat.weapon_delivery')
  local Delivery = require('src.content.defs.delivery')
  local Art = require('src.render.weapon_art')
  local artIds = {}
  for _, id in ipairs(Art.ids) do
    artIds[id] = true
  end
  local weapons = 0
  for id, profile in Weapons.registry:each() do
    weapons = weapons + 1
    local slot = id
    local player = { loadout = { id } }
    local atk = Weapons.attack({ player = player }, 1)
    if
      not (
        positive(atk.base)
        and positive(atk.impact)
        and positive(profile.cycle)
        and positive(profile.range)
      )
    then
      bad('weapon ' .. slot .. ' attack')
    end
    if not (atk.falloffEnd > atk.falloffStart and atk.minPower > 0 and atk.minPower <= 1) then
      bad('weapon ' .. slot .. ' falloff')
    end
    if not require('src.combat.reload').mechanisms[profile.mechanism or ''] then
      bad('weapon ' .. slot .. ' has no reload mechanism')
    end
    if not Deliveries:has(profile.delivery.kind) then
      bad('weapon ' .. slot .. ' has no delivery executor')
    end
    local art = profile.art or id
    if not artIds[art] or not Art[art] then
      bad('weapon ' .. slot .. ' has no loaded hands sheet')
    end
    local fire = profile.fire or {}
    if
      not (
        positive(fire.rounds)
        and positive(fire.pellets)
        and positive(fire.surfaceEvery)
        and positive(fire.trailEvery)
        and type(profile.id) == 'string'
        and type(profile.hud.title) == 'string'
        and type(fire.sound) == 'string'
        and type(fire.flash) == 'table'
      )
    then
      bad('weapon ' .. slot .. ' fire data')
    end
    for glyph in pairs(profile.glyphs or {}) do
      local g = { player = player, run = { glyph = glyph } }
      if not positive(Weapons.attack(g, 1).impact) then
        bad('weapon ' .. slot .. ' glyph ' .. glyph)
      end
    end
  end
  for kind in Delivery.kinds:each() do
    if not Deliveries:has(kind) then
      bad('weapon delivery ' .. kind .. ' has no executor')
    end
  end
  for kind in Deliveries:each() do
    if not Delivery.kinds:has(kind) then
      bad('weapon delivery ' .. kind .. ' has no schema')
    end
  end
  -- Waves only summon creatures that exist, and every creature in a wave arrives.
  for i, w in ipairs(Waves) do
    for _, kind in ipairs(w.queue or {}) do
      if not A.get(kind) then
        bad('wave ' .. i .. ' summons unknown ' .. kind)
      end
    end
  end
  -- Balance tiers must be continuous and every stability positive.
  local s = D.stagger
  if s.heavy.base < s.light.base + s.light.gain * s.heavy.from or s.heavy.max < s.heavy.base then
    bad('stagger tiers discontinuous')
  end
  if not positive(Rules.stability({ kind = 'imp' })) then
    bad('stability')
  end
  check(
    'content schema: '
      .. creatures
      .. ' creatures, '
      .. weapons
      .. ' weapons, every attack kind registered and complete'
      .. (#problems > 0 and (' / ' .. table.concat(problems, '; ')) or ''),
    #problems == 0 and creatures >= 6 and weapons >= 2
  )
  -- A kind missing from the classic role rotation still arrives in a wave.
  -- 0.24: one action format for demons and the knight. Every delivery kind
  -- has a schema (content) and a behaviour: a demon kind (enemies/actions.lua)
  -- or a knight ability kind (combat/explosives.lua: throw).
  local Action = require('src.content.defs.action')
  local Cast = require('src.combat.abilities')
  local knightKinds = Cast.kinds
  local unmatched = {}
  for kind in Action.kinds:each() do
    if not (Attacks.kinds[kind] or knightKinds[kind]) then
      unmatched[#unmatched + 1] = kind .. ' has no behaviour'
    end
  end
  for kind in pairs(Attacks.kinds) do
    if not Action.kinds:has(kind) then
      unmatched[#unmatched + 1] = kind .. ' has no schema'
    end
  end
  for kind, handler in pairs(knightKinds) do
    if not Action.kinds:has(kind) or type(handler) ~= 'function' then
      unmatched[#unmatched + 1] = kind .. ' has no schema or callable knight delivery'
    end
  end
  check(
    'every action kind has a schema and a behaviour'
      .. (#unmatched > 0 and (': ' .. table.concat(unmatched, ', ')) or ''),
    #unmatched == 0
  )
  local Abilities = require('src.content.abilities')
  local castable = true
  for _, ability in Abilities:each() do
    castable = castable
      and Action.kinds:has(ability.action.kind)
      and Cast.kinds[ability.action.kind] ~= nil
  end
  check('the knight abilities are actions of a known kind the caster can deliver', castable)
  local built = Waves.build(5, '', { imp = 1, wraith = 2 }, 1)
  local wraiths = 0
  for _, kind in ipairs(built.queue) do
    wraiths = wraiths + (kind == 'wraith' and 1 or 0)
  end
  check('a new kind of demon outside the classic rotation still arrives in its wave', wraiths == 2)
end
return Tests

-- Creature: the TYPE OBJECT of a demon. A creature file states only what
-- differs from the defaults (and from its parent): Creature.define completes
-- it (body, movement, actions), checks every field and returns the
-- definition the rules read. Instances in play point at it.
--   extends = <creature definition>    data inheritance (variant of a parent)
--   attacks = { { from = 'claw', ... } } an action of the parent, changed
--   Creature.boss({...})               the boss template (falters, 1 slot)
local Factions = require('src.content.factions')
local Schema = require('src.core.schema')
local Body = require('src.content.defs.body')
local Action = require('src.content.defs.action')
local Encounter = require('src.content.defs.encounter')
local Defaults = require('src.content.combat_defaults')
local Creature = {}
Creature.sounds = Schema:new('creature sounds', {
  alert = { type = 'string' },
  windup = { type = 'string' },
  strike = { type = 'string' },
  step = { type = 'string' },
  summon = { type = 'string' },
  arrival = { type = 'string' },
  death = { type = 'string' },
})
Creature.evade = Schema:new('evade', {
  speed = { type = 'number', required = true, min = 0 },
  time = { type = 'number', required = true, min = 0 },
  cooldown = { type = 'number', required = true, min = 0 },
  cone = { type = 'number', default = 0.06, min = 0, desc = 'aim cone that triggers it (rad)' },
})
-- How a duelling body spends the time between blows (enemies/styles.lua: duel).
Creature.duel = Schema:new('duel', {
  circle = { type = 'number', default = 3, min = 0, desc = 'weight of walking around' },
  close = { type = 'number', default = 2, min = 0, desc = 'weight of walking in' },
  back = { type = 'number', default = 1, min = 0, desc = 'weight of giving ground' },
  wait = { type = 'number', default = 1, min = 0, desc = 'weight of standing and watching' },
  hold = { type = 'number', default = 0.8, min = 0, desc = 'shortest of them (s)' },
  spread = { type = 'number', default = 0.9, min = 0, desc = 'added at most (s)' },
  far = { type = 'number', default = 3, min = 0, desc = 'this far past its ideal it comes (m)' },
})
Creature.move = Schema:new('move', {
  speed = { type = 'number', required = true, min = 0, desc = 'walking speed (m/s)' },
  accel = { type = 'number', default = Defaults.accel, min = 0, desc = 'divided by sqrt(mass)' },
  style = { type = 'string', default = 'keep', desc = 'movement style (enemies/styles.lua)' },
  ideal = { type = 'number', default = 6.5, min = 0, desc = "'keep': preferred distance (m)" },
  turn = { type = 'number', min = 0, desc = 'how fast the body turns (rad/s); absent: at once' },
  duel = { type = 'table', schema = Creature.duel, desc = "'duel': between its blows" },
  heavy = { type = 'boolean', default = false },
  evade = { type = 'table', schema = Creature.evade },
  targeting = {
    type = 'string',
    default = 'nearest',
    desc = 'whom it chooses to fight (enemies/target.lua: Target.strategies)',
  },
})
-- How a creature looks and is shown (0.24 F5): renderer, effects, portals,
-- animation and HUD read this instead of asking for a creature by name.
Creature.appearance = Schema:new('appearance', {
  atlas = {
    type = 'string',
    desc = 'painted sheet, idle cycle and hit masks (default: id)',
  },
  -- What the painting is made of where a shot meets it: parts, zones and
  -- materials (content/art/anatomy_regions.lua). A creature over existing art
  -- may describe it differently (iron plates where the parent has skin); the
  -- annotation must have a frame for every frame of the atlas.
  regions = { type = 'string', desc = 'anatomy annotation of its atlas frames (default: atlas)' },
  -- How a shot meets the body: its painted surface (mask + anatomy regions of
  -- the atlas, enemies/surface.lua) or explicit body volumes (a profile named
  -- by anatomy in enemies/hit_volumes.lua, enemies/geometry.lua). One is
  -- chosen; the other is never prepared.
  hit = { type = 'string', default = 'painted', values = { 'painted', 'volumes' } },
  anatomy = { type = 'string', desc = "body-volume profile (hit = 'volumes' only)" },
  portal = { type = 'table', required = true, desc = 'colour of its summoning portal' },
  stain = { type = 'table', desc = 'colour of its ground stain (default: blood)' },
  warning = { type = 'table', desc = 'colour of its wind-up ring (default: ember)' },
  shadow = { type = 'number', default = 1, min = 0, desc = 'shadow scale' },
  stature = { type = 'string', default = 'normal', values = { 'normal', 'large' } },
  casts = { type = 'table', desc = 'attack ids that glow as a spell in wind-up (all = every)' },
  cast = {
    type = 'table',
    default = { size = 0.55, height = 1.35 },
    desc = 'spell glow size, height',
  },
  motion = { type = 'string', desc = 'painted motion (enemies/animation.lua: Anim.motions)' },
  seal = { type = 'string', desc = 'its historical seal on the floor of its altar' },
  deathStain = { type = 'number', default = 0.65, min = 0, desc = 'stain size where it dies' },
  fieldRing = { type = 'number', default = 0.45, min = 0, desc = 'proving-ground spawn spacing' },
  banner = { type = 'table', desc = 'HUD title: calm, fury, exposed, plainFury' },
  art = { type = 'table', desc = 'attack id -> ability art sequence (render/ability_art.lua)' },
  evadeArt = { type = 'string', desc = 'ability art sequence of its sidestep' },
})
-- Where a creature is listed: the lists are built from these entries, never
-- written out per screen. field: its place in the proving-ground catalogue,
-- the gallery's statues and spawn pads (run/test_field.lua, world/gallery.lua);
-- bestiary: its card on the help screen (ui/screens/help.lua). A creature
-- with neither is not listed. A variant lists itself: never inherited.
Creature.bestiary = Schema:new('bestiary', {
  order = { type = 'number', required = true, min = 1, desc = 'place among the cards' },
  text = { type = 'string', required = true, desc = 'what it does' },
  tip = { type = 'string', required = true, desc = 'how to answer it' },
  color = { type = 'string', required = true, desc = 'its title colour (ui/palette.lua name)' },
})
Creature.catalog = Schema:new('catalog', {
  field = { type = 'number', min = 1, desc = 'place in the proving ground and the gallery' },
  bestiary = { type = 'table', schema = Creature.bestiary },
})
-- What a body does about what it sees (enemies/answers.lua).
Creature.answer = Schema:new('answer', {
  when = { type = 'string', required = true, desc = 'event (enemies/answers.lua: Answers.events)' },
  attack = { type = 'string', required = true, desc = 'the blow it answers with' },
  rest = { type = 'number', default = 4, min = 0, desc = 'before this event is answered again (s)' },
  within = { type = 'number', default = 4, min = 0, desc = 'distance the event is judged at (m)' },
  off = { type = 'number', default = 1.9, min = 0, desc = 'behind: radians off its facing' },
  after = { type = 'number', default = 1, min = 0, desc = 'hugging: for this long (s)' },
})
Creature.schema = Schema:new('creature', {
  id = { type = 'string', required = true },
  catalog = { type = 'table', default = {}, desc = 'where it is listed (Creature.catalog)' },
  kind = { type = 'string', required = true, desc = 'atlas and AI family' },
  variant = { type = 'string', desc = 'id of the variant of its kind' },
  name = { type = 'string', required = true },
  souls = { type = 'number', default = 0, min = 0 },
  ammo = {
    type = 'table',
    desc = 'what it leaves for the guns (run/drops.lua): weapon id, chance of a pack on a kill, '
      .. 'least and most rounds in it, rounds an execution always gives',
  },
  tactics = { type = 'table', schema = Encounter.tactics },
  phases = { type = 'table', list = Encounter.phase },
  guardian = {
    type = 'boolean',
    default = false,
    desc = 'a guardian: it arrives knowing where the knight is',
  },
  appearance = { type = 'table', required = true, desc = 'how it looks (Creature.appearance)' },
  faction = { type = 'string', default = 'demons', desc = 'its side (content/factions.lua)' },
  threat = { type = 'number', default = 1, min = 0 },
  maxAttackers = { type = 'number', min = 1, desc = 'own cap of simultaneous attackers' },
  sounds = { type = 'table', default = {}, schema = Creature.sounds },
  body = { type = 'table', required = true },
  move = { type = 'table', required = true },
  attacks = { type = 'table', required = true },
  answers = { type = 'table', list = Creature.answer, desc = 'blows that meet what it sees' },
})
-- The boss template: a large guard that falters instead of breaking,
-- longer stance, one attacker at a time, never a major wound from one hit.
Creature.bossTemplate = {
  threat = 3,
  maxAttackers = 1,
  body = { boss = true, stability = 1.5, woundAt = 1, microStun = 0 },
}
local function actionsOf(parent, child)
  if child == nil then
    return parent and Schema.copy(parent.attacks) or {}
  end
  assert(type(child) == 'table', 'creature.attacks: expected an array')
  local count = 0
  for key, value in pairs(child) do
    count = count + 1
    assert(
      type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= #child,
      'creature.attacks: expected a dense array'
    )
    assert(type(value) == 'table', 'creature.attacks[' .. key .. ']: expected an action')
  end
  assert(count == #child, 'creature.attacks: expected a dense array')
  local out = {}
  for i, a in ipairs(child) do
    if a.from then
      local base
      for _, p in ipairs(parent and parent.attacks or {}) do
        if p.id == a.from then
          base = p
        end
      end
      assert(base, 'attack from unknown parent action ' .. tostring(a.from))
      local changed = {}
      for k, v in pairs(a) do
        if k ~= 'from' then
          changed[k] = v
        end
      end
      out[i] = Schema.inherit(base, changed)
    else
      out[i] = a
    end
  end
  return out
end
function Creature.define(def)
  local parent = def.extends
  local merged = parent and Schema.inherit(parent, def) or Schema.copy(def)
  merged.extends = nil
  -- A child with attacks of its own decides among them itself.
  if def.attacks and not def.tactics then
    merged.tactics = nil
  end
  if def.attacks and not def.answers then
    merged.answers = nil
  end
  merged.catalog = def.catalog or {}
  merged.attacks = actionsOf(parent, def.attacks)
  merged.kind = merged.kind or merged.id
  local where = 'creature ' .. tostring(merged.id)
  merged = Creature.schema:fill(merged)
  merged.body = Body.schema:build(merged.body, where .. '.body')
  merged.move = Creature.move:build(merged.move, where .. '.move')
  if merged.move.evade then
    assert(merged.move.evade.time > 0, where .. '.move.evade.time: must be positive')
  end
  merged.appearance = Creature.appearance:build(merged.appearance, where .. '.appearance')
  merged.appearance.atlas = merged.appearance.atlas or merged.id
  merged.catalog = Creature.catalog:build(merged.catalog, where .. '.catalog')
  assert(
    Factions:has(merged.faction),
    where .. '.faction: unknown side ' .. tostring(merged.faction)
  )
  assert(#merged.attacks > 0, where .. '.attacks: at least one action required')
  local ids = {}
  for i, a in ipairs(merged.attacks) do
    merged.attacks[i] = Action.build(a, where .. '.attacks[' .. i .. ']')
    assert(not ids[a.id], where .. '.attacks: repeated action id ' .. a.id)
    ids[a.id] = true
  end
  for _, a in ipairs(merged.attacks) do
    assert(
      not a.string or not a.string.into or ids[a.string.into],
      where .. ': string into unknown ' .. a.id
    )
    for _, branch in ipairs(a.string and a.string.branches or {}) do
      assert(not branch.into or ids[branch.into], where .. ': branch into unknown ' .. a.id)
    end
  end
  for index, answer in ipairs(merged.answers or {}) do
    local path = where .. '.answers[' .. index .. ']'
    merged.answers[index] = Creature.answer:build(answer, path)
    assert(ids[answer.attack], path .. ': unknown attack ' .. tostring(answer.attack))
  end
  Creature.schema:validate(merged, where)
  Encounter.validate(merged, where)
  return merged
end
function Creature.boss(def)
  return Creature.define(Schema.inherit(Creature.bossTemplate, def))
end
return Creature

-- Firearms by id (0.24 F3). A weapon is a definition here (content/defs/
-- weapon.lua) and a live record in the knight's arsenal: player.arsenal[id]
-- = what its ammunition model holds (content/ammo/index.lua) and the state of its
-- action { open, loaded, spent, readyAt }. The knight carries the
-- weapons of his loadout (player.loadout, an ordered list of ids); its
-- weapon field is the slot in hand (the actor's, plan v11 E3). A new weapon is a new definition; nothing assumes two.
local T = require('src.content.tuning')
local Registry = require('src.core.registry')
local Weapon = require('src.content.defs.weapon')
local Ammo = require('src.content.ammo.index')
local Roles = require('src.core.roles')
local W = {}
-- weight: the physical body of the weapon (src/feedback/weight.lua). Recoil impulse =
-- momentum of a full discharge * power / mass; heavier guns lag the aim and
-- settle slower. roll is the render-only head twist per unit of recoil,
-- punch the bounded hand rise, back the shove of the gun toward the
-- eye, flip the muzzle rotation, tail the stone hall's answer (volume).
-- wrist is angular impulse per unit of recoil, supported by wristK / wristD
-- (spring / damping). The two-handed stock takes its impulse along the barrel;
-- the one-handed Judge turns around the grip before the wrist catches it.
local definitions = {
  {
    id = 'exorcist',
    name = 'weapon_exorcist',
    -- HUD words (text keys): its title, what kind of gun, its slot tab, how it
    -- is drawn, and the notice when one pull would be short of rounds.
    hud = {
      title = 'weapon_exorcist_title',
      kind = 'weapon_exorcist_kind',
      tab = 'weapon_exorcist_tab',
      draw = 'weapon_exorcist_draw',
      partial = 'weapon_exorcist_partial',
      partialShort = 'weapon_exorcist_partial_short',
    },
    ammo = {
      kind = 'magazine',
      capacity = 2,
      startReserve = T.startReserve,
      maxReserve = 72,
      packSize = 4,
    },
    cycle = T.shotgunCycle,
    range = T.shotgunRange,
    -- Reload mechanism (content/reloads.lua).
    reload = { mechanism = 'breech' },
    -- How a trigger pull fires (combat/combat.lua reads only this): rounds per
    -- pull (both barrels), pellets of a full pull, whether spent cases stay in
    -- the action, presentation, and whether the action reloads itself.
    fire = {
      heavy = true,
      rounds = 2,
      pellets = T.shotgunPellets,
      ejects = true,
      autoReload = true,
      muzzle = 0.065,
      shake = 0.05,
      flash = { 1, 0.42, 0.09 },
      sound = 'shot',
      volumePower = 0.3,
      smoke = 0.30,
      smokeTime = 0.62,
      surfaceEvery = 4,
      trailEvery = 2,
    },
    -- What one pellet delivers (src/combat/damage.lua). impact: guard damage;
    -- push (optional, defaults to impact): physical impulse.
    attack = {
      base = T.pelletDamage,
      headMultiplier = T.shotgunHeadMultiplier,
      penetration = 0.10,
      falloffStart = T.falloffStart,
      falloffEnd = T.falloffEnd,
      minPower = T.pelletMinPower,
      impact = T.pelletDamage,
    },
    -- Glyphs change fields of the attack: set replaces, scale multiplies;
    -- spread scales the pellet cone (FOCUS: 28 % tighter).
    glyphs = {
      pierce = { set = { penetration = 0.60 }, scale = { impact = 0.65 } },
      choke = { spread = 0.72 },
    },
    weight = {
      mass = 4,
      momentum = 96,
      fov = 1.6,
      roll = 0.008,
      aim = 0.78,
      carry = 1,
      punch = 0.033,
      back = 2.1,
      flip = 0.003,
      tail = 0.34,
      wrist = 0.014,
      wristK = 280,
      wristD = 28,
      wristLimit = 0.024,
      -- Two barrels: the view climbs 2 degrees and settles in ~0.25 s; a
      -- heavy thump under the report.
      viewKick = 0.035,
      viewKickRate = 22,
      thump = 0.36,
    },
  },
  {
    id = 'judge',
    name = 'weapon_judge',
    hud = {
      title = 'weapon_judge_title',
      kind = 'weapon_judge_kind',
      tab = 'weapon_judge_tab',
      draw = 'weapon_judge_draw',
    },
    ammo = {
      kind = 'magazine',
      capacity = T.revolverCapacity,
      startReserve = T.revolverStartReserve,
      maxReserve = T.revolverMaxReserve,
      packSize = 6,
    },
    cycle = T.revolverInterval,
    range = T.revolverRange,
    reload = { mechanism = 'cylinder' },
    fire = {
      muzzle = 0.045,
      shake = 0.018,
      flash = { 1, 0.62, 0.25 },
      sound = 'revolver',
      smoke = 0.17,
      smokeTime = 0.42,
    },
    attack = {
      base = T.revolverDamage,
      headMultiplier = T.revolverHeadMultiplier,
      penetration = T.revolverPenetration,
      falloffStart = T.revolverFalloffStart,
      falloffEnd = T.revolverFalloffEnd,
      minPower = T.revolverMinPower,
      impact = T.revolverImpact,
      -- The Judge breaks a guard (impact 44) more than it throws a body.
      push = 25,
      -- pierce: the heavy round passes through bodies (Call of Duty
      -- penetration): 62 % of its power survives flesh, armour costs .45 %
      -- per rating point; below minRetain of its power it stops.
      pierce = { bodies = 2, retain = 0.62, armorCost = 0.0045, minRetain = 0.2 },
    },
    weight = {
      mass = 1.5,
      momentum = 9,
      fov = 0.5,
      roll = 0.012,
      aim = 1,
      carry = 0.72,
      punch = 0.06,
      back = 5,
      flip = 0.008,
      tail = 0.20,
      wrist = 0.31,
      wristK = 210,
      wristD = 20,
      wristLimit = 0.075,
      -- One heavy round: a sharp 1 degree climb, back well before the next.
      viewKick = 0.018,
      viewKickRate = 34,
      thump = 0.14,
    },
  },
}
local registry = Registry:new('weapons')
for _, def in ipairs(definitions) do
  local built = Weapon.define(def)
  registry:register(built.id, built)
end
W.registry = registry
-- The loadout a new knight starts with (slot order).
W.defaultLoadout = { 'exorcist', 'judge' }
-- A weapon definition by id.
function W.get(id)
  return registry:get(id)
end
-- Register a weapon definition (a new gun, a mod, a test).
function W.define(def)
  local built = Weapon.define(def)
  registry:register(built.id, built)
  return built
end
-- A fresh live record of a weapon: full, its starting reserve, action closed.
function W.newState(def)
  local state = Ammo.of(def).newState(def.ammo)
  state.open, state.loaded, state.spent, state.readyAt = false, false, 0, 0
  return state
end
-- An arsenal for a loadout (a list of ids).
function W.arsenal(loadout)
  local arsenal = {}
  for _, id in ipairs(loadout) do
    arsenal[id] = W.newState(W.get(id))
  end
  return arsenal
end
-- Every query below is about one actor (plan v11 E3b): the knight given, else
-- the controlled one. A hand-made session without a knight has the default
-- loadout and the first slot.
local function holder(g, actor)
  return actor or (g and Roles.controlled(g))
end
W.holder = holder
local function loadoutOf(g, actor)
  local a = holder(g, actor)
  return a and a.loadout or W.defaultLoadout
end
-- The slot in the actor's hand.
function W.slot(g, actor)
  local a = holder(g, actor)
  return a and a.weapon or 1
end
-- The id of the weapon in a slot (default: the slot in hand).
function W.idAt(g, slot, actor)
  return loadoutOf(g, actor)[slot or W.slot(g, actor)]
end
-- The slot of a weapon id in the knight's loadout.
function W.slotOf(g, id, actor)
  for slot, known in ipairs(loadoutOf(g, actor)) do
    if known == id then
      return slot
    end
  end
end
-- The definition in a slot (g: whose loadout; default the starting one).
function W.profile(slot, g, actor)
  local id = loadoutOf(g, actor)[slot]
  return id and registry:find(id)
end
-- The definition and live record in hand (or in slot).
function W.inHand(g, slot, actor)
  local id = W.idAt(g, slot, actor)
  local a = holder(g, actor)
  local arsenal = a and a.arsenal
  return id and registry:find(id), id and arsenal and arsenal[id]
end
function W.state(g, slot, actor)
  local _, state = W.inHand(g, slot, actor)
  return state
end
function W.count(g, actor)
  return #loadoutOf(g, actor)
end
-- The slot after the one in hand (wrapping), for cycling weapons.
function W.nextSlot(g, actor)
  return W.slot(g, actor) % W.count(g, actor) + 1
end
-- What the interface shows of a weapon: value, reserve, capacity.
function W.meter(g, slot, actor)
  local def, state = W.inHand(g, slot, actor)
  assert(def and state, 'invalid weapon slot')
  return Ammo.of(def).meter(def.ammo, state)
end
function W.validAmmo(g, slot, actor)
  local def, state = W.inHand(g, slot, actor)
  if not def or not state then
    return false
  end
  return Ammo.of(def).valid(def.ammo, state)
end
-- What the next load of the weapon in hand moves.
function W.pending(g, actor)
  local def, state = W.inHand(g, nil, actor)
  return Ammo.of(def).pending(def.ammo, state)
end
-- What a supply could still add to this weapon, and adds to it.
function W.room(def, state)
  return Ammo.of(def).room(def.ammo, state)
end
function W.refill(def, state, amount, cap)
  return Ammo.of(def).refill(def.ammo, state, amount, cap)
end
function W.spend(def, state, count)
  return Ammo.of(def).spend(def.ammo, state, count)
end
function W.stocked(def, state)
  return Ammo.of(def).stocked(def.ammo, state)
end
-- Shots the actor could still fire, whatever its weapons hold.
function W.left(g, actor)
  local p, shots = holder(g, actor), 0
  for _, id in ipairs(p.loadout) do
    local def = W.get(id)
    shots = shots + Ammo.of(def).left(def.ammo, p.arsenal[id])
  end
  return shots
end
-- Every weapon of the actor: full, or empty, or as it starts.
function W.fill(g, actor)
  local p = holder(g, actor)
  for _, id in ipairs(p.loadout) do
    local def = W.get(id)
    Ammo.of(def).fill(def.ammo, p.arsenal[id])
  end
end
function W.clear(g, actor)
  local p = holder(g, actor)
  for _, id in ipairs(p.loadout) do
    local def = W.get(id)
    Ammo.of(def).clear(def.ammo, p.arsenal[id])
  end
end
function W.restock(g, actor)
  local p = holder(g, actor)
  for _, id in ipairs(p.loadout) do
    local def = W.get(id)
    Ammo.of(def).restock(def.ammo, p.arsenal[id])
  end
end
-- What changes with time (a heat gauge cooling).
function W.tick(g, dt, actor)
  local p = holder(g, actor)
  for _, id in ipairs(p.loadout or {}) do
    local def = W.get(id)
    local model = Ammo.of(def)
    if model.tick then
      model.tick(def.ammo, p.arsenal[id], dt)
    end
  end
end
-- The attack of a weapon as fired now: its data with the run's glyph applied.
-- alt: of its second mode (Weapon: secondary).
function W.attack(g, slot, glyph, actor, alt)
  local def = assert(W.inHand(g, slot, actor), 'invalid weapon slot')
  def = alt and def.secondary or def
  local attack = {}
  for k, v in pairs(def.attack) do
    attack[k] = v
  end
  local mod = glyph and def.glyphs and def.glyphs[glyph]
  if mod then
    for k, v in pairs(mod.set or {}) do
      attack[k] = v
    end
    for k, v in pairs(mod.scale or {}) do
      attack[k] = (attack[k] or 0) * v
    end
  end
  return attack
end
-- The pellet cone of the weapon in hand under the run's glyph (1: as made).
function W.spread(g, glyph, actor, alt)
  local def = W.inHand(g, nil, actor)
  def = alt and def and def.secondary or def
  local mod = def and glyph and def.glyphs and def.glyphs[glyph]
  return (def and def.fire.spread or 1) * (mod and mod.spread or 1)
end
function W.canFire(g, actor)
  if not W.validAmmo(g, nil, actor) then
    return false
  end
  local def, state = W.inHand(g, nil, actor)
  if state.open then
    return false
  end
  return Ammo.of(def).canFire(def.ammo, state)
end
-- Move rounds from the reserve into the weapon; returns how many.
function W.load(g, slot, actor)
  if not W.validAmmo(g, slot, actor) then
    return 0
  end
  local def, state = W.inHand(g, slot, actor)
  return Ammo.of(def).load(def.ammo, state)
end
-- Close every weapon's action and drop its spent cases (the shrine).
function W.close(g, actor)
  for _, state in pairs(holder(g, actor).arsenal or {}) do
    state.open, state.loaded, state.spent = false, false, 0
  end
end
-- Put every weapon's action back at rest, its cadence too (a new life).
function W.rest(g, actor)
  W.close(g, actor)
  for _, state in pairs(holder(g, actor).arsenal or {}) do
    state.readyAt = 0
  end
end
-- What a checkpoint keeps of the arsenal: the loadout and each weapon's
-- rounds and reserve.
function W.inventory(g, actor)
  local p = holder(g, actor)
  local loadout, weapons = {}, {}
  for i, id in ipairs(p.loadout) do
    loadout[i] = id
    weapons[id] = Ammo.of(W.get(id)).pack(p.arsenal[id])
  end
  return loadout, weapons
end
-- Back from a checkpoint: its loadout (when it names one) and rounds; a
-- weapon it does not mention starts full with its starting reserve.
function W.restore(g, loadout, weapons, actor)
  local p = holder(g, actor)
  if loadout then
    p.loadout = {}
    for i, id in ipairs(loadout) do
      p.loadout[i] = id
    end
    p.arsenal = W.arsenal(p.loadout)
  end
  for _, id in ipairs(p.loadout) do
    local def, state, saved = W.get(id), p.arsenal[id], weapons and weapons[id]
    for key, value in pairs(saved or Ammo.of(def).newState(def.ammo)) do
      state[key] = value
    end
  end
end
-- Add a weapon to the knight's loadout (next slot), fresh from its definition.
function W.give(g, id, actor)
  local p = holder(g, actor)
  local def = W.get(id)
  if p.arsenal[id] then
    return W.slotOf(g, id, actor)
  end
  p.loadout[#p.loadout + 1] = id
  p.arsenal[id] = W.newState(def)
  return #p.loadout
end
-- Load every weapon from its reserve.
function W.loadAll(g, actor)
  for slot = 1, W.count(g, actor) do
    W.load(g, slot, actor)
  end
end
return W

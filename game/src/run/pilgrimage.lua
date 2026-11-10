-- The way: fires, area by area. The world stands where the map
-- puts it; a rest heals the knight, fills his flask and rounds, sets where he wakes,
-- and secures what he cleared and took (0.42). A death brings back only what was cleared
-- or taken since; it leaves the souls where the knight fell; dying again before reaching
-- them loses them.
local Abilities = require('src.content.abilities')
local ActorReset = require('src.run.actor_reset')
local Characters = require('src.content.characters')
local Destruction = require('src.combat.destruction')
local Encounter = require('src.session.encounter')
local Execution = require('src.storage.execution')
local Feel = require('src.player.feel')
local Ground = require('src.physics.ground')
local Way = require('src.content.pilgrimage')
local MathX = require('src.core.mathx')
local Presentation = require('src.session.presentation')
local Signal = require('src.session.signal')
local Roles = require('src.core.roles')
local Rules = require('src.combat.rules')
local Sanctuary = require('src.session.sanctuary')
local Save = require('src.storage.save')
local Spawn = require('src.session.spawn')
local Interactions = require('src.session.interactions')
local Pools = require('src.session.world')
local Text = require('src.content.text')
local Weapons = require('src.content.weapons')
local Archetypes = require('src.content.enemies')
local Bodies = require('src.combat.bodies')
local Maps = require('src.content.maps.index')
local Shop = require('src.content.shop')
local Copy = require('src.core.schema').copy
local Economy = require('src.run.economy')
local Arena = require('src.world.arena')
local P = {}
local distance = MathX.distance
-- The format of its file (run/pilgrimage_save.lua).
local PilgrimageSave = require('src.run.pilgrimage_save')
-- The file of a save slot; the first keeps the name every earlier version wrote.
function P.file(slot)
  return (slot or 1) == 1 and 'pilgrimage.save' or ('pilgrimage-' .. slot .. '.save')
end
local function area(g)
  return Way.areas:get(g.run.area)
end
-- A relic found in the chapel (0.43, owner D8; session/interactions.lua: relic). Taken, it is
-- the way's: an engraving owned, a sigil one rank higher; it is put on at once when its place
-- is free (a gun with none, a free sigil place), else a fire changes it. Returns the notice.
-- 0.45 (owner, D15): the find and its place on the map go together, unlike supplies (D10): a
-- death before a fire does not lay it again, so the same relic cannot raise a rank twice.
function P.relicWanted(g, pickup)
  return g.run ~= nil and Shop.find(pickup.offer) ~= nil
end
function P.takeRelic(g, pickup)
  local r, offer = g.run, Shop.get(pickup.offer)
  if pickup.rewardId and r.taken[pickup.rewardId] then
    return ''
  end
  if pickup.rewardId then
    r.taken[pickup.rewardId] = true
  end
  if offer.kind == 'sigil' then
    r.vows[offer.id] = math.min(offer.limit, (r.vows[offer.id] or 0) + 1)
  else
    r.owned[offer.id] = true
    if r.worn and offer.weapon and not r.worn[offer.weapon] then
      r.worn[offer.weapon] = offer.id
    end
  end
  r.dirty = true
  return Text.get('pickup_relic', { name = Text.get(offer.name) })
end
-- The fire the knight stands at, if any.
function P.fireHere(g)
  local p = Roles.controlled(g)
  for _, fire in ipairs(area(g).fires) do
    if distance(p, fire) < Way.reach then
      return fire
    end
  end
end
local function place(g, entry)
  local e = g:spawn(entry.creature, entry.x, entry.z)
  e.home, e.leash, e.alertRange =
    { x = entry.x, z = entry.z }, entry.leash or Way.leash, entry.alert
  e.facing, e.spawnAge, e.awake = entry.yaw, 2, false
  e.patrol, e.post = entry.patrol, entry.id
  return e
end
-- What lies about, where the area says (content/pilgrimage.lua: supplies). Taken, it stays
-- taken for good once a rest secures it (D10), or until a death before that, with the creatures (0.42, the
-- owner: a way plans its route like a Doom level, a new try finds the floor full again).
local function lay(g, cache)
  Spawn.make(g, 'pickup', {
    x = cache.x,
    z = cache.z,
    kind = cache.kind or 'ammo',
    weapon = cache.weapon,
    offer = cache.offer,
    amount = cache.amount,
    rewardId = cache.id,
  })
end
-- The world as a death or a new arrival finds it: every creature at its post and every cache
-- full, but for what a rest secured (run.slain, run.taken). fallen, picked (optional): what a
-- way resumed in the field had cleared and taken since its last fire (0.43, D9).
function P.populate(g, fallen, picked)
  Encounter.clearStage(g)
  -- Small things stand again; what fell of the building stays down.
  Destruction.settle(g.world)
  -- Every area of the map stands at once (PLAN G4): his own first, then the
  -- others in the way's order, asleep until he walks in (P.update).
  local r, classes = g.run, {}
  local here = area(g)
  local areas = { here }
  for _, other in ipairs(Way.areasOf(here.map)) do
    if other ~= here then
      areas[#areas + 1] = other
    end
  end
  for _, garrisoned in ipairs(areas) do
    for _, entry in ipairs(garrisoned.garrison) do
      if not r.slain[entry.id] and not (fallen and fallen[entry.id]) then
        local e = place(g, entry)
        e.homeArea = garrisoned.id
        classes[Arena.class(Rules.radius(e), Rules.tall(g, e))] = e
      end
    end
    for _, cache in ipairs(garrisoned.supplies or {}) do
      if not r.taken[cache.id] and not (picked and picked[cache.id]) then
        lay(g, cache)
      end
    end
  end
  P.wake(g)
  -- The first route of a body's size walks the whole map: here, not in the first chase.
  for class, e in pairs(classes) do
    Arena.flow(g.world, e.x, e.z, class)
  end
end
-- What his vows make of him, from his character up: a rest and a purchase both ask.
local function swear(g)
  local p, vows = Roles.controlled(g), g.run.vows
  local body = Characters.of(p).body
  local stats = { maxHp = body.hp, maxArmor = body.armor }
  for _, offer in ipairs(Shop.offers) do
    local given = (vows[offer.id] or 0) * (offer.amount or 0)
    if offer.stat then
      stats[offer.stat] = stats[offer.stat] + given
    elseif offer.trait then
      -- A sigil's trait: its value at the rank found, none before the first or when it is not
      -- worn (0.43, D8: a knight wears Shop.sigilSlots of those he found).
      local worn = offer.kind ~= 'sigil' or Economy.wearing(g.run, offer)
      p[offer.trait] = worn and offer.ranks[vows[offer.id] or 0] or nil
    elseif offer.kind == 'vow' and offer.ability and p.abilityState[offer.ability] then
      p.abilityState[offer.ability].extra = given
    end
  end
  p.sigilRanks = Copy(g.run.sigils or {})
  p.maxHp, p.maxArmor = stats.maxHp, stats.maxArmor
end
-- A rest, a retry, a journey and a purchase: a fresh start, then everything full. A fire fills
-- each reserve up to what it gives (carried) and never takes away rounds gathered beyond it from
-- the creatures; only the start of a way gives exactly what a fire gives (fresh).
local function refresh(g, fresh)
  swear(g)
  local p = Roles.controlled(g)
  ActorReset.actor(g, p)
  -- Nothing of the last fight finishes on his camera or hands either.
  Presentation.call(g, 'motion.afresh')
  p.hp, p.armor = Characters.maxHp(p), p.maxArmor
  Characters.rest(p)
  Abilities.fill(g, nil, p)
  Abilities.rest(g, p)
  local gathered = {}
  for id in pairs(Way.carried) do
    local slot = Weapons.slotOf(g, id, p)
    gathered[id] = slot and not fresh and select(2, Weapons.meter(g, slot, p)) or 0
  end
  Weapons.fill(g, p)
  for id, amount in pairs(Way.carried) do
    if Weapons.slotOf(g, id, p) then
      Weapons.stock(g, id, math.max(amount, gathered[id]), p)
    end
  end
  Weapons.rest(g)
  p.reload, p.cooldown, p.invuln = 0, 0, 0
end
-- Where a knight wakes at a fire: its own spot, else K.wake m before it, facing on.
local function wakeAt(fire)
  local spot = fire.wake
  if spot then
    return spot.x, spot.z, spot.yaw
  end
  return fire.x, fire.z - Way.wake, math.pi
end
local function wake(g, fire)
  local p = Roles.controlled(g)
  p.x, p.z, p.yaw = wakeAt(fire)
  p.pitch = 0
end
-- A refused write stays owed: the next quiet moment tries again, never the next frame.
function P.save(g)
  local r = g.run
  r.saves = r.saves + 1
  local text = Save.encode('pilgrimage', Save.capture('pilgrimage', g), r.saves)
  local reason = Execution.effect(g, 'pilgrimage.save', function()
    local ok, problem = Save.write(P.file(r.slot), text)
    return not ok and problem or nil
  end)
  g.saveWarning = reason
  r.dirty, r.waited = reason ~= nil, 0
  -- moved: the field changed since this write (0.43, D9); a refused write keeps it owed.
  r.moved = r.moved and reason ~= nil or false
  return reason == nil
end
-- Whether the game holds anything the disk has not: a kill, or a field walked since the last
-- write (0.43, D9: leaving with no kill since then wrote nothing, and Continue refilled).
function P.unsaved(g)
  return g.run.dirty or g.run.moved == true
end
-- What is unsaved goes to disk now: the game stopped, or is about to.
function P.flush(g)
  return P.unsaved(g) and P.save(g)
end
-- A new way: the old one is gone, every copy of it.
function P.forget(g, slot)
  if g then
    g.run.dirty = false
  end
  Save.erase(P.file(slot or (g and g.run.slot)))
end
-- All a replay needs to start where this session started, and nothing from the disk.
function P.construction(g)
  local r = g.run
  return { slot = r.slot, origin = r.origin, saves = r.begun }
end
-- The world under the knight is his area's map, with that map's ruin.
local function stand(g)
  local r, map = g.run, area(g).map
  if g.world.mapId ~= map then
    g.world = Arena.new(map)
  end
  Destruction.restore(g.world, r.ruins[map])
end
-- On to another area. What fell where he leaves stays fallen.
local function enter(g, id)
  local r = g.run
  if id ~= r.area then
    r.ruins[g.world.mapId] = Copy(g.world.destruction or {})
    r.area = id
    Encounter.clearWorld(g)
    stand(g)
  end
end
local function renew(g, slot)
  local first = Way.start().first
  g.run = {
    phase = 'journey',
    wallet = 0,
    glyph = 'none',
    owned = {},
    deaths = 0,
    slot = slot or 1,
    market = 'fire',
    vows = {},
    area = Way.first,
    fire = first,
    lit = { [first] = true },
    opened = {},
    ruins = {},
    dirty = false,
    waited = 0,
    worn = {},
    slain = {},
    taken = {},
    sigils = {},
  }
  Weapons.restore(g, Way.startingWeapons, nil, Roles.controlled(g))
  Roles.controlled(g).weapon = 1
  Abilities.give(g, 'flask', Roles.controlled(g))
  stand(g)
end
-- The newest copy that both reads and restores. One that fails leaves a new run behind it
-- for the next; the start of the game never depends on a file being good.
local function resume(g, slot)
  local found, damaged = Save.candidates('pilgrimage', P.file(slot))
  for _, copy in ipairs(found) do
    if pcall(Save.restore, 'pilgrimage', g, copy.values) then
      return copy.values, copy.sequence, damaged
    end
    renew(g, slot)
    damaged = true
  end
  return nil, 0, damaged
end
-- A way taken up where it was left (owner, D9): the knight stands where he was, with the
-- health, rounds and draughts he had; what he cleared and took since his fire stays so, and
-- what hunted him hunts him still, from where it was. Nothing is refilled: quitting is no
-- rest and no way out of a fight.
local function resumeField(g, field)
  local r, p = g.run, Roles.controlled(g)
  if field.area ~= r.area then
    enter(g, field.area)
  end
  refresh(g, true)
  -- The rounds as the ammunition model packed them (Weapons.inventory) and checked them.
  Weapons.restore(g, nil, field.weapons, p)
  for id, uses in pairs(field.uses) do
    local state = p.abilityState[id]
    if state then
      state.uses = math.min(uses, Abilities.capacity(id, state))
    end
  end
  p.hp = math.min(field.hp, Characters.maxHp(p))
  p.armor = math.min(field.armor, p.maxArmor)
  if not Arena.solid(g.world, field.x, field.z, Rules.radius(p)) then
    p.x, p.z, p.yaw, p.pitch = field.x, field.z, field.yaw, 0
  else
    wake(g, (Way.fireOf(r.fire)))
  end
  if field.weapon and p.loadout[field.weapon] then
    p.weapon = field.weapon
  end
  P.populate(g, field.fallen, field.picked)
  local memory = require('src.content.combat_defaults').senses.memory
  for _, hunter in ipairs(field.hunters) do
    Bodies.eachCreature(g, function(e)
      if e.post == hunter.post and e.hp > 0 then
        e.x, e.z, e.facing = hunter.x, hunter.z, hunter.yaw
        e.hp = math.min(hunter.hp, e.maxHp)
        e.awake, e.memory = true, memory
        e.lastX, e.lastZ, e.lastLevel = p.x, p.z, p.level
      end
    end)
  end
  -- Then the fight exactly as it was, when the field carries it (0.43, audit review: a quit
  -- dropped the missile in the air, the blow begun, the rest of a cache, a drop, a wound).
  PilgrimageSave.resumeFight(g, field)
  if field.pools then
    Roles.controlled(g).sigilRanks = Copy(r.sigils or {})
  end
end
-- Souls left where the map no longer has floor wait where he wakes.
local function reachEcho(g)
  local r, echo = g.run, g.run.echo
  if echo and echo.area == r.area and Arena.solid(g.world, echo.x, echo.z, 0) then
    echo.x, echo.z = wakeAt(Way.fireOf(r.fire))
  end
end
-- options: slot; origin and saves when a journal replays a session, which reads no disk
-- (origin false: it began with no save).
function P.init(g, options)
  options = options or {}
  Encounter.clearWorld(g)
  renew(g, options.slot)
  local data, sequence, damaged = options.origin, options.saves or 0, false
  if data == nil then
    data, sequence, damaged = resume(g, options.slot)
    -- Nothing here can be played: it is set aside, never deleted, and the slot is free.
    if damaged and not data and Execution.canWrite(g) then
      Save.quarantine(P.file(options.slot))
    end
  elseif data then
    Save.restore('pilgrimage', g, data)
  end
  local r = g.run
  r.origin, r.saved = data or false, data and true or false
  r.saves, r.begun = sequence, sequence
  g.availableSave, g.saveRecovered = data or nil, damaged
  local field = r.resume
  r.resume = nil
  if field then
    resumeField(g, field)
    reachEcho(g)
    return
  end
  refresh(g, true)
  reachEcho(g)
  wake(g, (Way.fireOf(r.fire)))
  P.populate(g)
end
function P.start(g)
  g.state = 'playing'
  Presentation.capture(g, true)
  g:notify(Text.get('pilgrim_start'), 5)
end
local function doorHere(g)
  local p, here = Roles.controlled(g), g.run.area
  for _, around in Way.areas:each() do
    for _, door in ipairs(around.doors or {}) do
      if around.id == here and distance(p, door.side) < Way.doorReach then
        return door, true, around
      elseif (door.leads or around.id) == here and distance(p, door.back) < Way.doorReach then
        return door, false, around
      end
    end
  end
end
-- [E] at a door: barred, it opens from its own side, for good; open, the knight goes
-- through to the other side.
local function door(g)
  local found, own, home = doorHere(g)
  if not found then
    return false
  end
  local r = g.run
  if r.opened[found.id] then
    local to = own and found.back or found.side
    enter(g, own and (found.leads or home.id) or home.id)
    local p = Roles.controlled(g)
    p.x, p.z, p.yaw, p.pitch = to.x, to.z, to.yaw, 0
    p.vx, p.vz = 0, 0
    Feel.init(g)
    if found.leads then
      P.populate(g)
      P.save(g)
    end
    Signal(g, 'DoorPassed', { door = found.id })
  elseif own then
    r.opened[found.id] = true
    P.save(g)
    g:notify(Text.get('pilgrim_door_opened'), 3)
    Signal(g, 'DoorOpened', { door = found.id })
  else
    g:notify(Text.get('pilgrim_door_barred'), 2)
  end
  return true
end
-- Something awake hunts the knight near him: no fire takes him in until it gives up or falls
-- (owner, D1). 0.42: only a fight within K.huntReach counts; a crowded map elsewhere does not.
-- 0.43 (audit F02): a missile on its way near him is a fight too, whoever let it go.
-- How far a body's blows reach (its longest attack), once per kind of body.
local reaches = setmetatable({}, { __mode = 'k' })
local function reachOf(e)
  local def = Rules.archetype(e)
  if not reaches[def] then
    local far = 0
    for _, atk in ipairs(def.attacks or {}) do
      far = math.max(far, atk.range or 0)
    end
    reaches[def] = far
  end
  return reaches[def]
end
-- 0.43 (audit review): a body that sees him within the reach of its blows hunts him too (the
-- elites' far blows reach 18 m), and so does a missile near him or the mark of a body still
-- hunting (what a sleeping or dead body left is no fight: a rest clears it, calm).
local function fighting(g)
  local p = Roles.controlled(g)
  if
    Bodies.each(g, function(b)
      if not (b.awake and b.hp > 0) then
        return false
      end
      local d = distance(b, p)
      return d < Way.huntReach or (b.visible and d < reachOf(b))
    end) ~= nil
  then
    return true
  end
  for _, list in ipairs({ { 'projectiles', 'missile' }, { 'hazards', 'hazard' } }) do
    for _, b in ipairs(Pools.of(g, list[1])) do
      local owner = b.owner and Pools.get(g, b.owner)
      if
        Bodies.harms(g, b.side or 'demons', p, list[2])
        and distance(b, p) < Way.huntReach
        and (list[1] == 'projectiles' or (owner and owner.hp > 0 and owner.awake))
      then
        return true
      end
    end
  end
  return false
end
-- What creatures left behind them that can still harm him (pools, marks, missiles) is gone
-- once a fire takes him in, a journey moves him or he wakes from death: a rest is safe
-- (0.43, audit F02: a dead Buer's poison pool burnt a knight who had just rested).
local function calm(g)
  local p = Roles.controlled(g)
  for _, pool in ipairs({ { 'hazards', 'hazard' }, { 'projectiles', 'missile' } }) do
    local list = Pools.of(g, pool[1])
    for i = #list, 1, -1 do
      if Bodies.harms(g, list[i].side or 'demons', p, pool[2]) then
        Pools.removeAt(g, pool[1], i)
      end
    end
  end
end
-- A rest secures what he has done (0.42, the owner and Astra: the chapel no longer stands again
-- at a fire). What lies dead at a post stays dead and what was taken stays taken, for good; a
-- death brings back only what fell or was taken since (run.slain, run.taken).
local function secure(g)
  local r, here, alive, lying = g.run, area(g), {}, {}
  Bodies.eachCreature(g, function(e)
    if e.post and e.hp > 0 then
      alive[e.post] = true
    end
  end)
  for _, pickup in ipairs(Pools.of(g, 'pickups')) do
    if pickup.rewardId then
      lying[pickup.rewardId] = true
    end
  end
  for _, entry in ipairs(here.garrison) do
    r.slain[entry.id] = r.slain[entry.id] or not alive[entry.id] or nil
  end
  for _, cache in ipairs(here.supplies or {}) do
    r.taken[cache.id] = r.taken[cache.id] or not lying[cache.id] or nil
  end
end
P.fighting = fighting
-- A purchase at a fire: a vow holds from this moment, and the fire fills what it added.
function P.bought(g)
  refresh(g)
  return P.save(g)
end
-- [E] at a fire: the knight rests and the fire's menu opens: souls to spend, the road
-- to the other fires.
function P.interact(g)
  local fire = P.fireHere(g)
  if not fire then
    return door(g)
  end
  if fighting(g) then
    g:notify(Text.get('pilgrim_rest_refused'), 3)
    return true
  end
  local r = g.run
  r.fire, r.lit[fire.id] = fire.id, true
  calm(g)
  secure(g)
  -- Small things stand again; what fell of the building stays down.
  Destruction.settle(g.world)
  refresh(g)
  P.save(g)
  g:notify(Text.get('pilgrim_rested', { name = Text.get(fire.name) }), 3)
  Signal(g, 'Rested', { fire = fire.id })
  return Sanctuary.trade(g)
end
-- [ENTER] at a fire, or its menu's button: on to the next one lit.
function P.travel(g)
  local here = P.fireHere(g)
  if not here or fighting(g) then
    return false
  end
  Sanctuary.closeTrade(g)
  local fires, at = Way.fires(), nil
  for index, fire in ipairs(fires) do
    at = fire.id == here.id and index or at
  end
  for step = 1, #fires - 1 do
    local fire = fires[(at + step - 1) % #fires + 1]
    if g.run.lit[fire.id] then
      local _, home = Way.fireOf(fire.id)
      local moved = home.id ~= g.run.area
      calm(g)
      secure(g)
      enter(g, home.id)
      g.run.fire = fire.id
      refresh(g)
      wake(g, fire)
      -- The chapel he leaves stays as he left it; another area is laid as it was secured.
      if moved then
        P.populate(g)
      end
      Feel.init(g)
      P.save(g)
      g:notify(Text.get('pilgrim_rested', { name = Text.get(fire.name) }), 3)
      return true
    end
  end
  return false
end
-- Whether a fire other than this one is lit: travel goes only to fires already found, and
-- is not offered before there is one (owner).
local function elsewhere(g, here)
  for _, fire in ipairs(Way.fires()) do
    if g.run.lit[fire.id] and fire.id ~= here.id then
      return true
    end
  end
  return false
end
function P.context(g)
  local fire = P.fireHere(g)
  if fire then
    local prompt = elsewhere(g, fire) and 'pilgrim_prompt' or 'pilgrim_prompt_alone'
    return Text.get(
      fighting(g) and 'pilgrim_prompt_hunted' or prompt,
      { name = Text.get(fire.name) }
    )
  end
  local found, own = doorHere(g)
  if found then
    return Text.get(
      g.run.opened[found.id] and 'pilgrim_door_pass'
        or (own and 'pilgrim_door_prompt' or 'pilgrim_door_stuck')
    )
  end
  local echo = g.run.echo
  if echo and echo.area == g.run.area and distance(Roles.controlled(g), echo) < Way.reach then
    return Text.get('pilgrim_echo', { amount = echo.amount })
  end
end
-- A death: the souls stay where he fell, in place of any left there before.
function P.lose(g)
  local r, p = g.run, Roles.controlled(g)
  r.deaths = r.deaths + 1
  r.echo = r.wallet > 0 and { amount = r.wallet, x = p.x, z = p.z, area = r.area } or nil
  r.wallet, r.phase = 0, 'defeated'
  g.state = 'dead'
  P.save(g)
end
function P.retry(g)
  local r = g.run
  if r.phase ~= 'defeated' then
    return false
  end
  r.phase = 'journey'
  g.state, g.map, g.help = 'playing', false, false
  -- He wakes at his fire, on its area's map, wherever he fell; what fell where he died stays.
  local fire, home = Way.fireOf(r.fire)
  enter(g, home.id)
  calm(g)
  refresh(g)
  wake(g, fire)
  P.populate(g)
  Presentation.capture(g, true)
  return true
end
-- A kill changes the wallet but is no reason to stop the game for the disk: it is saved at
-- the next quiet moment, a durable event or the moment the game stops (P.flush).
function P.reward(g, event)
  local r = g.run
  event.souls = (Archetypes.of(event.enemy).souls or 0) * Way.souls
  r.wallet, r.dirty = r.wallet + event.souls, true
end
-- The knight is in the area he stands in (PLAN G4): crossing into another of
-- the same map is a step, not a journey. A body of an area he is not in sleeps
-- unless it already hunts him.
function P.wake(g)
  local r = g.run
  Bodies.eachCreature(g, function(e)
    e.dormant = (e.homeArea ~= nil and e.homeArea ~= r.area and not e.awake) or nil
  end)
end
function P.update(g, dt)
  local r = g.run
  if r.phase ~= 'journey' or g.state ~= 'playing' then
    return
  end
  local p = Roles.controlled(g)
  local here = Way.areaAt(g.world.mapId, p.x, p.z)
  if here and here.id ~= r.area then
    r.area = here.id
    Signal(g, 'AreaEntered', { area = here.id })
  end
  P.wake(g)
  r.moved = true
  local echo = r.echo
  if echo and echo.area == r.area and distance(Roles.controlled(g), echo) < Way.echoReach then
    r.wallet, r.echo = r.wallet + echo.amount, nil
    g:notify(Text.get('pilgrim_recovered', { amount = echo.amount }), 3)
    Signal(g, 'EchoRecovered', { amount = echo.amount })
    P.save(g)
  end
  if r.dirty then
    r.waited = r.waited + dt
    if r.waited >= Way.saveEvery and not fighting(g) then
      P.save(g)
    end
  end
end
-- What the world shows of the way: the fires beyond the first, which is the Ember.
function P.world(g, out)
  out.fires = out.fires or {}
  for i = #out.fires, 1, -1 do
    out.fires[i] = nil
  end
  local here = area(g)
  for _, fire in ipairs(here.fires) do
    if fire.id ~= here.first then
      out.fires[#out.fires + 1] = fire
    end
  end
  out.shrineActive = true
  out.doors = out.doors or {}
  local count = 0
  local function show(door, side)
    count = count + 1
    local mark = out.doors[count] or {}
    out.doors[count] = mark
    mark.x, mark.z, mark.yaw = side.art.x, side.art.z, side.art.yaw
    mark.art = g.run.opened[door.id] and 'chapel_door_open' or 'chapel_door_barred'
  end
  for _, around in Way.areas:each() do
    for _, door in ipairs(around.doors or {}) do
      if around == here then
        show(door, door.side)
      end
      if (door.leads or around.id) == here.id then
        show(door, door.back)
      end
    end
  end
  for i = #out.doors, count + 1, -1 do
    out.doors[i] = nil
  end
  return out
end
-- Everywhere a knight can walk from the area's first fire, doors counted as open: a cell
-- leads to the next if it is free and no more than a step below it. Tiles centre on whole
-- numbers.
local function reachable(world, area)
  local reached, queue, doors = {}, {}, {}
  local function round(v)
    return math.floor(v + 0.5)
  end
  local function key(x, z)
    return round(z) .. ':' .. round(x)
  end
  local function visit(x, z)
    x, z = round(x), round(z)
    if not reached[key(x, z)] then
      reached[key(x, z)] = true
      queue[#queue + 1] = { x, z }
    end
  end
  for _, door in ipairs(area.doors or {}) do
    if not door.leads then
      doors[key(door.side.x, door.side.z)] = door.back
      doors[key(door.back.x, door.back.z)] = door.side
    end
  end
  local first = Way.fireOf(area.first)
  visit(first.x, first.z)
  local at = 1
  while queue[at] do
    local x, z = queue[at][1], queue[at][2]
    at = at + 1
    local through = doors[key(x, z)]
    if through then
      visit(through.x, through.z)
    end
    local height = Ground.height(world, x, z, 0)
    for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nx, nz = x + step[1], z + step[2]
      local rise = Ground.height(world, nx, nz, 0) - height
      if not Arena.solid(world, nx, nz, Way.clearance) and rise <= world.stepHeight then
        visit(nx, nz)
      end
    end
  end
  return function(x, z)
    return reached[key(x, z)]
  end
end
-- What is wrong with an area against its map: a fire, a door, a post or a patrol in a wall or
-- out of reach, a creature that does not exist. A new area answers this before it is played.
function P.problems(area)
  local found = {}
  if not Maps:has(area.map) then
    return { area.id .. ': no map ' .. tostring(area.map) }
  end
  local world = Arena.new(area.map)
  local reached = reachable(world, area)
  local function stand(name, spot)
    if Arena.solid(world, spot.x, spot.z, Way.clearance) then
      found[#found + 1] = area.id .. ': ' .. name .. ' stands in a wall'
    elseif not reached(spot.x, spot.z) then
      found[#found + 1] = area.id .. ': ' .. name .. ' cannot be reached'
    end
  end
  for _, fire in ipairs(area.fires) do
    stand('fire ' .. fire.id, fire)
    local x, z = wakeAt(fire)
    stand('the wake of fire ' .. fire.id, { x = x, z = z })
  end
  for _, door in ipairs(area.doors or {}) do
    stand('door ' .. door.id, door.side)
    if not door.leads then
      stand('the back of door ' .. door.id, door.back)
    end
  end
  for _, around in Way.areas:each() do
    for _, door in ipairs(around.doors or {}) do
      if door.leads == area.id then
        stand('the far side of door ' .. door.id, door.back)
      end
    end
  end
  for _, cache in ipairs(area.supplies or {}) do
    stand('supply ' .. cache.id, cache)
    local kind = cache.kind or 'ammo'
    if not Interactions.supplies[kind] then
      found[#found + 1] = area.id .. ': supply ' .. cache.id .. ' is of no known kind'
    elseif kind == 'ammo' and not Weapons.has(cache.weapon) then
      found[#found + 1] = area.id .. ': supply ' .. cache.id .. ' names no weapon'
    elseif kind == 'relic' and not (Shop.find(cache.offer) and Shop.find(cache.offer).found) then
      found[#found + 1] = area.id .. ': relic ' .. cache.id .. ' names nothing to be found'
    end
  end
  for _, post in ipairs(area.garrison) do
    stand('post ' .. post.id, post)
    for index, point in ipairs(post.patrol or {}) do
      stand('patrol ' .. index .. ' of post ' .. post.id, point)
    end
    if not Archetypes.get(post.creature) then
      found[#found + 1] = area.id .. ': post ' .. post.id .. ' names no creature'
    end
  end
  return found
end
-- Who stands in this area, for the loading page.
function P.creatures(g)
  local ids, seen = {}, {}
  for _, post in ipairs(area(g).garrison) do
    if not seen[post.creature] then
      seen[post.creature] = true
      ids[#ids + 1] = post.creature
    end
  end
  return ids
end
local report = {}
function P.hud(g)
  local r = g.run
  -- worn: each gun's own engraving, so the bar names the one on the gun in hand (0.43, F07).
  report.glyph, report.wallet, report.echo, report.worn = r.glyph, r.wallet, r.echo, r.worn
  report.progress = Text.get('pilgrim_progress', { deaths = r.deaths })
  return report
end
PilgrimageSave.declare({ area = area, stand = stand })
return P

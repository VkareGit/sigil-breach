-- The way: fires, area by area. The world stands where the map
-- puts it; a rest heals the knight, fills his flask and rounds, sets where he wakes,
-- and raises every creature. Dying leaves the souls where the knight fell; dying again
-- before reaching them loses them.
local Abilities = require('src.content.abilities')
local Characters = require('src.content.characters')
local Destruction = require('src.combat.destruction')
local Encounter = require('src.session.encounter')
local Execution = require('src.storage.execution')
local Feel = require('src.player.feel')
local Ground = require('src.physics.ground')
local K = require('src.content.pilgrimage')
local MathX = require('src.core.mathx')
local Presentation = require('src.session.presentation')
local Roles = require('src.core.roles')
local Rules = require('src.combat.rules')
local Sanctuary = require('src.session.sanctuary')
local Save = require('src.storage.save')
local Text = require('src.content.text')
local Weapons = require('src.content.weapons')
local Archetypes = require('src.content.enemies')
local Bodies = require('src.combat.bodies')
local Maps = require('src.content.maps.index')
local Shop = require('src.content.shop')
local Copy = require('src.core.schema').copy
local World = require('src.world.arena')
local P = {}
local distance = MathX.distance
-- The file of a save slot; the first keeps the name every earlier version wrote.
function P.file(slot)
  return (slot or 1) == 1 and 'pilgrimage.save' or ('pilgrimage-' .. slot .. '.save')
end
local function area(g)
  return K.areas:get(g.run.area)
end
-- The fire the knight stands at, if any.
function P.fireHere(g)
  local p = Roles.controlled(g)
  for _, fire in ipairs(area(g).fires) do
    if distance(p, fire) < K.reach then
      return fire
    end
  end
end
local function place(g, entry)
  local e = g:spawn(entry.creature, entry.x, entry.z)
  e.home, e.leash, e.alertRange = { x = entry.x, z = entry.z }, entry.leash or K.leash, entry.alert
  e.facing, e.spawnAge, e.awake = entry.yaw, 2, false
  e.patrol, e.post = entry.patrol, entry.id
  return e
end
-- The world as a rest leaves it: every creature at its post.
function P.populate(g)
  Encounter.clearStage(g)
  -- Small things stand again; what fell of the building stays down.
  Destruction.settle(g.world)
  local classes = {}
  for _, entry in ipairs(area(g).garrison) do
    local e = place(g, entry)
    classes[World.class(Rules.radius(e), Rules.tall(g, e))] = e
  end
  -- The first route of a body's size walks the whole map: here, not in the first chase.
  for class, e in pairs(classes) do
    World.flow(g.world, e.x, e.z, class)
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
    elseif offer.kind == 'vow' and p.abilityState[offer.ability] then
      p.abilityState[offer.ability].extra = given
    end
  end
  p.maxHp, p.maxArmor = stats.maxHp, stats.maxArmor
end
local function refresh(g)
  swear(g)
  local p = Roles.controlled(g)
  p.hp, p.armor = Characters.maxHp(p), p.maxArmor
  p.dash = Characters.of(p).body.dashCharges
  p.rally, p.rallyLeft, p.conditions = nil, nil, nil
  Characters.rest(p)
  Abilities.fill(g, nil, p)
  Abilities.rest(g, p)
  Weapons.fill(g, p)
  Weapons.rest(g)
  p.reload, p.cooldown, p.invuln = 0, 0, 0
end
local function wake(g, fire)
  local p = Roles.controlled(g)
  p.x, p.z, p.pitch = fire.x, fire.z - K.wake, 0
  p.yaw = math.pi
  p.jump, p.jumpV, p.dashTimer = 0, 0, 0
end
function P.save(g)
  local r = g.run
  r.saves, r.dirty, r.waited = r.saves + 1, false, 0
  local text = Save.encode('pilgrimage', Save.capture('pilgrimage', g), r.saves)
  local reason = Execution.effect(g, 'pilgrimage.save', function()
    local ok, problem = Save.write(P.file(r.slot), text)
    return not ok and problem or nil
  end)
  g.saveWarning = reason
  return reason == nil
end
-- What a kill left unsaved goes to disk now: the game stopped, or is about to.
function P.flush(g)
  return g.run.dirty and P.save(g)
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
    g.world = World.new(map)
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
  local first = K.start().first
  g.run = {
    phase = 'journey',
    wallet = 0,
    glyph = 'none',
    owned = {},
    deaths = 0,
    slot = slot or 1,
    market = 'fire',
    vows = {},
    area = K.first,
    fire = first,
    lit = { [first] = true },
    opened = {},
    ruins = {},
    dirty = false,
    waited = 0,
  }
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
-- Souls left where the map no longer has floor wait where he wakes.
local function reachEcho(g)
  local r, echo = g.run, g.run.echo
  if echo and echo.area == r.area and World.solid(g.world, echo.x, echo.z, 0) then
    local fire = K.fireOf(r.fire)
    echo.x, echo.z = fire.x, fire.z - K.wake
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
  refresh(g)
  reachEcho(g)
  wake(g, (K.fireOf(r.fire)))
  P.populate(g)
end
function P.start(g)
  g.state = 'playing'
  Presentation.capture(g, true)
  g:notify(Text.get('pilgrim_start'), 5)
end
local function doorHere(g)
  local p, here = Roles.controlled(g), g.run.area
  for _, around in K.areas:each() do
    for _, door in ipairs(around.doors or {}) do
      if around.id == here and distance(p, door.side) < K.doorReach then
        return door, true, around
      elseif (door.leads or around.id) == here and distance(p, door.back) < K.doorReach then
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
    Presentation.cue(g, 'seal', 0.5)
  elseif own then
    r.opened[found.id] = true
    P.save(g)
    g:notify(Text.get('pilgrim_door_opened'), 3)
    Presentation.cue(g, 'seal', 0.5)
  else
    g:notify(Text.get('pilgrim_door_barred'), 2)
  end
  return true
end
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
  local r = g.run
  r.fire, r.lit[fire.id] = fire.id, true
  refresh(g)
  P.populate(g)
  P.save(g)
  g:notify(Text.get('pilgrim_rested', { name = Text.get(fire.name) }), 3)
  Presentation.cue(g, 'seal', 0.5)
  return Sanctuary.trade(g)
end
-- [ENTER] at a fire, or its menu's button: on to the next one lit.
function P.travel(g)
  local here = P.fireHere(g)
  if not here then
    return false
  end
  Sanctuary.closeTrade(g)
  local fires, at = K.fires(), nil
  for index, fire in ipairs(fires) do
    at = fire.id == here.id and index or at
  end
  for step = 1, #fires - 1 do
    local fire = fires[(at + step - 1) % #fires + 1]
    if g.run.lit[fire.id] then
      local _, home = K.fireOf(fire.id)
      enter(g, home.id)
      g.run.fire = fire.id
      refresh(g)
      wake(g, fire)
      P.populate(g)
      Feel.init(g)
      P.save(g)
      g:notify(Text.get('pilgrim_rested', { name = Text.get(fire.name) }), 3)
      return true
    end
  end
  return false
end
function P.context(g)
  local fire = P.fireHere(g)
  if fire then
    return Text.get('pilgrim_prompt', { name = Text.get(fire.name) })
  end
  local found, own = doorHere(g)
  if found then
    return Text.get(
      g.run.opened[found.id] and 'pilgrim_door_pass'
        or (own and 'pilgrim_door_prompt' or 'pilgrim_door_stuck')
    )
  end
  local echo = g.run.echo
  if echo and echo.area == g.run.area and distance(Roles.controlled(g), echo) < K.reach then
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
  refresh(g)
  wake(g, (K.fireOf(r.fire)))
  P.populate(g)
  Presentation.capture(g, true)
  return true
end
-- A kill changes the wallet but is no reason to stop the game for the disk: it is saved at
-- the next quiet moment, a durable event or the moment the game stops (P.flush).
function P.reward(g, event)
  local r = g.run
  r.wallet, r.dirty = r.wallet + (Archetypes.of(event.enemy).souls or 0) * K.souls, true
end
local function fighting(g)
  return Bodies.each(g, function(b)
    return b.awake
  end) ~= nil
end
function P.update(g, dt)
  local r = g.run
  if r.phase ~= 'journey' or g.state ~= 'playing' then
    return
  end
  local echo = r.echo
  if echo and echo.area == r.area and distance(Roles.controlled(g), echo) < K.echoReach then
    r.wallet, r.echo = r.wallet + echo.amount, nil
    g:notify(Text.get('pilgrim_recovered', { amount = echo.amount }), 3)
    Presentation.cue(g, 'seal', 0.5)
    P.save(g)
  end
  if r.dirty then
    r.waited = r.waited + dt
    if r.waited >= K.saveEvery and not fighting(g) then
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
  for _, around in K.areas:each() do
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
  local first = K.fireOf(area.first)
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
      if not World.solid(world, nx, nz, K.clearance) and rise <= world.stepHeight then
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
  local world = World.new(area.map)
  local reached = reachable(world, area)
  local function stand(name, spot)
    if World.solid(world, spot.x, spot.z, K.clearance) then
      found[#found + 1] = area.id .. ': ' .. name .. ' stands in a wall'
    elseif not reached(spot.x, spot.z) then
      found[#found + 1] = area.id .. ': ' .. name .. ' cannot be reached'
    end
  end
  for _, fire in ipairs(area.fires) do
    stand('fire ' .. fire.id, fire)
    stand('the wake of fire ' .. fire.id, { x = fire.x, z = fire.z - K.wake })
  end
  for _, door in ipairs(area.doors or {}) do
    stand('door ' .. door.id, door.side)
    if not door.leads then
      stand('the back of door ' .. door.id, door.back)
    end
  end
  for _, around in K.areas:each() do
    for _, door in ipairs(around.doors or {}) do
      if door.leads == area.id then
        stand('the far side of door ' .. door.id, door.back)
      end
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
  report.glyph, report.wallet, report.echo = r.glyph, r.wallet, r.echo
  report.progress = Text.get('pilgrim_progress', { deaths = r.deaths })
  return report
end
local function whole(value, low, high)
  return type(value) == 'number'
    and MathX.finite(value)
    and value == math.floor(value)
    and value >= low
    and value <= high
end
-- The ids of a set that the game still has; an id content dropped goes with it.
local function known(set, exists)
  assert(type(set) == 'table', 'invalid set of ids')
  local kept = {}
  for id, value in pairs(set) do
    assert(type(id) == 'string' and value == true, 'invalid entry of a set of ids')
    if exists(id) then
      kept[id] = true
    end
  end
  return kept
end
local function validEcho(echo, home)
  if echo == nil then
    return nil
  end
  assert(type(echo) == 'table', 'invalid echo')
  assert(whole(echo.amount, 1, Shop.maxWallet), 'invalid echo amount')
  assert(MathX.finite(echo.x) and MathX.finite(echo.z), 'invalid echo position')
  return {
    amount = echo.amount,
    x = echo.x,
    z = echo.z,
    area = K.areas:has(echo.area) and echo.area or home,
  }
end
-- The ids of a list that the game still has, in order, once each.
local function listed(list, exists)
  assert(type(list) == 'table', 'invalid list of ids')
  local kept, seen = {}, {}
  for _, id in ipairs(list) do
    assert(type(id) == 'string', 'invalid entry of a list of ids')
    if exists(id) and not seen[id] then
      seen[id] = true
      kept[#kept + 1] = id
    end
  end
  return kept
end
local function validVows(vows)
  assert(type(vows) == 'table', 'invalid vows')
  local kept = {}
  for id, rank in pairs(vows) do
    assert(type(id) == 'string' and whole(rank, 1, math.huge), 'invalid vow')
    local offer = Shop.find(id)
    if offer and offer.kind == 'vow' then
      kept[id] = math.min(rank, offer.limit)
    end
  end
  return kept
end
local function validRuins(ruins)
  assert(type(ruins) == 'table', 'invalid ruins')
  local kept = {}
  for mapId, states in pairs(ruins) do
    assert(type(mapId) == 'string' and type(states) == 'table', 'invalid ruin')
    if Maps:has(mapId) then
      kept[mapId] = Destruction.clean(mapId, states)
    end
  end
  return kept
end
Save.declare({
  name = 'pilgrimage',
  file = 'pilgrimage',
  version = 2,
  migrations = {
    -- One area, one map, one ruin.
    [1] = function(data)
      data.ruins, data.ruin = { proving = data.ruin }, nil
      if data.echo then
        data.echo.area = K.first
      end
      return data
    end,
  },
  pack = function(g)
    local r = g.run
    local ruins = Copy(r.ruins)
    ruins[g.world.mapId] = g.world.destruction or {}
    return {
      wallet = r.wallet,
      deaths = r.deaths,
      fire = r.fire,
      lit = r.lit,
      echo = r.echo,
      owned = r.owned,
      glyph = r.glyph,
      opened = r.opened,
      ruins = ruins,
      vows = r.vows,
      loadout = (Weapons.inventory(g, Roles.controlled(g))),
      abilities = select(2, Abilities.inventory(g, Roles.controlled(g))),
    }
  end,
  -- A file is judged here, before it touches a session: a wrong type refuses the whole of
  -- it, and what names content that is gone is dropped, so a save outlives a content change.
  unpack = function(data)
    assert(type(data) == 'table', 'invalid way')
    assert(whole(data.wallet, 0, Shop.maxWallet), 'invalid wallet')
    assert(whole(data.deaths, 0, math.huge), 'invalid deaths')
    assert(type(data.fire) == 'string', 'invalid fire')
    assert(type(data.glyph) == 'string', 'invalid engraving')
    local fire, home = K.fireOf(data.fire)
    if not fire then
      home = K.start()
      fire = K.fireOf(home.first)
    end
    local out = {
      wallet = data.wallet,
      deaths = data.deaths,
      area = home.id,
      fire = fire.id,
      lit = known(data.lit, K.fireOf),
      owned = known(data.owned, Shop.find),
      opened = known(data.opened, K.doorOf),
      ruins = validRuins(data.ruins),
      echo = validEcho(data.echo, home.id),
      vows = validVows(data.vows or {}),
      loadout = listed(data.loadout or {}, Weapons.has),
      abilities = listed(data.abilities or {}, function(id)
        return Abilities:has(id)
      end),
    }
    out.lit[fire.id] = true
    out.glyph = out.owned[data.glyph] and data.glyph or 'none'
    return out
  end,
  restore = function(g, data)
    local r = g.run
    r.wallet, r.deaths, r.area, r.fire = data.wallet, data.deaths, data.area, data.fire
    r.lit, r.owned, r.glyph = Copy(data.lit), Copy(data.owned), data.glyph
    r.opened, r.ruins, r.echo = Copy(data.opened), Copy(data.ruins), Copy(data.echo)
    r.vows = Copy(data.vows)
    stand(g)
    -- The kit last: nothing above can leave it half changed. A way with no kit of its own
    -- keeps the knight's.
    local p = Roles.controlled(g)
    if data.loadout[1] then
      Weapons.restore(g, data.loadout, nil, p)
    end
    if data.abilities[1] then
      Abilities.restore(g, nil, data.abilities, p)
      Abilities.give(g, 'flask', p)
    end
  end,
})
return P

-- The way through the chapel: fires. The world stands where the map
-- puts it; a rest heals the knight, fills his flask and rounds, sets where he wakes,
-- and raises every creature. Dying leaves the souls where the knight fell; dying again
-- before reaching them loses them.
local Abilities = require('src.content.abilities')
local Characters = require('src.content.characters')
local Destruction = require('src.combat.destruction')
local Encounter = require('src.session.encounter')
local Execution = require('src.storage.execution')
local Feel = require('src.player.feel')
local K = require('src.content.pilgrimage')
local MathX = require('src.core.mathx')
local Presentation = require('src.session.presentation')
local Roles = require('src.core.roles')
local Sanctuary = require('src.session.sanctuary')
local Save = require('src.storage.save')
local Text = require('src.content.text')
local Weapons = require('src.content.weapons')
local Archetypes = require('src.content.enemies')
local P = {}
local FILE = 'pilgrimage.save'
local distance = MathX.distance
local function fireOf(id)
  for _, fire in ipairs(K.fires) do
    if fire.id == id then
      return fire
    end
  end
end
-- The fire the knight stands at, if any.
function P.fireHere(g)
  local p = Roles.controlled(g)
  for _, fire in ipairs(K.fires) do
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
  for _, entry in ipairs(K.garrison) do
    place(g, entry)
  end
end
local function refresh(g)
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
  r.saves = r.saves + 1
  local text = Save.encode('pilgrimage', Save.capture('pilgrimage', g), r.saves)
  local reason = Execution.effect(g, 'pilgrimage.save', function()
    local ok, problem = Save.write(FILE, text)
    return not ok and problem or nil
  end)
  g.saveWarning = reason
  return reason == nil
end
-- A new way: the old one is gone, every copy of it.
function P.forget()
  for _, name in ipairs({ FILE, FILE .. '.tmp', FILE .. '.previous' }) do
    love.filesystem.remove(name)
  end
end
function P.construction(g)
  return { origin = g.run.origin }
end
function P.init(g, options)
  Encounter.clearWorld(g)
  g.run = {
    phase = 'journey',
    wallet = 0,
    glyph = 'none',
    owned = {},
    claimed = {},
    pending = {},
    deaths = 0,
    fragment = false,
    fire = K.first,
    lit = { [K.first] = true },
    opened = {},
  }
  Abilities.give(g, 'flask', Roles.controlled(g))
  -- A journal replays the way as it was when the session began.
  local data, sequence, damaged = options and options.origin, 0, false
  if not data then
    data, sequence, damaged = Save.read('pilgrimage', FILE)
  end
  g.run.origin, g.run.saves, g.run.saved = data, sequence, data ~= nil
  g.availableSave, g.saveRecovered = data, damaged
  if data then
    Save.restore('pilgrimage', g, data)
  end
  refresh(g)
  wake(g, fireOf(g.run.fire))
  P.populate(g)
end
function P.start(g)
  g.state = 'playing'
  Presentation.capture(g, true)
  g:notify(Text.get('pilgrim_start'), 5)
end
local function doorHere(g)
  local p = Roles.controlled(g)
  for _, door in ipairs(K.doors) do
    if distance(p, door.side) < K.doorReach then
      return door, true
    elseif distance(p, door.back) < K.doorReach then
      return door, false
    end
  end
end
-- [E] at a door: barred, it opens from its own side, for good; open, the knight goes
-- through to the other side.
local function door(g)
  local found, own = doorHere(g)
  if not found then
    return false
  end
  local r = g.run
  if r.opened[found.id] then
    local to = own and found.back or found.side
    local p = Roles.controlled(g)
    p.x, p.z, p.yaw, p.pitch = to.x, to.z, to.yaw, 0
    p.vx, p.vz = 0, 0
    Feel.init(g)
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
  local at
  for index, fire in ipairs(K.fires) do
    at = fire.id == here.id and index or at
  end
  for step = 1, #K.fires - 1 do
    local fire = K.fires[(at + step - 1) % #K.fires + 1]
    if g.run.lit[fire.id] then
      g.run.fire = fire.id
      refresh(g)
      wake(g, fire)
      P.populate(g)
      Feel.init(g)
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
  if echo and distance(Roles.controlled(g), echo) < K.reach then
    return Text.get('pilgrim_echo', { amount = echo.amount })
  end
end
-- A death: the souls stay where he fell, in place of any left there before.
function P.lose(g)
  local r, p = g.run, Roles.controlled(g)
  r.deaths = r.deaths + 1
  r.echo = r.wallet > 0 and { amount = r.wallet, x = p.x, z = p.z } or nil
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
  wake(g, fireOf(r.fire))
  P.populate(g)
  Presentation.capture(g, true)
  return true
end
function P.reward(g, event)
  g.run.wallet = g.run.wallet + (Archetypes.of(event.enemy).souls or 0) * K.souls
  P.save(g)
end
function P.update(g)
  local r = g.run
  if r.phase ~= 'journey' or g.state ~= 'playing' then
    return
  end
  local echo = r.echo
  if echo and distance(Roles.controlled(g), echo) < K.echoReach then
    r.wallet, r.echo = r.wallet + echo.amount, nil
    g:notify(Text.get('pilgrim_recovered', { amount = echo.amount }), 3)
    Presentation.cue(g, 'seal', 0.5)
  end
end
-- What the world shows of the way: the fires beyond the first, which is the Ember.
function P.world(g, out)
  out.fires = out.fires or {}
  for i = #out.fires, 1, -1 do
    out.fires[i] = nil
  end
  for _, fire in ipairs(K.fires) do
    if fire.id ~= K.first then
      out.fires[#out.fires + 1] = fire
    end
  end
  out.shrineActive = true
  out.doors = out.doors or {}
  local count = 0
  for _, door in ipairs(K.doors) do
    local art = g.run.opened[door.id] and 'chapel_door_open' or 'chapel_door_barred'
    for _, side in ipairs({ door.side, door.back }) do
      count = count + 1
      local mark = out.doors[count] or {}
      out.doors[count] = mark
      mark.x, mark.z, mark.yaw, mark.art = side.art.x, side.art.z, side.art.yaw, art
    end
  end
  return out
end
local report = {}
function P.hud(g)
  local r = g.run
  report.glyph, report.wallet, report.echo = r.glyph, r.wallet, r.echo
  report.progress = Text.get('pilgrim_progress', { deaths = r.deaths })
  return report
end
Save.declare({
  name = 'pilgrimage',
  file = 'pilgrimage',
  version = 1,
  pack = function(g)
    local r = g.run
    return {
      wallet = r.wallet,
      deaths = r.deaths,
      fire = r.fire,
      lit = r.lit,
      echo = r.echo,
      owned = r.owned,
      glyph = r.glyph,
      opened = r.opened,
      ruin = g.world.destruction or {},
    }
  end,
  unpack = function(data)
    assert(type(data.fire) == 'string' and fireOf(data.fire), 'unknown fire')
    return data
  end,
  restore = function(g, data)
    local r = g.run
    r.wallet, r.deaths, r.fire = data.wallet, data.deaths, data.fire
    r.lit, r.echo = data.lit, data.echo
    r.owned, r.glyph, r.opened = data.owned, data.glyph, data.opened
    Destruction.restore(g.world, data.ruin)
  end,
})
return P

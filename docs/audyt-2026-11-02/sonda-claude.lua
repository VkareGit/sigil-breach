require('src.run.modes')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local Weapons = require('src.content.weapons')
local Ballistics = require('src.combat.ballistics')
local Rules = require('src.combat.rules')
local Bot = require('qa.souls_bot')
local T = {}
local ORDER = { { 'sanctuary', 24, 10.5 }, { 'west', 10, 22 }, { 'east', 38, 22 } }
local function goal(g)
  for _, stop in ipairs(ORDER) do
    if not g.run.lit[stop[1]] then
      return stop[2], stop[3], stop[1]
    end
  end
end
local function setup(Game, post)
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  g.state = 'playing'
  local foe
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.post == post then
      foe = e
    else
      e.x, e.z, e.dummy, e.alertRange = 24, 39, true, 0
    end
  end
  foe.dummy = true
  return g, foe
end
-- All the rounds of one weapon at one height of the body.
local function volley(Game, post, id, height)
  local g, foe = setup(Game, post)
  local p = g.player
  local slot = Weapons.slotOf(g, id, p)
  p.weapon = slot
  local start, shots = foe.hp, 0
  for _ = 1, 120 * 120 do
    local mag, reserve = Weapons.meter(g, slot, p)
    if foe.hp <= 0 or mag + reserve == 0 then
      break
    end
    foe.dummy = true
    p.hp, p.armor = 100, 40
    p.x, p.z = foe.x, foe.z + 3.5
    local _, eye = Ballistics.origin(g)
    p.yaw, p.pitch = math.pi, math.atan2(height - eye, 3.5)
    local before = p.shots
    g:update(1 / 120, { shoot = mag > 0 })
    if mag == 0 then
      g:reloadGun()
    end
    shots = shots + (p.shots - before)
  end
  P.forget()
  return start - foe.hp, shots
end
local function bestHeight(Game, post, label)
  local g, foe = setup(Game, post)
  local aim = Rules.body(foe).aimY
  P.forget()
  local top, at = 0, 0
  for _, k in ipairs({ 0.5, 0.8, 1, 1.25, 1.5, 1.75, 2, 2.3, 2.6 }) do
    local done = volley(Game, post, 'judge', aim * k)
    print(string.format('MEASURE %s judge height %.2f m (aimY x %.2f): %.0f damage', label, aim * k, k, done))
    if done > top then
      top, at = done, aim * k
    end
  end
  local shells = volley(Game, post, 'exorcist', at)
  print(string.format('MEASURE %s best height %.2f: judge %.0f + exorcist %.0f = %.0f of %.0f', label, at, top, shells, top + shells, foe.maxHp or foe.hp))
end
local function powder(Game, post, label)
  local g, foe = setup(Game, post)
  local p = g.player
  p.x, p.z, p.yaw = foe.x, foe.z + 4, math.pi
  local start = foe.hp
  for _ = 1, 3 do
    g:cast(1)
    for _ = 1, 120 * 3 do
      foe.dummy = true
      p.hp, p.armor = 100, 40
      g:update(1 / 120, {})
    end
  end
  print(string.format('MEASURE %s three powder charges: %.0f damage', label, start - foe.hp))
  P.forget()
end
local function refusals(Game, miss, seed)
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g.rng.sim:seed(seed)
  math.randomseed(seed * 13 + 1)
  g:act('start')
  g.state = 'playing'
  local bot = Bot.walker(Bot.human(miss, math.random))
  local memory, seen, prev, dodges = {}, {}, 0, 0
  local stamMin = 100
  local lastDash = 0
  for t = 1, 6 * 60 * 120 do
    if g.state == 'dead' then
      g:act('retry')
      memory = {}
    end
    if g.state == 'shop' then
      g:act('closeShop')
    end
    local x, z = goal(g)
    if not x then
      break
    end
    if math.abs(g.player.x - x) + math.abs(g.player.z - z) < 2 and P.fireHere(g) then
      g:interact()
      if g.state == 'shop' then
        g:act('closeShop')
      end
    end
    g:update(1 / 120, bot(g, memory, x, z))
    local left = g.view.refusalTimer or 0
    if left > prev and g.view.refusal then
      seen[g.view.refusal] = (seen[g.view.refusal] or 0) + 1
    end
    prev = left
    local timer = g.player.dashTimer or 0
    if timer > 0 and lastDash == 0 then
      dodges = dodges + 1
    end
    lastDash = timer
    stamMin = math.min(stamMin, g.player.resources.stamina or 100)
  end
  local parts = {}
  for k, v in pairs(seen) do
    parts[#parts + 1] = k .. '=' .. v
  end
  print(string.format('MEASURE refusals miss %.1f seed %d dodges %d lowest stamina %.0f [%s]', miss, seed, dodges, stamMin, table.concat(parts, ' ')))
  P.forget()
end
function T.run(Game)
  bestHeight(Game, 'west_hall', 'margrave')
  bestHeight(Game, 'east_hall', 'furfur')
  powder(Game, 'west_hall', 'margrave')
  refusals(Game, 0, 1)
  refusals(Game, 0.1, 2)
  return {}
end
return T

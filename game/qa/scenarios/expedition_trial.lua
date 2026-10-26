-- The expedition trial (plan v11 E0): a deterministic expedition that is
-- saved and loaded on the way, the second half of the state projection's
-- reference beside the golden scenarios. A scripted knight clears the first
-- wave, the checkpoint is written and read into a new session (the menu's
-- CONTINUE: run/modes 'load'), the loaded session fights the next wave,
-- falls (the defeat checkpoint with its echo) and is loaded once more.
-- Saves never touch a file (g.testing): their texts are kept in the result,
-- the SIGIL09 fixtures of 0.33 (tests/fixtures/v033/).
local W = require('src.world.arena')
local B = require('src.combat.ballistics')
local Grid = require('src.physics.grid')
local Modes = require('src.run.modes')
local Run = require('src.run.descent')
local RunSave = require('src.storage.run_save')
local Sanctuary = require('src.session.sanctuary')
local S = { rate = 120 }
-- A plain knight: aim at the nearest living demon, close in along the flow
-- field, keep 4-6 m, fire every third step, dash out of a late wind-up. With
-- no demon left it walks to goal (x, z), when it has one.
local function brain(goal)
  local field, fx, fz, age = nil, nil, nil, 0
  local function along(g, x, z)
    local p = g.player
    local tx, tz = math.floor(x + 0.5), math.floor(z + 0.5)
    if not field or tx ~= fx or tz ~= fz or age > 0.5 then
      field, fx, fz, age = W.flow(g.world, x, z), tx, tz, 0
    end
    local cx, cz = math.floor(p.x + 0.5), math.floor(p.z + 0.5)
    local bx, bz, low = cx, cz, 1e9
    for _, o in ipairs({ { 0, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 } }) do
      local d = field[Grid.key(g.world, cx + o[1], cz + o[2])]
      if d and d < low and not W.solid(g.world, cx + o[1], cz + o[2], 0.22) then
        bx, bz, low = cx + o[1], cz + o[2], d
      end
    end
    if bx == cx and bz == cz then
      return x - p.x, z - p.z
    end
    return bx - p.x, bz - p.z
  end
  local function steer(p, input, dx, dz)
    local len = math.sqrt(dx * dx + dz * dz)
    if len > 1 then
      dx, dz = dx / len, dz / len
    end
    input.forward = dx * math.sin(p.yaw) + dz * math.cos(p.yaw)
    input.strafe = dx * math.cos(p.yaw) - dz * math.sin(p.yaw)
  end
  return function(g, tick)
    local p = g.player
    local target, best = nil, 1e9
    for _, e in ipairs(g.enemies) do
      if e.hp > 0 then
        local d = math.sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2)
        if d < best then
          target, best = e, d
        end
      end
    end
    local input = {}
    age = age + 1 / S.rate
    if target then
      p.yaw = math.atan2(target.x - p.x, target.z - p.z)
      local _, eye = B.origin(g)
      p.pitch = math.atan2(1.35 - eye, best)
      local dx, dz = 0, 0
      if best > 6 then
        dx, dz = along(g, target.x, target.z)
      elseif best < 4 then
        dx, dz = p.x - target.x, p.z - target.z
      end
      steer(p, input, dx, dz)
      input.shoot = W.visible(g.world, p.x, p.z, target.x, target.z) and tick % 3 == 0
      input.dash = target.ai == 'windup' and target.windup < 0.15 and best < 3
      if tick % 900 == 450 then
        g:switchWeapon(p.weapon == 1 and 2 or 1)
      end
    elseif goal then
      p.yaw = math.atan2(goal.x - p.x, goal.z - p.z)
      steer(p, input, along(g, goal.x, goal.z))
    end
    g:update(1 / S.rate, input)
  end
end
-- Steps of a session until done(g) or the limit; observer(g, tick) after each.
local function play(g, observer, from, limit, done, goal)
  local think, tick = brain(goal), from
  while tick < from + limit and not done(g) do
    tick = tick + 1
    think(g, tick)
    if observer then
      observer(g, tick)
    end
  end
  return tick
end
-- The checkpoint of a session as the SIGIL09 file text (sequence n).
local function saved(g, n)
  return RunSave.encode(Run.snapshot(g), n, g)
end
-- A new expedition session from a save text (the menu's CONTINUE).
local function loaded(G, text)
  local data = assert(RunSave.decode(text))
  local g = G.new('descent')
  g.testing = true
  Modes.act(g, 'load', data)
  return g
end
S.loaded = loaded
-- observer(g, tick) after every step; mark(g, kind) at a save or a load.
-- Returns the save texts by name and the last session.
function S.run(G, observer, mark)
  mark = mark or function() end
  local saves = {}
  local g = G.new('descent')
  g.testing = true
  g:start()
  saves.start = saved(g, 1)
  Run.ready(g)
  if observer then
    observer(g, 0)
  end
  -- The first wave, until the shrine opens again.
  local tick = play(g, observer, 0, S.rate * 240, function(s)
    return s.state ~= 'playing' or (s.run.phase == 'preparing' and s.run.wave >= 2)
  end)
  assert(g.run.phase == 'preparing' and g.run.wave == 2, 'the trial knight did not clear wave 1')
  -- An engraving bought at the shrine: the checkpoints after it carry it.
  tick = play(g, observer, tick, S.rate * 30, Sanctuary.near, Sanctuary.at(g))
  assert(g:interact() and Run.buy(g, 'pierce'), 'the trial knight could not buy the engraving')
  Run.closeShop(g)
  mark(g, 'save')
  saves.preparing = saved(g, 2)
  g = loaded(G, saves.preparing)
  mark(g, 'load')
  Run.ready(g)
  -- Twelve seconds into the second wave the knight falls where it stands,
  -- with the souls of the wave on it: the defeat leaves its echo.
  tick = play(g, observer, tick, S.rate * 12, function(s)
    return s.state ~= 'playing'
  end)
  assert(g.state == 'playing' and g.run.phase == 'wave', 'the trial knight left the second wave')
  g.player.hp = 0
  Modes.act(g, 'lose')
  mark(g, 'save')
  saves.defeated = saved(g, 3)
  g = loaded(G, saves.defeated)
  mark(g, 'load')
  -- Retry from the checkpoint and fight five more seconds.
  Modes.act(g, 'retry')
  Run.ready(g)
  play(g, observer, tick, S.rate * 5, function(s)
    return s.state ~= 'playing'
  end)
  return saves, g
end
return S

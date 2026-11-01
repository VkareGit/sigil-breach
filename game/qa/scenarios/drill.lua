-- Golden drill (0.24 / E0): a scripted, deterministic fight in the proving
-- ground that touches every system the bots skip: both weapons and their
-- reloads, the powder charge, dodges, slides, jumps, every demon kind,
-- leaps, charges, bolts, pools, lightning, counters, falls and corpses.
-- setup and step are separate so a test can record, rewind or replay it.
local S = {}
S.rate = 120
function S.setup(G)
  local Field = require('src.run.test_field')
  local g = Field.new(G)
  g.testing = true
  Field.reset(g)
  Field.close(g)
  g.testField.invincible = true
  local p = g.player
  p.x, p.z, p.yaw = 16, 22, math.pi
  local roster = {
    { 'imp', 13, 15 },
    { 'imp', 19, 15 },
    { 'armored', 16, 12 },
    { 'stolas', 10, 10 },
    { 'buer', 22, 10 },
    { 'furfur', 16, 7 },
  }
  for _, r in ipairs(roster) do
    local e = g:spawn(r[1], r[2], r[3])
    e.awake, e.memory, e.spawnAge = true, 60, 1
  end
  return g
end
-- One scripted tick; false once every demon is down.
function S.step(g, tick)
  local p = g.player
  -- Aim at the nearest living demon (deterministic: first on ties).
  local best, bestD
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      local d = (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2
      if not bestD or d < bestD then
        best, bestD = e, d
      end
    end
  end
  if best then
    p.yaw = math.atan2(best.x - p.x, best.z - p.z)
  end
  local t = tick / S.rate
  if tick % 480 == 1 then
    g:switchWeapon(p.weapon == 1 and 2 or 1)
  end
  if tick % 600 == 300 and (p.abilityState.powder.uses or 0) > 0 then
    g:cast(1)
  end
  g:update(1 / S.rate, {
    forward = math.sin(t * 0.7) * 0.6,
    strafe = math.cos(t * 1.3),
    shoot = best ~= nil and tick % 3 == 0,
    dash = tick % 360 == 180,
    slide = tick % 720 == 500,
    jump = tick % 420 == 210,
  })
  return best ~= nil
end
function S.run(G, observer, seconds, from)
  local g = S.setup(G)
  if observer then
    observer(g, 0)
  end
  return S.play(g, observer, seconds, from)
end
-- Ticks from..(seconds * rate) of the script on an existing session.
function S.play(g, observer, seconds, from)
  local steps = (seconds or 40) * S.rate
  for tick = from or 1, steps do
    local alive = S.step(g, tick)
    if observer then
      observer(g, tick)
    end
    if not alive then
      break
    end
  end
  return g
end
return S

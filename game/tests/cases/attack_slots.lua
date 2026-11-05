-- A committed string keeps its place through its short connecting recovery.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local Enemies = require('src.content.enemies')
  local Actions = require('src.enemies.actions')
  local Rules = require('src.combat.rules')
  local World = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'attack slots: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local function room()
    local g = F.arena(Game)
    for z = 8, 30 do
      for x = 8, 26 do
        World.setCell(g.world, x, z, Tiles.floor)
      end
    end
    return g
  end
  local function body(g, x, z, kind)
    local e = g:spawn(kind or 'imp', x, z)
    e.target, e.awake, e.visible, e.memory, e.spawnAge, e.sense = g.player.id, true, true, 60, 2, 10
    e.facing = math.atan2(g.player.x - x, g.player.z - z)
    e.attack = 0
    return e
  end
  local function gap(g, e)
    Actions.begin(g, e, 1.8, Enemies.imp.attacks[1])
    e.ai, e.phase, e.recover = 'recover', 0, 0.14
    e.chain, e.chainFrom = 'claw-late', 'claw'
  end
  for _, transition in ipairs({ 'waiting', 'interrupted', 'dead', 'other-target' }) do
    local g = room()
    for i = 1, 3 do
      gap(g, body(g, 15 + i * 0.6, 23.2))
    end
    local waiting = body(g, 16, 26.8)
    local held = g.enemies[1]
    if transition == 'interrupted' then
      Rules.interrupt(held)
    elseif transition == 'dead' then
      held.hp = 0
    elseif transition == 'other-target' then
      -- A friendly demon is not a valid alternative target and would be
      -- replaced by perception before the waiting body makes its choice.
      local ally = g:spawn('imp', 25, 25)
      ally.faction, ally.dummy = 'knight', true
      held.target = ally.id
    end
    g:update(1 / 120, {})
    check(
      transition .. ' accounts for the real owner of the slot',
      (waiting.ai == 'windup') == (transition ~= 'waiting')
    )
  end
  for _, hz in ipairs({ 60, 120, 240 }) do
    local g = room()
    local p = g.player
    p.hp, p.maxHp = 10000, 10000
    g.rng.sim:seed(6)
    for i = 1, 8 do
      local a = i / 8 * math.pi * 2
      body(g, p.x + math.sin(a) * 5, p.z + math.cos(a) * 5)
    end
    local peak, continuations = 0, 0
    g.bus:on('sim', 'AttackTelegraphed', function(ev)
      if ev.attack.id == 'claw-late' or ev.attack.id == 'pounce' then
        continuations = continuations + 1
      end
    end)
    for _ = 1, 8 * hz do
      g:update(1 / hz, {})
      local active = 0
      for _, e in ipairs(g.enemies) do
        if e.hp > 0 and (e.ai == 'windup' or e.ai == 'strike') then
          active = active + 1
        end
      end
      peak = math.max(peak, active)
    end
    check('a live pack stays within three attacks at ' .. hz .. ' Hz', peak <= 3)
    check('the cap does not discard every follow-up at ' .. hz .. ' Hz', continuations > 0)
  end
  do
    local g = room()
    for i = 1, 3 do
      gap(g, body(g, 15 + i * 0.6, 23.2))
    end
    body(g, 16, 26.8)
    local saved = Snapshot.capture(g)
    for _ = 1, 90 do
      g:update(1 / 120, {})
    end
    local expected = Integrity.capture(g)
    Snapshot.restore(g, saved)
    for _ = 1, 90 do
      g:update(1 / 120, {})
    end
    check(
      'restoring a connecting recovery preserves the entire fight',
      not Integrity.difference(expected, Integrity.capture(g))
    )
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T

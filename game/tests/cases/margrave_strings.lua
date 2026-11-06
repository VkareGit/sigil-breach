-- A cleaver string must offer its promised full recovery, including after Continue.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local World = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Enemies = require('src.content.enemies')
  local Actions = require('src.enemies.actions')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local Save = require('src.storage.save')
  local specs, lines, failures = {}, {}, {}
  for _, spec in ipairs(Enemies.boss.attacks) do
    specs[spec.id] = spec
  end
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'margrave-strings: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local function room(seed)
    local g = F.arena(Game)
    for z = 8, 30 do
      for x = 8, 26 do
        World.setCell(g.world, x, z, Tiles.floor)
      end
    end
    g.rng.sim:seed(seed)
    local p = g.player
    p.x, p.z, p.yaw, p.armor, p.hp, p.maxHp = 16, 18, math.pi, 0, 10000, 10000
    local e = g:spawn('boss', 16, 15)
    e.awake, e.visible, e.memory, e.target, e.facing, e.spawnAge = true, true, 60, p.id, 0, 2
    return g, e
  end
  local function step(g, e, hz, dodge)
    e.attack = 999
    e.answered = { behind = 999, hugging = 999, drinking = 999, reloading = 999, sniped = 999 }
    if not dodge then
      e.answered.dodged = 999
    elseif e.chain then
      g.player.dodgeEnds = g.elapsed + 0.1
    end
    g:update(1 / hz, {})
  end
  for _, hz in ipairs({ 60, 120, 240 }) do
    for _, dodge in ipairs({ false, true }) do
      local longest, shortest, catches, fullRest = 0, 100, 0, true
      for _, seed in ipairs({ 1, 3, 6, 7, 10, 20, 43, 54, 77, 93 }) do
        local g, e = room(seed)
        local releases = 0
        g.bus:on('sim', 'AttackReleased', function(event)
          if event.enemy == e then
            releases = releases + 1
            if event.attack.id == 'ash-catch' then
              catches = catches + 1
            end
          end
        end)
        Actions.begin(g, e, 3, specs.cleave)
        local finished = false
        for _ = 1, hz * 20 do
          step(g, e, hz, dodge)
          if e.ai == 'recover' and not e.chain then
            finished = true
            -- A 60 Hz update may consume the first 120 Hz recovery substep.
            fullRest = fullRest and e.spent >= 1.2 - 1 / hz - 1e-6 and e.spent <= 1.2
            break
          end
        end
        check('finite string / ' .. hz .. '/' .. seed .. '/' .. tostring(dodge), finished)
        longest, shortest = math.max(longest, releases), math.min(shortest, releases)
      end
      check(
        'at most three blows including answers / ' .. hz .. '/' .. tostring(dodge),
        longest <= 3
      )
      check('strings still vary in length / ' .. hz .. '/' .. tostring(dodge), shortest < longest)
      check(
        'every string ends with the full punish window / ' .. hz .. '/' .. tostring(dodge),
        fullRest
      )
      if dodge then
        check('an early dodge can still be answered / ' .. hz, catches > 0)
      end
    end
  end
  do
    local g, e = room(43)
    Actions.begin(g, e, 3, specs.cleave)
    while not e.chain and g.elapsed < 5 do
      step(g, e, 120)
    end
    check('the save lies in a connecting beat', e.chain ~= nil)
    local before = Integrity.capture(g)
    local section = Save.section('pools')
    section.restore(g, section.unpack(section.pack(g)))
    e = g.enemies[1]
    check(
      'serialized pools retain the string budget',
      not Integrity.difference(before, Integrity.capture(g))
    )
    local saved = Snapshot.capture(g)
    for _ = 1, 600 do
      step(g, e, 120)
    end
    local after = Integrity.capture(g)
    Snapshot.restore(g, saved)
    e = g.enemies[1]
    for _ = 1, 600 do
      step(g, e, 120)
    end
    check(
      'Continue repeats the same end and contacts',
      not Integrity.difference(after, Integrity.capture(g))
    )
  end
  do
    local g, e = room(43)
    Actions.begin(g, e, 3, specs.cleave)
    for _ = 1, 1200 do
      step(g, e, 120)
      if e.ai == 'recover' and not e.chain then
        break
      end
    end
    e.spent, e.recover = 0, 0
    Actions.begin(g, e, 3, specs.cleave)
    check('a fresh string receives a fresh budget', e.stringCount == 1 and e.stringLimit == 3)
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T

-- Landing and the following wave are two readable, physically separate beats.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local W = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Actions = require('src.enemies.actions')
  local Enemies = require('src.content.enemies')
  local Save = require('src.storage.save')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local specs, lines, failures = {}, {}, {}
  for _, a in ipairs(Enemies.boss.attacks) do
    specs[a.id] = a
  end
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'margrave-landing: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local function room(d)
    local g = F.arena(Game)
    for z = 8, 31 do
      for x = 8, 27 do
        W.setCell(g.world, x, z, Tiles.floor)
      end
    end
    local p = g.player
    p.x, p.z, p.yaw, p.armor, p.hp, p.maxHp = 16, 15 + d, math.pi, 0, 10000, 10000
    local e = g:spawn('boss', 16, 15)
    e.awake, e.visible, e.memory, e.target, e.facing, e.spawnAge = true, true, 60, p.id, 0, 2
    g.rng.sim:seed(1)
    return g, e
  end
  local function step(g, e, hz, input)
    e.attack = 999
    e.answered =
      { dodged = 999, behind = 999, hugging = 999, drinking = 999, reloading = 999, sniped = 999 }
    g:update(1 / hz, input or {})
  end
  for _, hz in ipairs({ 60, 120, 240 }) do
    for _, d in ipairs({ 4.5, 7, 10, 11 }) do
      local g, e = room(d)
      Actions.begin(g, e, d, specs['ash-leap'])
      local landed
      g.bus:on('sim', 'Landed', function(ev)
        if ev.enemy == e then
          landed = g.elapsed
        end
      end)
      for _ = 1, hz * 3 do
        step(g, e, hz)
        if landed then
          break
        end
      end
      check(
        'landing contact at ' .. d .. 'm / ' .. hz,
        landed and g.player.hp == 10000 - (d == 11 and 0 or 56)
      )
      check(
        'landing stays on the near side of the body / ' .. d .. '/' .. hz,
        e.z <= g.player.z - 1.51
      )
    end
    for _, response in ipairs({ 'still', 'jump-early', 'jump-late', 'side' }) do
      local g, e = room(7)
      local landed, wave, jumped
      g.bus:on('sim', 'Landed', function(ev)
        if ev.enemy == e then
          landed = g.elapsed
        end
      end)
      g.bus:on('sim', 'AttackReleased', function(ev)
        if ev.enemy == e and ev.attack.id == 'ash-ring' then
          wave = g.elapsed
        end
      end)
      Actions.begin(g, e, 7, specs['ash-leap'])
      for _ = 1, hz * 3 do
        local input = {}
        if
          landed
          and response:match('^jump')
          and not jumped
          and g.elapsed - landed >= (response == 'jump-early' and 0.55 or 0.7)
        then
          input.jump = true
          jumped = true
        end
        if response == 'side' then
          input.strafe = 1
        end
        step(g, e, hz, input)
      end
      check(
        'separate breath before the wave / ' .. response .. '/' .. hz,
        landed and wave and wave - landed >= 0.65
      )
      check(
        'the second beat can be answered after taking the first / ' .. response .. '/' .. hz,
        g.player.hp == 10000 - (response == 'still' and 86 or response:match('^jump') and 56 or 0)
      )
    end
    do
      local g, e = room(7)
      Actions.begin(g, e, 7, specs['ash-leap'])
      for x = 8, 27 do
        W.setCell(g.world, x, 18, Tiles.wall)
      end
      for _ = 1, hz * 3 do
        step(g, e, hz)
      end
      check(
        'neither landing nor wave crosses a solid wall / ' .. hz,
        g.player.hp == 10000 and e.z < 18
      )
    end
    for _, at in ipairs({ 0.2, 1.0 }) do
      local g, e = room(7)
      Actions.begin(g, e, 7, specs['ash-leap'])
      for _ = 1, math.floor(at * hz) do
        step(g, e, hz)
      end
      e.hp, e.ai, e.deathTime = 0, 'dead', 0
      for _ = 1, hz * 2 do
        step(g, e, hz)
      end
      check(
        'death cancels unreleased landing and wave at ' .. at .. '/' .. hz,
        g.player.hp == 10000 and #g.hazards == 0
      )
    end
  end
  for _, at in ipairs({ 0.2, 1.0, 1.6, 2.1 }) do
    local g, e = room(7)
    Actions.begin(g, e, 7, specs['ash-leap'])
    for _ = 1, math.floor(at * 120) do
      step(g, e, 120)
    end
    local packed = Save.capture('session', g)
    local path = 'margrave-landing-test.save'
    local encoded = Save.encode('session', packed, 1)
    local ok, reason = Save.write(path, encoded)
    check('write real Continue file at ' .. at, ok)
    local values = ok and Save.read('session', path)
    if values then
      Save.restore('session', g, values)
    end
    Save.erase(path)
    e = g.enemies[1]
    -- Restoring invalidates world geometry caches; compare the complete persisted state.
    check(
      'disk Continue retains action at ' .. at,
      values and encoded == Save.encode('session', Save.capture('session', g), 1)
    )
    local snapshot = Snapshot.capture(g)
    for _ = 1, 240 do
      step(g, e, 120)
    end
    local future = Integrity.capture(g)
    Snapshot.restore(g, snapshot)
    e = g.enemies[1]
    for _ = 1, 240 do
      step(g, e, 120)
    end
    check(
      'restored action produces the same future at ' .. at,
      not Integrity.difference(future, Integrity.capture(g))
    )
  end
  do
    local g, e = room(7)
    -- The normal session bootstrap must load trusted legacy definitions, even when
    -- an already migrated save no longer runs a version migration on its next load.
    local legacy = package.loaded['src.content.migrations.margrave_045']
    check('cold session bootstrap knows frozen definitions', type(legacy) == 'table')
    local old
    for _, spec in ipairs(legacy and legacy.attacks or {}) do
      if spec.id == 'ash-leap' then
        old = spec
      end
    end
    if old then
      Actions.begin(g, e, 7, old)
      local section = Save.section('pools')
      local encoded = section.pack(g)
      local function historicalPaths(t)
        if type(t) ~= 'table' then
          return
        end
        if t['$def'] and t['$def'][1] == 'src.content.migrations.margrave_045' then
          t['$def'][1] = 'src.content.creatures.boss'
        else
          for _, child in pairs(t) do
            historicalPaths(child)
          end
        end
      end
      historicalPaths(encoded)
      section.restore(g, section.unpack(section.migrations[6](encoded)))
      e = g.enemies[1]
      check(
        'old Continue preserves the committed landing and gap',
        e.attackSpec.landRadius == 1.1 and e.attackSpec.string.gap == 0
      )
      local packed = Save.capture('session', g)
      local values = Save.decode('session', Save.encode('session', packed, 1))
      check('an already migrated file can be decoded again', values ~= nil)
      if values then
        Save.restore('session', g, values)
      end
      e = g.enemies[1]
      local landed
      g.bus:on('sim', 'Landed', function(ev)
        if ev.enemy == e then
          landed = true
        end
      end)
      for _ = 1, 360 do
        step(g, e, 120)
      end
      check('the legacy committed landing finishes', landed)
      check(
        'future choices use the current landing',
        specs['ash-leap'].landRadius == 1.5 and specs['ash-leap'].string.gap == 0.5
      )
    end
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T

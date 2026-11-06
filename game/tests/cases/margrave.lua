-- A cleaver, its body, and its cinders must agree about the committed direction.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local E = require('src.content.enemies')
  local A = require('src.enemies.actions')
  local W = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local M = require('src.core.mathx')
  local Anchor = require('src.enemies.contact_anchor')
  local Recipes = require('src.audio.recipes')
  local Art = require('src.content.art.rites')
  local Save = require('src.storage.save')
  local lines, failures, specs = {}, {}, {}
  for _, s in ipairs(E.boss.attacks) do
    specs[s.id] = s
  end
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'margrave: ' .. name
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
    e.attack, e.chain = 999, nil
    e.answered =
      { dodged = 999, behind = 999, hugging = 999, drinking = 999, reloading = 999, sniped = 999 }
    g:update(1 / hz, input or {})
  end
  check(
    'health, reward, and guard opening preserved',
    E.boss.body.hp == 2700 and E.boss.souls == 25 and E.boss.body.breakTime == 1.2
  )
  for _, hz in ipairs({ 60, 120, 240 }) do
    for _, id in ipairs({
      'cleave',
      'backcut',
      'burning-cut',
      'turn-cut',
      'ash-catch',
      'ash-thrust',
    }) do
      local g, e = room(4)
      A.begin(g, e, 4, specs[id])
      local aligned, moved = true, false
      for _ = 1, hz * 3 do
        step(g, e, hz, { strafe = 1 })
        if e.ai == 'strike' and e.lungeX then
          moved = true
          aligned = aligned
            and math.abs(M.wrapAngle(math.atan2(e.lungeX, e.lungeZ) - e.facing)) < 1e-6
        end
      end
      check(id .. ' shows its actual delivery direction / ' .. hz, moved and aligned)
    end
    do
      local g, e = room(7)
      local anchored, aimed, seen = false, false, false
      local bullet, velocity
      g.bus:on('sim', 'AttackReleased', function(ev)
        if ev.enemy == e and ev.attack.id == 'cinder-spear' then
          bullet = g.bullets[#g.bullets]
          local x, y, z = Anchor.point(g, e, e.phase or 0, e.x, e.z, 'cleaver')
          anchored = bullet
            and x
            and math.abs(bullet.x - x) + math.abs(bullet.y - y) + math.abs(bullet.z - z) < 1e-6
          if bullet then
            local dx, dz = e.aimX - bullet.x, e.aimZ - bullet.z
            aimed = math.abs(dx * bullet.vz - dz * bullet.vx) < 1e-5
            velocity = { bullet.vx, bullet.vy, bullet.vz }
            seen = true
          end
        end
      end)
      A.begin(g, e, 7, specs['cinder-spear'])
      for _ = 1, hz * 2 do
        step(g, e, hz, { strafe = 1 })
      end
      check('cinder leaves the painted cleaver / ' .. hz, anchored)
      check('cinder travels toward the frozen aim / ' .. hz, aimed)
      check(
        'released cinder never homes after later input / ' .. hz,
        seen and bullet.vx == velocity[1] and bullet.vy == velocity[2] and bullet.vz == velocity[3]
      )
    end
  end
  for _, role in ipairs({ 'breath', 'murmur', 'alert', 'hurt', 'death' }) do
    local name = E.boss.sounds[role]
    local cue = name and Recipes[name]
    check(
      'own varied body voice ' .. role,
      cue and cue.path and #(cue.variants or {}) >= (role == 'death' and 2 or 1)
    )
  end
  for _, id in ipairs({
    'cleave',
    'backcut',
    'overhead',
    'ash-thrust',
    'ash-leap',
    'stomp',
    'turn-cut',
    'ash-catch',
    'burning-cut',
    'ash-lance',
    'cinder-spear',
    'ash-ring',
    'ash-burst',
  }) do
    local a = specs[id]
    check(
      'distinct throat beside material / ' .. id,
      a.windupVoice and a.windupVoice ~= a.windupSound and Recipes[a.windupVoice]
    )
  end
  for _, id in ipairs({ 'ash-lance', 'ash-burst', 'burning-cut' }) do
    local g, e = room(id == 'ash-burst' and 2 or 7)
    A.begin(g, e, 7, specs[id])
    local first
    for _ = 1, 240 do
      step(g, e, 120, { strafe = 1 })
      if #g.hazards > 0 then
        first = g.hazards[1]
        break
      end
    end
    check(
      id .. ' retains its own painted ground profile',
      first and first.art == 'ash' and Art.pools and Art.pools[first.art]
    )
    if first then
      local section = Save.section('pools')
      local encoded = section.pack(g)
      section.restore(g, section.unpack(encoded))
      e = g.enemies[1]
      check(
        id .. ' keeps its exact footprint through Continue',
        g.hazards[1].radius == first.radius
          and g.hazards[1].volume.top == first.volume.top
          and g.hazards[1].art == first.art
      )
      e.hp, e.ai, e.deathTime = 0, 'dead', 0
      local live = false
      for _ = 1, 24 do
        step(g, e, 120)
        live = live or #g.hazards > 0
      end
      check(id .. ' released material persists after its caster dies', live)
      for _ = 1, 600 do
        step(g, e, 120)
      end
      check(
        id .. ' material and harmless ash both expire',
        #g.hazards == 0 and #(g.view.poolBursts or {}) == 0
      )
    end
  end
  do
    local g, e = room(7)
    A.begin(g, e, 7, specs['ash-leap'])
    for _ = 1, 240 do
      step(g, e, 120)
      if (e.landings or 0) > 0 then
        break
      end
    end
    local b = (g.view.impactBursts or {})[1]
    check(
      'landing painting follows the true impact instead of the aimed target',
      b and b.x == e.x and b.z == e.z and b.radius == specs['ash-leap'].landRadius
    )
  end
  for _, ground in ipairs({ 0, 2 }) do
    local g, e = room(7)
    g.world.floor, e.level, g.player.level = ground, ground, ground
    A.begin(g, e, 7, specs['cinder-spear'])
    e.ai = 'strike'
    A.execute(g, e)
    local b = g.bullets[#g.bullets]
    local x, y, z = Anchor.point(g, e, e.phase, e.x, e.z, 'cleaver')
    check(
      'cinder emitter uses the body floor exactly once / ' .. ground,
      b and math.abs(b.y - ground - y) < 1e-6
    )
    local cx, cz = math.floor(x + 0.5), math.floor(z + 0.5)
    check(
      'cleaver origin is physically outside the centre cell / ' .. ground,
      cx ~= math.floor(e.x + 0.5) or cz ~= math.floor(e.z + 0.5)
    )
    W.setCell(g.world, cx, cz, Tiles.wall)
    local count = #g.bullets
    A.execute(g, e)
    check('a cleaver through a column cannot emit through stone / ' .. ground, #g.bullets == count)
  end
  do
    local Snapshot = require('src.session.snapshot')
    local Integrity = require('src.session.integrity')
    for _, id in ipairs({
      'cleave',
      'backcut',
      'overhead',
      'ash-thrust',
      'ash-leap',
      'stomp',
      'turn-cut',
      'ash-catch',
      'burning-cut',
      'ash-lance',
      'cinder-spear',
      'ash-ring',
      'ash-burst',
    }) do
      for _, state in ipairs({ 'windup', 'strike', 'recover' }) do
        local g, e = room(6)
        A.begin(g, e, 6, specs[id])
        for _ = 1, 900 do
          if e.ai == state then
            break
          end
          step(g, e, 120)
        end
        check(id .. ' reaches saved phase ' .. state, e.ai == state)
        local text = Save.encode('session', Save.capture('session', g), 1)
        local path = 'margrave-body-test.save'
        local written = Save.write(path, text)
        local values = written and Save.read('session', path)
        Save.erase(path)
        if values then
          Save.restore('session', g, values)
        end
        e = g.enemies[1]
        check(
          id .. ' disk Continue preserves ' .. state,
          values and text == Save.encode('session', Save.capture('session', g), 1)
        )
        local snapshot = Snapshot.capture(g)
        for _ = 1, 120 do
          step(g, e, 120, { strafe = 1 })
        end
        local future = Integrity.capture(g)
        Snapshot.restore(g, snapshot)
        e = g.enemies[1]
        for _ = 1, 120 do
          step(g, e, 120, { strafe = 1 })
        end
        check(
          id .. ' Continue repeats future contacts / ' .. state,
          not Integrity.difference(future, Integrity.capture(g))
        )
      end
    end
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T

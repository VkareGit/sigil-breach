-- Delivery boundaries are physical: height, stone, expiry, ownership and save state.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local Actions = require('src.enemies.actions')
  local Enemies = require('src.content.enemies')
  local Spawn = require('src.session.spawn')
  local Projectiles = require('src.combat.projectiles')
  local Hazards = require('src.enemies.hazards')
  local Stream = require('src.combat.stream')
  local Ground = require('src.physics.ground')
  local World = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local lines = {}
  local check = F.checker(lines, 'gardener edges: ', 'gardener edges: ')
  local function fresh()
    local g = F.arena(Game)
    for z = 18, 28 do
      for x = 12, 20 do
        World.setCell(g.world, x, z, Tiles.floor)
      end
    end
    g.player.armor, g.player.z = 0, 23
    local e = g:spawn('buer', 16, 20)
    e.target, e.awake, e.visible, e.memory, e.spawnAge, e.facing = g.player.id, true, true, 60, 2, 0
    return g, e
  end
  local specs = Enemies.buer.attacks
  do
    local g, e = fresh()
    local a = specs[2]
    Actions.begin(g, e, 3, a)
    e.ai, e.phase = 'strike', 0
    Actions.execute(g, e)
    local s = Stream.shape(g, e, a)
    local p = { x = s.x + s.dx * 2, z = s.z + s.dz * 2, jump = 0.8 }
    check(
      'a normal jump is not immunity to a chest-height discharge',
      Stream.test(g, s, g.player, p)
    )
    p.level, p.jump = 3, 0
    g.world.decks = { [math.floor(p.z + 0.5)] = { [math.floor(p.x + 0.5)] = { { 2.7, 3 } } } }
    check('a body on another floor is clear of the stream', not Stream.test(g, s, g.player, p))
    g.world.decks, p.level = nil, nil
    p.x, p.z = s.x + s.dx * (s.reach + 0.1), s.z + s.dz * (s.reach + 0.1)
    check('the end has no invisible extra reach', not Stream.test(g, s, g.player, p))
    local dx, dz = e.lungeX, e.lungeZ
    g.player.x = 20
    e.phase = 0.2
    Actions.strike(g, e, 1 / 120, g.player)
    check('release bearing stays fixed after a sidestep', e.lungeX == dx and e.lungeZ == dz)
    g.player.x = 16
    local hp = g.player.hp
    e.phase = a.duration + 1 / 120
    Actions.strike(g, e, 1 / 120, g.player)
    check('expired spray cannot wound a late entrant', g.player.hp == hp)
  end
  do
    local g, e = fresh()
    e.previewFrame = 7
    g.mode, g.testField = 'field', {}
    local Surface = require('src.enemies.surface')
    local p = Surface.prepare(g, e)
    check('landmarks sample the live spit frame', p.frame == 7)
    -- Independently read on the original 311 by 315 crop at (635, 314).
    for _, point in ipairs({
      { 825, 425, true, 'face above the mouth' },
      { 795, 478, true, 'belly' },
      { 896, 554, true, 'right forearm' },
      { 872, 467, false, 'detached old side spray' },
    }) do
      local u, v = (point[1] - 635) / 311, (point[2] - 314) / 315
      local part = Surface.part(p.parts, u, v)
      local hit = Surface.painted(p.mask, u, v, true) and part and part.hittable ~= false
      check('frame 7 keeps the independent landmark: ' .. point[4], not not hit == point[3])
    end
  end
  local function projectile(g, e, y, vy, life)
    return Spawn.make(g, 'projectile', {
      x = 16,
      y = y,
      z = 22,
      vx = 0,
      vy = vy,
      vz = 0,
      gravity = 5,
      radius = 0.18,
      life = life or 3,
      owner = e.id,
      side = 'demons',
      packet = specs[1].packet,
      deposit = specs[1].deposit,
      art = 'rot-spit',
      color = specs[1].color,
    })
  end
  for _, rate in ipairs({ 60, 120, 240 }) do
    local g, e = fresh()
    g.player.z = 26
    g.world.decks = { [22] = { [16] = { { 2.7, 3 } } } }
    projectile(g, e, 4, -3)
    for _ = 1, rate do
      Projectiles.update(g, 1 / rate)
    end
    check(
      'landing stays on its contacted deck / ' .. rate,
      #g.hazards == 1 and math.abs(Ground.of(g.world, g.hazards[1]) - 3) < 1e-6
    )
    g.player.x, g.player.z, g.player.level = 16, 22, 0
    local hp = g.player.hp
    for _ = 1, rate do
      Hazards.update(g, 1 / rate)
    end
    check('a planted deck does not poison the floor beneath / ' .. rate, g.player.hp == hp)
    g, e = fresh()
    g.player.z = 26
    g.world.decks = { [22] = { [16] = { { 2.7, 3 } } } }
    projectile(g, e, 2, 5)
    for _ = 1, rate do
      Projectiles.update(g, 1 / rate)
    end
    check('ceiling impact creates no ground patch / ' .. rate, #g.bullets == 0 and #g.hazards == 0)
    g, e = fresh()
    projectile(g, e, 8, 0, 0.01)
    for _ = 1, math.ceil(rate * 0.02) do
      Projectiles.update(g, 1 / rate)
    end
    check('expired airborne seed creates no patch / ' .. rate, #g.hazards == 0 and #g.bullets == 0)
  end
  return lines
end
return T

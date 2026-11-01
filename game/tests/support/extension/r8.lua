-- Plan v12 R8: a turret, a barrel, a person and a lever, each one declaration and
-- each kept by a save, through public registries alone.
local Proof = require('tests.support.extension.proof')
local Ballistics = require('src.combat.ballistics')
local Bodies = require('src.combat.bodies')
local Damage = require('src.combat.damage')
local Entities = require('src.session.entities')
local Explosives = require('src.combat.explosives')
local Pools = require('src.session.world')
local Save = require('src.storage.session_save')
local Tiles = require('src.core.tiles')
local World = require('src.world.arena')
local R = {}
local function free(g)
  local w = g.world
  for z = 8, #w.map - 8 do
    for x = 8, #w.map[z] - 8 do
      local clear = true
      for dz = -3, 3 do
        for dx = -3, 3 do
          clear = clear and Tiles.walkable[w.map[z + dz][x + dx]]
        end
      end
      if clear then
        return x, z
      end
    end
  end
end
function R.run(Game, check, session)
  check(
    'a system without a place is refused',
    not pcall(Entities.define, { id = 'proof_wrong', system = { step = function() end } })
  )
  local ids = { 'proof_turret', 'proof_barrel', 'proof_person', 'proof_lever' }
  Proof.with({
    function()
      for _, id in ipairs(ids) do
        Entities.undefine(id)
      end
    end,
  }, function()
    -- A turret: it shoots what it sees, on its own clock.
    Entities.define({
      id = 'proof_turret',
      health = 800,
      hittable = true,
      collides = true,
      system = {
        after = 'demons',
        step = function(g, e, dt)
          e.state.wait = (e.state.wait or 0) - dt
          if e.state.wait > 0 then
            return
          end
          for _, target in ipairs(Pools.of(g, 'enemies')) do
            if
              target.hp > 0
              and World.visible(g.world, e.x, e.z, target.x, target.z)
              and (target.x - e.x) ^ 2 + (target.z - e.z) ^ 2 < 64
            then
              e.state.wait = 0.5
              e.state.shots = (e.state.shots or 0) + 1
              g:damageBody(target, 12, e.x, e.z, { base = 12, impact = 5 }, 'turret')
              return
            end
          end
        end,
      },
    })
    local g = session(Game)
    local x, z = free(g)
    local p = g.player
    p.x, p.z = x + 3, z + 3
    local turret = Entities.spawn(g, 'proof_turret', x, z)
    local demon = g:spawn('imp', x + 2, z)
    demon.awake = false
    for _ = 1, 150 do
      g:update(1 / 120, {})
    end
    check(
      'a turret shoots creatures on its own',
      demon.hp < demon.maxHp and turret.state.shots >= 2
    )
    local copy = session(Game)
    Save.restore(copy, assert(Save.decode(Save.encode(g))))
    local kept = Pools.of(copy, 'entities')[1]
    check('a save keeps it and its state', kept and kept.state.shots == turret.state.shots)
    p.x, p.z = x, z + 1
    p.yaw, p.pitch = math.pi, 0
    local dx, _, dz = Ballistics.spreadDirection(p.yaw, p.pitch, 0, 0)
    p.x, p.z = x - dx * 3, z - dz * 3
    p.cooldown = 0
    require('src.content.weapons').state(g, nil, p).readyAt = 0
    local health = turret.hp
    g:shoot()
    check('a shot meets it', turret.hp < health)
    p.x, p.z = x + 0.1, z
    for _ = 1, 2 do
      g:update(1 / 120, {})
    end
    check('a knight stops at it', (p.x - x) ^ 2 + (p.z - z) ^ 2 >= 0.4 ^ 2)
    -- A barrel: what kills it sets it off.
    Entities.define({
      id = 'proof_barrel',
      health = 10,
      hittable = true,
      die = function(g2, e, owner)
        Explosives.strike(
          g2,
          { x = e.x, y = 1, z = e.z, owner = owner },
          3,
          { base = 500, impact = 100, damageType = 'fire', falloffStart = 1, falloffEnd = 3 },
          'charge'
        )
      end,
    })
    g = session(Game)
    x, z = free(g)
    g.player.x, g.player.z = x + 3, z + 3
    local barrel = Entities.spawn(g, 'proof_barrel', x, z)
    local near = g:spawn('imp', x + 1, z)
    near.awake = false
    Entities.hurt(g, barrel, 20, g.player.id)
    check('a barrel goes up with what breaks it', near.hp <= 0 and #Pools.of(g, 'entities') == 0)
    -- A person, and a lever opening a door.
    local spoken, door = 0, nil
    Entities.define({
      id = 'proof_person',
      interact = {
        prompt = function()
          return 'Talk'
        end,
        act = function()
          spoken = spoken + 1
        end,
      },
    })
    Entities.define({
      id = 'proof_lever',
      interact = {
        act = function(g2, e)
          e.state.open = not e.state.open
          g2:setCell(door[1], door[2], e.state.open and Tiles.floor or Tiles.wall)
        end,
      },
    })
    g = session(Game)
    x, z = free(g)
    local actor = g.player
    actor.x, actor.z = x, z
    Entities.spawn(g, 'proof_person', x + 1, z)
    check('a person offers its word', g:context() == 'Talk')
    g:interact()
    check('and answers the use key', spoken == 1)
    Pools.clear(g, 'entities')
    door = { x + 3, z }
    g:setCell(door[1], door[2], Tiles.wall)
    Entities.spawn(g, 'proof_lever', x + 1, z)
    g:interact()
    check('a lever opens a door', not World.solid(g.world, door[1], door[2], 0))
    g:interact()
    check('and shuts it', World.solid(g.world, door[1], door[2], 0))
    local list = Bodies.targets(g)
    check('targets are bodies and hittable things only', #list == 0)
  end)
  check('its kinds leave with it', not Entities.kinds:has('proof_turret'))
  check('the damage rules ask nothing of a thing', type(Damage.resolve) == 'function')
end
return R

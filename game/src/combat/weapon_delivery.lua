-- Only the transport of a discharge lives here. Ammo/cadence belong to Combat;
-- all deliveries use its shared contact/damage receipts. A new algorithm adds
-- an executor + data schema, never a branch in the knight or a gun-id switch.
local Registry = require('src.core.registry')
local Spawn = require('src.session.spawn')
local B = require('src.combat.ballistics')
local Roles = require('src.core.roles')
local Delivery = Registry:new('weapon deliveries', function(entry, id)
  assert(type(entry.fire) == 'function', id .. ': delivery requires fire(g, shot, prepared)')
  assert(entry.prepare == nil or type(entry.prepare) == 'function', id .. ': invalid prepare')
end)
Delivery:register('projectile', {
  fire = function(g, shot)
    local def, p = shot.profile.delivery, shot.shooter or Roles.controlled(g)
    local spread = shot.spread
    for i = 1, shot.count do
      local ox, oy = 0, 0
      if shot.profile.fire.pellets > 1 then
        -- The shooter's own sequence chooses the pattern (plan v11 E3).
        ox, oy = B.pellet(i, shot.sequence or shot.serial, shot.count)
        ox, oy = ox * spread, oy * spread
      end
      local dx, dy, dz = B.spreadDirection(shot.yaw or p.yaw, shot.pitch or p.pitch, ox, oy)
      -- Start at the actual origin; a muzzle offset must not teleport a shot
      -- through thin cover. World and painted body sweeps own every contact.
      Spawn.make(g, 'projectile', {
        x = shot.origin[1],
        y = shot.origin[2],
        z = shot.origin[3],
        vx = dx * def.speed,
        vy = dy * def.speed,
        vz = dz * def.speed,
        life = shot.profile.range / def.speed,
        radius = def.radius,
        color = def.color,
        big = def.big,
        side = 'knight',
        owner = p.id,
        packet = shot.attack,
        shot = shot,
        travelled = 0,
      })
    end
  end,
})
return Delivery

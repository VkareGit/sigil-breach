-- Deterministic integration playthrough: ordinary inputs, actual damage, resources and collisions.
-- The bot knows objective positions; it receives no health, ammo or teleport cheats.
local W = require('src.world.arena')
local B = require('src.combat.ballistics')
local Grid = require('src.physics.grid')
local S = {}
function S.run(G)
  local g = G.new()
  g.testing = true
  g.state = 'playing'
  local field, fieldX, fieldZ, fieldAge = nil, nil, nil, 0
  local lastX, lastZ = g.player.x, g.player.z
  local stuck = 0
  local shotgun, revolver, pulses = 0, 0, 0
  local function pathTo(x, z)
    local tx, tz = math.floor(x + 0.5), math.floor(z + 0.5)
    if not field or tx ~= fieldX or tz ~= fieldZ or fieldAge > 0.35 then
      field = W.flow(g.world, x, z)
      fieldX, fieldZ = tx, tz
      fieldAge = 0
    end
    local p = g.player
    local cx, cz = math.floor(p.x + 0.5), math.floor(p.z + 0.5)
    if cx == tx and cz == tz then
      return x - p.x, z - p.z
    end
    if stuck > 0.2 then
      return cx - p.x, cz - p.z
    end
    local bx, bz, best = cx, cz, 1e9
    for _, o in ipairs({ { 0, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 } }) do
      local nx, nz = cx + o[1], cz + o[2]
      local d = field[Grid.key(g.world, nx, nz)]
      if d and d < best and not W.solid(g.world, nx, nz, 0.22) then
        bx, bz, best = nx, nz, d
      end
    end
    return bx - p.x, bz - p.z
  end
  for tick = 1, 120 * 360 do
    if g.state ~= 'playing' then
      break
    end
    local p = g.player
    local nearest, visible, distance, any, anyDist = nil, false, 1e9, nil, 1e9
    for _, e in ipairs(g.enemies) do
      if e.hp > 0 then
        local d = math.sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2)
        if d < anyDist then
          any, anyDist = e, d
        end
        if W.visible(g.world, p.x, p.z, e.x, e.z) and d < distance then
          nearest, visible, distance = e, true, d
        end
      end
    end
    local dx, dz = 0, 0
    local dash = false
    if nearest then
      p.yaw = math.atan2(nearest.x - p.x, nearest.z - p.z)
      local _, eye = B.origin(g)
      p.pitch = math.atan2((nearest.kind == 'boss' and 1.75 or 1.35) - eye, distance)
      local desired = distance < 6.3
          and (p.arsenal.exorcist.mag > 0 or p.arsenal.exorcist.reserve > 0)
          and 1
        or 2
      if
        p.arsenal.judge.mag + p.arsenal.judge.reserve == 0
        and p.arsenal.exorcist.mag + p.arsenal.exorcist.reserve > 0
      then
        desired = 1
      end
      if desired ~= g.player.weapon and g.player.reload == 0 and g.player.cooldown == 0 then
        g:switchWeapon(desired)
      end
      if distance > 7 then
        dx, dz = pathTo(nearest.x, nearest.z)
      else
        local ux, uz =
          (nearest.x - p.x) / math.max(0.01, distance), (nearest.z - p.z) / math.max(0.01, distance)
        local radial = distance > 4.7 and 0.65 or (distance < 3.5 and -1 or 0)
        local side = math.sin(g.elapsed * 0.9) > 0 and 1 or -1
        dx, dz = ux * radial + uz * side * 0.8, uz * radial - ux * side * 0.8
        if W.solid(g.world, p.x + dx * 0.5, p.z + dz * 0.5, 0.22) then
          dx, dz = ux * radial - uz * side * 0.8, uz * radial + ux * side * 0.8
        end
        dash = nearest.ai == 'windup' and nearest.windup < 0.18 and distance < 3.2
      end
      if
        p.abilityState.powder.uses > 0
        and distance > 5
        and distance < 7
        and nearest.kind == 'boss'
        and g:cast(1)
      then
        pulses = pulses + 1
      end
    elseif any then
      dx, dz = pathTo(any.x, any.z)
    else
      local objective, dist = nil, 1e9
      if require('src.session.encounter').guardianDead(g) then
        objective = g.world.portal
      else
        for _, s in ipairs(g.world.seals) do
          local d = (s.x - p.x) ^ 2 + (s.z - p.z) ^ 2
          if not s.active and d < dist then
            objective, dist = s, d
          end
        end
      end
      if objective then
        dx, dz = pathTo(objective.x, objective.z)
        g:interact()
      end
    end
    local len = math.sqrt(dx * dx + dz * dz)
    if len > 1 then
      dx, dz = dx / len, dz / len
    end
    local shotCount = g.player.shots
    g:update(1 / 120, {
      forward = dx * math.sin(p.yaw) + dz * math.cos(p.yaw),
      strafe = dx * math.cos(p.yaw) - dz * math.sin(p.yaw),
      shoot = visible,
      jump = visible,
      dash = dash,
    })
    if g.player.shots > shotCount then
      if g.player.weapon == 1 then
        shotgun = shotgun + 1
      else
        revolver = revolver + 1
      end
    end
    fieldAge = fieldAge + 1 / 120
    if math.abs(p.x - lastX) + math.abs(p.z - lastZ) < 0.001 and len > 0.1 then
      stuck = stuck + 1 / 120
    else
      stuck = 0
    end
    lastX, lastZ = p.x, p.z
  end
  local result = {
    state = g.state,
    time = g.elapsed,
    hp = g.player.hp,
    damage = require('src.session.stats').total(g, 'damageTaken'),
    kills = require('src.session.stats').total(g, 'kills'),
    seals = require('src.world.arena').activeSeals(g.world),
    ammo = g.player.arsenal.exorcist.mag + g.player.arsenal.exorcist.reserve,
    shotgun = shotgun,
    revolver = revolver,
    pulses = pulses,
    x = g.player.x,
    z = g.player.z,
  }
  local text = string.format(
    'FULL LIMBO INPUT SIMULATION\nResult: %s\nTime: %.2f s\nSeals: %d / 3\nKills: %d\nFinal health: %.1f\nDamage taken: %.1f\nRemaining shells: %d\nShotgun volleys: %d\nRevolver shots: %d\nPowder charges: %d\nFinal position: %.2f, %.2f\nNo damage/health/ammunition overrides. Objectives known to bot. This is a regression check, not a human difficulty study.\n',
    result.state,
    result.time,
    result.seals,
    result.kills,
    result.hp,
    result.damage,
    result.ammo,
    result.shotgun,
    result.revolver,
    result.pulses,
    result.x,
    result.z
  )
  local file = assert(io.open(require('qa.output').path('classic-playtest.txt'), 'w'))
  file:write(text)
  file:close()
  print(text)
  return result
end
return S

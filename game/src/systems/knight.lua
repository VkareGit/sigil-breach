-- The knight's systems: recovery (invulnerability, dodge charges,
-- conditions, guard), the reload timeline, the position snapshot that
-- melee and projectile sweeps interpolate from, and movement.
local Feel = require('src.player.feel')
local Intent = require('src.player.intent')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local BodyContact = require('src.combat.body_contact')
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Knight = {}
-- Every knight recovers (plan v10 V2: knights are a pool; the controlled one
-- first, the others in pool order).
local function recover(knight, dt)
  knight.invuln = math.max(0, knight.invuln - dt)
  knight.dash = math.min(
    Tuning.knight.dashCharges,
    knight.dash + dt * Tuning.dashRecharge * Rules.recoveryScale(knight)
  )
  Rules.tick(knight, dt)
  Rules.recover(knight, dt, Rules.playerBody())
end
Knight.recovery = {
  name = 'knightRecovery',
  run = function(g, dt)
    local controlled = Bodies.controlled(g)
    recover(controlled, dt)
    for _, knight in ipairs(Pools.of(g, 'knights')) do
      if knight ~= controlled and knight.hp > 0 then
        recover(knight, dt)
      end
    end
  end,
}
Knight.reload = {
  name = 'reload',
  run = function(g, dt)
    Feel.reloadUpdate(g, dt)
  end,
}
Knight.snapshot = {
  name = 'knightSnapshot',
  run = function(g, _, _, frame)
    local player = Bodies.controlled(g)
    frame.previousPlayer =
      { x = player.x, z = player.z, jump = player.jump, crouch = player.crouch or 0 }
    -- Other knights only when there are any (no table for one knight).
    local knights = Pools.of(g, 'knights')
    frame.previousKnights = nil
    if #knights > 1 then
      local previous = {}
      for _, knight in ipairs(knights) do
        if knight ~= player and knight.id then
          previous[knight.id] =
            { x = knight.x, z = knight.z, jump = knight.jump, crouch = knight.crouch or 0 }
        end
      end
      frame.previousKnights = previous
    end
  end,
}
Knight.motion = {
  name = 'knightMotion',
  run = function(g, dt, input)
    Feel.update(g, dt, input)
  end,
}
-- The knight stops at the demons he walked into (combat/body_contact.lua).
Knight.contact = {
  name = 'knightContact',
  run = function(g)
    BodyContact.knight(g)
  end,
}
Knight.trigger = {
  name = 'trigger',
  run = function(g, dt, input)
    Intent.fire(g, dt, input.shoot, input.fireCommand)
  end,
}
return Knight

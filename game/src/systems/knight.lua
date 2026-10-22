-- The knight's systems: recovery (invulnerability, dodge charges,
-- conditions, guard), the reload timeline, the position snapshot that
-- melee and projectile sweeps interpolate from, and movement.
local Feel = require('src.player.feel')
local Intent = require('src.player.intent')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local BodyContact = require('src.combat.body_contact')
local Knight = {}
Knight.recovery = {
  name = 'knightRecovery',
  run = function(g, dt)
    local player = g.player
    player.invuln = math.max(0, player.invuln - dt)
    player.dash = math.min(
      Tuning.knight.dashCharges,
      player.dash + dt * Tuning.dashRecharge * Rules.recoveryScale(player)
    )
    Rules.tick(player, dt)
    Rules.recover(player, dt, Rules.playerBody())
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
    local player = g.player
    frame.previousPlayer =
      { x = player.x, z = player.z, jump = player.jump, crouch = player.crouch or 0 }
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
    Intent.fire(g, dt, input.shoot)
  end,
}
return Knight

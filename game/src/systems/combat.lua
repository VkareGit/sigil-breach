-- The fight: demons (body, senses, state), their separation, the bodies
-- meeting the knight, marked hazards, projectiles and the knight's powder
-- charges. What may act is the session's capabilities (session/
-- capabilities.lua): a frozen proving ground stops all of it, between
-- expedition waves the demons rest but shots already fired keep flying, and
-- a broken guard holds missiles, ground and charges for a beat.
local AI = require('src.enemies.ai')
local Hazards = require('src.enemies.hazards')
local Projectiles = require('src.combat.projectiles')
local Explosives = require('src.combat.explosives')
local Capabilities = require('src.session.capabilities')
local BodyContact = require('src.combat.body_contact')
local Combat = {}
local demonsAct = Capabilities.demonsAct
Combat.demons = {
  name = 'demons',
  run = function(g, dt, _, frame)
    if demonsAct(g) then
      AI.demons(g, dt, frame.previousPlayer)
    end
  end,
}
Combat.separation = {
  name = 'separation',
  run = function(g, dt)
    if demonsAct(g) then
      AI.separate(g, dt)
    end
  end,
}
-- Demons that walked into the knight step back out of him.
Combat.bodies = {
  name = 'bodies',
  run = function(g)
    BodyContact.demons(g)
  end,
}
Combat.hazards = {
  name = 'hazards',
  run = function(g, dt, _, frame)
    if Capabilities.groundActs(g) then
      Hazards.update(g, dt, frame.previousPlayer)
    end
  end,
}
Combat.projectiles = {
  name = 'projectiles',
  run = function(g, dt, _, frame)
    if Capabilities.missilesFly(g) then
      Projectiles.update(g, dt, frame.previousPlayer)
    end
  end,
}
Combat.charges = {
  name = 'charges',
  run = function(g, dt)
    if Capabilities.missilesFly(g) and g.state == 'playing' then
      Explosives.update(g, dt)
    end
  end,
}
return Combat

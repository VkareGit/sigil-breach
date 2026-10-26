-- Roles of bodies by who plays and who watches (plan v10 V2): the one module
-- that names them, with no dependencies, so every rule can ask it.
--   controlled(g)  the knight the player controls (commands, camera, HUD)
--   viewer(g)      whose eyes the poses are seen from: a presented sample
--                  may name another (a second camera, a replay camera);
--                  else the controlled knight
local Roles = {}
function Roles.controlled(g)
  return g.player
end
-- Hand control to knight (a session restored from its save).
function Roles.control(g, knight)
  g.player = knight
end
function Roles.viewer(g)
  return g.viewer or g.player
end
return Roles

-- One physical radius for the sweep, contact receipt and painted projectile rim.
local defaults = require('src.content.combat_defaults').attacks
local Shape = {}
function Shape.defaultRadius(big)
  return big and defaults.bigBoltRadius or defaults.boltRadius
end
function Shape.radius(projectile)
  return projectile.radius or Shape.defaultRadius(projectile.big)
end
return Shape

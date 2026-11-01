-- Where the proving ground sets the knight (plan v10 V6: run/test_field.lua
-- split by responsibility): beside a seal of the map, at the Ember's trial
-- shop. Every function takes the field module (run/test_field.lua).
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Sanctuary = require('src.session.sanctuary')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Text = require('src.content.text')
local K = require('src.content.field')
local Observation = require('src.combat.observation')
local Intent = require('src.player.intent')
local Visits = {}
local distance = MathX.distance
-- Teleport is a simulation operation, even without an application transition.
-- Only the moved knight forgets shots seen/buffered at his previous place.
local function relocate(g, p, x, z, resetsHeight)
  local moved = p.x ~= x
    or p.z ~= z
    or (resetsHeight and ((p.jump or 0) ~= 0 or (p.crouch or 0) ~= 0))
  p.x, p.z = x, z
  if moved then
    Observation.invalidateActor(g, p)
    Intent.clear(g, p)
    g.view.presentationPrevious = nil
  end
end
-- Stand the knight on the first clear spot around the seal id, facing it.
function Visits.seal(field, g, id)
  if not g.testField then
    return false
  end
  local S = K.seal
  for _, s in ipairs(g.world.seals) do
    if s.id == tostring(id):lower() then
      local function clear(x, z)
        if W.solid(g.world, x, z, S.clearance) or not W.visible(g.world, x, z, s.x, s.z) then
          return false
        end
        for _, e in ipairs(Pools.of(g, 'enemies')) do
          if e.hp > 0 and distance(e, { x = x, z = z }) < S.crowd then
            return false
          end
        end
        return true
      end
      local x, z
      for _, radius in ipairs(S.radii) do
        for i = 0, S.around - 1 do
          local a = i * math.pi * 2 / S.around
          local tx, tz = s.x + math.sin(a) * radius, s.z + math.cos(a) * radius
          if not x and clear(tx, tz) then
            x, z = tx, tz
          end
        end
      end
      if not x then
        field.tell(g, 'field_seal_blocked')
        return false
      end
      local p = Roles.controlled(g)
      relocate(g, p, x, z, true)
      p.yaw = math.atan2(s.x - x, s.z - z)
      p.pitch = S.pitch
      p.vx, p.vz, p.jump, p.jumpV, p.crouch = 0, 0, 0, 0, 0
      p.dashTimer, p.slideTimer, p.jumpBuffer = 0, 0, 0
      g.view.presentationPrevious = nil
      field.tell(g, 'field_seal', { name = Text.get(s.name) })
      return true
    end
  end
  return false
end
-- The Ember's trial shop: the knight at the nave's foot facing it, the
-- trial purse full.
function Visits.shop(_, g)
  if not g.testField then
    return false
  end
  local p = Roles.controlled(g)
  local start = require('src.run.field.station_layout').get(g).start
  relocate(g, p, start.x, start.z)
  local shrine = Sanctuary.at(g)
  p.yaw = math.atan2(shrine.x - p.x, shrine.z - p.z)
  p.pitch = 0
  p.vx, p.vz = 0, 0
  g.run.wallet = K.wallet
  g.state = 'playing'
  g.map = false
  g.help = false
  g.shopMessage = Text.get('field_shop')
  return Sanctuary.openShop(g)
end
return Visits

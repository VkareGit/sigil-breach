local Spawn = require('src.session.spawn')
local Pools = require('src.session.world')
local Anchor = require('src.enemies.contact_anchor')
local Ground = require('src.physics.ground')
local Contact = require('src.enemies.attack_contact')
local Bodies = require('src.combat.bodies')
local Area = require('src.combat.area_contact')
local Stream = require('src.combat.stream')
local Garden = require('src.combat.garden')
local Dodge = require('src.combat.dodge')
local K = require('src.content.combat_defaults').attacks
local Kinds = {}
Kinds.stream = {
  execute = function(g, e, a, angle)
    Contact.face(g, e, a, angle)
    local mouth = Stream.shape(g, e, a)
    -- The painted mouth is off the body's centre. Aim from that source once;
    -- keep this bearing throughout the exhale when the target steps away.
    Contact.face(g, e, a, math.atan2(e.aimX - mouth.x, e.aimZ - mouth.z))
    e.streamHits = {}
  end,
  strike = function(g, e, a, dt, ctx)
    if ctx.before >= a.duration then
      return
    end
    local s = Stream.shape(g, e, a)
    Bodies.each(g, function(b)
      local key = b.id or 'knight'
      if e.streamHits[key] or not Bodies.harms(g, Bodies.side(g, e), b, 'hazard') then
        return false
      end
      local previous = b == Bodies.controlled(g) and ctx.previous or Bodies.previous(g, b)
      local point = Area.sample(g, b, previous, 1)
      local hit, receipt = Stream.test(g, s, b, point)
      local ghost = not hit and Dodge.afterimage(g, b)
      if hit then
        receipt.kind, receipt.id, receipt.owner, receipt.target = 'stream', a.id, e.id, b.id
        receipt.time, receipt.fraction = dt, 1
        g:damageBody(b, a.packet.base, e.x, e.z, a.packet, e, { contact = receipt })
        e.streamHits[key] = true
      elseif ghost and Stream.test(g, s, b, ghost) then
        Dodge.perfect(g, a.packet, e, b)
        e.streamHits[key] = true
      end
      return false
    end)
  end,
}
Kinds.sow = {
  available = function(g, e, a)
    return not a.needsSpace or (g and Garden.count(g, e.id, a.deposit.group) < a.deposit.limit)
  end,
  execute = function(g, e, a, angle)
    Contact.face(g, e, a, angle)
    local x, y, z = Anchor.point(g, e, e.phase, e.x, e.z, a.anchor)
    x, y, z = x or e.x, Ground.of(g.world, e) + (y or a.height), z or e.z
    for _, mark in ipairs(a.marks) do
      local room = Garden.count(g, e.id, a.deposit.group) < a.deposit.limit
      if room or not a.needsSpace then
        local tx = e.aimX + math.sin(angle) * mark.forward + math.cos(angle) * mark.lateral
        local tz = e.aimZ + math.cos(angle) * mark.forward - math.sin(angle) * mark.lateral
        local dx, dz = tx - x, tz - z
        local length = math.sqrt(dx * dx + dz * dz)
        local time = math.max(K.seedMinFlight, length / a.speed)
        local targetY = Ground.height(g.world, tx, tz, e.aimLevel) + a.radius
        Spawn.make(g, 'projectile', {
          x = x,
          y = y,
          z = z,
          vx = dx / time,
          vz = dz / time,
          vy = (targetY - y) / time + a.gravity * time * 0.5,
          gravity = a.gravity,
          life = K.boltLife,
          radius = a.radius,
          color = a.color,
          packet = a.packet,
          owner = e.id,
          side = Bodies.side(g, e),
          art = a.art,
          deposit = room and a.deposit or nil,
        })
      end
    end
  end,
}
Kinds.harvest = {
  unseen = true,
  available = Garden.available,
  commit = function(g, e, a)
    e.harvestMarks = {}
    for _, h in ipairs(Pools.of(g, 'hazards')) do
      if Garden.eligible(g, e, a, h) and h.life > e.windupDuration + a.life then
        e.harvestMarks[#e.harvestMarks + 1] = h
        h.harvest = { attack = a.id, radius = a.radius, duration = e.windupDuration }
      end
    end
  end,
  execute = function(g, e, a, angle)
    Contact.face(g, e, a, angle)
    for _, h in ipairs(e.harvestMarks or {}) do
      if h and h.harvest and h.owner == e.id and h.life > 0 then
        h.radius, h.volume, h.packet = a.radius, a.volume, a.packet
        h.condition = nil
        h.delay, h.maxDelay, h.pulse, h.interval, h.life = 0, 0, 0, a.life, a.life
        h.harvest, h.erupting, h.art = nil, true, a.art
      end
    end
    e.harvestMarks = nil
  end,
}
return Kinds

-- Energy belongs to the presentation, never to a body's alpha or hit mask.
local Surface = require('src.enemies.surface')
local Anchor = require('src.enemies.contact_anchor')
local ActionPhase = require('src.enemies.action_phase')
local Rites = require('src.content.art.rites')
local HazardArt = require('src.render.hazard_art')
local Ground = require('src.physics.ground')
local Context = require('src.session.context')
local Archetypes = require('src.content.enemies')
local Accents = {}
local Painters = require('src.render.painters')
local posed = {}
local function centre(g, e, id)
  local p = Surface.prepare(g, e, posed)
  return Surface.centre(p, id)
end

function Accents.draw(r, g, e, effects)
  local spec = e.attackSpec
  if e.hp <= 0 then
    return false
  end
  if Painters.cast(r, g, e) then
    return true
  end
  local look = Archetypes.look(e)
  local evading = look.evadeArt and e.ai == 'move' and (e.evadeTime or 0) > 0
  local slipping = spec and spec.kind == 'blink' and e.ai == 'windup'
  if evading or slipping then
    local viewer = Context.viewer(g)
    local progress = slipping and ActionPhase.sample(e)
      or (1 - e.evadeTime / Archetypes.of(e).move.evade.time)
    HazardArt.upright(
      r,
      e.x,
      Ground.of(g.world, e) + Rites.accents.evadeLift,
      e.z,
      slipping and HazardArt.sequence(Rites.blink.prepare, progress)
        or (progress < Rites.accents.feathers and 'fragments' or 'feathers'),
      Rites.accents.evadeSize,
      math.atan2(viewer.x - e.x, viewer.z - e.z),
      1
    )
    return true
  end
  if not spec then
    return false
  end
  local windup = e.ai == 'windup'
  local cast = look.cast and Rites.casts[look.cast.sequence]
  local permitted = not look.casts or look.casts.all or look.casts[spec.id]
  if cast and permitted and (windup or e.ai == 'strike') then
    local t = ActionPhase.sample(e)
    local age = e.phase or 0
    if not windup and spec.kind == 'salvo' then
      age = age - math.max(0, (e.act and e.act.released or 1) - 1) * spec.interval
    end
    local alpha = windup and 1 or math.max(0, 1 - age / cast.release)
    local viewer = Context.viewer(g)
    local yaw = math.atan2(viewer.x - e.x, viewer.z - e.z)
    local size = look.cast.size * (windup and (cast.minScale + (1 - cast.minScale) * t) or 1)
    for _, hand in ipairs(cast.anchors) do
      local x, y, z = Anchor.point(g, e, e.phase or 0, e.x, e.z, hand, viewer)
      if x and alpha > 0 then
        HazardArt.upright(
          r,
          x + math.sin(yaw) * cast.forward,
          Ground.of(g.world, e) + y - size * 0.5,
          z + math.cos(yaw) * cast.forward,
          HazardArt.sequence(cast.frames, windup and t or 1),
          size,
          yaw,
          alpha
        )
      end
    end
    return true
  end
  if Rites.antlerCasts[spec.id] and (windup or e.ai == 'strike') then
    local t = ActionPhase.sample(e)
    local A = Rites.accents
    local charge = windup and t or math.max(0, 1 - (e.phase or 0) / A.glow)
    if not windup and spec.kind == 'storm' then
      -- These are the marking instants, not the later strikes of each ground mark.
      local beat = (e.phase or 0) % spec.interval
      charge = math.max(0, 1 - beat / A.glow)
    end
    local x, y, z = centre(g, e, 'antlers')
    if x then
      local p = posed
      local storm = Rites.lightnings[spec.art]
      if storm then
        local viewer = Context.viewer(g)
        local size = storm.hornSize * (A.hornBase + charge * A.hornGrow)
        for _, side in ipairs({ -A.hornSpread, A.hornSpread }) do
          HazardArt.upright(
            r,
            x + p.rx * side,
            y - size * A.hornDrop,
            z + p.rz * side,
            HazardArt.sequence(storm.frames, charge),
            size,
            math.atan2(viewer.x - x, viewer.z - z),
            A.hornAlpha + charge * A.hornAlphaGrow
          )
        end
        return true
      end
      for i = 1, 4 do
        local side = (i - 2.5) * A.sparkSpacing -- constant: four sparks centred
        effects.spell(
          r,
          g,
          0,
          math.floor(charge * 3) / 3,
          x + p.rx * side,
          y + (i % 2) * A.sparkLift,
          z + p.rz * side,
          A.sparkSize,
          1,
          false
        )
      end
    end
    return true
  end
  return false
end
return Accents

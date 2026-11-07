-- What a trigger pull looks and sounds like ('present' listeners of
-- ShotFired and VolleyResolved): recoil, flash, powder, surface marks,
-- trails, damage numbers, the hitmarker and the named rules. The shot itself
-- (rounds, cadence, pellets, damage) is resolved in combat/combat.lua.
local Capabilities = require('src.session.capabilities')
local Medals = require('src.feedback.medals')
local Audio = require('src.audio.audio')
local Weapons = require('src.content.weapons')
local FX = require('src.feedback.effects')
local Ballistics = require('src.combat.ballistics')
local Impact = require('src.feedback.impact_response')
local Trails = require('src.feedback.shot_trails')
local Weight = require('src.feedback.weight')
local DamageNumbers = require('src.feedback.damage_numbers')
local K = require('src.content.tuning').shot
local Materials = require('src.content.ballistic_surfaces')
local Pools = require('src.session.world')
local Context = require('src.session.context')
local Recipient = require('src.feedback.recipient')
local Shot = {}
-- The debris of a body surface that stops a shot without a wound (the
-- margrave's cleaver): its material's, none for a soft one.
local function debris(material)
  return Materials[material] and Materials[material].debris
end
-- ShotFired: { profile, shotPower }
function Shot.discharge(g, e)
  local p, fire = Recipient.actor(g, e.actor), e.profile.fire
  if not p then
    return
  end
  local personal = Recipient.context(g, p)
  if personal then
    personal.view.shotPower = e.shotPower
    personal.view.muzzle = fire.muzzle
    personal.view.shake = fire.shake
    personal.view.flashColor = { fire.flash[1], fire.flash[2], fire.flash[3] }
    -- Recoil belongs to the firing actor, never to whichever view renders next.
    Weight.shot(personal, Weapons.inHand(g, nil, p) or e.profile, e.shotPower or 1)
  end
  local volume = fire.volume + fire.volumePower * e.shotPower
  if Context.isControlled(g, p) then
    Audio.play(fire.sound, volume)
  else
    Audio.playAt(fire.sound, p.x, p.z, Context.viewer(g), volume)
  end
  -- Powder hangs where it was fired, then rises; the revolver gets a smaller
  -- wisp. Clip the emitter before cover so a close wall cannot swallow it.
  local fx, fy, fz = Ballistics.direction(p.yaw, p.pitch)
  local ox, oy, oz = Ballistics.origin(g, p)
  local cover = Ballistics.world(g.world, ox, oy, oz, fx, fy, fz, K.smokeReach)
  local muzzleDistance = math.min(K.smokeMax, math.max(K.smokeMin, cover - K.smokeClearance))
  FX.emit(
    g,
    'smoke',
    ox + fx * muzzleDistance,
    oy + fy * muzzleDistance - K.smokeDrop,
    oz + fz * muzzleDistance,
    fire.smoke,
    { vx = fx * K.smokeDrift, vy = K.smokeRise, vz = fz * K.smokeDrift, duration = fire.smokeTime }
  )
end
-- The surfaces struck and the trails of every pellet.
local function rays(g, e)
  local report, fire = e.report, e.profile.fire
  local marked = {}
  for i, ray in ipairs(report.rays) do
    if ray.target and ray.part and not ray.corpse and not marked[ray.target] then
      for _, hit in ipairs(report.hitTargets) do
        if hit.id == ray.target then
          local blood = hit.healthDamage > 0 and not debris(ray.material)
          Impact.contact(g, ray, blood, hit.healthDamage + hit.armorAbsorbed)
          marked[ray.target] = true
          break
        end
      end
    end
    if not ray.target and ray.kind ~= 'range' then
      ray.response = Impact.surface(g, e.attack, {
        x = ray.x,
        y = ray.y,
        z = ray.z,
        dx = ray.dx,
        dy = ray.dy,
        dz = ray.dz,
        distance = ray.distance,
        normal = ray.normal,
        kind = ray.kind,
        seed = ray.seed,
      }, i % fire.surfaceEvery == 0)
    elseif ray.corpse and i % fire.surfaceEvery == 0 then
      local body = Pools.get(g, ray.target)
      if body then
        -- Cosmetic wound on a falling corpse; never another HP transaction.
        Impact.body(
          g,
          body,
          { ray.x, ray.y, ray.z },
          Impact.retained(e.attack, ray.distance),
          0,
          ray
        )
      end
    elseif ray.target and ray.part == false and debris(ray.material) then
      Impact.solid(g, Impact.retained(e.attack, ray.distance), {
        x = ray.x,
        y = ray.y,
        z = ray.z,
        dx = ray.dx,
        dy = ray.dy,
        dz = ray.dz,
        normal = ray.normal,
        seed = ray.seed,
        kind = 'body',
      }, debris(ray.material), i % fire.surfaceEvery == 0)
    end
    if i % fire.trailEvery == 0 then
      Trails.emit(g, report.origin, ray.dx, ray.dy, ray.dz, ray.trail, fire.heavy)
    end
  end
end
-- VolleyResolved: { report, results, attack, profile }
function Shot.volley(g, e)
  local report, results = e.report, e.results
  rays(g, e)
  for i, detail in ipairs(report.hitTargets) do
    local result = results[i]
    -- Where effort is paid the sum stands on the target's bar (ui/hud.lua).
    if not Capabilities.attrition(g) then
      DamageNumbers.add(
        g,
        detail.point,
        detail.healthDamage,
        detail.killed,
        detail.headHits > 0,
        detail.absorbed > detail.damage * 0.5,
        result.staggered,
        result.wounded,
        result.counter,
        result.crippled or result.tripped
      )
    end
  end
  local personal = Recipient.context(g, report.actor)
  if not personal then
    return
  end
  g = personal
  g.view.armorHit = report.blocked > report.damage * K.armorShare
  g.view.shotReport = report
  g.view.precisionHit = report.headHits > 0
  g.view.lastDamage = math.floor(report.healthDamage + 0.5)
  g.view.lastKill = report.kills > 0
  g.view.hitWeight = math.min(1, report.maxHealthDamage / K.heavyDamage)
  g.view.hitmarker = 0
  if report.targets == 0 then
    return
  end
  g.view.hitmarker = K.hitmarker + g.view.hitWeight * K.hitmarkerWeight
  -- Heavy flesh hits and kills land in the frame itself, not only in the reticle.
  g.view.shake = math.max(g.view.shake or 0, K.hitShake + g.view.hitWeight * K.hitShakeWeight)
  if report.kills > 0 then
    g.view.killPunch = K.killPunch
  end
  if report.kills > 0 then
    -- Longer than a hit: he can stop shooting.
    g.view.hitmarker = math.max(g.view.hitmarker, K.killHitmarker)
    g.view.killPop = K.killPop
  end
  if report.kills >= 2 then
    Medals.show(g, 'one_shot')
  elseif report.kills > 0 and report.headHits > 0 then
    Medals.show(g, 'smitten')
  end
  for _, result in ipairs(results) do
    if result.parried then
      Medals.show(g, 'parry')
    end
  end
  Weight.confirm(
    g,
    report,
    results,
    g.view.armorHit and 'hit_armor' or 'hit_tick',
    K.tickVolume + g.view.hitWeight * K.tickWeight
  )
end
return Shot

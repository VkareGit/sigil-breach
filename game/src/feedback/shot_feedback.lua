-- What a trigger pull looks and sounds like ('present' listeners of
-- ShotFired and VolleyResolved): recoil, flash, powder, surface marks,
-- trails, damage numbers, the hitmarker and the named rules. The shot itself
-- (rounds, cadence, pellets, damage) is resolved in combat/combat.lua.
local A = require('src.audio.audio')
local Weapons = require('src.content.weapons')
local FX = require('src.feedback.effects')
local B = require('src.combat.ballistics')
local Impact = require('src.feedback.impact_response')
local Trails = require('src.feedback.shot_trails')
local Weight = require('src.feedback.weight')
local Numbers = require('src.feedback.damage_numbers')
local K = require('src.content.tuning').shot
local Materials = require('src.content.ballistic_surfaces')
local Pools = require('src.session.world')
local Text = require('src.content.text')
local Shot = {}
-- The debris of a body surface that stops a shot without a wound (the
-- margrave's cleaver): its material's, none for a soft one.
local function debris(material)
  return Materials[material] and Materials[material].debris
end
-- ShotFired: { profile, shotPower }
function Shot.discharge(g, e)
  local p, fire = g.player, e.profile.fire
  g.view.shotPower = e.shotPower
  g.view.muzzle = fire.muzzle
  g.view.shake = fire.shake
  g.view.flashColor = { fire.flash[1], fire.flash[2], fire.flash[3] }
  -- Recoil from the weapon in hand: its own profile (mass, momentum).
  Weight.shot(g, Weapons.inHand(g) or Weapons.profile(1, g), g.view.shotPower or 1)
  A.play(fire.sound, fire.volume + fire.volumePower * g.view.shotPower)
  -- Powder hangs where it was fired, then rises; the revolver gets a smaller
  -- wisp. Clip the emitter before cover so a close wall cannot swallow it.
  local fx, fy, fz = B.direction(p.yaw, p.pitch)
  local ox, oy, oz = B.origin(g)
  local cover = B.world(g.world, ox, oy, oz, fx, fy, fz, K.smokeReach)
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
  for i, ray in ipairs(report.rays) do
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
    Numbers.add(
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
  if g.view.armorHit then
    A.play('shell', 0.22)
  end
  g.view.hitmarker = K.hitmarker + g.view.hitWeight * K.hitmarkerWeight
  -- Heavy flesh hits and kills land in the frame itself, not only in the reticle.
  g.view.shake = math.max(g.view.shake or 0, K.hitShake + g.view.hitWeight * K.hitShakeWeight)
  if report.kills > 0 then
    g.view.killPunch = K.killPunch
  end
  A.play(
    report.maxHealthDamage >= K.heavyHitSound and 'heavyhit'
      or (report.maxHealthDamage < K.grazeSound and 'graze' or 'hit'),
    0.22 + g.view.hitWeight * 0.28
  )
  if report.kills >= 2 then
    g.view.feedback = Text.get('feedback_multikill', { count = report.kills })
    g.view.feedbackTimer = 2
    A.play('multikill', 0.34)
  end
  Weight.confirm(g, report, results)
end
return Shot

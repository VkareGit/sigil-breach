local F = require('tests.support.fixtures')
local T = {}
function T.run(G, renderer)
  local Surface = require('src.enemies.surface')
  local B = require('src.combat.ballistics')
  local FX = require('src.feedback.effects')
  local lines = {}
  local check = F.checker(lines, 'hit feedback: ', 'hit feedback: ')
  for _, slot in ipairs({ 1, 2 }) do
    local g = F.arena(G)
    g.player.weapon, g.player.cooldown = slot, 0
    local e = g:spawn('imp', 16, 19)
    e.spawnAge, e.dummy, e.facing = 2, true, 0
    local x, y, z = Surface.locateZone(Surface.prepare(g, e), 'torso')
    local ox, oy, oz = B.origin(g)
    g.player.yaw = math.atan2(x - ox, z - oz)
    g.player.pitch = math.atan2(y - oy, math.sqrt((x - ox) ^ 2 + (z - oz) ^ 2))
    assert(g:shoot())
    local contact, ray
    for _, effect in ipairs(g.view.effects) do
      if effect.kind == 'contact_blood' then
        contact = effect
      end
    end
    for _, candidate in ipairs(g.view.shotReport.rays) do
      if candidate.target == e.id and candidate.part then
        ray = candidate
        break
      end
    end
    check(
      'weapon ' .. slot .. ' marks an actual pellet contact immediately',
      contact
        and ray
        and math.abs(contact.x - ray.x) < 0.03
        and math.abs(contact.y - ray.y) < 0.03
        and math.abs(contact.z - ray.z) < 0.03
        and FX.profile(contact).alpha >= 0.9
    )
    for _ = 1, 4 do
      g:update(1 / 120, {})
    end
    check(
      'weapon ' .. slot .. ' keeps the body flash through the second 30 Hz sample',
      renderer.tell(e) >= 0.60
    )
    check('the compact contact survives that second sample', contact.age < contact.duration)
  end
  local g = F.arena(G)
  g.player.weapon, g.player.yaw, g.player.pitch = 2, math.pi / 2, -0.4
  assert(g:shoot())
  local ray, mark = g.view.shotReport.rays[1], g.view.surfaceMarks[1]
  local contact
  for _, effect in ipairs(g.view.effects) do
    if effect.kind == 'contact_stone' then
      contact = effect
    end
  end
  check(
    'a miss has a compact impact and a persistent scar at its actual surface',
    not ray.target
      and mark
      and contact
      and math.abs(mark.x - ray.x) < 0.1
      and math.abs(mark.z - ray.z) < 0.1
      and math.abs(contact.x - ray.x) < 0.1
      and math.abs(contact.z - ray.z) < 0.1
      and g.view.hitmarker == 0
  )
  -- A hit that is not a shot (a charge, a rite, a field) is confirmed from its
  -- own outcome, taken when it landed: nothing of an earlier shot's mark stays,
  -- and presentation, run after the step, never reads a later state of the body.
  do
    local Outcomes = require('src.session.damage_outcomes')
    local heavy = require('src.content.tuning').shot.heavyDamage
    local h = F.arena(G)
    local imp = h:spawn('imp', 16, 19)
    imp.spawnAge, imp.dummy = 2, true
    imp.hp, imp.maxHp = 100, 100
    -- What a heavy shot on armour left on the mark.
    h.view.armorHit, h.view.hitWeight, h.view.lastKill = true, 0.9, true
    h.bus.stepping = true
    Outcomes.enemy(h, imp, 20, 'charge', nil, h.player.id)
    h.bus:flush()
    check(
      "a charge's hit is marked by itself: no armour mark and the weight of its own 20 HP",
      h.view.hitmarker > 0
        and h.view.armorHit == false
        and math.abs(h.view.hitWeight - math.min(1, 20 / heavy)) < 1e-9
        and h.view.lastKill == false
    )
    -- Two hits in one step: the first is read as it landed, not after the second.
    local other = h:spawn('imp', 18, 19)
    other.spawnAge, other.dummy = 2, true
    other.hp, other.maxHp = 100, 100
    h.view.damageTrail = nil
    -- A later step (the hits of one step are one confirmation).
    h.elapsed = h.elapsed + 1 / 120
    h.bus.stepping = true
    Outcomes.enemy(h, other, 10, 'charge', nil, h.player.id)
    Outcomes.enemy(h, other, 80, 'charge', nil, h.player.id)
    h.bus:flush()
    local trail = h.view.damageTrail
    check(
      'two hits in one step: the trail starts from the health before the first and ends at 10',
      trail
        and trail.shown == 100
        and trail.hp == 10
        and trail.sum == 90
        and h.view.lastKill == false
    )
    -- A step whose blast kills one body and wounds another confirms the kill.
    h.elapsed = h.elapsed + 1 / 120
    local a, b = h:spawn('imp', 15, 21), h:spawn('imp', 17, 21)
    for _, e in ipairs({ a, b }) do
      e.spawnAge, e.dummy, e.hp, e.maxHp = 2, true, 30, 30
    end
    h.bus.stepping = true
    Outcomes.enemy(h, a, 40, 'charge', nil, h.player.id)
    Outcomes.enemy(h, b, 5, 'charge', nil, h.player.id)
    h.bus:flush()
    check(
      'one step that kills one body and wounds another confirms the kill',
      h.view.lastKill == true and math.abs(h.view.hitWeight - math.min(1, 30 / heavy)) < 1e-9
    )
  end
  return lines
end
return T

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
  return lines
end
return T

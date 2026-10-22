local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'v16 ', '')
  require('tests.cases.animation').run(G, check)
  require('tests.cases.typography').run(check)
  local Art = require('src.render.weapon_art')
  local V = require('src.render.weapon')
  local Reload = require('src.combat.reload')
  for slot = 1, 2 do
    local m = Art[Art.ids[slot]]
    local data = love.image.newImageData(m.path)
    check(
      'weapon ' .. slot .. ' uses its explicit active atlas manifest',
      V.paths[Art.ids[slot]] == m.path
        and data:getWidth() == m.width
        and data:getHeight() == m.height
        and #m.frames == 16
    )
    for index, frame in ipairs(m.frames) do
      local r = frame.rect
      local grip = frame.grip
      local muzzle = frame.muzzle
      check(
        'weapon ' .. slot .. ' frame ' .. index .. ' has registered grip and muzzle inside its crop',
        r[1] >= 0
          and r[2] >= 0
          and r[1] + r[3] <= m.width
          and r[2] + r[4] <= m.height
          and grip[1] >= 0
          and grip[1] < r[3]
          and grip[2] > 0
          and grip[2] <= r[4]
          and muzzle[1] >= 0
          and muzzle[1] < r[3]
          and muzzle[2] >= 0
          and muzzle[2] < r[4]
      )
      local top, bottom = 0, 0
      for x = r[1], r[1] + r[3] - 1 do
        local _, _, _, a = data:getPixel(x, r[2])
        top = top + (a > 0.6 and 1 or 0)
        local _, _, _, b = data:getPixel(x, r[2] + r[4] - 1)
        bottom = bottom + (b > 0.6 and 1 or 0)
      end
      check(
        'weapon ' .. slot .. ' frame ' .. index .. ' row gutters do not cut the painted silhouette',
        top < 4 and bottom < 4
      )
    end
    data:release()
    local g = G.new('classic')
    g.testing = true
    g.state = 'playing'
    g.weapon = slot
    g.view.shotAge = 10
    g.player.arsenal.exorcist.mag = 0
    g.player.arsenal.exorcist.reserve = 1
    g.player.arsenal.judge.mag = 0
    g.player.arsenal.judge.reserve = 3
    assert(Reload.start(g, true))
    local close = slot == 1 and 0.82 or 1.55
    Reload.update(g, close - 1e-5)
    local before = V.sourceFrame(g)
    Reload.update(g, 2e-5)
    local after = V.sourceFrame(g)
    check(
      'weapon ' .. slot .. ' visual latch changes at the physical commit',
      (slot == 1 and before == 14 and after == 15) or (slot == 2 and before == 12 and after == 13)
    )
    Reload.cancel(g)
    require('src.content.weapons').state(g, slot).open = true
    check(
      'weapon ' .. slot .. ' cancelled open reload stays visibly open',
      V.sourceFrame(g) == 8 or V.sourceFrame(g) == 12
    )
    g.player.arsenal.exorcist.open = false
    g.player.arsenal.judge.open = false
    g.view.shotAge = 0.02
    check(
      'weapon ' .. slot .. ' discharge selects the authored recoil and attached powder',
      V.sourceFrame(g) == 2 and V.muzzlePhase(g) ~= nil
    )
    g.reload = 0
    g.reloadWeapon = nil
    g.view.shotAge = 10
    g.player.arsenal.exorcist.mag = 0
    g.player.arsenal.exorcist.reserve = 2
    g.player.arsenal.judge.mag = 0
    g.player.arsenal.judge.reserve = 6
    assert(Reload.start(g, true))
    local honest = true
    for _ = 1, math.ceil((slot == 1 and 0.94 or 1.85) * 240) + 2 do
      local frame = V.sourceFrame(g)
      local action = m.frames[frame].action
      local p = g.player
      local opened = slot == 1 and p.arsenal.exorcist.open or slot == 2 and p.arsenal.judge.open
      if action == 'loaded' then
        honest = honest
          and (slot == 1 and p.arsenal.exorcist.mag > 0 or slot == 2 and p.arsenal.judge.loaded)
      end
      if slot == 1 and frame == 15 or slot == 2 and frame >= 13 then
        honest = honest and not opened
      end
      Reload.update(g, 1 / 240)
    end
    check(
      'weapon ' .. slot .. ' sampled art never precedes ammunition or latch transactions',
      honest
    )
  end
  return lines
end
return Tests

-- Plan v7: independently authored source-image landmarks, checked in live
-- poses from 3, 8 and 16 m. All original coordinates are retained; H3-H5
-- defects are now positive regressions, including non-flesh materials.
local Fixtures = require('tests.support.fixtures')
local T = {}
function T.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'hit landmarks: ', 'hit landmarks: ')
  local Landmarks = require('qa.hit_landmarks')
  local results = Landmarks.run(G, renderer)
  local frames, reached, onPaint, judged, pending = {}, 0, 0, 0, 0
  for _, r in ipairs(results) do
    local entry, point = r.entry, r.point
    local name = entry.kind .. ' frame ' .. entry.frame .. ' ' .. point[4]
    if not frames[entry] then
      frames[entry] = true
      check(
        entry.kind .. ' frame ' .. entry.frame .. ' is shown live after a ' .. entry.via,
        r.reached and r.image
      )
      reached = reached + 1
    end
    local painted = point[3] ~= 'air'
    check(
      name .. ' lies on its painting as drawn (' .. (painted and 'pigment' or 'air') .. ')',
      painted and (r.alpha >= 0.65 and r.drawn ~= 'air' and not r.edge)
        or (not painted and r.alpha <= 0.05 and r.drawn == 'air' and not r.edge)
    )
    onPaint = onPaint + 1
    if r.ok ~= nil then
      judged = judged + 1
      if point[5] then
        pending = pending + 1
        check(name .. ' is still a known defect (plan v7 ' .. point[5] .. ')', r.ok == false)
      else
        check(name .. ' meets ' .. point[3] .. ' from 3, 8 and 16 m', r.ok)
      end
    end
  end
  check(
    string.format(
      '%d live frames, %d landmarks on their painting, %d judged, %d pending a later stage',
      reached,
      onPaint,
      judged,
      pending
    ),
    reached > 0 and judged > pending
  )
  -- Known defects measured by the H0 review (hit-engine.txt), held here so
  -- the stage that removes one also changes its check.
  local Field = require('src.run.test_field')
  local B = require('src.combat.ballistics')
  local Geometry = require('src.enemies.geometry')
  local g = Field.new(G)
  g.ephemeral = true
  local p = g.player
  local e = g:spawn('imp', p.x + math.sin(p.yaw) * 0.5, p.z + math.cos(p.yaw) * 0.5)
  e.spawnAge = 1
  local ox, oy, oz = B.origin(g)
  local d, part = B.body(g, e, ox, oy, oz, -math.sin(p.yaw), 0, -math.cos(p.yaw), 1000)
  check(
    'H3: a close thrall cannot be hit by shooting away from its painted body',
    d == nil and part == nil
  )
  local Surface = require('src.enemies.surface')
  local probe = { mode = 'field', player = { x = 0, z = 8 }, time = 0, testField = {} }
  local body = { kind = 'boss', id = 7, hp = 100, x = 0, z = 0, previewFrame = 9 }
  local _, before = Surface.locate(Surface.prepare(probe, body), 'head')
  Geometry.register('boss', renderer.frames.boss, renderer.feet.boss)
  local _, after = Surface.locate(Surface.prepare(probe, body), 'head')
  check(
    'H1: authored geometry is identical before and after validating renderer frame metadata',
    before ~= nil and before == after
  )
  return lines
end
return T

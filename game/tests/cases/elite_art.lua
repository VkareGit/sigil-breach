-- New pigment must remain a real hittable painting. Normalized poses are
-- checked separately from the action-duration integration owned by P1b.
local F = require('tests.support.fixtures')
local T = {}
function T.run(G)
  local Anim = require('src.enemies.animation')
  local A = require('src.content.enemies')
  local Poses = require('src.content.art.poses')
  local Surface = require('src.enemies.surface')
  local Schema = require('src.core.schema')
  local lines = {}
  local check = F.checker(lines, 'elite art: ', 'elite art: ')
  for _, kind in ipairs({ 'boss', 'furfur' }) do
    local g = F.arena(G)
    local e = g:spawn(kind, 16, 18)
    e.spawnAge, e.ai, e.phase = 1, 'hurt', 0
    e.archetype = Schema.copy(A.of(e))
    for _, duration in ipairs({ 0.6, 1.2, 1.6 }) do
      e.archetype.body.breakTime = duration
      e.conditions.exposed, e.stun = duration * 0.6, duration * 0.6
      e.phase = duration * 0.4
      local frame, _, lean, _, sy = Anim.pose(g, e)
      g.time = g.time + 20
      local other, _, lean2, _, sy2 = Anim.pose(g, e)
      check(
        kind .. ' exhaustion follows the window, not wall time ' .. duration,
        frame == other
          and lean == lean2
          and sy == sy2
          and math.abs(Anim.exposedProgress(e) - 0.4) < 1e-8
      )
      e.phase = 0
      check(
        kind .. ' another hit cannot restart the guard breath ' .. duration,
        Anim.pose(g, e) == frame
      )
    end
    local poses = Anim.poses(e)
    check(
      kind .. ' has three distinct pain and recovery paintings',
      #poses.pain.frames >= 3 and #poses.recover.frames >= 3 and #poses.exposed.frames >= 3
    )
    -- Every new frame gets a real head and torso ray, using its own mask.
    local first = kind == 'boss' and 21 or 29
    g.mode, g.testField = 'field', {}
    for frame = first, Anim.frameCount(kind) do
      e.previewFrame = frame
      local p = Surface.prepare(g, e, {})
      check(kind .. ' preview selects frame ' .. frame, p.frame == frame)
      if p.frame == frame then
        for _, zone in ipairs({ 'head', 'torso' }) do
          local found = false
          for v = 0.05, 0.95, 0.025 do
            for u = 0.05, 0.95, 0.025 do
              local x, y, z = Surface.point(p, u, v)
              local _, hit = Surface.ray(p, x + p.nx * 3, y, z + p.nz * 3, -p.nx, 0, -p.nz, 4)
              if hit == zone then
                found = true
                break
              end
            end
            if found then
              break
            end
          end
          check(kind .. ' frame ' .. frame .. ' carries ' .. zone, found)
        end
      end
    end
  end
  local g = F.arena(G)
  local e = g:spawn('furfur', 16, 18)
  local storm = Anim.posed(e, 'strike.storm-steps')
  local duration = 4 * 0.42 + 0.4
  for i = 0, 4 do
    check('storm marking accent ' .. (i + 1), Poses.frame(storm, i * 0.42 / duration + 1e-8) == 31)
  end
  -- A real release is deferred until after the hazard clock advances. The
  -- afterimage must survive that ordering without extending damage geometry.
  local Actions = require('src.enemies.actions')
  local Hazards = require('src.enemies.hazards')
  local RiteFeedback = require('src.feedback.rite_feedback')
  local Golden = require('qa.golden')
  g = F.arena(G)
  e = g:spawn('stolas', 16, 18)
  local ray
  for _, spec in ipairs(A.of(e).attacks) do
    if spec.id == 'star-lance' then
      ray = spec
    end
  end
  Actions.begin(g, e, 7, ray)
  g.elapsed = 1 / 120
  g.bus:beginStep()
  Actions.execute(g, e)
  local hazard = g.hazards[#g.hazards]
  Hazards.update(g, 1 / 120)
  check('ray warning advances before presentation', hazard.delay < hazard.maxDelay)
  local digest = Golden.digest(g)
  g.bus:flush()
  check('deferred ray release creates one afterimage', #(g.view.riteBursts or {}) == 1)
  check('ray presentation leaves simulation unchanged', Golden.digest(g) == digest)
  local burst = g.view.riteBursts[1]
  check('ray flare starts at the remaining hazard clock', math.abs(burst.starts - ray.delay) < 1e-8)
  g.elapsed = ray.delay + 0.06
  Hazards.update(g, ray.delay + 0.06)
  RiteFeedback.update(g)
  check('flame can outlive the brief damage ray', #g.hazards == 0 and #g.view.riteBursts == 1)
  g.elapsed = burst.starts + 0.33
  RiteFeedback.update(g)
  check('ray fragments expire without a hazard', #g.view.riteBursts == 0)
  return lines
end
return T

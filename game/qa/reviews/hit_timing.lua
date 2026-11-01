-- Measure the last presented pose at actual trigger events under different
-- render schedules. Uses the application's fixed-step/interpolation sequence;
-- reported delays are observations, not an assertion of perfect synchrony.
local Field = require('src.run.test_field')
local Presentation = require('src.render.presentation')
local Review = {}
local STEP = 1 / 120
local schedules = {
  { name = '30', dt = { 1 / 30 } },
  { name = '60', dt = { 1 / 60 } },
  { name = '120', dt = { 1 / 120 } },
  { name = '144', dt = { 1 / 144 } },
  { name = '240', dt = { 1 / 240 } },
  { name = 'jitter', dt = { 0.007, 0.033, 0.012, 0.055 } },
}
function Review.run(G, truth, output)
  local lines = {
    'kind,render_schedule,shots,max_root_difference_m,mean_root_difference_m,changed_painted_frame,max_steps_per_render',
  }
  for _, kind in ipairs({ 'imp', 'stolas', 'boss', 'furfur' }) do
    for _, schedule in ipairs(schedules) do
      local g = Field.new(G)
      g.testing = true
      local enemy = Field.spawn(g, kind, 1)[1]
      Field.close(g)
      -- A durable test target keeps this observation about timing rather
      -- than ending the sample after a different number of kills.
      enemy.hp = 1000000
      g:switchWeapon(2)
      local last = truth:place(g, enemy, {})
      local count, maximum, sum, changed, maxSteps = 0, 0, 0, 0, 0
      g.bus:on('sim', 'ShotFired', function()
        local now = truth:place(g, enemy, {})
        local d =
          math.sqrt((now.x - last.x) ^ 2 + (now.z - last.z) ^ 2 + (now.baseY - last.baseY) ^ 2)
        count, sum, maximum = count + 1, sum + d, math.max(maximum, d)
        changed = changed + (now.key ~= last.key and 1 or 0)
      end)
      local accumulator, wallTime, frame = 0, 0, 0
      while wallTime < 6 do
        frame = frame + 1
        local dt = schedule.dt[(frame - 1) % #schedule.dt + 1]
        wallTime, accumulator = wallTime + dt, math.min(0.20, accumulator + dt)
        local steps = 0
        while accumulator >= STEP do
          Presentation.capture(g)
          g:update(STEP, { shoot = true })
          accumulator, steps = accumulator - STEP, steps + 1
        end
        maxSteps = math.max(maxSteps, steps)
        local shown = Presentation.sample(g, accumulator / STEP)
        last = truth:place(shown, shown.enemies[1], {})
      end
      assert(count > 0, 'timing observation did not fire: ' .. kind .. '/' .. schedule.name)
      lines[#lines + 1] = string.format(
        '%s,%s,%d,%.6f,%.6f,%d,%d',
        kind,
        schedule.name,
        count,
        maximum,
        sum / count,
        changed,
        maxSteps
      )
    end
  end
  local f = assert(io.open(output .. '/hit-timing.csv', 'w'))
  f:write(table.concat(lines, '\n') .. '\n')
  f:close()
  require('qa.reviews.hit_outcomes').run(G, truth, output)
  require('qa.reviews.hit_outcomes').run(G, truth, output, 'mousepress')
  require('qa.reviews.hit_outcomes').run(G, truth, output, 'press-buffer')
  return #lines - 1
end
return Review

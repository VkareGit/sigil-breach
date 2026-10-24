local Tests = {}
function Tests.run()
  local Plan = require('src.app.load_plan')
  local lines = {}
  local check = require('tests.support.fixtures').checker(lines, 'load plan: ', 'load plan: ')
  local events, now = {}, 0
  local plan = Plan.new('fixture', {
    {
      label = 'first',
      run = function(checkpoint)
        events[#events + 1] = 'a'
        now = now + 0.02
        checkpoint('decoded')
        events[#events + 1] = 'b'
        now = now + 0.01
      end,
    },
    {
      label = 'second',
      run = function()
        events[#events + 1] = 'c'
      end,
    },
  }, function()
    return now
  end)
  plan:step()
  check('no work before a displayed frame', #events == 0)
  plan.shown = true
  plan:step()
  check('checkpoint pauses within provider', #events == 1 and plan.remaining == 2)
  plan:step()
  check('update cannot resume twice without draw', #events == 1)
  plan.shown = true
  plan:step()
  check('completed provider advances progress', #events == 2 and plan.remaining == 1)
  plan.shown = true
  check(
    'final provider completes exactly once',
    plan:step() and #events == 3 and plan.remaining == 0
  )
  plan.shown = true
  plan:step()
  check('done never repeats work', #events == 3 and plan.steps == 3)
  check(
    'diagnostics retain maximum slice and stage',
    math.abs(plan.maxStep - 0.02) < 1e-8 and plan.timings[1].detail == 'decoded'
  )
  local attempts = 0
  local broken = Plan.new('failure', {
    {
      run = function()
        attempts = attempts + 1
        error('fixture failure')
      end,
    },
  })
  broken.shown = true
  broken:step()
  broken.shown = true
  broken:step()
  check(
    'error is visible and never busy-retried',
    broken.error:find('fixture failure', 1, true) and attempts == 1
  )
  local cancelled = Plan.new('cancel', {
    {
      run = function(checkpoint)
        checkpoint()
        error('cancelled worker resumed')
      end,
    },
  })
  cancelled.shown = true
  cancelled:step()
  cancelled:cancel()
  cancelled.shown = true
  cancelled:step()
  check(
    'cancel drops suspended worker and provider references',
    cancelled.cancelled and not cancelled.worker and #cancelled.jobs == 0
  )
  return lines
end
return Tests

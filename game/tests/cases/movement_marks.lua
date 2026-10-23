-- The knight's movement as the painted world shows it (feedback/movement_marks.lua):
-- each move throws its pigments where it belongs, a perfect dodge stills the
-- frame and leaves its shade, and nothing of it touches the simulation.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local Presentation = require('src.session.presentation')
  local Signal = require('src.session.signal')
  local Clocks = require('src.systems.clocks')
  local Data = require('src.content.movement_marks')
  local Feel = require('src.content.tuning').feel
  -- Flecks of a pigment, those within r m of (x, z) when given.
  local function count(g, pigment, x, z, r)
    local color, n = Data.pigments[pigment], 0
    for _, fleck in ipairs(g.view.particles) do
      if fleck.color == color and (not x or (fleck.x - x) ^ 2 + (fleck.z - z) ^ 2 < r * r) then
        n = n + 1
      end
    end
    return n
  end
  local g = Fixtures.arena(G)
  local p = g.player
  g.view.particles, g.view.surge = {}, 0
  local sim = g.rng.sim.state
  local x0, z0 = p.x, p.z
  g:dash(1, 0)
  local dash = Data.moves.dash
  check(
    'a dodge leaves ash and soot where the knight stood and gilds the frame',
    count(g, 'ash', x0, z0, 0.6) == dash.sprays[1].count
      and count(g, 'soot', x0, z0, 0.6) == dash.sprays[2].count
      and g.view.surge == dash.flash
  )
  local ahead = true
  for _, fleck in ipairs(g.view.particles) do
    if fleck.color == Data.pigments.gold then
      ahead = ahead and (fleck.x - p.x) * math.sin(p.yaw) + (fleck.z - p.z) * math.cos(p.yaw) > 1
    end
  end
  check('a dodge streams its gold motes before the eyes', count(g, 'gold') > 0 and ahead)
  local before = #g.view.particles
  Presentation.call(g, 'motion.marks', 0.1)
  check(
    'a dodge under way trails soot and ash from the heels every 0.03 s',
    #g.view.particles - before == 3 * #Data.moves.dashTrail.sprays
  )
  -- A slide on the ground: plaster bursts, sparks fly up off the greaves.
  g.view.particles = {}
  p.dashTimer, p.slideTimer, p.slideX, p.slideZ, p.jump = 0, 0.3, 0, -1, 0
  p.vx, p.vz = 0, -8.7
  Presentation.call(g, 'motion.slide')
  check('a slide begins in plaster dust', count(g, 'lime') == Data.moves.slide.sprays[1].count)
  Presentation.call(g, 'motion.marks', 0.1)
  local rising, along = true, true
  for _, fleck in ipairs(g.view.particles) do
    if fleck.color == Data.pigments.ember then
      rising = rising and fleck.vy > 0
      along = along and fleck.vz < -7
    end
  end
  check(
    'a slide throws rising sparks along its way',
    count(g, 'ember') == 2 * Data.moves.slideTrail.sprays[1].count and rising and along
  )
  -- Landings: a soft one raises nothing, a hard fall the whole ring.
  g.view.particles = {}
  p.slideTimer, p.vx, p.vz = 0, 0, 0
  Presentation.call(g, 'motion.landing', -Data.moves.landing.fall.from)
  local soft = #g.view.particles
  Presentation.call(g, 'motion.landing', -Data.moves.landing.fall.full)
  check(
    'a hard landing rings the boots with dust, a soft one does not',
    soft == 0 and count(g, 'ash', p.x, p.z, 0.2) == Data.moves.landing.sprays[1].count
  )
  -- The perfect dodge: the frame stills, the shade rises where he stood.
  g.view.particles = {}
  Signal(g, 'PerfectDodge', { packet = {}, source = {} })
  check(
    'a perfect dodge stills the frame and leaves a shade of gold where the knight stood',
    g.view.perfectDodge == Feel.perfectDodgeFlash
      and count(g, 'gold', p.dodgeFromX, p.dodgeFromZ, 0.6)
        == Data.moves.afterimage.sprays[1].count
  )
  Clocks.run(g, Feel.perfectDodgeFlash)
  check('the stilled frame returns once its flash has run', g.view.perfectDodge == 0)
  -- A powder charge in flight sheds embers from its fuse.
  g.view.particles = {}
  g.charges = { { x = 10, y = 1.2, z = 10, vx = 4, vy = 1, vz = 0 } }
  Presentation.call(g, 'motion.marks', 0.1)
  g.charges = {}
  check('a powder charge in flight sheds embers', count(g, 'ember', 10, 10, 0.6) > 0)
  check(
    'movement marks draw only from the presentation stream',
    g.rng.sim.state == sim and p.x == x0 and p.z == z0
  )
end
return Tests

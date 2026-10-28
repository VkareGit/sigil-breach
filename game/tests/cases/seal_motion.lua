local Tests = {}
function Tests.run(Game)
  local F = require('tests.support.fixtures')
  local check, lines
  lines = {}
  check = F.checker(lines, 'seal motion: ', 'seal motion: ')
  local Motion = require('src.render.seal_motion')
  local Q = require('src.run.queries')
  local g = Game.new('field', 'proving', require('src.app.release').sessionOptions.field)
  g.testing = true
  check('idle has no phantom activation', Motion.sample(Q.world(g), 'asmoday', 0) == 0)
  g:act('catalog', 'field_chamber_ash')
  local view = Q.world(g)
  check(
    'trial exports authored altar identity and clock',
    view.summoningSeal == 'asmoday' and view.summoningStarted == g.testField.roomTrial.started
  )
  local glow, reveal, lift = Motion.sample(view, 'asmoday', g.elapsed + 0.325)
  check('activation traces ink and raises the seal', glow > 0.65 and reveal == 0.5 and lift > 0)
  local ember, full, settled = Motion.sample(view, 'asmoday', g.elapsed + 6)
  check(
    'activation settles to an ember without endless bobbing',
    ember < 0.13 and full == 1 and math.abs(settled) < 1e-8
  )
  check(
    'other altar never reacts to this trial',
    Motion.sample(view, 'furfur', g.elapsed + 0.325) == 0
  )
  local before = require('src.session.integrity').capture(g)
  for i = 1, 60 do
    Motion.sample(view, 'asmoday', g.elapsed + i / 60)
  end
  check(
    'sampling animation does not alter simulation',
    not require('src.session.integrity').difference(
      before,
      require('src.session.integrity').capture(g)
    )
  )
  g:act('catalog', 'field_chamber_storm')
  check('replacement retires previous seal', Q.world(g).summoningSeal == 'furfur')
  require('src.run.test_field').reset(g)
  check('reset clears ritual presentation', Q.world(g).summoningSeal == nil)
  return lines
end
return Tests

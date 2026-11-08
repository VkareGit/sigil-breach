local Fixtures = require('tests.support.fixtures')
local T = {}
function T.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'v17 ', '')
  require('tests.cases.weapon_detail').run(G, check)
  local S = require('src.feedback.surface_marks')
  local Trails = require('src.feedback.shot_trails')
  local Impact = require('src.feedback.impact_response')
  local Field = require('src.run.test_field')
  local B = require('src.combat.ballistics')
  local near = Fixtures.within(1e-7, true)
  local function fresh(slot)
    local g = Field.new(G)
    g.ephemeral = true
    Field.close(g)
    g.testField.frozen = true
    g.enemies = {}
    g.pickups = {}
    g.player.weapon = slot or 2
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 21.5, 28, math.pi * 0.5, 0
    return g
  end
  local g = fresh(2)
  check('real revolver shot is accepted', g:shoot())
  check(
    'a resolved wall contact leaves one painted scar',
    #g.view.surfaceMarks == 1 and g.view.surfaceMarks[1].surface == 'wall'
  )
  local t = g.view.traces[1]
  local ray = g.view.shotReport.rays[1]
  local o = g.view.shotReport.origin
  check(
    'powder trail lies exactly on the resolved ray at both ends',
    near(t.y1, o[2] + ray.dy * 0.3)
      and near(t.x2, ray.x)
      and near(t.y2, ray.y)
      and near(t.z2, ray.z)
  )
  local x, y, z, nx, ny, nz =
    S.mount(g.world, { x = ray.x, y = ray.y, z = ray.z, kind = ray.kind, normal = { -1, 0, 0 } })
  check(
    'wall scar mounts on the visible lime instead of inside collision',
    x < ray.x and ray.x - x < 0.10 and ny == 0
  )
  local oblique = {
    x = 29.5,
    y = 1.38,
    z = 22.1,
    kind = 'wall',
    normal = { -1, 0, 0 },
    dx = 0.34,
    dy = 0,
    dz = math.sqrt(1 - 0.34 ^ 2),
  }
  local gx, gy, gz = S.mount(g.world, oblique)
  check(
    'oblique scars intersect the visible plaster along the actual ray',
    gx
      and gx < 29.5
      and math.abs((gx - oblique.x) * oblique.dz - (gz - oblique.z) * oblique.dx) < 1e-8
  )
  local mark = g.view.surfaceMarks[1]
  local px, py, pz = mark.x, mark.y, mark.z
  g.player.x = g.player.x - 0.5
  g.player.yaw = 0
  check(
    'moving the player never relocates the scar',
    mark.x == px and mark.y == py and mark.z == pz
  )
  local a, b = Trails.bounds(t)
  check('a trail starts with a bounded outward exposure', a == 0 and b > 0.4 and b < 1)
  Trails.update(g, t.maxLife * 0.5)
  local c, d = Trails.bounds(t)
  check('the exposed tail moves forward and never passes the contact', c > a and d <= 1 and c < d)
  local pool = g.view.tracePool
  Trails.update(g, 1)
  check('expired trails return to a bounded pool', #g.view.traces == 0 and #pool == 1)
  local old = pool[1]
  old.swept = false
  old.width = 99
  local reused = Trails.emit(g, { 1, 2, 3 }, 1, 0, 0, 4, true)
  check(
    'recycled trails reset lifetime width colour and sweep mode',
    reused == old
      and reused.swept
      and reused.width == 0.55
      and reused.life == reused.maxLife
      and reused.x2 == 5
  )
  for i = 1, 300 do
    Trails.emit(g, { 0, 0, 0 }, 0, 0, 1, i, false)
  end
  check('rapid shooting has a hard active trace bound', #g.view.traces == Trails.limit)
  check(
    'zero distance contact never leaves a floating tracer',
    Trails.emit(g, { 0, 0, 0 }, 0, 0, 1, 0, false) == nil
  )
  g = fresh(1)
  assert(g:shoot())
  check(
    'all shotgun surface scars derive from actual pellet contacts',
    #g.view.surfaceMarks > 1
      and #g.view.surfaceMarks <= g.view.shotReport.pellets
      and #g.view.traces == 10
  )
  local smoke = 0
  for _, e in ipairs(g.view.effects) do
    if e.kind == 'smoke' then
      smoke = smoke + 1
    end
  end
  check('one shotgun discharge emits one bounded powder puff', smoke == 1)
  g = fresh(2)
  g.player.pitch = -0.65
  assert(g:shoot())
  check(
    'floor marks lie just above the actual floor mesh',
    #g.view.surfaceMarks == 1
      and near(g.view.surfaceMarks[1].y, 0.004)
      and g.view.surfaceMarks[1].ny == 1
  )
  g = fresh(2)
  g.player.x, g.player.z, g.player.yaw = 12, 27.5, math.pi
  assert(g:shoot())
  check(
    'pillar hits remain on their visible decorative face',
    #g.view.surfaceMarks == 1
      and near(g.view.surfaceMarks[1].z, 25.514)
      and g.view.surfaceMarks[1].nz == 1
  )
  g = fresh(2)
  g.player.pitch = math.pi * 0.5
  assert(g:shoot())
  check(
    'a shot into the open sky does not paint an invented surface',
    g.view.shotReport.rays[1].kind == 'range' and #g.view.surfaceMarks == 0
  )
  g = fresh(2)
  g.player.yaw = math.pi
  local e = g:spawn('imp', 21.5, 26)
  e.hp = 10000
  assert(g:shoot())
  check(
    'body contacts never acquire stationary wall scars',
    g.view.shotReport.targets > 0 and #g.view.surfaceMarks == 0
  )
  g = fresh(2)
  assert(g:shoot())
  mark = g.view.surfaceMarks[1]
  local alpha = S.alpha(mark)
  S.update(g, 29)
  check('scars hold their pigment before their final fade', S.alpha(mark) == alpha)
  S.update(g, 4)
  check('old scars fade rather than pop out', S.alpha(mark) > 0 and S.alpha(mark) < alpha)
  S.update(g, 4)
  check(
    'expired scar storage is reusable',
    #g.view.surfaceMarks == 0 and #g.view.surfaceMarkPool == 1
  )
  local contact = {
    x = 23.5,
    y = 1.38,
    z = 28,
    kind = 'wall',
    normal = { -1, 0, 0 },
    dx = 1,
    dy = 0,
    dz = 0,
    seed = 41,
  }
  local response = Impact.measure(40, contact, 'plaster')
  for i = 1, 220 do
    contact.y = 0.4 + (i % 33) * 0.1
    contact.z = 27.6 + (i % 4) * 0.2
    S.emit(g, contact, response)
  end
  check(
    'shotgun scars have bounded storage even under sustained fire',
    #g.view.surfaceMarks <= S.limit and #g.view.surfaceMarks > 1
  )
  local before = #g.view.surfaceMarks
  require('src.feedback.motion').clearAll(g)
  check(
    'reduced motion preserves physical traces on the environment',
    #g.view.surfaceMarks == before
  )
  require('src.session.encounter').clearWorld(g)
  check(
    'arena reset removes old surface marks and tracers',
    #g.view.surfaceMarks == 0 and #g.view.traces == 0
  )
  for _, hz in ipairs({ 30, 60, 144 }) do
    local q = fresh(2)
    assert(q:shoot())
    for _ = 1, hz * 33 do
      S.update(q, 1 / hz)
    end
    check(
      'scar lifetime is elapsed time at ' .. hz .. ' Hz',
      #q.view.surfaceMarks == 1 and math.abs(S.alpha(q.view.surfaceMarks[1]) - 0.455) < 1e-6
    )
  end
  local function receipt(motion)
    local q = fresh(2)
    q.view.motion = motion
    local target = q:spawn('armored', 22.8, 28)
    q:shoot()
    return table.concat({
      target.hp,
      q.player.arsenal.judge.mag,
      q.player.cooldown,
      q.player.arsenal.judge.readyAt,
      q.view.shotReport.damage,
      q.view.shotReport.impact,
    }, '|')
  end
  check(
    'motion preference cannot change ammunition damage or firing clocks',
    receipt(true) == receipt(false)
  )
  local data = love.image.newImageData(S.path)
  local w, h = data:getDimensions()
  local gutter = true
  for i = 0, w - 1 do
    local _, _, _, a = data:getPixel(i, math.floor(h / 2))
    gutter = gutter and a < 0.1
  end
  for i = 0, h - 1 do
    local _, _, _, a = data:getPixel(math.floor(w / 2), i)
    gutter = gutter and a < 0.1
  end
  check(
    'painted impact atlas has four isolated cells with transparent gutters',
    w >= 1024 and h >= 1024 and gutter
  )
  for index = 0, 3 do
    local ox, oy = math.floor(index % 2 * w / 2), math.floor(math.floor(index / 2) * h / 2)
    local ink, clear = 0, 0
    for yy = oy, oy + h / 2 - 1, 4 do
      for xx = ox, ox + w / 2 - 1, 4 do
        local _, _, _, alpha = data:getPixel(xx, yy)
        if alpha > 0.1 then
          ink = ink + 1
        else
          clear = clear + 1
        end
      end
    end
    check(
      'impact cell ' .. (index + 1) .. ' retains real transparent negative space',
      ink > 50 and clear > ink
    )
  end
  data:release()
  return lines
end
return T

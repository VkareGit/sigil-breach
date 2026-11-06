-- Native camera visibility and geometry protect the painted attack contract.
local T = {}
function T.run(Game, renderer)
  local F = require('tests.support.fixtures')
  local Release = require('src.app.release')
  local A = require('src.enemies.actions')
  local E = require('src.content.enemies')
  local Kinds = require('src.render.hazard_kinds')
  local Rites = require('src.content.art.rites')
  local Integrity = require('src.session.integrity')
  local Surface = require('src.enemies.surface')
  local Anchor = require('src.enemies.contact_anchor')
  local Feedback = require('src.feedback.rite_feedback')
  local lines, specs = {}, {}
  local check = F.checker(lines, 'margrave art: ', '')
  for _, s in ipairs(E.boss.attacks) do
    specs[s.id] = s
  end
  local function fresh(d)
    local g = Game.new('field', Release.sessionMaps.field, Release.sessionOptions.field)
    g.ephemeral, g.state, g.testField.invincible = true, 'playing', true
    g.time, g.view.motion = 12, false
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 10, 16 + d, math.pi, 0
    local e = g:spawn('boss', 10, 16)
    e.awake, e.visible, e.memory, e.target, e.facing, e.spawnAge = true, true, 60, g.player.id, 0, 2
    return g, e
  end
  local function frame(g)
    g.view.presentationPrevious = nil
    renderer:draw(g, 1280, 720)
    return renderer.canvas:newImageData()
  end
  do
    local g, e = fresh(7)
    A.begin(g, e, 7, specs['ash-lance'])
    while g.elapsed < 1.2 do
      e.attack, e.chain = 999, nil
      g:update(1 / 120, {})
    end
    local central = g.hazards[2]
    check('a central delayed eruption exists', central and central.delay > 0)
    local hazards = g.hazards
    g.hazards = { central }
    local before = Integrity.capture(g)
    local with = frame(g)
    check(
      'drawing cannot change the footprint or combat clock',
      not Integrity.difference(before, Integrity.capture(g))
    )
    g.hazards = {}
    local without = frame(g)
    g.hazards = hazards
    local changed, w, h = 0, with:getDimensions()
    for y = math.floor(h * 0.15), math.floor(h * 0.75) do
      for x = 0, w - 1 do
        local a, b, c = with:getPixel(x, y)
        local d, f, k = without:getPixel(x, y)
        if math.abs(a - d) + math.abs(b - f) + math.abs(c - k) > 1e-5 then
          changed = changed + 1
        end
      end
    end
    with:release()
    without:release()
    check('ash beneath a level camera still warns above the actual rim', changed > 200)
  end
  do
    local g, e = fresh(7)
    A.begin(g, e, 7, specs['ash-ring'])
    A.execute(g, e)
    local h = g.hazards[#g.hazards]
    h.delay, h.radius = -0.4, 6
    frame(g):release()
    local before = Integrity.capture(g)
    Kinds.of(h).air(renderer, g, h)
    local mesh = renderer.hazardArt.ribbon
    local first, count = mesh:getDrawRange()
    local tallest, outer, inner, uv = 0, 0, math.huge, true
    for i = first, first + count - 1 do
      local x, y, z, u, v = mesh:getVertex(i)
      tallest = math.max(tallest, y)
      outer = math.max(outer, math.sqrt(x * x + z * z))
      inner = math.min(inner, math.sqrt(x * x + z * z))
      uv = uv and u >= 0 and u <= 1 and v >= 0 and v <= 1
    end
    check(
      'low fire matches its exact contact height and outer edge',
      math.abs(tallest - h.volume.top) < 1e-6 and math.abs(outer - h.radius) < 1e-5
    )
    check(
      'the painted flames rise upright instead of stretching into diagonal strips',
      math.abs(outer - inner) < 1e-5
    )
    check(
      'flame tiling stays bounded and inside its original crop',
      uv and count <= Rites.ribbon.capacity * 6
    )
    check(
      'sampling flame geometry never alters damage',
      not Integrity.difference(before, Integrity.capture(g))
    )
  end
  do
    local g, e = fresh(6)
    g.mode, g.testField = 'field', {}
    for _, index in ipairs({ 5, 6, 7, 8, 21, 22, 23, 27, 28, 29, 30, 31, 32 }) do
      e.previewFrame = index
      local p = Surface.prepare(g, e, {})
      local x, y, z = Anchor.point(g, e, 0, e.x, e.z, 'cleaver', g.player)
      local hit, zone, part
      if x then
        hit, zone, part = Surface.ray(p, x + p.nx * 3, y, z + p.nz * 3, -p.nx, 0, -p.nz, 4)
      end
      check(
        'emitter belongs to the painted cleaver in frame ' .. index,
        x and hit ~= nil and zone == false
      )
    end
  end
  do
    local g, e = fresh(6)
    local before = Integrity.capture(g)
    local style = Rites.impacts.ashImpact
    for _ = 1, 100 do
      Feedback.landed(g, { enemy = e, attack = specs['ash-leap'] })
    end
    check('crowded landings have a bounded view record', #g.view.impactBursts == style.limit)
    check(
      'landing debris is presentation only',
      not Integrity.difference(before, Integrity.capture(g))
    )
    g.elapsed = g.elapsed + style.life + 0.01
    Feedback.update(g)
    check('landing debris expires completely', #g.view.impactBursts == 0)
  end
  return lines
end
return T

local S = {}
function S.run(G, r)
  local FX = require('src.feedback.effects')
  local Geometry = require('src.enemies.geometry')
  local M = require('src.render.mesh')
  local lines = {}
  local function check(name, value)
    assert(value, name)
    lines[#lines + 1] = 'PASS ' .. name
  end
  check(
    'runtime loads only active enemy atlases, never historical fixtures',
    r.enemyAtlas == nil and r.legacyArmored == nil
  )
  check(
    'Furfur has 24 action frames and four registered watchful frames',
    r.frames.furfur and #r.frames.furfur == 28 and #r.feet.furfur == 28
  )
  local function bodySpan(frame, dx, dy)
    local image = (r.frameImages.furfur and r.frameImages.furfur[frame]) or r.animations.furfur
    local w, h = image:getDimensions()
    local region = r.frames.furfur[frame]
    return math.sqrt(
      (dx / (w * region.rect[3]) * region.width) ^ 2
        + (dy / (h * region.rect[4]) * region.height) ^ 2
    ) * 3.4
  end
  -- Fresco v12: hand-reviewed hip/muzzle landmarks in the new source cells,
  -- recorded on fresco-enemies/furfur-landmark-grid.png; never antlers or flame.
  check(
    'fresco pose15 retains neighboring14 hip-to-muzzle body scale',
    math.abs(bodySpan(15, 138, 76) / bodySpan(14, 95, 111) - 1) < 0.08
  )
  check(
    'fresco pose16 retains neighboring17 hip-to-muzzle body scale',
    math.abs(bodySpan(16, 154, 39) / bodySpan(17, 166, 32) - 1) < 0.08
  )
  check(
    'generic FX and enemy spells have independent 16-frame atlases',
    #r.effectFrames == 16 and #r.spellFrames == 16 and r.effects ~= r.spells
  )
  local g = { view = { effects = {}, decals = {} } }
  for i = 1, 300 do
    FX.emit(g, 'stone', i, 1, 2, 0.5)
  end
  check(
    'impact effects have a strict 48-record active bound',
    #g.view.effects == 48 and g.view.effects[1].x == 253
  )
  for i = 1, 100 do
    FX.emit(g, 'smoke', i, 1, 2, 0.5)
  end
  local smoke = 0
  for _, e in ipairs(g.view.effects) do
    if e.kind == 'smoke' then
      smoke = smoke + 1
    end
  end
  check(
    'smoke cannot grow into an opaque screen of more than eight puffs',
    smoke == 8 and #g.view.effects <= 48
  )
  local first = g.view.effects[1]
  FX.update(g, 1)
  check(
    'expired effects return to a bounded pool and leave no holes',
    #g.view.effects == 0 and #g.view.effectPool <= 48
  )
  local pool = #g.view.effectPool
  FX.emit(g, 'blood', 3, 1, 2, 0.5)
  check(
    'an impact reuses a record after its previous lifetime ends',
    #g.view.effectPool == pool - 1 and #g.view.effects == 1
  )
  check(
    'reused effect resets position kind and age',
    g.view.effects[1].kind == 'blood' and g.view.effects[1].x == 3 and g.view.effects[1].age == 0
  )
  for i = 1, 160 do
    FX.stain(g, i, 2, 0.4, 'blood')
  end
  check('stains have a strict 40-record bound', #g.view.decals == 40 and g.view.decals[1].x == 121)
  FX.update(g, 25)
  check('expired stains return to a bounded pool', #g.view.decals == 0 and #g.view.decalPool == 40)
  local ranges = true
  for _, kind in ipairs({ 'stone', 'blood', 'smoke', 'arc' }) do
    local e = FX.emit(g, kind, 0, 0, 0)
    local start = FX.frame(e)
    e.age = e.duration * 0.999
    ranges = ranges and FX.frame(e) == start + 3
  end
  check('four FX animation rows advance across their own four frames', ranges)
  local trace = { x1 = 2, y1 = 3, z1 = 4, x2 = 5, y2 = 6, z2 = 7, color = { 0.3, 0.4, 0.5 } }
  local fresh = {}
  M.quad(
    fresh,
    { 1.9, 2.8, 3.7 },
    { 2.1, 3.2, 4.3 },
    { 5.1, 6.2, 7.3 },
    { 4.9, 5.8, 6.7 },
    { 0.3, 0.4, 0.5, 0.6 }
  )
  local slab = {}
  for i = 1, 6 do
    slab[i] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
  end
  M.traceQuad(slab, 0, trace, 0.1, 0.2, 0.3, 0.6)
  local same = true
  for i = 1, 6 do
    for _, j in ipairs({ 1, 2, 3, 7, 8, 9, 10 }) do
      same = same and math.abs(fresh[i][j] - slab[i][j]) < 1e-9
    end
  end
  check('persistent tracer vertices retain original position winding and alpha', same)
  local batch = r.particleBatch
  batch:clear()
  for i = 1, 260 do
    batch:add(0, 0, 0, 1, { 1, 1, 1 })
  end
  check(
    'particle instance upload is bounded to 240 records',
    batch.count == 240 and not batch:add(0, 0, 0, 1)
  )
  batch:clear()
  check(
    'batch clear reuses the GPU stream and CPU slab',
    batch.count == 0 and #batch.vertices == 240
  )
  local field = require('src.run.test_field').new(G)
  local e = field:spawn('furfur', 16, 20)
  e.ai = 'move'
  e.walkSpeed = 2
  e.walk = 0
  e.facing = 0
  local Surface = require('src.enemies.surface')
  local skullX, skullY = Surface.locate(Surface.prepare(field, e), 'head')
  check(
    'Furfur skull is painted beside its ribcage, not above a human capsule',
    skullX and math.abs(skullX - e.x) > 0.35
  )
  e.ai = 'strike'
  e.attackKind = 'charge'
  e.phase = 0.03
  local _, chargeY = Surface.locate(Surface.prepare(field, e), 'head')
  check(
    'Furfur charge lowers the same painted skull the hit overlay shows',
    chargeY and chargeY < skullY - 0.3
  )
  local _, hover, _, _, _, _, _, height, baseY, atlas = Geometry.pose(field, e)
  local frame = require('src.enemies.animation').pose(field, e)
  check(
    'renderer and collision use the same registered foot baseline',
    math.abs(baseY - (hover - r.feet[atlas][frame] * height)) < 1e-9
  )
  local previous = love.graphics.getShader()
  field.testField.hitboxes = true
  r:draw(field, 1280, 720)
  check(
    'live hit-volume overlay draws with real enemies and preserves outer canvas',
    love.graphics.getCanvas() == nil
  )
  love.graphics.setShader(previous)
  return lines
end
return S

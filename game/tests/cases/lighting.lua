local T = {}
function T.run(G, check, r)
  local V = require('src.render.light_visibility')
  local resources = require('src.render.resources').new('lighting test')
  local Lights = require('src.render.lights')
  local function fixture()
    local w = { size = 9, map = {}, lamps = { { x = 3, y = 1.18, z = 5, phase = 0 } }, seals = {} }
    for z = 1, 9 do
      w.map[z] = {}
      for x = 1, 9 do
        w.map[z][x] = (x == 1 or z == 1 or x == 9 or z == 9) and 1 or 0
      end
    end
    for z = 2, 8 do
      w.map[z][5] = 1
    end
    return w
  end
  local w = fixture()
  check(
    'light reaches a visible floor and the facing wall surface',
    V.visible(w, 3, 5, 4, 5) and V.visible(w, 3, 5, 4.51, 5)
  )
  check('wall prevents light arriving at the opposite corridor', not V.visible(w, 3, 5, 7, 5))
  w.map[5][5] = 0
  check('opening the actual wall admits the light ray', V.visible(w, 3, 5, 7, 5))
  w = fixture()
  w.map[3][4] = 1
  w.map[4][3] = 1
  check('two touching walls close their diagonal corner', not V.visible(w, 3, 3, 4, 4))
  check(
    'wall contact shade is stronger than open floor',
    V.ambient(w, 4.48, 6) < V.ambient(w, 3, 6)
  )
  w = fixture()
  local sources = { { x = 3, y = 1.18, z = 5 } }
  local a = V.build(w, sources, resources)
  local again = V.build(w, sources, resources)
  check(
    'unchanged world geometry reuses the same shadow atlas',
    a == again and a.image:getWidth() == 512
  )
  local lit = V.sample(a, 1, 3, 5)
  local dark = V.sample(a, 1, 7, 5)
  check('baked atlas agrees with open and occluded floor rays', lit > 0.95 and dark < 0.05)
  local _, _, blocked = V.sample(a, 1, 5, 5)
  check('dynamic light blocker channel contains the wall', blocked > 0.95)
  w.map[5][5] = 0
  local changed = V.build(w, sources, resources)
  check(
    'a map edit invalidates cached light visibility',
    changed ~= a and V.sample(changed, 1, 7, 5) > 0.95
  )
  local g = G.new('descent')
  g.testing = true
  g:start()
  g.time = 2
  g.bullets = {}
  local lighting = Lights.new()
  lighting:update(g)
  local previousAtlas = lighting.visibility
  g.world.map[23][16] = 1
  require('src.world.arena').rebuild(g.world)
  lighting:update(g)
  check(
    'world rebuild invalidates renderer light visibility after a geometry edit',
    lighting.visibility ~= previousAtlas
  )
  local positions = {}
  for i, p in ipairs(lighting.positions) do
    positions[i] = { p[1], p[2], p[3] }
  end
  g.player.x, g.player.z = 7, 17
  lighting:update(g)
  local stable = true
  for i, p in ipairs(positions) do
    for k = 1, 3 do
      stable = stable and p[k] == lighting.positions[i][k]
    end
  end
  check(
    'camera travel never reorders or replaces static light sources',
    stable and #lighting.sources <= 14
  )
  check(
    'static and dynamic lights stay inside a fixed sixteen-slot budget',
    #lighting.positions == 16 and #lighting.tiles == 16
  )
  local last = lighting.colors[#lighting.sources]
  local active = last[2]
  g.run.phase = 'wave'
  lighting:update(g)
  check('shrine light announces preparation and recedes during combat', active > last[2] * 3)
  g.bullets = {
    { x = 7, y = 1, z = 18, color = { 1, 0.4, 0.1 } },
    { x = 7, y = 1, z = 19, color = { 0.3, 0.5, 1 } },
    { x = 7, y = 1, z = 20, color = { 1, 0, 0 } },
  }
  lighting:update(g)
  check(
    'only two nearest projectiles receive dynamic light slots',
    lighting.positions[15][3] == 18 and lighting.positions[16][3] == 19
  )
  g.bullets = {}
  lighting:update(g)
  check(
    'expired projectile lights are cleared without lingering',
    lighting.colors[15][1] == 0 and lighting.colors[16][3] == 0
  )
  -- Actual fragment-shader comparison: identical floor patches, one behind a
  -- solid wall. This checks rendered energy, not just the CPU visibility code.
  w = fixture()
  local lg = love.graphics
  local Mesh = require('src.render.mesh')
  local vertices = {}
  Mesh.quad(
    vertices,
    { 1.5, 0, 1.5 },
    { 1.5, 0, 8.5 },
    { 8.5, 0, 8.5 },
    { 8.5, 0, 1.5 },
    { 0.3, 0.3, 0.3 }
  )
  local mesh = Mesh.finish(vertices)
  local target = lg.newCanvas(256, 256)
  local s = r.shader
  lighting:release()
  lighting = Lights.new()
  lighting:update({ world = w, time = 0, player = { x = 3, z = 5 }, bullets = {} })
  local function sample(enabled, dynamic)
    lighting:update({
      world = w,
      time = 0,
      player = { x = 3, z = 5 },
      bullets = dynamic and { { x = 3.8, y = 1, z = 5, color = { 1, 1, 1 } } } or {},
    })
    if dynamic or not enabled then
      for i = 1, 14 do
        lighting.colors[i] = { 0, 0, 0 }
      end
    end
    if not enabled then
      lighting.colors[15] = { 0, 0, 0 }
      lighting.colors[16] = { 0, 0, 0 }
    end
    lg.push('all')
    lg.setCanvas(target)
    lg.origin()
    lg.setShader(s)
    lg.setScissor()
    lg.setDepthMode()
    lg.clear(0, 0, 0, 1)
    lg.setColor(1, 1, 1)
    s:send('camera', { 5, 10, 5 })
    s:send('rightDir', { 1, 0, 0 })
    s:send('upDir', { 0, 0, -1 })
    s:send('forwardDir', { 0, -1, 0 })
    s:send('aspect', 1)
    s:send('projectionScale', 2)
    s:send('objectPos', { 0, 0, 0 })
    s:send('objectYaw', 0)
    s:send('objectScale', 1)
    s:send('flash', 0)
    s:send('flashColor', { 1, 1, 1 })
    s:send('tint', { 1, 1, 1 })
    s:send('objectAlpha', 1)
    lighting:bind(s)
    lg.draw(mesh)
    lg.pop()
    local data = target:newImageData()
    local red, green, blue = data:getPixel(82, 128)
    local near = red * 0.3 + green * 0.59 + blue * 0.11
    red, green, blue = data:getPixel(184, 128)
    local far = red * 0.3 + green * 0.59 + blue * 0.11
    data:release()
    return near, far
  end
  local baseNear, baseFar = sample(false)
  local onNear, onFar = sample(true)
  check('real world shader lights the exposed floor', onNear - baseNear > 0.04)
  check('real world shader leaves the occluded floor at ambient', math.abs(onFar - baseFar) < 0.012)
  local dynamicNear, dynamicFar = sample(true, true)
  check('real projectile light remains visible on its near side', dynamicNear - baseNear > 0.015)
  check(
    'real projectile light does not bleed through the wall',
    math.abs(dynamicFar - baseFar) < 0.012
  )
  mesh:release()
  target:release()
  lighting:release()
  resources:release()
end
return T

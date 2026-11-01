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
  local g = G.new('floor')
  g.ephemeral = true
  g:start()
  g.time = 2
  g.bullets = {}
  local lighting = Lights.new()
  lighting:update(g)
  local originalWorld, originalAtlas = lighting.world, lighting.visibility
  local replacement = fixture()
  local createImage = love.graphics.newImage
  love.graphics.newImage = function(data, ...)
    if type(data) == 'userdata' and data:getWidth() == 1 and data:getHeight() == 1 then
      error('injected deck image allocation failure')
    end
    return createImage(data, ...)
  end
  local success, failure = pcall(lighting.prepare, lighting, replacement)
  love.graphics.newImage = createImage
  check(
    'failed deck allocation preserves the previous complete lighting revision',
    not success
      and tostring(failure):find('injected deck', 1, true)
      and lighting.world == originalWorld
      and lighting.visibility == originalAtlas
  )
  lighting:prepare(replacement)
  check(
    'failed world preparation can retry its uncommitted revision',
    lighting.world == replacement
  )
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
  lighting:release()

  -- Plan v10 V3: a long hall (80 x 12, wider than one tile's window) with 30
  -- braziers west of a wall across it at x = 40, more than the slots.
  local hall = { width = 80, depth = 12, map = {}, lamps = {}, seals = {} }
  for z = 1, 12 do
    hall.map[z] = {}
    for x = 1, 80 do
      hall.map[z][x] = (x == 1 or z == 1 or x == 80 or z == 12 or x == 40) and 1 or 0
    end
  end
  for i = 1, 30 do
    hall.lamps[i] = { x = 1.9 + i * 1.25, y = 1.18, z = 6, phase = i }
  end
  local big = Lights.new()
  local function look(x)
    big:update(
      { world = hall, time = 0, player = { x = x, z = 6 }, bullets = {} },
      { x, 1.6, 6 },
      { 1, 0, 0 }
    )
  end
  local function slotOf(lamp)
    for i = 1, Lights.capacity do
      if big.slots[i] and big.slots[i].lamp == lamp then
        return i
      end
    end
  end
  look(10)
  local near, full = true, 0
  for _, lamp in ipairs(hall.lamps) do
    if math.abs(lamp.x - 10) < Lights.reach then
      local i = slotOf(lamp)
      near = near and i ~= nil and big.colors[i][1] > 1.5
      full = full + 1
    end
  end
  check(
    'a map may have any number of lights: every brazier near the camera takes a slot, fully lit',
    #big.sources == 30 and near and full >= 6
  )
  check(
    'lights left out of the slots are reported, never dropped in silence',
    big.report.left == 30 - Lights.capacity and big.report.frames == 1 and big.report.most == 16
  )
  local edge = slotOf(hall.lamps[14])
  check(
    'the last chosen light fades toward the cut instead of popping',
    edge and big.colors[edge][1] > 0 and big.colors[edge][1] < 1.5
  )
  local kept = slotOf(hall.lamps[6])
  look(14)
  check(
    'a light keeps its slot while it stays chosen; a newly chosen one takes a free slot',
    kept
      and slotOf(hall.lamps[6]) == kept
      and slotOf(hall.lamps[16]) ~= nil
      and slotOf(hall.lamps[1]) == nil
  )
  look(34)
  local last = slotOf(hall.lamps[30])
  check(
    'on a large map a light tile covers the window around its light, walls included',
    last ~= nil
      and big.origins[last][1] == hall.lamps[30].x - V.window / 2
      and V.sample(big.visibility, last, 37, 6) > 0.95
      and V.sample(big.visibility, last, 41.5, 6) < 0.05
  )
  local groundWidth, groundDepth = big.ground.image:getDimensions()
  local baked = big.visibility.bakes
  local litBefore, shadeBefore, wallBefore = V.sample(big.visibility, last, 37, 6)
  look(10)
  look(34)
  local litAfter, shadeAfter, wallAfter = V.sample(big.visibility, slotOf(hall.lamps[30]), 37, 6)
  check(
    'revisiting lamps reuses bounded tiles with identical visibility pixels',
    big.visibility.bakes == baked
      and litBefore == litAfter
      and shadeBefore == shadeAfter
      and wallBefore == wallAfter
  )
  for i = 1, V.cacheCapacity + 2 do
    V.prime(big.visibility, { x = 2 + i * 0.01, z = 6 })
  end
  check(
    'light tile cache stays bounded even with many distinct source positions',
    #big.visibility.cacheOrder == V.cacheCapacity
  )
  look(10)
  look(34)
  local restored = V.sample(big.visibility, slotOf(hall.lamps[30]), 37, 6)
  check('an evicted light is reconstructed without changing its shadow', restored == litBefore)
  check(
    'a large map keeps its contact shade and walls in a ground image of the whole map',
    big.ground.image ~= big.visibility.image
      and groundWidth == 80 * V.texels
      and groundDepth == 12 * V.texels
  )
  -- The fragment shader on the large map: the floor among the braziers is
  -- lit; the floor past the wall at x 40 is not.
  vertices = {}
  Mesh.quad(vertices, { 30, 0, 2 }, { 30, 0, 10 }, { 46, 0, 10 }, { 46, 0, 2 }, { 0.3, 0.3, 0.3 })
  mesh = Mesh.finish(vertices)
  local function hallSample(enabled)
    look(34)
    if not enabled then
      for i = 1, 16 do
        big.colors[i] = { 0, 0, 0 }
      end
    end
    lg.push('all')
    lg.setCanvas(target)
    lg.origin()
    lg.setShader(s)
    lg.setScissor()
    lg.setDepthMode()
    lg.clear(0, 0, 0, 1)
    lg.setColor(1, 1, 1)
    s:send('camera', { 38, 10, 6 })
    s:send('rightDir', { 1, 0, 0 })
    s:send('upDir', { 0, 0, -1 })
    s:send('forwardDir', { 0, -1, 0 })
    s:send('aspect', 1)
    s:send('projectionScale', 1.25)
    s:send('objectPos', { 0, 0, 0 })
    s:send('objectYaw', 0)
    s:send('objectScale', 1)
    s:send('flash', 0)
    s:send('flashColor', { 1, 1, 1 })
    s:send('tint', { 1, 1, 1 })
    s:send('objectAlpha', 1)
    big:bind(s)
    lg.draw(mesh)
    lg.pop()
    local data = target:newImageData()
    -- Screen x of world x: 128 + (x - 38) * 1.25 / 10 * 128.
    local red, green, blue = data:getPixel(128 + math.floor((36 - 38) * 16), 128)
    local lit = red * 0.3 + green * 0.59 + blue * 0.11
    red, green, blue = data:getPixel(128 + math.floor((41.5 - 38) * 16), 128)
    local past = red * 0.3 + green * 0.59 + blue * 0.11
    data:release()
    return lit, past
  end
  local darkLit, darkPast = hallSample(false)
  local onLit, onPast = hallSample(true)
  check('the world shader lights the floor beside a brazier of a large map', onLit - darkLit > 0.04)
  check(
    'and its light stops at the wall, as the window tile says',
    math.abs(onPast - darkPast) < 0.012 or onPast - darkPast < (onLit - darkLit) * 0.25
  )
  mesh:release()
  target:release()
  big:release()
  resources:release()
end
return T

-- Source-art and real animation tests, usable by the integrated selftest or
-- a small offscreen LÖVE runner. They do not touch saved games or game clocks.
local T = {}
local function readBounds(data, r)
  local w, h = data:getDimensions()
  local x, y = math.floor(r[1] * w + 0.5), math.floor(r[2] * h + 0.5)
  local rw, rh = math.floor(r[3] * w + 0.5), math.floor(r[4] * h + 0.5)
  local top, bottom, left, right, opaque, total = 0, 0, 0, 0, 0, 0
  local minimum, maximum = rh - 1, 0
  for py = 0, rh - 1 do
    for px = 0, rw - 1 do
      local _, _, _, a = data:getPixel(x + px, y + py)
      total = total + 1
      if a > 0.65 then
        opaque = opaque + 1
        minimum = math.min(minimum, py)
        maximum = math.max(maximum, py)
        if py == 0 then
          top = top + 1
        end
        if py == rh - 1 then
          bottom = bottom + 1
        end
        if px == 0 then
          left = left + 1
        end
        if px == rw - 1 then
          right = right + 1
        end
      end
    end
  end
  return {
    top = top,
    bottom = bottom,
    left = left,
    right = right,
    min = minimum,
    max = maximum,
    occupancy = opaque / total,
    x = x,
    y = y,
    w = rw,
    h = rh,
  }
end
local function enemy(kind)
  return {
    kind = kind == 'armored' and 'imp' or kind,
    armored = kind == 'armored',
    id = 7,
    hp = 100,
    x = 0,
    z = 0,
    facing = 0,
    awake = true,
    memory = 60,
    ai = 'idle',
    phase = 0,
    walk = 0,
    walkSpeed = 0,
    deathTime = 0,
    windup = 0.4,
    windupDuration = 0.6,
  }
end
function T.run(check, renderer)
  local C = require('src.render.fresco_enemies')
  local I = require('src.enemies.idle')
  local Anim = require('src.enemies.animation')
  local Geometry = require('src.enemies.geometry')
  local Surface = require('src.enemies.surface')
  renderer = renderer or {}
  if not renderer.animations then
    C.loadAll(renderer)
  end
  local count = 0
  local function verify(name, ok)
    count = count + 1
    if check then
      check(name, not not ok)
    else
      assert(ok, name)
    end
  end
  for _, kind in ipairs(C.kinds) do
    local entry, quiet = C.entries[kind], I.entries[kind]
    local frames, feet = renderer.frames[kind], renderer.feet[kind]
    Geometry.register(kind, frames, feet)
    verify(
      'idle ' .. kind .. ' appends exactly four poses after the complete action atlas',
      #frames == entry.originalCount + 4 and quiet.first == entry.originalCount + 1
    )
    local g = { time = 0, player = { x = 0, z = 10 } }
    local e = enemy(kind)
    local selected = {}
    local unmorphed, desynced, distinct = true, false, {}
    for n = 0, 160 do
      g.time = n * quiet.period / 160
      local frame, _, _, sx, sy = Anim.pose(g, e)
      selected[frame] = true
      unmorphed = unmorphed and sx == 1 and sy == 1
      if I.sample(kind, g.time, e.id) ~= I.sample(kind, g.time, e.id + 1) then
        desynced = true
      end
    end
    local unique = 0
    for frame in pairs(selected) do
      unique = unique + 1
    end
    verify('idle ' .. kind .. ' real animation visits four painted poses', unique == 4)
    verify('idle ' .. kind .. ' does not squash or stretch to fake breathing', unmorphed)
    verify('idle ' .. kind .. ' neighbours do not breathe in synchrony', desynced)
    for _, state in ipairs({ 'windup', 'strike', 'recover', 'hurt' }) do
      e.ai = state
      e.phase = 0.05
      e.walkSpeed = 0
      verify(
        'idle ' .. kind .. ' cannot interrupt ' .. state,
        Anim.pose(g, e) <= entry.originalCount
      )
    end
    e.hp = 0
    e.ai = 'idle'
    verify('idle ' .. kind .. ' cannot replace death', Anim.pose(g, e) <= entry.originalCount)
    e.hp = 100
    e.ai = 'move'
    e.walkSpeed = 2
    e.walk = 1
    verify(
      'idle ' .. kind .. ' cannot replace a movement cycle',
      Anim.pose(g, e) <= entry.originalCount
    )
    local source = 'assets/art/' .. kind .. '-idle-fresco-v13.png'
    local data = love.image.newImageData(source)
    local minHeight, maxHeight = math.huge, 0
    for n = 0, 3 do
      local frame = quiet.first + n
      local region = frames[frame]
      local r = region.rect
      local b = readBounds(data, r)
      local sourceImage = renderer.frameImages[kind][frame]
      verify(
        'idle ' .. kind .. ' pose ' .. n + 1 .. ' uses its new transparent GPU source',
        sourceImage and sourceImage ~= renderer.animations[kind]
      )
      verify(
        'idle ' .. kind .. ' pose ' .. n + 1 .. ' is isolated on all four crop boundaries',
        b.top == 0 and b.bottom == 0 and b.left == 0 and b.right == 0
      )
      verify(
        'idle ' .. kind .. ' pose ' .. n + 1 .. ' has genuine surrounding transparency',
        b.occupancy > 0.10 and b.occupancy < 0.80
      )
      verify(
        'idle ' .. kind .. ' pose ' .. n + 1 .. ' grounded opacity matches its foot registration',
        math.abs((b.h - 1 - b.max) / b.h - feet[frame]) < 0.006
      )
      verify(
        'idle ' .. kind .. ' pose ' .. n + 1 .. ' UV stays inside the exact image',
        r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= 1.000001 and r[2] + r[4] <= 1.000001
      )
      local crop = love.image.newImageData(b.w, b.h)
      crop:paste(data, 0, 0, b.x, b.y, b.w, b.h)
      distinct[love.data.hash('sha256', crop:getString())] = true
      crop:release()
      local height = (b.max - b.min + 1) / b.h * region.height
      minHeight = math.min(minHeight, height)
      maxHeight = math.max(maxHeight, height)
      g.testField = true
      e.previewFrame = frame
      e.ai = 'idle'
      e.walkSpeed = 0
      -- The head a shot meets in this pose: the centre of its painted region.
      local surface = Surface.prepare(g, e)
      local hx, hy, _, u, v = Surface.locate(surface, 'head')
      local px = math.floor((r[1] + r[3] * (u or 0)) * data:getWidth())
      local py = math.floor((r[2] + r[4] * (v or 0)) * data:getHeight())
      local _, _, _, headAlpha = data:getPixel(
        math.max(0, math.min(data:getWidth() - 1, px)),
        math.max(0, math.min(data:getHeight() - 1, py))
      )
      verify(
        'idle ' .. kind .. ' pose ' .. n + 1 .. ' head region is on the painted silhouette',
        hx ~= nil and headAlpha > 0.5
      )
      verify(
        'idle ' .. kind .. ' pose ' .. n + 1 .. ' head is above the body base and finite',
        hy ~= nil and hy > surface.baseY and hy == hy
      )
    end
    local changed = 0
    for _ in pairs(distinct) do
      changed = changed + 1
    end
    verify('idle ' .. kind .. ' supplies four different painted source frames', changed == 4)
    verify(
      'idle ' .. kind .. ' maintains physical scale across the breathing loop',
      maxHeight / minHeight < 1.08
    )
    data:release()
  end
  return count
end
function T.contacts(renderer, output)
  local C = require('src.render.fresco_enemies')
  local I = require('src.enemies.idle')
  local Geometry = require('src.enemies.geometry')
  local function save(path, data)
    local f = assert(io.open(path, 'wb'))
    f:write(data)
    f:close()
  end
  for _, kind in ipairs(C.kinds) do
    Geometry.register(kind, renderer.frames[kind], renderer.feet[kind])
    local c = love.graphics.newCanvas(2000, 550)
    love.graphics.setCanvas(c)
    love.graphics.clear(0.17, 0.16, 0.15)
    for i = 1, 5 do
      local frame = i == 1 and 1 or I.entries[kind].first + i - 2
      local g = { time = 0, player = { x = 0, z = 10 }, testField = true }
      local e = enemy(kind)
      e.previewFrame = frame
      local _, _, _, _, _, size, width, height, base = Geometry.pose(g, e)
      local image = renderer.frameImages[kind][frame] or renderer.animations[kind]
      local region = renderer.frames[kind][frame]
      local iw, ih = image:getDimensions()
      local r = region.rect
      local q = love.graphics.newQuad(r[1] * iw, r[2] * ih, r[3] * iw, r[4] * ih, iw, ih)
      local x = (i - 1) * 400 + 200
      local ground = 465
      local scale = 290 / size
      love.graphics.setColor(0.35, 0.31, 0.27)
      love.graphics.line(x - 190, ground, x + 190, ground)
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(
        image,
        q,
        x - width * scale / 2,
        ground - (base + height) * scale,
        0,
        width * scale / (r[3] * iw),
        height * scale / (r[4] * ih)
      )
      -- The authored regions a shot meets (enemies/surface.lua), head in gold.
      for _, part in ipairs(require('src.enemies.surface').prepare(g, e).parts) do
        local points = {}
        for n = 1, #part.polygon, 2 do
          points[n] = x + (part.polygon[n] - 0.5) * width * scale
          points[n + 1] = ground - (base + height) * scale + part.polygon[n + 1] * height * scale
        end
        local head = part.zone == 'head'
        love.graphics.setColor(head and 0.9 or 0.4, head and 0.7 or 0.6, 0.3, 0.7)
        love.graphics.polygon('line', points)
      end
      love.graphics.setColor(0.87, 0.82, 0.68)
      love.graphics.print(
        i == 1 and kind .. ' / walk 1' or 'vigilance ' .. (i - 1) .. ' / frame ' .. frame,
        x - 190,
        26
      )
      q:release()
    end
    love.graphics.setCanvas()
    local data = c:newImageData()
    save(output .. '/' .. kind .. '-registered-contact.png', data:encode('png'):getString())
    data:release()
    c:release()
  end
end
return T

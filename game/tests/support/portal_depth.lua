-- Real frame/GPU regression: transparent art against an opaque decoration,
-- then against a foreground decoration and masonry. No mocked depth test.
local T = {}
function T.run(Game, r, check)
  local F = require('tests.support.fixtures')
  local Objects = require('src.render.world_objects')
  local Queries = require('src.run.queries')
  local M = require('src.render.mesh')
  local lg = love.graphics
  local g = F.arena(Game)
  g.world.seals, g.world.lamps = {}, {}
  g.world.portal = { x = 16, z = 21 }
  g.view.motion = false
  local view = Queries.world(g)
  view.gates = { { x = 16, z = 21, kind = 'imp', delay = 0.2, maxDelay = 1.2 } }
  local query = Queries.world
  Queries.world = function()
    return view
  end
  local vertices = {}
  M.quad(
    vertices,
    { -20, -10, 0 },
    { 20, -10, 0 },
    { 20, 20, 0 },
    { -20, 20, 0 },
    { 0.2, 0.3, 0.25, 1 }
  )
  local plane = M.finish(vertices)
  local at, stage = 20, 'sprites'
  local function opaque(pass)
    return function()
      if stage ~= pass then
        return
      end
      lg.setShader(r.shader)
      lg.setDepthMode('less', true)
      r:object(plane, 16, 0, at)
      lg.setShader(r.spriteShader)
    end
  end
  Objects.register('test_portal_depth', {
    { pass = 'architecture', order = 999, draw = opaque('architecture') },
    { pass = 'sprites', order = 999, draw = opaque('sprites') },
  })
  local originals = {}
  for _, id in ipairs({ 'gate', 'seal' }) do
    originals[id] = Objects.unregister(id)
  end
  local function render()
    r:draw(g, 640, 360)
    return r.canvas:newImageData()
  end
  local function difference(a, b)
    local count = 0
    for y = 0, a:getHeight() - 1 do
      for x = 0, a:getWidth() - 1 do
        local ar, ag, ab = a:getPixel(x, y)
        local br, bg, bb = b:getPixel(x, y)
        if math.abs(ar - br) + math.abs(ag - bg) + math.abs(ab - bb) > 0.03 then
          count = count + 1
        end
      end
    end
    a:release()
    b:release()
    return count
  end
  local ok, err = xpcall(function()
    for _, kind in ipairs({ 'pending', 'arrival', 'seal' }) do
      g.enemies, g.world.seals = {}, {}
      view.gates = kind == 'pending'
          and { { x = 16, z = 21, kind = 'imp', delay = 0.2, maxDelay = 1.2 } }
        or {}
      if kind == 'arrival' then
        g:spawn('imp', 16, 21).spawnAge = 0.2
      end
      if kind == 'seal' then
        g.world.seals = { { id = 'stolas', x = 16, z = 21, summoning = true } }
      end
      local id = (kind == 'arrival' or kind == 'pending') and 'gate' or kind
      for _, obstruction in ipairs({ 'behind', 'foreground', 'wall' }) do
        at = obstruction == 'behind' and 20 or 22
        stage = obstruction == 'wall' and 'architecture' or 'sprites'
        local without = render()
        Objects.register(id, originals[id])
        local with = render()
        Objects.unregister(id)
        local count = difference(without, with)
        check(
          kind .. ' / ' .. obstruction .. ' GPU changed pixels=' .. count,
          obstruction == 'behind' and count > 10 or obstruction ~= 'behind' and count == 0
        )
      end
    end
  end, debug.traceback)
  for id, entry in pairs(originals) do
    if Objects.has(id) then
      Objects.unregister(id)
    end
    Objects.register(id, entry)
  end
  Objects.unregister('test_portal_depth')
  Queries.world = query
  plane:release()
  assert(ok, err)
end
return T

-- Plan v10 V3: bodies of one image are drawn together. The frame is the
-- same as with one draw per body; the draws no longer grow with the bodies.
local T = {}
function T.run(G, check, renderer)
  local Pools = require('src.session.world')
  local g = G.new('floor')
  g.testing = true
  g:start()
  g.state = 'playing'
  local kinds = { 'imp', 'armored', 'imp', 'stolas' }
  for i = 1, 32 do
    local e = g:spawn(kinds[i % #kinds + 1], 10 + (i % 8) * 1.6, 14 + math.floor(i / 8) * 1.7)
    e.spawnAge = 1
  end
  g.player.x, g.player.z, g.player.yaw = 16, 26, math.pi
  local function frame(single)
    if single then
      renderer.enemy = function(self, game, e)
        return getmetatable(self).__index.enemy(self, game, e)
      end
    end
    local before = love.graphics.getStats().drawcalls
    renderer:draw(g, 640, 360)
    local draws = love.graphics.getStats().drawcalls - before
    renderer.enemy = nil
    local data = renderer.canvas:newImageData()
    return data, draws
  end
  local batched, batchedDraws = frame(false)
  local single, singleDraws = frame(true)
  local same = batched:getWidth() == single:getWidth() and batched:getHeight() == single:getHeight()
  for y = 0, batched:getHeight() - 1, 2 do
    for x = 0, batched:getWidth() - 1 do
      if same then
        local r1, g1, b1 = batched:getPixel(x, y)
        local r2, g2, b2 = single:getPixel(x, y)
        same = r1 == r2 and g1 == g2 and b1 == b2
      end
    end
  end
  batched:release()
  single:release()
  check(
    'bodies drawn by image paint the same frame as one draw per body ('
      .. #Pools.of(g, 'enemies')
      .. ' bodies)',
    same
  )
  check(
    'the bodies take a draw per image, not one per body ('
      .. batchedDraws
      .. ' draws against '
      .. singleDraws
      .. ')',
    singleDraws - batchedDraws >= 32 - 8
  )
end
return T

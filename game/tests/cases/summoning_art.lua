-- Presentation contracts: the warning remains tied to its existing timer,
-- and the authored cells cannot sample a neighbouring portal pose.
local Fixtures = require('tests.support.fixtures')
local Tests = {}

function Tests.run(_, renderer)
  local Portal = require('src.render.portals')
  local Spawner = require('src.run.spawner')
  local lines = {}
  local check = Fixtures.checker(lines, 'summoning art: ', 'summoning art: ')
  local function finite(x)
    return type(x) == 'number' and x == x and x > -math.huge and x < math.huge
  end
  local function integerFrame(x, first, last)
    return finite(x) and x == math.floor(x) and x >= first and x <= last
  end
  check('fresh 1.2 second telegraph starts closed', Portal.progress({ delay = 1.2 }) == 0)
  check('elapsed warning reaches its existing spawn boundary', Portal.progress({ delay = 0 }) == 1)
  check('overdue warning clamps at arrival', Portal.progress({ delay = -0.5 }) == 1)
  check('delayed warning cannot run before zero', Portal.progress({ delay = 4 }) == 0)
  for _, gate in ipairs({
    { delay = 0, maxDelay = 0 },
    { delay = 0.5, maxDelay = -1 },
    { delay = 0 / 0, maxDelay = 1.2 },
    { delay = 0.5, maxDelay = 0 / 0 },
  }) do
    check('malformed presentation clock stays finite', finite(Portal.progress(gate)))
    check(
      'malformed presentation clock selects a valid source cell',
      integerFrame(Portal.frame(gate, 3), 1, 6)
    )
  end
  local seen, bounded = {}, true
  for i = 0, 144 do
    local age = i / 120
    local gate = { delay = 1.2 - age, maxDelay = 1.2, index = 2, kind = 'stolas' }
    local frame = Portal.frame(gate, 30 + age)
    bounded = bounded and integerFrame(frame, 1, 6)
    seen[frame] = true
    assert(
      gate.delay == 1.2 - age and gate.maxDelay == 1.2 and gate.kind == 'stolas',
      'portal selector mutated the authoritative warning'
    )
  end
  check('all 145 warning samples select valid source cells', bounded)
  for frame = 1, 4 do
    check('opening visits painted cell ' .. frame, seen[frame])
  end
  check('full aperture has a painted breathing variation', seen[5] or seen[6])
  for _, kind in ipairs({ 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }) do
    local expected, actual = Spawner.colors[kind], Portal.color(kind)
    check(
      kind .. ' keeps its established warning colour',
      actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3]
    )
  end
  for _, age in ipairs({ 0, 0.15, 0.35, 0.599 }) do
    check('arrival uses collapse art at age ' .. age, integerFrame(Portal.arrivalFrame(age), 6, 8))
  end
  check('arrival art expires at the existing grace boundary', Portal.arrivalFrame(0.6) == nil)
  check('old enemies do not retain arrival art', Portal.arrivalFrame(100) == nil)

  local image = love.image.newImageData(Portal.path)
  local width, height = image:getDimensions()
  check('portal sheet has four by two whole source cells', width % 4 == 0 and height % 2 == 0)
  local cw, ch = width / 4, height / 2
  for index = 1, 8 do
    local left, top = (index - 1) % 4 * cw, math.floor((index - 1) / 4) * ch
    local opaque, gutter = 0, true
    for y = top, top + ch - 1 do
      for x = left, left + cw - 1 do
        local _, _, _, alpha = image:getPixel(x, y)
        if alpha > 0.25 then
          opaque = opaque + 1
        end
        if x == left or x == left + cw - 1 or y == top or y == top + ch - 1 then
          gutter = gutter and alpha < 0.06
        end
      end
    end
    check(
      'painted portal cell ' .. index .. ' contains an authored silhouette',
      opaque > cw * ch * 0.003
    )
    check('portal cell ' .. index .. ' has a clear intercell gutter', gutter)
    if index >= 3 and index <= 6 then
      local _, _, _, centerAlpha =
        image:getPixel(left + math.floor(cw / 2), top + math.floor(ch / 2))
      check(
        'open portal cell ' .. index .. ' reveals the world through its center',
        centerAlpha < 0.06
      )
    end
  end
  image:release()
  if renderer then
    local previousProjection = renderer.projection
    renderer.projection = renderer.projection or 1
    local lg = love.graphics
    local target = lg.newCanvas(64, 64)
    local depth = lg.newCanvas(64, 64, { format = 'depth24', readable = false })
    local draw, calls, readOnlyDepth = lg.draw, 0, true
    local randomState = love.math.getRandomState()
    lg.push('all')
    lg.setCanvas({ target, depthstencil = depth })
    lg.setDepthMode('less', true)
    lg.setShader(renderer.shader)
    lg.draw = function(...)
      local mode, writes = lg.getDepthMode()
      readOnlyDepth = readOnlyDepth and mode == 'less' and writes == false
      calls = calls + 1
      return draw(...)
    end
    local ok, err = xpcall(function()
      Portal.draw(renderer, { x = 0, z = 5, kind = 'imp', delay = 0.2, maxDelay = 1.2 }, 2)
      local mode, writes = lg.getDepthMode()
      check(
        'warning restores the caller shader and depth writes',
        lg.getShader() == renderer.shader and mode == 'less' and writes == true
      )
      Portal.arrival(renderer, {}, { x = 0, z = 5, kind = 'imp', spawnAge = 0.3 })
      mode, writes = lg.getDepthMode()
      check(
        'arrival restores the caller shader and depth writes',
        lg.getShader() == renderer.shader and mode == 'less' and writes == true
      )
      check(
        'painted portal draws test scene depth without writing over bodies',
        calls >= 4 and readOnlyDepth
      )
      check(
        'portal rendering leaves the random generator unchanged',
        love.math.getRandomState() == randomState
      )
    end, debug.traceback)
    lg.draw = draw
    lg.pop()
    target:release()
    depth:release()
    renderer.projection = previousProjection
    assert(ok, err)
  end
  return lines
end

return Tests

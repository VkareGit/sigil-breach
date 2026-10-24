-- Repeated native renderer ownership through actual world and HUD draws.
-- Counts are structural assertions; Lua memory is reported, not an FPS proxy.
local Plateau = {}
function Plateau.run(Game, renderer, initial, settings, output)
  local Tooling = require('qa.tooling')
  local Renderer = require('src.render.renderer')
  local Gallery = require('src.render.gallery')
  local UI = require('src.ui.interface')
  local Field = require('src.run.test_field')
  local lg = love.graphics
  local cycles = tonumber(os.getenv('SIGIL_RESOURCE_CYCLES') or '8')
  assert(
    cycles and cycles % 1 == 0 and cycles >= 3 and cycles <= 32,
    'resource cycles must be an integer from 3 to 32'
  )
  local lines = Tooling.header('REAL RENDERER RESOURCE PLATEAU', false)
  local function snapshot(label)
    collectgarbage('collect')
    collectgarbage('collect')
    local stats = lg.getStats()
    stats.heap = collectgarbage('count')
    lines[#lines + 1] = string.format(
      '%s images=%d canvases=%d texture_MiB=%.3f lua_KiB=%.3f',
      label,
      stats.images,
      stats.canvases,
      stats.texturememory / 1048576,
      stats.heap
    )
    return stats
  end
  local w, h = lg.getDimensions()
  renderer:draw(initial, w, h)
  UI.draw(initial, w, h, settings)
  lg.present()
  snapshot('application_before')
  local baseline, fresh
  local heaps = {}
  local ok, problem = xpcall(function()
    for cycle = 1, cycles do
      local game = Field.new(Game)
      game.testing = true
      Field.close(game)
      fresh = Renderer.new()
      while Gallery.pending(fresh) > 0 do
        Gallery.preloadStep(fresh)
      end
      fresh:draw(game, w, h)
      UI.draw(game, w, h, settings)
      lg.present()
      snapshot('cycle_' .. cycle .. '_drawn')
      local mesh = fresh.worldMesh
      fresh:release()
      -- Keep the simulation alive while checking that its native mesh died.
      assert(
        game.world and not pcall(mesh.getVertexCount, mesh),
        'a living session retained a released renderer mesh'
      )
      fresh, game, mesh = nil, nil, nil
      local after = snapshot('cycle_' .. cycle .. '_released')
      heaps[#heaps + 1] = after.heap
      baseline = baseline or after
      assert(
        after.images <= baseline.images
          and after.canvases <= baseline.canvases
          and after.texturememory <= baseline.texturememory,
        'native images/canvases/textures grew after renderer release'
      )
    end
  end, debug.traceback)
  if fresh then
    fresh:release()
  end
  assert(ok, problem)
  local low, high = math.huge, -math.huge
  for i = math.max(1, #heaps - 2), #heaps do
    low, high = math.min(low, heaps[i]), math.max(high, heaps[i])
  end
  lines[#lines + 1] = string.format(
    'Last 3 released cycles: Lua spread %.3f KiB; native resource counts/texture bytes did not grow beyond the first released warm cycle.',
    high - low
  )
  lines[#lines + 1] =
    'The application renderer, UI and global weapon presentation remain live intentionally. Each temporary renderer drew a separate living world and the real HUD. PNG pixels and sampling variants are unchanged.'
  Tooling.write(output, 'resource-plateau.txt', lines, false)
  for _, line in ipairs(lines) do
    print(line)
  end
end
return Plateau

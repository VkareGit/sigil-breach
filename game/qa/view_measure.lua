-- Plan v11 E5: one or two full views of an identical two-knight workload.
-- Each process measures exactly one variant; compare alternating fresh runs.
local Context = require('src.session.context')
local Pools = require('src.session.world')
local Field = require('src.run.test_field')
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Presentation = require('src.render.presentation')
local Integrity = require('src.session.integrity')
local Serialize = require('src.core.serialize')
local UI = require('src.ui.interface')
local Tooling = require('qa.tooling')
local M = {}
local WARMUP, STEPS, FRAMES, DT = 300, 2400, 720, 1 / 120
local function summary(values)
  table.sort(values)
  local function q(f)
    local at = 1 + (#values - 1) * f
    local lo, hi = math.floor(at), math.ceil(at)
    return values[lo] + (values[hi] - values[lo]) * (at - lo)
  end
  return string.format(
    'median_ms=%.6f q1_ms=%.6f q3_ms=%.6f iqr_ms=%.6f n=%d',
    q(0.5),
    q(0.25),
    q(0.75),
    q(0.75) - q(0.25),
    #values
  )
end
local function digest(g)
  local encoded = Serialize.encode(Integrity.capture(g))
  return love.data.encode('string', 'hex', love.data.hash('sha256', encoded))
end
local function scene(G, count)
  love.math.setRandomSeed(909)
  local g = Field.new(G)
  g.ephemeral = true
  Field.close(g)
  local a = Context.actor(g)
  a.x, a.z, a.yaw, a.pitch, a.hp = 16, 25, math.pi, 0.035, 100000
  local kit = { 'exorcist', 'judge' }
  local proto = g.ecs:create('knight', {
    id = 'view_measure_b',
    x = 17,
    z = 25,
    yaw = math.pi,
    pitch = 0.035,
    hp = 100000,
    loadout = kit,
    arsenal = Weapons.arsenal(kit),
    weapon = 2,
    abilities = { 'powder' },
    abilityState = Abilities.kit({ 'powder' }),
  }, false)
  assert(g:actorJoin(Pools.memberRecord(proto)))
  local b = assert(Pools.get(g, 'view_measure_b'))
  if count == 2 then
    assert(Context.watch(g, b.id))
  end
  local kinds = { 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }
  for i = 1, 20 do
    local angle = -1.2 + 2.4 * (i - 1) / 19
    local distance = 6 + (i % 3) * 2
    local e = g:spawn(
      kinds[(i - 1) % #kinds + 1],
      a.x + math.sin(a.yaw + angle) * distance,
      a.z + math.cos(a.yaw + angle) * distance
    )
    e.spawnAge, e.awake, e.hp = 1, true, 100000
  end
  return g, a, b
end
function M.run(G, renderer, settings, output)
  local count = tonumber(os.getenv('SIGIL_VIEW_COUNT') or '1')
  assert(count == 1 or count == 2, 'SIGIL_VIEW_COUNT must be 1 or 2')
  assert(os.getenv('SIGIL_UI_AUDIT') ~= '1', 'Disable UI audit during timing')
  local lg, clock = love.graphics, love.timer.getTime
  local lines = Tooling.header('V11 COMPLETE VIEW MEASUREMENT', false)
  lines[#lines + 1] = string.format(
    'views=%d knights=2 demons=20 canvas_each=1280x720 warmup=%d steps=%d frames=%d',
    count,
    WARMUP,
    STEPS,
    FRAMES
  )
  lines[#lines + 1] = 'Renderer: ' .. table.concat({ lg.getRendererInfo() }, ' / ')
  lines[#lines + 1] =
    'Whole simulation timing includes capture and update, excludes rendering. Two actors move and turn without firing in both variants; only watched-view count differs.'
  lines[#lines + 1] =
    'Frame timing uses a separately prepared world after 300 moving warmup steps+frames, then frozen simulation. Includes interpolation, renderer, postprocess, HUD and synchronous 1-pixel readback of each complete canvas; no screen present, no VSync timing or VSync setting change.'
  lines[#lines + 1] =
    'Health is 100000 in this diagnostic fixture to preserve population; mechanics/timings are unmodified. Lua GC stays enabled; frame loop has no simulation advance.'
  local canvases = {}
  for i = 1, count do
    canvases[i] = lg.newCanvas(1280, 720)
  end
  local ownPresent, nativePresent = rawget(renderer, 'present'), renderer.present
  local previousMouse, previousScreen = UI.useMouse, UI.screen
  UI.useMouse, UI.screen = false, 'playing'
  local target
  renderer.present = function(self, g, w, h)
    lg.setCanvas(target)
    lg.origin()
    return nativePresent(self, g, w, h)
  end
  local function frame(g, b)
    for i = 1, count do
      target = canvases[i]
      local context = i == 1 and g or Context.of(g, b)
      local shown = Presentation.sample(context, 0.5)
      renderer:draw(shown, 1280, 720)
      UI.draw(shown, 1280, 720, settings)
    end
    lg.setCanvas()
    for _, canvas in ipairs(canvases) do
      local pixel = canvas:newImageData(1, 1, 0, 0, 1, 1)
      pixel:release()
    end
  end
  local function step(g, a, b, index)
    local sign = math.floor(index / 120) % 2 == 0 and 1 or -1
    local input = {
      actors = {
        [a.id] = { strafe = sign * 0.25, turn = sign * 0.03 },
        [b.id] = { strafe = -sign * 0.25, turn = -sign * 0.03 },
      },
    }
    Presentation.capture(g)
    g:update(DT, input)
  end
  lg.push('all')
  local ok, problem = pcall(function()
    local g, a, b = scene(G, count)
    for i = 1, WARMUP do
      step(g, a, b, i)
      frame(g, b)
    end
    collectgarbage('collect')
    local times = {}
    for i = 1, STEPS do
      local start = clock()
      step(g, a, b, WARMUP + i)
      times[i] = (clock() - start) * 1000
    end
    lines[#lines + 1] = 'whole_step ' .. summary(times)
    lines[#lines + 1] = 'simulation_final_sha256=' .. digest(g)
    lines[#lines + 1] = 'simulation_final_demons=' .. #Pools.of(g, 'enemies')
    g, a, b = scene(G, count)
    for i = 1, WARMUP do
      step(g, a, b, i)
      frame(g, b)
    end
    collectgarbage('collect')
    local before = Integrity.capture(g)
    times = {}
    for i = 1, FRAMES do
      local start = clock()
      frame(g, b)
      times[i] = (clock() - start) * 1000
    end
    assert(not Integrity.difference(before, Integrity.capture(g)), 'render changed simulation')
    lines[#lines + 1] = 'complete_frame ' .. summary(times)
    lines[#lines + 1] = 'render_simulation_unchanged=true'
  end)
  lg.pop()
  renderer.present = ownPresent
  UI.useMouse, UI.screen = previousMouse, previousScreen
  for _, canvas in ipairs(canvases) do
    canvas:release()
  end
  if not ok then
    error(problem)
  end
  for _, line in ipairs(lines) do
    print(line)
  end
  Tooling.write(output, 'view-measure.txt', lines, false)
end
return M

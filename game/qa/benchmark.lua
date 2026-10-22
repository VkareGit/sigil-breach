-- Deterministic renderer workload. No present-derived FPS: draw submission,
-- synchronous readback, simulation and Lua allocation are measured separately.
-- Complete-frame and lifecycle passes include UI; legacy world passes do not.
local B = {}
local function write(path, text)
  local f = assert(io.open(path, 'wb'))
  f:write(text)
  f:close()
end
function B.run(output)
  local lg = love.graphics
  love.window.setVSync(0)
  lg.setDefaultFilter('nearest', 'nearest')
  local clock = love.timer.getTime
  local begin = clock()
  local initialStats = lg.getStats()
  local lines = {}
  local function log(s)
    lines[#lines + 1] = s
    print(s)
  end
  local name, version, vendor, device = lg.getRendererInfo()
  log('SIGIL renderer benchmark / ' .. os.date('!%Y-%m-%dT%H:%M:%SZ'))
  log('Build: ' .. require('src.core.build').version)
  log('Renderer: ' .. name .. ' / ' .. version .. ' / ' .. vendor .. ' / ' .. device)
  log(
    'vsync='
      .. love.window.getVSync()
      .. '; viewport=1280x720; scene height='
      .. math.floor(require('src.content.tuning').renderHeight * 5 / 6)
      .. '; fixed seed=909; no present timing'
  )
  assert(os.getenv('SIGIL_UI_AUDIT') ~= '1', 'Disable SIGIL_UI_AUDIT during performance timing')
  local Audio = require('src.audio.audio')
  local UI = require('src.ui.interface')
  local initialization = clock()
  Audio.init()
  Audio.muted = true
  love.audio.setVolume(0)
  local audioInit = (clock() - initialization) * 1000
  initialization = clock()
  UI.init()
  local uiInit = (clock() - initialization) * 1000
  log(
    string.format(
      'audio_init_ms=%.3f ui_init_ms=%.3f (new process; output muted)',
      audioInit,
      uiInit
    )
  )
  local Atlas = require('src.render.atlas')
  local load = Atlas.load
  local loads = {}
  Atlas.load = function(path, ...)
    local t = clock()
    local a, b, c = load(path, ...)
    loads[#loads + 1] = { path, (clock() - t) * 1000 }
    return a, b, c
  end
  collectgarbage('collect')
  local before = lg.getStats()
  local t = clock()
  local r = require('src.render.renderer').new()
  local startup = (clock() - t) * 1000
  Atlas.load = load
  local after = lg.getStats()
  log(
    string.format(
      'renderer_init_ms=%.3f images_added=%d texture_added_MiB=%.3f',
      startup,
      after.images - before.images,
      (after.texturememory - before.texturememory) / 1048576
    )
  )
  for _, entry in ipairs(loads) do
    log(string.format('atlas_load_ms %.3f %s', entry[2], entry[1]))
  end
  local G = require('src.session.game')
  local Field = require('src.run.test_field')
  local FX = require('src.feedback.effects')
  local function scene(heavy, live)
    love.math.setRandomSeed(909)
    local g = Field.new(G)
    g.testing = true
    Field.close(g)
    local kinds = {}
    for _, entry in ipairs(Field.catalog.enemies) do
      kinds[#kinds + 1] = entry.id
    end
    for i = 1, (heavy and 20 or 4) do
      assert(Field.spawn(g, kinds[1 + (i - 1) % #kinds], 1))
    end
    g.time = 4
    g.elapsed = 20
    g.view.messageTimer = 0
    g.zoneTimer = 0
    g.player.yaw = math.pi
    g.player.pitch = 0.035
    if not live then
      local colors = { { 0.64, 0.15, 0.06 }, { 0.43, 0.4, 0.24 }, { 0.36, 0.30, 0.25 } }
      for i = 1, (heavy and 240 or 16) do
        g.view.particles[i] = {
          x = 12 + (i * 0.37) % 8,
          y = 0.2 + (i * 0.19) % 2,
          z = 17 + (i * 0.71) % 8,
          life = 0.7,
          size = 0.4 + (i % 5) * 0.1,
          color = colors[1 + i % 3],
        }
      end
      for i = 1, (heavy and 48 or 4) do
        local effect = FX.emit(
          g,
          (i > 32 and i % 4 == 3) and 'stone'
            or ({ 'stone', 'blood', 'smoke', 'arc' })[1 + (i - 1) % 4],
          12 + (i * 0.89) % 8,
          0.4 + (i * 0.31) % 2,
          17 + (i * 0.63) % 7,
          0.4 + (i % 3) * 0.12
        );
        (effect or g.view.effects[#g.view.effects]).age = 0.04
      end
      for i = 1, (heavy and 64 or 3) do
        g.view.traces[i] = {
          x1 = 16,
          y1 = 1.3,
          z1 = 26,
          x2 = 12 + (i * 0.67) % 8,
          y2 = 0.7 + (i * 0.13) % 1.5,
          z2 = 18 + (i * 0.29) % 5,
          width = 0.7,
          life = 0.03,
          maxLife = 0.08,
          color = { 0.9, 0.65, 0.3 },
        }
      end
      for i = 1, (heavy and 40 or 3) do
        FX.stain(g, 12 + (i * 0.73) % 8, 18 + (i * 0.31) % 7, 0.4, 'blood')
      end
      local Marks = require('src.feedback.surface_marks')
      local Impact = require('src.feedback.impact_response')
      for i = 1, (heavy and 96 or 3) do
        local contact = {
          x = 12 + (i % 12) * 0.6,
          y = 0.025,
          z = 17 + math.floor(i / 12) * 0.6,
          kind = 'floor',
          normal = { 0, 1, 0 },
          dx = 0,
          dy = -1,
          dz = 0,
          seed = i,
        }
        Marks.emit(g, contact, Impact.measure(40, contact, 'stone'))
      end
      for i = 1, (heavy and 12 or 2) do
        g.bullets[i] =
          { x = 14 + (i * 0.41) % 4, y = 1.2, z = 19 + (i * 0.47) % 5, color = { 0.7, 0.35, 0.12 } }
      end
      for i = 1, (heavy and 8 or 1) do
        g.hazards[i] =
          { x = 13 + (i * 0.67) % 6, z = 18 + (i * 0.49) % 5, radius = 0.8, delay = 0.4, life = 3 }
      end
    end
    return g
  end
  local function percentile(values, p)
    table.sort(values)
    return values[math.ceil(#values * p)]
  end
  local function sync()
    local d = r.canvas:newImageData(1, 1, 0, 0, 1, 1)
    d:release()
  end
  -- Redirect only the final present pass in this benchmark. Reading this full
  -- canvas waits for postprocessing AND the actual UI, not just the scene.
  local complete = lg.newCanvas(1280, 720)
  local nativePresent = r.present
  local function presentToCanvas(self, game, w, h)
    lg.setCanvas(complete)
    return nativePresent(self, game, w, h)
  end
  local Application = require('src.app.application')
  local Presentation = require('src.render.presentation')
  local app = Application.new()
  app.qa = require('qa.runtime').new({ '--benchmark' })
  app.renderer = r
  -- No desktop keyboard/mouse polling in a deterministic workload. The real
  -- accumulator, fixed steps, presentation capture/sample and audio still run.
  app.input.sample = function()
    return {
      forward = 0,
      strafe = 0,
      turn = 0,
      shoot = false,
      dash = false,
      slide = false,
      jump = false,
    }
  end
  app:reset(false)
  local menu = app.game
  UI.useMouse = false
  local function completeFrame(advance)
    local start = clock()
    if advance then
      app:update(1 / 60)
    end
    local updated = clock()
    local game = app.game
    r:draw(Presentation.sample(game, app.accumulator * 120), 1280, 720)
    local world = clock()
    UI.draw(game, 1280, 720, app.settings)
    lg.setCanvas() -- flush the full image before timing its readback separately
    local submitted = clock()
    local pixel = complete:newImageData(1, 1, 0, 0, 1, 1)
    pixel:release()
    local finished = clock()
    return (updated - start) * 1000,
      (world - updated) * 1000,
      (submitted - world) * 1000,
      (submitted - start) * 1000,
      (finished - submitted) * 1000,
      (finished - start) * 1000
  end
  local function captureComplete(filename)
    local pixels = complete:newImageData()
    local png = pixels:encode('png')
    write(output .. '/' .. filename .. '.png', png:getString())
    png:release()
    pixels:release()
  end
  r.present = presentToCanvas
  local _, coldWorld, coldUI, coldSubmit, coldSync, coldTotal = completeFrame(false)
  local firstImage = lg.getStats()
  log(
    string.format(
      'first_complete_menu world_submit_ms=%.3f ui_submit_ms=%.3f submit_ms=%.3f readback_wait_ms=%.3f total_ms=%.3f initialization_to_first_image_ms=%.3f images_added=%d texture_added_MiB=%.3f',
      coldWorld,
      coldUI,
      coldSubmit,
      coldSync,
      coldTotal,
      (clock() - begin) * 1000,
      firstImage.images - initialStats.images,
      (firstImage.texturememory - initialStats.texturememory) / 1048576
    )
  )
  log(
    'Initialization starts inside benchmark after LOVE/module startup; filesystem/driver caches are not forcibly cold. First image includes lazy UI/shader work; PNG encoding excluded.'
  )
  captureComplete('first-complete-menu')
  r.present = nativePresent
  for _, heavy in ipairs({ false, true }) do
    local label = heavy and 'heavy' or 'normal'
    local g = scene(heavy, false)
    log(
      string.format(
        '%s counts enemies=%d particles=%d effects=%d traces=%d decals=%d bullets=%d hazards=%d',
        label,
        #g.enemies,
        #g.view.particles,
        #g.view.effects,
        #g.view.traces,
        #g.view.decals,
        #g.bullets,
        #g.hazards
      )
    )
    if not heavy then
      t = clock()
      r:draw(g, 1280, 720)
      sync()
      log(
        string.format(
          'first_field_world_draw_after_menu_and_sync_ms=%.3f (new field, menu already rendered)',
          (clock() - t) * 1000
        )
      )
      -- A new session on a warm renderer (entering the field from the menu).
      local fresh = scene(false, false)
      t = clock()
      r:draw(fresh, 1280, 720)
      sync()
      log(
        string.format(
          'new_session_first_draw_and_sync_ms=%.3f (warm renderer, new world)',
          (clock() - t) * 1000
        )
      )
    end
    for _ = 1, 30 do
      r:draw(g, 1280, 720)
      sync()
    end
    local submissions, readbacks = {}, {}
    local stats0 = lg.getStats()
    for i = 1, 180 do
      t = clock()
      r:draw(g, 1280, 720)
      submissions[i] = (clock() - t) * 1000
      t = clock()
      sync()
      readbacks[i] = (clock() - t) * 1000
    end
    local stats1 = lg.getStats()
    log(
      string.format(
        '%s draw_submit_median_ms=%.4f p95_ms=%.4f gpu_sync_readback_median_ms=%.4f p95_ms=%.4f drawcalls=%.1f canvas_switches=%.1f shader_switches=%.1f',
        label,
        percentile(submissions, 0.5),
        percentile(submissions, 0.95),
        percentile(readbacks, 0.5),
        percentile(readbacks, 0.95),
        (stats1.drawcalls - stats0.drawcalls) / 180,
        (stats1.canvasswitches - stats0.canvasswitches) / 180,
        (stats1.shaderswitches - stats0.shaderswitches) / 180
      )
    )
    collectgarbage('collect')
    collectgarbage('stop')
    local mem = collectgarbage('count')
    for _ = 1, 30 do
      r:draw(g, 1280, 720)
      sync()
    end
    log(
      string.format(
        '%s lua_allocated_KiB_per_draw=%.4f (GC stopped, includes readback object)',
        label,
        (collectgarbage('count') - mem) / 30
      )
    )
    collectgarbage('restart')
    collectgarbage('collect')
    local prof = {}
    local original = {}
    for _, method in ipairs({
      'object',
      'enemy',
      'prop',
      'effect',
      'tracers',
      'seal',
      'shrine',
      'mural',
      'pickup',
    }) do
      local key = method
      original[key] = r[key]
      prof[key] = 0
      r[key] = function(self, ...)
        local start = clock()
        local result = original[key](self, ...)
        prof[key] = prof[key] + clock() - start
        return result
      end
    end
    for _ = 1, 60 do
      r:draw(g, 1280, 720)
      sync()
    end
    for key, fn in pairs(original) do
      r[key] = fn
      log(string.format('%s profile_%s_ms=%.4f', label, key, prof[key] * 1000 / 60))
    end
    local image = r.canvas:newImageData()
    write(output .. '/' .. label .. '.png', image:encode('png'):getString())
    image:release()
    -- Simulation is a fresh live scene, never the synthetic frozen FX snapshot.
    g = scene(heavy, true)
    local input = {}
    for _ = 1, 60 do
      g:update(1 / 120, input)
    end
    local updates = {}
    for i = 1, 1200 do
      t = clock()
      g:update(1 / 120, input)
      updates[i] = (clock() - t) * 1000
    end
    log(
      string.format(
        '%s live_update_median_ms=%.4f p95_ms=%.4f final_enemies=%d',
        label,
        percentile(updates, 0.5),
        percentile(updates, 0.95),
        #g.enemies
      )
    )
    -- Legacy world-only submission: one simulation step and one draw with
    -- the collector running. There is no UI, present, or per-frame sync here.
    local frames, worst = {}, 0
    collectgarbage('collect')
    for i = 1, 600 do
      t = clock()
      g:update(1 / 120, input)
      r:draw(g, 1280, 720)
      frames[i] = (clock() - t) * 1000
      worst = math.max(worst, frames[i])
    end
    log(
      string.format(
        '%s frame_update_draw_median_ms=%.4f p99_ms=%.4f max_ms=%.4f (collector running)',
        label,
        percentile(frames, 0.5),
        percentile(frames, 0.99),
        worst
      )
    )
    -- A following interval with the collector stopped. Different simulation
    -- times and driver scheduling mean max differences are not pure GC cost.
    collectgarbage('collect')
    collectgarbage('stop')
    local quiet = 0
    for _ = 1, 600 do
      t = clock()
      g:update(1 / 120, input)
      r:draw(g, 1280, 720)
      quiet = math.max(quiet, (clock() - t) * 1000)
    end
    collectgarbage('restart')
    log(string.format('%s frame_update_draw_max_ms_without_collector=%.4f', label, quiet))
    -- The application's pacing (content/tuning.lua: collector, set by
    -- Application.settle at every transition): its worst frame.
    local pacing = require('src.content.tuning').collector
    collectgarbage('collect')
    local pause = collectgarbage('setpause', pacing.pause)
    local stepmul = collectgarbage('setstepmul', pacing.stepmul)
    local paced, pacedWorst = {}, 0
    for i = 1, 600 do
      t = clock()
      g:update(1 / 120, input)
      r:draw(g, 1280, 720)
      paced[i] = (clock() - t) * 1000
      pacedWorst = math.max(pacedWorst, paced[i])
    end
    log(
      string.format(
        '%s frame_update_draw_app_pacing p99_ms=%.4f max_ms=%.4f (collector pause %d, stepmul %d)',
        label,
        percentile(paced, 0.99),
        pacedWorst,
        pacing.pause,
        pacing.stepmul
      )
    )
    collectgarbage('setpause', pause)
    collectgarbage('setstepmul', stepmul)
    collectgarbage('collect')
    collectgarbage('stop')
    local before = collectgarbage('count')
    for _ = 1, 240 do
      g:update(1 / 120, input)
    end
    log(
      string.format(
        '%s sim_allocated_KiB_per_step=%.4f (GC stopped)',
        label,
        (collectgarbage('count') - before) / 240
      )
    )
    collectgarbage('restart')
  end
  -- These passes exercise the complete shipped frame, in addition to the
  -- historical world-only measurements above. Timers end before bookkeeping.
  r.present = presentToCanvas
  local function measurements()
    return { update = {}, world = {}, ui = {}, submit = {}, readback = {}, total = {} }
  end
  local function sample(samples, i, advance)
    local update, world, ui, submit, readback, total = completeFrame(advance)
    samples.update[i], samples.world[i], samples.ui[i] = update, world, ui
    samples.submit[i], samples.readback[i], samples.total[i] = submit, readback, total
  end
  local function summarize(label, samples, prior)
    local count = #samples.total
    local stats = lg.getStats()
    for _, key in ipairs({ 'update', 'world', 'ui', 'submit', 'readback', 'total' }) do
      local values = samples[key]
      log(
        string.format(
          '%s %s n=%d median_ms=%.4f p95_ms=%.4f p99_ms=%.4f max_ms=%.4f',
          label,
          key,
          count,
          percentile(values, 0.5),
          percentile(values, 0.95),
          percentile(values, 0.99),
          values[#values]
        )
      )
    end
    log(
      string.format(
        '%s drawcalls_per_frame=%.2f canvas_switches_per_frame=%.2f shader_switches_per_frame=%.2f',
        label,
        (stats.drawcalls - prior.drawcalls) / count,
        (stats.canvasswitches - prior.canvasswitches) / count,
        (stats.shaderswitches - prior.shaderswitches) / count
      )
    )
  end
  local function resources(label)
    collectgarbage('collect')
    local stats = lg.getStats()
    local entries, bytes, maximum = 0, 0, 0
    for _, font in pairs(UI.fonts) do
      local count = 0
      for text in pairs(font.inkCache) do
        count, bytes = count + 1, bytes + #text
      end
      entries, maximum = entries + count, math.max(maximum, count)
    end
    assert(maximum <= 256, 'bitmap ink cache exceeded its working-set bound')
    log(
      string.format(
        '%s retained_lua_KiB=%.3f images=%d canvases=%d texture_MiB=%.3f ink_entries=%d max_entries_per_font=%d ink_key_bytes=%d audio_live=%d audio_pooled=%d',
        label,
        collectgarbage('count'),
        stats.images,
        stats.canvases,
        stats.texturememory / 1048576,
        entries,
        maximum,
        bytes,
        #Audio.live,
        Audio.pooled
      )
    )
  end
  for _, heavy in ipairs({ false, true }) do
    local label = heavy and 'complete_heavy20_frozen_fx' or 'complete_normal4_frozen_fx'
    local game = scene(heavy, false)
    -- Include both RGB-only ability shaders in the same repeatable workload.
    for _, e in ipairs(game.enemies) do
      e.spawnAge = 1
      if e.kind == 'imp' then
        e.ai, e.attackKind, e.phase = 'strike', 'leap', 0.35
        e.leaping, e.leapY, e.leapVY, e.leapFlight = true, 0.4, 1, 1
      elseif e.kind == 'stolas' then
        e.ai, e.evadeTime, e.evadeSide = 'move', 0.13, -1
      end
    end
    app:adopt(game)
    for _ = 1, 30 do
      completeFrame(false)
    end
    local samples, prior = measurements(), lg.getStats()
    for i = 1, 240 do
      sample(samples, i, false)
    end
    summarize(label, samples, prior)
    captureComplete(label)
  end
  app:adopt(menu)
  -- Real session routing: 36 simulated arena seconds plus four menu seconds.
  -- Audio voices run with zero output volume; this is no listening assessment.
  Audio.muted = false
  resources('lifecycle_before')
  local function lifecycle(cycle)
    local heavy = cycle % 2 == 0
    local count = heavy and 20 or 4
    local started = clock()
    app:action('field_start')
    local created = (clock() - started) * 1000
    app.game.testing = true
    for i = 1, count do
      local kind = Field.catalog.enemies[1 + (i - 1) % #Field.catalog.enemies].id
      app:action('field_spawn_' .. kind .. '_1')
    end
    app:action('field_close')
    assert(
      app.game.state == 'playing' and #app.game.enemies == count,
      'lifecycle did not enter the requested arena'
    )
    local _, _, _, submitted, waited, total = completeFrame(false)
    log(
      string.format(
        'cycle_%d arena_enemies=%d create_session_ms=%.3f first_submit_ms=%.3f first_readback_wait_ms=%.3f first_complete_ms=%.3f',
        cycle,
        count,
        created,
        submitted,
        waited,
        total
      )
    )
    local samples, prior = measurements(), lg.getStats()
    for i = 1, 540 do
      sample(samples, i, true)
    end
    summarize('cycle_' .. cycle .. '_arena_live', samples, prior)
    log(
      string.format(
        'cycle_%d final_enemies=%d simulated_elapsed=%.3f effects=%d particles=%d',
        cycle,
        #app.game.enemies,
        app.game.elapsed,
        #app.game.view.effects,
        #app.game.view.particles
      )
    )
    started = clock()
    app:action('field_leave')
    local returned = (clock() - started) * 1000
    assert(
      app.game == menu and not app.fieldReturn and app.game.state == 'menu',
      'lifecycle did not return to its original menu'
    )
    _, _, _, submitted, waited, total = completeFrame(false)
    log(
      string.format(
        'cycle_%d return_session_ms=%.3f first_menu_submit_ms=%.3f first_menu_readback_wait_ms=%.3f first_menu_complete_ms=%.3f',
        cycle,
        returned,
        submitted,
        waited,
        total
      )
    )
    samples, prior = measurements(), lg.getStats()
    for i = 1, 60 do
      sample(samples, i, true)
    end
    summarize('cycle_' .. cycle .. '_menu', samples, prior)
  end
  for cycle = 1, 4 do
    lifecycle(cycle)
    resources('lifecycle_after_cycle_' .. cycle)
  end
  -- Faster-changing clocks deliberately stress the rendered HUD cache. These
  -- timestamps are synthetic: 1024 images do not stand for 1024 played seconds.
  app:adopt(scene(false, false))
  Audio.muted = true
  resources('clock_churn_before')
  local function clockChurn(batch)
    local samples, prior = measurements(), lg.getStats()
    for i = 1, 512 do
      app.game.elapsed = 100000 + (batch - 1) * 512 + i
      app.game.run.wallet = (batch - 1) * 512 + i
      sample(samples, i, false)
    end
    summarize('clock_churn_batch_' .. batch, samples, prior)
  end
  for batch = 1, 2 do
    clockChurn(batch)
    resources('clock_churn_after_batch_' .. batch)
  end
  captureComplete('complete-clock-churn')
  app:adopt(menu)
  completeFrame(false)
  resources('final_menu')
  r.present = nativePresent
  complete:release()
  log(
    'Legacy world passes exclude UI; complete_* / cycle_* / clock_churn_* include world, postprocessing, bitmap UI and a final-canvas 1px readback. Submit can include driver back-pressure; readback is extra waiting/copy, not GPU-only time. No present/vsync FPS or input-latency claim. PNG encoding and per-frame result bookkeeping excluded.'
  )
  write(output .. '/benchmark.txt', table.concat(lines, '\n') .. '\n')
  return lines
end
return B

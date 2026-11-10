-- First field entry through the real application, before gallery residency.
-- PNG uploads are measured separately from final world/UI draw and readback.
local ColdField = {}
function ColdField.run(app, output, lines, check)
  local lg, clock = love.graphics, love.timer.getTime
  local width, height = lg.getDimensions()
  local canvas = lg.newCanvas(width, height)
  local originalImage, originalPresent = lg.newImage, app.renderer.present
  local fileImages, nativeImages, filePaths = 0, 0, {}
  lg.newImage = function(source, ...)
    nativeImages = nativeImages + 1
    if type(source) == 'string' then
      fileImages = fileImages + 1
      filePaths[fileImages] = source
    end
    return originalImage(source, ...)
  end
  local ok, problem = xpcall(function()
    -- Submit the ready menu before the user's first field action. It has not
    -- rendered a prepared field or warmed the gallery behind the loader.
    local menuStarted, menuImages = clock(), fileImages
    app:draw()
    lg.present()
    lines[#lines + 1] = string.format(
      'First ready menu draw+present: %.3f ms; lazy file images %d',
      (clock() - menuStarted) * 1000,
      fileImages - menuImages
    )
    -- What the menu draws was uploaded behind the loading page (PLAN Z8).
    local late = {}
    for index = menuImages + 1, fileImages do
      late[#late + 1] = filePaths[index]
    end
    check(
      'the ready menu loads no image of its own'
        .. (#late > 0 and ': ' .. table.concat(late, ', ') or ''),
      #late == 0
    )
    local menu, pending = app.game, 0
    local start, firstFiles = clock(), fileImages
    app:action('field_start')
    assert(app.game.mode == 'field', 'first field action was not accepted')
    local actionTime, plan = clock() - start, app.loading
    pending = pending + #require('src.render.kit.halls').loadingJobs(app.renderer, app.game.world)
    check(
      'first field shows a loading plan for what the menu has not already drawn',
      -- The creatures of the world, then the world itself.
      plan and plan.kind == 'transition' and plan.total == pending + 2
    )
    app:update(1 / 60)
    check(
      'field entry cannot upload unseen loading steps',
      plan.steps == 0 and fileImages == firstFiles
    )
    local elapsed, displayed, maximumDraw, maximumUpdate = app.game.elapsed, 0, 0, 0
    while app.loading and not plan.error do
      assert(displayed < 500, 'first field loading did not converge')
      local before = clock()
      app:draw()
      lg.present()
      maximumDraw = math.max(maximumDraw, clock() - before)
      before = clock()
      app:update(1 / 60)
      maximumUpdate = math.max(maximumUpdate, clock() - before)
      displayed = displayed + 1
    end
    assert(not plan.error, plan.error)
    check(
      'first field displays every loading job and completes without advancing combat',
      plan.done
        and not app.loading
        and plan.steps == displayed
        and displayed > pending
        and app.game.elapsed == elapsed
    )
    check('cold images are uploaded by the displayed plan', fileImages - firstFiles == pending)
    lines[#lines + 1] = string.format(
      'Cold field through Application: action %.3f ms; displayed loading frames %d; PNGs %d; ready %.3f ms; max provider %.3f ms; max update %.3f ms; max loading draw+present %.3f ms',
      actionTime * 1000,
      displayed,
      fileImages - firstFiles,
      (clock() - start) * 1000,
      plan.maxStep * 1000,
      maximumUpdate * 1000,
      maximumDraw * 1000
    )
    -- Redirect only the final output pass. App.draw still runs its normal
    -- world, HUD and Input:present; 1px readback waits on their complete canvas.
    app.renderer.present = function(renderer, game, w, h)
      lg.setCanvas(canvas)
      return originalPresent(renderer, game, w, h)
    end
    local function completedFrame(label)
      local priorFiles, priorNative = fileImages, nativeImages
      local began = clock()
      app:draw()
      lg.setCanvas()
      local submitted = clock()
      local pixel = canvas:newImageData(1, 1, 0, 0, 1, 1)
      pixel:release()
      local finished = clock()
      local lazyFiles, lazyNative = fileImages - priorFiles, nativeImages - priorNative
      local latePaths = {}
      for index = priorFiles + 1, fileImages do
        latePaths[#latePaths + 1] = filePaths[index]
      end
      local detail = #latePaths > 0 and (' (' .. table.concat(latePaths, ', ') .. ')') or ''
      check(
        label .. ' has no deferred image allocation' .. detail,
        lazyFiles == 0 and lazyNative == 0
      )
      lines[#lines + 1] = string.format(
        '%s: submit %.3f ms; readback %.3f ms; complete %.3f ms; lazy file images %d; native images %d',
        label,
        (submitted - began) * 1000,
        (finished - submitted) * 1000,
        (finished - began) * 1000,
        lazyFiles,
        lazyNative
      )
      lg.setColor(1, 1, 1)
      lg.draw(canvas)
      lg.present()
    end
    completedFrame('First field catalogue after LoadPlan')
    app:action('field_close')
    assert(app.game.state == 'playing', 'field catalogue could not close')
    completedFrame('First playing field after LoadPlan')
    local pixels = canvas:newImageData()
    local png = pixels:encode('png')
    local file = assert(io.open(output .. '/startup-first-field.png', 'wb'))
    file:write(png:getString())
    file:close()
    png:release()
    pixels:release()
    app.renderer.present = originalPresent
    app:action('field_leave')
    local returned = app.game == menu
    -- The menu is painted behind its own loading page on the way back (audit E02).
    while app.loading do
      assert(not app.loading.error, app.loading.error)
      app:draw()
      app:update(1 / 60)
    end
    app:action('field_start')
    while app.loading do
      assert(not app.loading.error, app.loading.error)
      app:draw()
      app:update(1 / 60)
    end
    check(
      'loaded field returns to the original menu and reenters warm',
      returned and app.game.mode == 'field' and not app.loading
    )
    app:action('field_leave')
    lines[#lines + 1] =
      'Cold means first gallery entry in this fresh process, not cleared filesystem/driver caches. Loading draw includes present; final submit/readback excludes present and PNG encoding. Native data-backed images are counted separately from deferred file uploads. No 16.7 ms or input-latency claim.'
  end, debug.traceback)
  lg.newImage, app.renderer.present = originalImage, originalPresent
  lg.setCanvas()
  canvas:release()
  assert(ok, problem)
end
return ColdField

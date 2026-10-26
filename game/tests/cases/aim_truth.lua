-- Rendered reticle versus an actual shot after the shortest allowed swap.
-- Uses the renderer's camera/project path, not a copy of its projection math.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(Game, renderer)
  local B = require('src.combat.ballistics')
  local Field = require('src.run.test_field')
  local Layout = require('src.ui.layout')
  local UI = require('src.ui.interface')
  local Presentation = require('src.render.presentation')
  local Weapons = require('src.content.weapons')
  local lines = {}
  local check = Fixtures.checker(lines, 'aim truth: ', 'aim truth: ')
  local rows = { 'size,motion,second_shot_s,aim_kick_rad,reticle_error_pixels' }
  local worst, shots = 0, 0
  -- Observe the actual 2x2 centre drawn by either HUD, then compare it with
  -- the renderer's independent projection of the physical firing ray.
  local function measure(g, w, h)
    renderer:frameCamera(g, w, h)
    local ox, oy, oz = B.origin(g)
    local dx, dy, dz = B.direction(g.player.yaw, g.player.pitch)
    local px, py = renderer:project(ox + dx * 8, oy + dy * 8, oz + dz * 8)
    local vx, vy, vw, vh = Layout.scene(g, w, h)
    px, py = vx + px / renderer.w * vw, vy + py / renderer.h * vh
    love.graphics.setCanvas()
    local scale, xoff, yoff = Layout.viewport(w, h)
    local rectangle, error = love.graphics.rectangle, math.huge
    love.graphics.rectangle = function(mode, x, y, rw, rh, ...)
      if mode == 'fill' and rw == 2 and rh == 2 then
        local ex, ey = xoff + (x + 1) * scale - px, yoff + (y + 1) * scale - py
        error = math.min(error, math.sqrt(ex * ex + ey * ey))
      end
      return rectangle(mode, x, y, rw, rh, ...)
    end
    local ok, err = pcall(UI.draw, g, w, h, { hints = false })
    love.graphics.rectangle = rectangle
    assert(ok, err)
    return error
  end
  for _, size in ipairs({
    { 960, 540 },
    { 1280, 720 },
    { 1024, 768 },
    { 1720, 720 },
    { 1920, 1080 },
  }) do
    for _, motion in ipairs({ true, false }) do
      local g = Field.new(Game)
      g.testing, g.view.motion = true, motion
      Field.close(g)
      g.player.yaw, g.player.pitch = math.pi, 0.2
      assert(g:shoot(), 'initial shotgun shot')
      assert(g:switchWeapon(2), 'switch to loaded Judge')
      g.bus:on('sim', 'ShotFired', function()
        local error = measure(g, size[1], size[2])
        shots, worst = shots + 1, math.max(worst, error)
        rows[#rows + 1] = string.format(
          '%dx%d,%s,%.6f,%.9f,%.6f',
          size[1],
          size[2],
          tostring(motion),
          g.elapsed,
          g.view.aimKick or 0,
          error
        )
      end)
      for _ = 1, 40 do
        g:update(1 / 120, { shoot = true })
        if g.player.shots == 2 then
          break
        end
      end
      assert(g.player.shots == 2, 'swap must exercise a real second shot')
    end
  end
  local out = assert(io.open(require('qa.output').path('aim-swap.csv'), 'w'))
  out:write(table.concat(rows, '\n') .. '\n')
  out:close()
  check('every viewport fires the real swapped weapon with motion on/off', shots == 10)
  check(
    'the earliest swapped shot projects into the drawn reticle (within 0.25 pixel)',
    worst <= 0.25
  )
  local maximum, samples, inherited, markers = 0, 0, true, true
  for _, mode in ipairs({ 'field', 'classic' }) do
    local g = mode == 'field' and Field.new(Game) or Game.new('classic')
    g.testing = true
    if mode == 'field' then
      Field.close(g)
    else
      g:start()
    end
    g.enemies = {}
    g.player.yaw, g.player.pitch = 0.79, -0.37
    g.view.hitmarker, g.view.hitWeight = 0.2, 0.6
    g.view.armorHit, g.view.precisionHit, g.view.breakConfirm = true, true, 0.2
    for _, motion in ipairs({ true, false }) do
      g.view.motion = motion
      for _, fov in ipairs({ 85, 115 }) do
        g.view.fov = fov
        g.view.aimKick, g.view.rollPunch, g.view.fovKick = 0.035, -0.055, 3
        g.view.bank, g.view.shake, g.time = 0.03, 0.1, 0.67
        Presentation.capture(g)
        g.player.hp, g.player.armor = 63, 29
        Weapons.state(g).mag = 1
        g.view.aimKick, g.view.rollPunch, g.view.fovKick = 0.005, 0.035, 0.4
        for _, alpha in ipairs({ 0, 0.35, 0.9, 1 }) do
          local shown = Presentation.sample(g, alpha)
          inherited = inherited
            and shown.player.hp == 63
            and shown.player.armor == 29
            and Weapons.ammo(shown) == 1
            and shown.state == g.state
          for _, size in ipairs({
            { 960, 540 },
            { 1024, 768 },
            { 1720, 720 },
            { 1920, 1080 },
            { 1001, 731 },
          }) do
            maximum = math.max(maximum, measure(shown, size[1], size[2]))
            samples = samples + 1
          end
        end
      end
    end
    local Skin = require('src.ui.skin')
    local function marks(kick)
      g.view.motion, g.view.aimKick = true, kick
      local line, icon, captured = love.graphics.line, Skin.icon, {}
      love.graphics.line = function(...)
        local coords = { ... }
        if
          type(coords[1]) == 'number'
          and math.abs(coords[1] - UI.aimX) < 75
          and math.abs(coords[2] - UI.aimY) < 75
        then
          local relative = {}
          for i, value in ipairs(coords) do
            relative[i] = value - (i % 2 == 1 and UI.aimX or UI.aimY)
          end
          captured[#captured + 1] = relative
        end
        return line(...)
      end
      Skin.icon = function(name, x, y, ...)
        if name == 'armor' and math.abs(x - UI.aimX) < 75 then
          captured[#captured + 1] = { x - UI.aimX, y - UI.aimY }
        end
        return icon(name, x, y, ...)
      end
      local ok, err = pcall(UI.draw, g, 1280, 720, { hints = false })
      love.graphics.line, Skin.icon = line, icon
      assert(ok, err)
      return captured
    end
    local resting, kicked = marks(0), marks(0.035)
    markers = markers and #resting >= 9 and #resting == #kicked
    for i, coords in ipairs(resting) do
      for j, value in ipairs(coords) do
        markers = markers and math.abs(value - kicked[i][j]) < 1e-8
      end
    end
  end
  check(
    'both HUDs project sampled roll/recoil/FOV and motion-off in five viewport shapes',
    samples == 160 and maximum < 1e-6
  )
  check('hit, break, precision, armor and spread indications follow the reticle together', markers)
  check(
    'presentation samples preserve current integer health, armor, ammo and screen state',
    inherited
  )

  -- Exercise the actual Application draw boundary: the renderer and HUD must
  -- receive the same sample, while drawing leaves the gameplay state intact.
  local Application = require('src.app.application')
  local g = Field.new(Game)
  Field.close(g)
  Presentation.capture(g)
  g.view.aimKick, g.player.hp, g.player.armor = 0.035, 57, 12
  Weapons.state(g).mag = 1
  local app = Application.new()
  app.game, app.accumulator = g, 0.25 / 120
  local rendered, drawn
  app.renderer = {
    draw = function(_, shown)
      rendered = shown
    end,
  }
  local draw = UI.draw
  UI.draw = function(shown)
    drawn = shown
  end
  local ok, err = pcall(app.draw, app)
  UI.draw = draw
  assert(ok, err)
  check(
    'application gives renderer and HUD the identical interpolated sample',
    rendered == drawn and drawn ~= g and math.abs(drawn.view.aimKick - 0.00875) < 1e-9
  )
  check(
    'drawing keeps authoritative aim, health, armor and ammo unchanged',
    g.view.aimKick == 0.035 and g.player.hp == 57 and g.player.armor == 12 and Weapons.ammo(g) == 1
  )
  UI.screen, UI.useMouse = 'playing', false
  UI.focus, UI.mouseX, UI.mouseY = 3, 9, 11
  local Golden = require('qa.golden')
  local before, relative = Golden.digest(g), love.mouse.getRelativeMode()
  app.renderer = renderer
  app:draw()
  measure(drawn, 1280, 720)
  check(
    'real renderer and HUD draw preserve the simulation digest and mouse capture',
    before == Golden.digest(g) and relative == love.mouse.getRelativeMode()
  )
  check(
    'playing HUD draw preserves keyboard focus and mouse coordinates',
    UI.focus == 3 and UI.mouseX == 9 and UI.mouseY == 11
  )
  g.state = 'paused'
  app:draw()
  check(
    'a screen change still resets focus and draws the current menu state',
    UI.screen == 'paused' and UI.focus == 1 and Presentation.sample(g, 0.25) == g
  )
  UI.focus, UI.mouseX, UI.mouseY = 1, -1, -1
  return lines
end
return Tests

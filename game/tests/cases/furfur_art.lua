-- Test actual camera visibility and observer-relative turns, not only atlas declarations.
local T = {}
function T.run(Game, renderer)
  local F = require('tests.support.fixtures')
  local Actions = require('src.enemies.actions')
  local Enemies = require('src.content.enemies')
  local Anim = require('src.enemies.animation')
  local Poses = require('src.content.art.poses')
  local Surface = require('src.enemies.surface')
  local Integrity = require('src.session.integrity')
  local Release = require('src.app.release')
  local lines, specs = {}, {}
  local check = F.checker(lines, 'furfur art: ', '')
  for _, spec in ipairs(Enemies.furfur.attacks) do
    specs[spec.id] = spec
  end
  local function fresh()
    local g = Game.new('field', Release.sessionMaps.field, Release.sessionOptions.field)
    g.ephemeral, g.state, g.testField.invincible = true, 'playing', true
    g.time, g.view.motion = 12, false
    local p = g.player
    p.x, p.z, p.yaw, p.pitch = 10, 23, math.pi, 0
    local e = g:spawn('furfur', 10, 16)
    e.awake, e.visible, e.memory, e.target, e.facing, e.spawnAge = true, true, 60, p.id, 0, 2
    return g, e
  end
  local function frame(g)
    g.view.presentationPrevious = nil
    renderer:draw(g, 1280, 720)
    return renderer.canvas:newImageData()
  end
  for _, id in ipairs({ 'lightning', 'storm-steps' }) do
    local g, e = fresh()
    Actions.begin(g, e, 7, specs[id])
    local until_ = id == 'lightning' and 0.5 or 0.9
    while g.elapsed < until_ do
      e.attack, e.chain = 999, nil
      g:update(1 / 120, {})
    end
    local before = Integrity.capture(g)
    local with = frame(g)
    check(
      id .. ' rendering is presentation only',
      not Integrity.difference(before, Integrity.capture(g))
    )
    local hazards = g.hazards
    g.hazards = {}
    local without = frame(g)
    g.hazards = hazards
    local count, w, h = 0, with:getDimensions()
    for y = math.floor(h * 0.15), math.floor(h * 0.75) do
      for x = 0, w - 1 do
        local a, b, c = with:getPixel(x, y)
        local d, f, k = without:getPixel(x, y)
        if math.abs(a - d) + math.abs(b - f) + math.abs(c - k) > 1e-5 then
          count = count + 1
        end
      end
    end
    with:release()
    without:release()
    check(id .. ' warning reaches a level first-person camera inside its footprint', count > 200)
  end
  do
    local g, e = fresh()
    Actions.begin(g, e, 3, specs['antler-pivot'])
    e.phase, e.windup = e.windupDuration * 0.5, e.windupDuration * 0.5
    e.facing = math.pi
    check('the rear answer shows the actual back before turning', Anim.pose(g, e) == 19)
    e.facing = 0
    check('the same gesture shows its front to the opposite observer', Anim.pose(g, e) ~= 19)
    local poses = Anim.poses(e)
    check(
      'an invalid rear pose fails its contract',
      #Poses.problems({ test = { frames = { 1 }, rear = 'missing' } }, 37) > 0
    )
    check(
      'the charge return names an observer-relative rear',
      Poses.resolve(poses, 'turn.charge').rear == 'watchRear'
    )
    g.mode, g.testField = 'field', {}
    for _, index in ipairs({ 7, 8, 9, 10, 11, 12, 19, 29, 30, 31 }) do
      e.previewFrame = index
      local p = Surface.prepare(g, e, {})
      local x, y, z = Surface.centre(p, 'antlers')
      check(
        'frame ' .. index .. ' emits from its authored antlers',
        x ~= nil and y > p.baseY and y < p.baseY + p.height and z == z
      )
    end
  end
  return lines
end
return T

-- Attack captures are driven by the real AI/update clock, not hand-posed stills.
local S = {}
function S.run(G, r, output)
  local Field = require('src.run.test_field')
  local U = require('src.ui.interface')
  local count = 0
  local report = {}
  local function capture(g, e, name)
    r:draw(g, 1280, 720)
    local target = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas(target)
    r:present(g, 1280, 720)
    U.draw(g, 1280, 720, { sensitivity = 1, motion = true, music = 0, hints = true })
    love.graphics.setCanvas()
    local data = target:newImageData()
    local f = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    f:write(data:encode('png'):getString())
    f:close()
    data:release()
    target:release()
    count = count + 1
    report[#report + 1] = string.format(
      '%s time=%.3f state=%s attack=%s frame=%d hazards=%d bullets=%d',
      name,
      g.time,
      e.ai,
      e.attackKind or 'ranged',
      require('src.enemies.animation').pose(g, e),
      #g.hazards,
      #g.bullets
    )
  end
  local function setup(kind, attackCount)
    local g = Field.new(G)
    g.ephemeral = true
    Field.close(g)
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 24.5, math.pi, -0.12
    local e = g:spawn(kind, 16, 18.8)
    e.attack = 0
    e.attackCount = attackCount or 0
    if kind == 'furfur' and attackCount == 1 then
      e.lastAttack, e.attackRepeats = 'charge', 1
    end
    e.awake = true
    e.memory = 5
    e.facing = 0
    for _ = 1, 120 do
      if e.ai == 'windup' then
        break
      end
      g:update(1 / 120, {})
    end
    assert(e.ai == 'windup', 'showcase AI failed to enter windup')
    -- A clear viewing position outside the committed target demonstrates that
    -- the warning stays at its original location and does not follow the camera.
    g.testField.selected = kind
    g.player.z = 27.5
    g.view.messageTimer = 0
    g.zoneTimer = 0
    g.elapsed = 70
    return g, e
  end
  local g, e = setup('furfur', 1)
  capture(g, e, 'attack-furfur-lightning-1-commit')
  for _ = 1, 60 do
    g:update(1 / 120, {})
  end
  capture(g, e, 'attack-furfur-lightning-2-warning')
  for _ = 1, 120 do
    if e.ai == 'strike' then
      break
    end
    g:update(1 / 120, {})
  end
  capture(g, e, 'attack-furfur-lightning-3-strike')
  for _ = 1, 44 do
    g:update(1 / 120, {})
  end
  capture(g, e, 'attack-furfur-lightning-4-recover')
  g, e = setup('furfur', 0)
  g.testField.hitboxes = true
  capture(g, e, 'attack-furfur-charge-1-commit')
  for _ = 1, 90 do
    if e.windup < 0.28 then
      break
    end
    g:update(1 / 120, {})
  end
  capture(g, e, 'attack-furfur-charge-2-warning')
  for _ = 1, 90 do
    if e.ai == 'strike' then
      break
    end
    g:update(1 / 120, { strafe = 1 })
  end
  for _ = 1, 14 do
    g:update(1 / 120, { strafe = 1 })
  end
  capture(g, e, 'attack-furfur-charge-3-lunge')
  for _ = 1, 80 do
    g:update(1 / 120, {})
  end
  capture(g, e, 'attack-furfur-charge-4-after')
  g, e = setup('stolas')
  capture(g, e, 'attack-stolas-1-charge')
  for _ = 1, 120 do
    if #g.bullets > 0 then
      break
    end
    g:update(1 / 120, {})
  end
  for _ = 1, 18 do
    g:update(1 / 120, {})
  end
  capture(g, e, 'attack-stolas-2-projectile')
  local f = assert(io.open(output .. '/attack-timelines.txt', 'wb'))
  f:write(table.concat(report, '\n') .. '\n')
  f:close()
  return count
end
return S

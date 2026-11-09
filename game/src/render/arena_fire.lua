-- Authored boundary scenery. Reuses the four painted brazier flames, with
-- the metal bowl excluded by UVs. No hazards, particles or collision state.
local Context = require('src.session.context')
local Ground = require('src.physics.ground')
local FireLook = require('src.content.art.arena_fire_look')
local Fire = {}
function Fire.draw(r, g, view, time)
  if not view.arenaFire then
    return
  end
  local alpha = math.min(1, math.max(0, (g.elapsed - view.arenaStarted) / FireLook.fadeIn))
  local shader, viewer = r.spriteShader, Context.viewer(g)
  if not r.arenaFlameRects then
    local top = FireLook.flameTop / FireLook.sheetHeight
    r.arenaFlameRects = {}
    for i = 1, 4 do
      r.arenaFlameRects[i] = { (i - 1) / 4, 0, 1 / 4, top }
    end
  end
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setShader(shader)
  love.graphics.setColor(1, 1, 1)
  r.sprite:setTexture(r.props)
  shader:send('silhouette', 0)
  shader:send('soft', 0)
  shader:send('effectAlpha', alpha * FireLook.alpha)
  shader:send('effectTint', FireLook.tint)
  shader:send('brightness', FireLook.brightness)
  shader:send('lean', 0)
  shader:send('pain', 0)
  for i, at in ipairs(view.arenaFire) do
    -- Offset the authored sequence so the perimeter does not march in unison.
    local frame = 1 + math.floor(time * FireLook.rate + i * FireLook.offset) % 4
    local height = FireLook.height + FireLook.swell * math.sin(i * FireLook.wave) ^ 2
    shader:send('frameRect', r.arenaFlameRects[frame])
    shader:send('spriteStretch', r:vec2(FireLook.width, 1))
    shader:send('objectPos', r:vec3(at.x, Ground.height(g.world, at.x, at.z), at.z))
    shader:send('objectYaw', math.atan2(viewer.x - at.x, viewer.z - at.z))
    shader:send('objectScale', height)
    shader:send('mirror', i % 2)
    love.graphics.draw(r.sprite)
  end
  shader:send('effectTint', { 1, 1, 1 })
  shader:send('effectAlpha', 1)
  shader:send('mirror', 0)
  love.graphics.pop()
end
return Fire

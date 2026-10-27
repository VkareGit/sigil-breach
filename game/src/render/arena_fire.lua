-- Authored boundary scenery. Reuses the four painted brazier flames, with
-- the metal bowl excluded by UVs. No hazards, particles or collision state.
local Context = require('src.session.context')
local Ground = require('src.physics.ground')
local Fire = {}
function Fire.draw(r, g, view, time)
  if not view.arenaFire then
    return
  end
  local alpha = math.min(1, math.max(0, (g.elapsed - view.arenaStarted) / 0.8))
  local shader, viewer = r.spriteShader, Context.viewer(g)
  r.arenaFlameRects = r.arenaFlameRects
    or {
      { 0, 0, 0.25, 192 / 887 },
      { 0.25, 0, 0.25, 192 / 887 },
      { 0.5, 0, 0.25, 192 / 887 },
      { 0.75, 0, 0.25, 192 / 887 },
    }
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setShader(shader)
  love.graphics.setColor(1, 1, 1)
  r.sprite:setTexture(r.props)
  shader:send('silhouette', 0)
  shader:send('soft', 0)
  shader:send('effectAlpha', alpha * 0.94)
  shader:send('effectTint', { 1, 0.88, 0.72 })
  shader:send('brightness', 0.94)
  shader:send('lean', 0)
  shader:send('pain', 0)
  for i, at in ipairs(view.arenaFire) do
    -- Offset the authored sequence so the perimeter does not march in unison.
    local frame = 1 + math.floor(time * 7 + i * 1.37) % 4
    local height = 0.56 + 0.12 * math.sin(i * 2.7) ^ 2
    shader:send('frameRect', r.arenaFlameRects[frame])
    shader:send('spriteStretch', r:vec2(2.3, 1))
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

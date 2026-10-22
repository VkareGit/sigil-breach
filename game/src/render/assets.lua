-- Only active illustrations live here; old atlases remain versioned assets.
local Atlas = require('src.render.atlas')
local A = {}
function A.load(r)
  r.textures = love.graphics.newImage('assets/art/textures-fresco-v12.png')
  r.textures:setFilter('linear', 'linear')
  r.shader:send('atlas', r.textures)
  r.horizon = love.graphics.newImage('assets/art/horizon-fresco-v12.png')
  r.horizon:setFilter('linear', 'linear')
  r.horizon:setWrap('repeat', 'clamp')
  r.skyShader:send('horizon', r.horizon)
  r.animations = {}
  r.feet = {}
  r.frames = {}
  r.frameImages = {}
  r.frameMirrors = {}
  require('src.render.fresco_enemies').loadAll(r)
  r.shrineImage, r.shrineFeet, r.shrineFrames = Atlas.load('assets/art/shrine-fresco-v12.png', 4, 1)
  r.frescoes = love.graphics.newImage('assets/art/murals-fresco-v12.png')
  r.frescoes:setFilter('linear', 'linear')
  require('src.render.fresco_effects').load(r)
end
return A

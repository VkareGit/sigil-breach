-- Only active illustrations live here; old atlases remain versioned assets.
local Atlas = require('src.render.atlas')
local Resources = require('src.render.resources')
local A = {}
function A.load(r)
  r.resources = r.resources or Resources.new('renderer artwork')
  r.textures = r.resources:image('assets/art/textures-fresco-v12.png', { filter = 'linear' })
  r.shader:send('atlas', r.textures)
  r.horizon =
    r.resources:image('assets/art/horizon-fresco-v12.png', { filter = 'linear', wrapX = 'repeat' })
  r.skyShader:send('horizon', r.horizon)
  r.animations = {}
  r.feet = {}
  r.frames = {}
  r.frameImages = {}
  r.frameMirrors = {}
  require('src.render.fresco_enemies').onDemand(r)
  r.shrineImage, r.shrineFeet, r.shrineFrames =
    Atlas.load('assets/art/shrine-fresco-v12.png', 4, 1, nil, nil, r.resources)
  r.frescoes = r.resources:image('assets/art/murals-fresco-v12.png', { filter = 'linear' })
  for _, entry in pairs(require('src.content.art.environment')) do
    r.resources:image(entry.path, entry)
  end
  require('src.render.fresco_effects').load(r)
end
return A

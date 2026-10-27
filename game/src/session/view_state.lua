-- Personal presentation initialization, independent of movement and context.
local Presentation = require('src.session.presentation')
local Defaults = require('src.content.tuning').viewDefaults
local ViewState = {}
local cameraKeys = {
  'recoil',
  'recoilV',
  'swayX',
  'swayY',
  'bank',
  'fovKick',
  'land',
  'landV',
  'bobWeight',
  'shake',
}
local function clearCamera(g)
  for _, key in ipairs(cameraKeys) do
    g.view[key] = 0
  end
end
-- Private state only: watch/reset never touches the actor or shared effects.
function ViewState.init(g)
  clearCamera(g)
  g.view.shotAge, g.view.swapAge, g.view.stepSound = Defaults.shotAge, 1, 0
  g.view.shotReport, g.view.interruptedClose = nil, nil
  g.view.precisionHit, g.view.hitWeight, g.view.shotPower = false, 0, 1
  g.view.lastDamage, g.view.lastKill = 0, false
  g.view.shells = {}
  g.view.flashColor = { Defaults.flash[1], Defaults.flash[2], Defaults.flash[3] }
  Presentation.call(g, 'motion.init')
end
ViewState.clearCamera = clearCamera
return ViewState

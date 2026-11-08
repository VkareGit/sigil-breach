-- Personal presentation initialization, independent of movement and context.
local Presentation = require('src.session.presentation')
local Defaults = require('src.content.tuning').viewDefaults
local Fields = require('src.session.fields')
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
    g.view[key] = Fields.viewStarts[key]
  end
end
-- Private state only: watch/reset never touches the actor or shared effects.
-- Every field with a start value begins with it (session/fields.lua).
function ViewState.init(g)
  Fields.startView(g.view)
  g.view.shotReport, g.view.interruptedClose = nil, nil
  g.view.precisionHit, g.view.lastKill = false, false
  g.view.shells = {}
  g.view.flashColor = { Defaults.flash[1], Defaults.flash[2], Defaults.flash[3] }
  Presentation.call(g, 'motion.init')
end
-- A new session's presentation: empty shared effects, no watched actors,
-- motion on, then the controlled knight's own view.
function ViewState.start(g)
  g.view.traces, g.view.surfaceMarks, g.view.corpses = {}, {}, {}
  g.view.effects, g.view.decals = {}, {}
  g.view.actors, g.view.observers = nil, nil
  g.view.motion = true
  ViewState.init(g)
end
ViewState.clearCamera = clearCamera
return ViewState

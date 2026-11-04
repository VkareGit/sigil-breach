-- Built-in modes translate their private records into common read-only views.
-- No renderer or screen imports a mode's mutable
-- record layout: each mode hands its record (state) to these builders
-- (run/modes.lua), and presentation asks session/queries.lua for the view. Each
-- builder fills the session's own view table (out; plan v11 E2).
local Chambers = require('src.run.field.chambers')
local Sanctuary = require('src.session.sanctuary')
local Text = require('src.content.text')
local Views = {}
local empty = {}

local function world(g, state, view)
  view.shrine, view.shrineActive = Sanctuary.at(g), true
  view.echo, view.gates = state.echo, state.pending or empty
  return view
end
function Views.pilgrimWorld(g, state, out)
  return world(g, state, out)
end
function Views.fieldWorld(g, state, out, field)
  out.arenaFire = Chambers.arena(g, field)
  out.arenaStarted = field.roomTrial and field.roomTrial.started
  out.encounterStatus = field.roomTrial and field.roomTrial.status
  out.encounterStarted = field.roomTrial and field.roomTrial.started
  out.encounterFinished = field.roomTrial and field.roomTrial.finished
  Chambers.ritual(g, field, out)
  return world(g, state, out)
end
function Views.fieldTools(_, state, tools)
  tools.combatTrial = state.roomTrial and true or nil
  tools.gallery, tools.hitboxes = true, state.hitboxes == true
  tools.labels = state.labels or empty
  return tools
end
-- The run a mode keeps (its wallet, echo and fires; the proving ground's shop
-- record): what screens and the HUD show of it.
function Views.run(_, state, run)
  run.market = state.market
  run.sigils, run.vows = state.sigils, state.vows
  run.wallet, run.echo, run.deaths = state.wallet, state.echo, state.deaths
  run.glyph, run.owned, run.worn = state.glyph, state.owned, state.worn
  run.rest, run.lit, run.saved = state.fire, state.lit, state.saved
  run.area, run.slot = state.area, state.slot
  return run
end
-- The proving ground's settings and selection, for its screens.
function Views.field(_, state, proving)
  proving.features = state.features
  proving.message, proving.station, proving.selected = state.message, state.station, state.selected
  proving.frozen, proving.invincible, proving.hitboxes =
    state.frozen, state.invincible, state.hitboxes
  proving.poseIndex, proving.skirmish = state.poseIndex, state.skirmish
  proving.labels, proving.archiveSelection = state.labels, state.archiveSelection
  return proving
end
function Views.fieldObjective()
  return Text.get('objective_field')
end
return Views

-- Built-in modes translate their private records into common read-only views.
-- No renderer or screen imports the expedition's or the field's mutable
-- record layout: each mode hands its record (state) to these builders
-- (run/modes.lua), and presentation asks run/queries.lua for the view. Each
-- builder fills the session's own view table (out; plan v11 E2).
local Sanctuary = require('src.session.sanctuary')
local Descent = require('src.run.descent')
local Pools = require('src.session.world')
local Text = require('src.content.text')
local World = require('src.world.arena')
local Encounter = require('src.session.encounter')
local Views = {}
local empty = {}

local function world(g, state, view)
  view.shrine, view.shrineActive = Sanctuary.at(g), state.phase == 'preparing'
  view.echo, view.gates = state.echo, state.pending or empty
  view.paintedPickups, view.classicSecret = true, false
  return view
end
function Views.classicWorld(_, out)
  out.gates, out.paintedPickups, out.classicSecret = empty, false, true
  return out
end
function Views.expeditionWorld(g, state, out)
  return world(g, state, out)
end
function Views.fieldWorld(g, state, out, field)
  local Chambers = require('src.run.field.chambers')
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
-- The run a mode keeps (the expedition's waves, wallet and echo; the
-- proving ground's shop record): what screens and the HUD show of it.
function Views.run(_, state, run)
  run.phase, run.wave, run.countdown = state.phase, state.wave, state.countdown
  run.wallet, run.echo, run.fragment, run.deaths =
    state.wallet, state.echo, state.fragment, state.deaths
  run.glyph, run.owned = state.glyph, state.owned
  return run
end
-- The proving ground's settings and selection, for its screens.
function Views.field(_, state, proving)
  proving.features = state.features
  proving.message, proving.station, proving.selected = state.message, state.station, state.selected
  proving.frozen, proving.invincible, proving.hitboxes =
    state.frozen, state.invincible, state.hitboxes
  proving.poseIndex, proving.skirmish, proving.tier = state.poseIndex, state.skirmish, state.tier
  proving.labels, proving.archiveSelection = state.labels, state.archiveSelection
  return proving
end
function Views.fieldObjective()
  return Text.get('objective_field')
end
function Views.expeditionObjective(g, state)
  local name = state.wave == Descent.totalWaves + 1 and Text.get('guardian')
    or Text.get('wave', { wave = state.wave, total = Descent.totalWaves })
  if state.phase == 'complete' then
    return Text.get('fragment_recovered')
  elseif state.phase == 'preparing' then
    return Text.get('preparing', { wave = name })
  elseif state.phase == 'countdown' then
    return Text.get('countdown', { seconds = math.ceil(state.countdown) })
  end
  return Text.get('remaining', { wave = name, count = Descent.remaining(g) })
end
function Views.classicObjective(g)
  local seals = World.activeSeals(g.world)
  if Encounter.guardianDead(g) then
    return Text.get('objective_classic_gate')
  elseif seals < 3 then
    return Text.get('objective_classic_seals', { seals = seals })
  elseif not Encounter.guardianSpawned(g) then
    local alive = 0
    for _, enemy in ipairs(Pools.of(g, 'enemies')) do
      if enemy.hp > 0 then
        alive = alive + 1
      end
    end
    return Text.get('objective_classic_defenders', { count = alive })
  end
  return Text.get('objective_classic_guardian')
end
return Views

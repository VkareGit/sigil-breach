-- Built-in modes translate their private records into common read-only views.
-- No renderer imports the expedition or field's mutable record layout.
local Sanctuary = require('src.session.sanctuary')
local Descent = require('src.run.descent')
local Pools = require('src.session.world')
local Views = {}
local empty = {}
local classic = { gates = empty, paintedPickups = false, classicSecret = true }
local expedition, field, tools = {}, {}, {}

local function world(g, view)
  local state = g.run
  view.shrine, view.shrineActive = Sanctuary.at(g), state.phase == 'preparing'
  view.echo, view.gates = state.echo, state.pending or empty
  view.paintedPickups, view.classicSecret = true, false
  return view
end
function Views.classicWorld()
  return classic
end
function Views.expeditionWorld(g)
  return world(g, expedition)
end
function Views.fieldWorld(g)
  return world(g, field)
end
function Views.fieldTools(g)
  tools.gallery, tools.hitboxes = true, g.testField.hitboxes == true
  tools.labels = g.testField.labels or empty
  return tools
end
function Views.fieldObjective()
  return 'PROVING GROUND / [F2] Trial catalogue'
end
function Views.expeditionObjective(g)
  local state = g.run
  local name = state.wave == Descent.totalWaves + 1 and 'LIMBO GUARDIAN'
    or ('WAVE ' .. state.wave .. ' / ' .. Descent.totalWaves)
  if state.phase == 'complete' then
    return 'Ring fragment recovered.'
  elseif state.phase == 'preparing' then
    return 'Preparation / ' .. name
  elseif state.phase == 'countdown' then
    return 'The rite begins in ' .. math.ceil(state.countdown)
  end
  return name .. ' / Remaining: ' .. Descent.remaining(g)
end
function Views.classicObjective(g)
  if g.bossDead then
    return 'Return to the gate and end the trial.'
  elseif g.seals < 3 then
    return 'Break the court seals  ' .. g.seals .. ' / 3'
  elseif not g.bossSpawned then
    local alive = 0
    for _, enemy in ipairs(Pools.of(g, 'enemies')) do
      if enemy.hp > 0 then
        alive = alive + 1
      end
    end
    return 'Defeat the remaining defenders: ' .. alive
  end
  return 'Destroy the Margrave of Ash.'
end
return Views

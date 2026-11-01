-- Catalogue actions are registered tools; parsing and validation precede
-- execution. Field lifecycle, targets and stations remain owned by Field.
local Registry = require('src.core.registry')
local Catalog = require('src.run.field.catalog')
local Presentation = require('src.session.presentation')
local Abilities = require('src.content.abilities')
local Weapons = require('src.content.weapons')
local Occult = require('src.content.occult_catalog')
local Settings = require('src.content.field')
local Stations = require('src.run.field.stations')
local Roles = require('src.core.roles')
local Access = require('src.run.field.access')
local Archetypes = require('src.content.enemies')
local Attacks = require('src.enemies.actions')
local MathX = require('src.core.mathx')
local Bodies = require('src.combat.bodies')
local Actions = {}
Actions.fixed = Registry:new('field actions', function(entry, id)
  assert(type(entry.run) == 'function', 'field action ' .. id .. ' needs run(g, field)')
  Access.check(entry.feature)
end)
Actions.families = Registry:new('field action families', function(entry, id)
  assert(type(entry.pattern) == 'string', 'field family ' .. id .. ' needs a pattern')
  assert(type(entry.run) == 'function', 'field family ' .. id .. ' needs run(g, field, value)')
end)
local function call(method, close, feature)
  return {
    feature = feature,
    run = function(g, field)
      local result = field[method](g)
      if result and close then
        field.close(g)
      end
      return true
    end,
  }
end
for _, entry in ipairs({
  { 'field_close', 'close' },
  { 'field_open', 'open' },
  { 'field_reset', 'reset' },
  { 'field_skirmish', 'skirmish' },
  { 'field_refill', 'refill' },
  { 'field_god', 'toggleGod' },
  { 'field_freeze', 'toggleFreeze' },
  { 'field_shop', 'shop', 'trade' },
}) do
  Actions.fixed:register(entry[1], call(entry[2], false, entry[3]))
end
Actions.fixed:register('field_archive', {
  run = function(g)
    g.state, g.help, g.map = 'field_archive', false, false
    g.view.presentationPrevious = nil
    Presentation.capture(g, false)
    return true
  end,
})
Actions.fixed:register('field_hitboxes', {
  run = function(g, field)
    g.testField.hitboxes = not g.testField.hitboxes
    field.tell(g, g.testField.hitboxes and 'field_hitboxes_on' or 'field_hitboxes_off')
    return true
  end,
})
-- The attacks of the selected demon, one at a time, on demand: F3 names the next,
-- F4 has the nearest of its kind do it (app/field_tools.lua).
local function selectedBlows(g)
  return Archetypes.get(g.testField.selected).attacks
end
Actions.fixed:register('field_blow_next', {
  run = function(g, field)
    local blows = selectedBlows(g)
    g.testField.blow = (g.testField.blow or 0) % #blows + 1
    local blow = blows[g.testField.blow]
    field.tell(g, 'field_blow', { index = g.testField.blow, count = #blows, id = blow.id })
    return true
  end,
})
Actions.fixed:register('field_blow_go', {
  run = function(g, field)
    local p, best, far = Roles.controlled(g), nil, math.huge
    Bodies.each(g, function(e)
      local d = MathX.len(e.x - p.x, e.z - p.z)
      if e.hp > 0 and e.fieldKind == g.testField.selected and d < far then
        best, far = e, d
      end
    end)
    local blow = selectedBlows(g)[g.testField.blow or 1]
    if not best then
      field.tell(g, 'field_no_body')
      return true
    end
    best.awake, best.visible, best.memory, best.target = true, true, Settings.engage.memory, p.id
    best.previewFrame, best.recover = nil, 0
    Attacks.begin(g, best, far, blow)
    field.tell(g, 'field_blow_gone', { id = blow.id, windup = blow.windup })
    return true
  end,
})
for _, entry in ipairs({ { 'field_pose_prev', -1 }, { 'field_pose_next', 1 } }) do
  local delta = entry[2]
  Actions.fixed:register(entry[1], {
    run = function(g, field)
      if field.pose(g, delta) then
        field.close(g)
      end
      return true
    end,
  })
end
Actions.fixed:register('field_low', {
  run = function(g, field)
    Roles.controlled(g).hp, Roles.controlled(g).armor, Roles.controlled(g).souls =
      Settings.lowHealth, 0, 0
    Abilities.fill(g, true, Roles.controlled(g))
    Weapons.clear(g, Roles.controlled(g))
    field.tell(g, 'field_low')
    field.close(g)
    return true
  end,
})
Actions.families:register('archive', {
  pattern = '^archive_(%d+)$',
  run = function(g, _, index)
    index = tonumber(index)
    if not Occult.entries[index] then
      return false
    end
    g.testField.archiveSelection = index
    return true
  end,
})
Actions.families:register('station', {
  pattern = '^field_station_([%w_]+)$',
  run = function(g, field, id)
    local station = Stations:find(id)
    if not station or not Access.allows(g.testField, station.feature) then
      return false
    end
    return station.run(g, field)
  end,
})
Actions.families:register('chamber', {
  pattern = '^field_chamber_([%w_]+)$',
  run = function(g, field, id)
    return field.chamber(g, id, 1)
  end,
})
Actions.families:register('select', {
  pattern = '^field_select_([%w_]+)$',
  run = function(g, _, id)
    if not Catalog.contains(id) then
      return false
    end
    g.testField.selected, g.testField.poseIndex = id, 1
    return true
  end,
})
Actions.families:register('spawn', {
  pattern = '^field_spawn_([%w_]+)_([13])$',
  run = function(g, field, id, count)
    if not Catalog.contains(id) then
      return false
    end
    if field.summon(g, id, tonumber(count)) then
      field.close(g)
    end
    return true
  end,
})
Actions.families:register('weapon', {
  pattern = '^field_weapon_(%d+)$',
  run = function(g, field, value)
    local slot = tonumber(value)
    if not Weapons.inHand(g, slot) then
      return false
    end
    g:switchWeapon(slot)
    field.close(g)
    return true
  end,
})
Actions.families:register('seal', {
  pattern = '^field_seal_([%w_]+)$',
  run = function(g, field, id)
    if field.visitSeal(g, id) then
      field.close(g)
    end
    return true
  end,
})
function Actions.dispatch(g, id, field)
  if not g.testField or type(id) ~= 'string' then
    return false
  end
  local exact = Actions.fixed:find(id)
  if exact then
    if not Access.allows(g.testField, exact.feature) then
      return false
    end
    return exact.run(g, field)
  end
  for _, family in Actions.families:each() do
    local first, second = id:match(family.pattern)
    if first then
      return family.run(g, field, first, second)
    end
  end
  return false
end
return Actions

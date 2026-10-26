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
local Actions = {}
Actions.fixed = Registry:new('field actions', function(entry, id)
  assert(type(entry.run) == 'function', 'field action ' .. id .. ' needs run(g, field)')
end)
Actions.families = Registry:new('field action families', function(entry, id)
  assert(type(entry.pattern) == 'string', 'field family ' .. id .. ' needs a pattern')
  assert(type(entry.run) == 'function', 'field family ' .. id .. ' needs run(g, field, value)')
end)
local function call(method, close)
  return {
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
  { 'field_shop', 'shop' },
}) do
  Actions.fixed:register(entry[1], call(entry[2]))
end
Actions.fixed:register('field_archive', {
  run = function(g)
    g.state, g.help, g.map = 'field_archive', false, false
    g.view.presentationPrevious = nil
    Presentation.capture(g, false)
    return true
  end,
})
Actions.fixed:register('field_tier', {
  run = function(g, field)
    g.testField.tier = (g.testField.tier or 1) % Settings.maxTier + 1
    field.tell(g, 'field_tier', { tier = g.testField.tier })
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
    Abilities.fill(g, true)
    for _, state in pairs(Roles.controlled(g).arsenal) do
      state.mag, state.reserve = 0, 0
    end
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
    if not station then
      return false
    end
    return station.run(g, field)
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

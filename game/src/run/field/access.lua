-- Per-session tool availability. Missing features preserve historical field
-- sessions/replays; a release may disable tools without deleting executors.
-- UI passes the read-only field view, execution passes the mode's record.
local Id = require('src.core.id')
local Access = {}
function Access.check(feature)
  if feature ~= nil then
    Id.check(feature, 'field feature')
    assert(require('src.content.field').toolFeatures[feature], 'unknown field feature ' .. feature)
  end
end
function Access.copy(options)
  local features = options and options.features
  if features == nil then
    return nil
  end
  assert(type(features) == 'table', 'field features must be a table')
  local copy = {}
  for id, enabled in pairs(features) do
    Access.check(id)
    assert(type(enabled) == 'boolean', 'field feature ' .. id .. ' must be boolean')
    copy[id] = enabled
  end
  return copy
end
function Access.allows(record, feature)
  return feature == nil or not record or not record.features or record.features[feature] ~= false
end
return Access

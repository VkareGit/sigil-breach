-- Registry keys are also persisted by SIGIL06–08. Keep one grammar at the
-- definition and save boundaries; display labels and local action names are free text.
local Id = {}
function Id.valid(value)
  return type(value) == 'string' and value:match('^[%w_]+$') ~= nil
end
function Id.check(value, path)
  assert(Id.valid(value), (path or 'id') .. ': expected letters, digits or underscores')
  return value
end
return Id

-- The ending screen: a lost trial on the proving ground, a death in the chapel.
local D = require('src.ui.chapel')
local FieldUI = require('src.ui.test_field')
local Queries = require('src.session.queries')
local S = {}
function S.draw(g, _, U)
  if Queries.field(g) then
    return FieldUI.ending(g, U)
  end
  return D.ending(g)
end
return S

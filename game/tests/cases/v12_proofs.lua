-- The extension proofs of plan v12 start here: what the public registries
-- already take today, with no change in game/src, and left as it was found.
local F = require('tests.support.fixtures')
local Proof = require('tests.support.extension.proof')
local Conditions = require('src.content.conditions')
local Release = require('src.app.release')
local T = {}
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'extension: ', 'extension: ')
  Proof.with({
    function()
      Conditions.unregister('proof_frost')
    end,
  }, function()
    Conditions.register('proof_frost', { speed = 0.6 })
    check('a new condition enters through its registry', Conditions.find('proof_frost') ~= nil)
    local g = Game.new('field', 'proving', Release.sessionOptions.field)
    check('and a session starts with it present', g ~= nil)
  end)
  check('the proof leaves nothing behind', Conditions.find('proof_frost') == nil)
  check('a failing proof still undoes its registrations', not pcall(Proof.with, {}, function()
    error('expected')
  end))
  return lines
end
return T

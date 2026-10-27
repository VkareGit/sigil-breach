-- Historical CONTENT configuration for frozen v0.33 regression fixtures.
-- Point 4 intentionally changes boss decisions/life stocks. Old projections
-- still verify the current engine against the old encounters, not a rewritten
-- expected result. The current encounters have their own golden/replay/tests.
-- No production flag, global mutation, or patch to an executor.
local Schema = require('src.core.schema')
local A = require('src.content.enemies')
local M = {}
function M.game(Game)
  local old = { boss = Schema.copy(A.boss), furfur = Schema.copy(A.furfur) }
  for _, def in pairs(old) do
    def.phases, def.tactics = nil, nil
  end
  old.boss.attacks = { old.boss.attacks[1] }
  old.furfur.attacks = { old.furfur.attacks[1], old.furfur.attacks[2], old.furfur.attacks[3] }
  old.furfur.attacks[2].rest, old.furfur.attacks[3].rest = nil, nil
  return setmetatable({
    new = function(...)
      local g = Game.new(...)
      local spawn = g.spawn
      g.spawn = function(self, kind, x, z)
        local e = spawn(self, kind, x, z)
        if old[kind] then
          e.archetype = old[kind]
          e.phaseBaseHp = nil
        end
        return e
      end
      return g
    end,
  }, { __index = Game })
end
return M

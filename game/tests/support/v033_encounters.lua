-- Historical CONTENT configuration for frozen v0.33 regression fixtures.
-- Point 4 intentionally changes boss decisions/life stocks. Old projections
-- still verify the current engine against the old encounters, not a rewritten
-- expected result. The current encounters have their own golden/replay/tests.
-- No production flag, global mutation, or patch to an executor.
local Schema = require('src.core.schema')
local M = {}
-- A session already made takes the old encounters from now on.
function M.adopt(g, old)
  old = old or M.content()
  local spawn = g.spawn
  g.spawn = function(self, kind, x, z)
    local e = spawn(self, kind, x, z)
    if old[kind] then
      local Rules = require('src.combat.rules')
      Rules.equip(e, old[kind])
      Rules.applyTier(e, e.tier)
      e.phaseBaseHp = nil
    end
    return e
  end
  return g
end
function M.content()
  local old = {
    boss = Schema.copy(require('tests.support.content.boss_v1')),
    furfur = Schema.copy(require('tests.support.content.furfur_v1')),
    imp = Schema.copy(require('tests.support.content.imp_pre_pressure')),
    armored = Schema.copy(require('tests.support.content.armored_pre_pressure')),
    stolas = Schema.copy(require('tests.support.content.stolas_pre_pressure')),
    buer = Schema.copy(require('tests.support.content.buer_pre_pressure')),
  }
  for _, def in pairs(old) do
    def.phases, def.tactics = nil, nil
  end
  old.boss.attacks = { old.boss.attacks[1] }
  old.stolas.attacks = { old.stolas.attacks[1] }
  old.buer.attacks = { old.buer.attacks[1] }
  old.furfur.attacks = { old.furfur.attacks[1], old.furfur.attacks[2], old.furfur.attacks[3] }
  old.furfur.attacks[2].rest, old.furfur.attacks[3].rest = nil, nil
  return old
end
function M.game(Game)
  local old = M.content()
  return setmetatable({
    new = function(mode, map, options)
      -- The old rules of effort too: the field's drill was recorded under them.
      if mode == 'field' then
        options = options and Schema.copy(options) or {}
        options.attrition = false
      end
      return M.adopt(Game.new(mode, map, options), old)
    end,
  }, { __index = Game })
end
return M

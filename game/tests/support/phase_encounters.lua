-- Frozen content for phase lifecycle/follow-up regression, not live balance.
-- Public bosses now have one stock; the reusable multi-stock system remains
-- covered by these explicit examples and still uses the current executors.
local Current = require('src.content.enemies')
local F = setmetatable({
  boss = require('tests.support.content.boss_v1'),
  furfur = require('tests.support.content.furfur_v1'),
}, { __index = Current })
function F.game(Game)
  return setmetatable({
    new = function(...)
      local g = Game.new(...)
      local spawn = g.spawn
      g.spawn = function(self, kind, x, z)
        local e = spawn(self, kind, x, z)
        if kind == 'boss' or kind == 'furfur' then
          require('src.combat.rules').equip(e, F[kind])
        end
        return e
      end
      return g
    end,
  }, { __index = Game })
end
return F

-- What the game teaches (audit L04): the first page of the help is the rules of the fight, a
-- line for each move; a thing first seen is taught once, only when nothing hunts the knight.
local Encounter = require('src.session.encounter')
local F = require('tests.support.fixtures')
local Help = require('src.ui.screens.help')
local K = require('src.content.tuning').clocks
local Lessons = require('src.feedback.lessons')
local P = require('src.run.pilgrimage')
local Text = require('src.content.text')
local T = {}
local function run(g, seconds)
  for _ = 1, math.ceil(seconds * 120) do
    g:update(1 / 120, {})
  end
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'lessons: ', 'lessons: ')
  P.forget()
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  Encounter.clearStage(g)
  local p = g.player
  -- Every move the fight turns on has its words.
  for _, key in ipairs({
    'rule_ring_2',
    'rule_guard_2',
    'rule_execution_2',
    'rules_rally',
    'rules_chain',
    'rules_breath',
    'rules_rounds',
    'rules_fire',
    'lesson_ring',
    'lesson_guard',
    'lesson_chain',
    'lesson_rounds',
  }) do
    check(key .. ' is written', Text.get(key) ~= key and #Text.get(key) > 20)
  end
  Help.reset(g)
  local _, _, _, page, total = Help.page(g)
  check('the help opens on the rules', page == 1 and total >= 2)
  -- A chain while a creature hunts him: taught after, not during.
  local hunter = g:spawn('imp', p.x + 10, p.z - 10)
  hunter.awake = true
  for _ = 1, 2 do
    local e = g:spawn('imp', p.x + 8, p.z - 8)
    g:damageEnemy(e, e.hp + 1, 'weapon', nil, p.id, p.loadout[1])
  end
  for _ = 1, 12 do
    hunter.awake, hunter.memory = true, 1
    g:update(1 / 120, {})
  end
  check('a chain is noted', g.view.lessons and g.view.lessons.seen.chain)
  check('but not taught while he is hunted', Lessons.showing(g.view) == nil)
  hunter.hp = 0
  run(g, 0.1)
  check('it is taught once nothing hunts him', Lessons.showing(g.view) == 'lesson_chain')
  run(g, K.lessonTime + 0.2)
  check('for a while', Lessons.showing(g.view) == nil)
  for _ = 1, 2 do
    local e = g:spawn('imp', p.x + 8, p.z - 8)
    g:damageEnemy(e, e.hp + 1, 'weapon', nil, p.id, p.loadout[1])
  end
  run(g, 0.1)
  check('and never twice', Lessons.showing(g.view) == nil)
  P.forget()
  return lines
end
return T

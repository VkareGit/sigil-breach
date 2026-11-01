-- E3/E4: the session's ECS world, its prefabs and strict entities.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  -- Rules proven on the encounters they were tuned for (tests/support/v033_encounters.lua).
  G = require('tests.support.v033_encounters').game(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'entities: ', 'entities: ')
  local Strict = require('src.core.strict')
  local wasStrict = Strict.enabled
  Strict.enabled = true
  local g = G.new('floor')
  g.testing = true
  g:start()
  check(
    'a session owns an ECS world, an event bus and two random streams',
    g.ecs and g.bus and g.rng and g.rng.sim and g.rng.present and g.rng.sim ~= g.rng.present
  )
  -- Pools follow the session's own arrays, even when a test replaces them.
  g.enemies = {}
  local imp = g:spawn('imp', 16, 20)
  check(
    'a spawned demon comes from the creature prefab and joins the enemies pool',
    imp.prefab == 'creature' and g.ecs:query('brain', 'health')[1] == imp
  )
  check(
    'prefab defaults and the demon-specific values are both in place',
    imp.ai == 'idle'
      and imp.attack == 1.5
      and imp.hp == 112
      and imp.lastX == 16
      and imp.facing == math.pi
  )
  local typo = pcall(function()
    imp.hpp = 1
  end)
  check('writing a field that no component declares is an error in strict mode', not typo)
  -- A whole fight writes only declared fields (strict mode would raise).
  local ok, message = pcall(function()
    g.player.x, g.player.z = 16, 26
    for _, kind in ipairs({ 'armored', 'stolas', 'buer', 'furfur' }) do
      local e = g:spawn(kind, 10 + #g.enemies * 2, 14)
      e.awake, e.memory = true, 30
    end
    for _ = 1, 600 do
      g:update(1 / 120, { shoot = true })
    end
  end)
  check('ten seconds of fighting write only declared fields (' .. tostring(message) .. ')', ok)
  Strict.enabled = wasStrict
  return lines
end
return Tests

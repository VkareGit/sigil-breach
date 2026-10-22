-- Shared test fixtures (0.24 E11): the helpers every test file used to
-- write for itself — the check that records PASS lines, the tolerance
-- comparison and the common sessions. A new test starts from these.
local Fixtures = {}
-- check(name, ok): fails with 'FAIL <fail><name>', records 'PASS <pass><name>'.
function Fixtures.checker(lines, fail, pass)
  fail, pass = fail or '', pass or ''
  return function(name, ok)
    assert(ok, 'FAIL ' .. fail .. name)
    lines[#lines + 1] = 'PASS ' .. pass .. name
  end
end
-- near(a, b[, tolerance]) with the file's default tolerance; fixed: the
-- tolerance cannot be overridden by a third argument.
function Fixtures.within(default, fixed)
  return function(a, b, tolerance)
    if a == nil or b == nil then
      return false
    end
    return math.abs(a - b) < ((not fixed and tolerance) or default)
  end
end
-- The classic arena, started and emptied: no demons, shots, hazards or
-- supplies; the knight at the nave's entrance facing the altar.
function Fixtures.arena(G)
  local g = G.new('classic')
  g.testing = true
  g:start()
  g.enemies, g.bullets, g.hazards, g.pickups = {}, {}, {}, {}
  g.player.x, g.player.z, g.player.yaw = 16, 25, math.pi
  return g
end
-- A session field by name, wherever it lives (presentation state is g.view).
function Fixtures.field(g, key)
  if require('src.session.fields').viewOwner(key) then
    return g.view[key]
  end
  return g[key]
end
-- A hand-made knight's weapons: { id = { mag, reserve, spent = n }, ... } in
-- the default loadout order; returns loadout, arsenal.
function Fixtures.arsenal(rounds)
  local Weapons = require('src.content.weapons')
  local loadout, arsenal = {}, {}
  for i, id in ipairs(Weapons.defaultLoadout) do
    loadout[i] = id
    local state = Weapons.newState(Weapons.get(id))
    local r = rounds[id]
    if r then
      state.mag, state.reserve, state.spent = r[1], r[2], r.spent or 0
    end
    arsenal[id] = state
  end
  return loadout, arsenal
end
-- A started expedition.
function Fixtures.expedition(G)
  local g = G.new('descent')
  g.testing = true
  g:start()
  return g
end
return Fixtures

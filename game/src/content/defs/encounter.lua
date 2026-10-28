-- Optional encounter data. Phases select immutable attacks by id.
local Schema = require('src.core.schema')
local E = {}
local Follow = Schema:new('attack follow-up', {
  attack = { type = 'string', required = true },
  within = { type = 'number', required = true, min = 0 },
})
local Move = Schema:new('attack choice', {
  attack = { type = 'string', required = true },
  ideal = { type = 'number', required = true, min = 0 },
  weight = { type = 'number', default = 1, min = 0 },
  min = { type = 'number', default = 0, min = 0 },
  max = { type = 'number', min = 0 },
  fromTier = { type = 'number', default = 1, min = 1 },
  after = {
    type = 'table',
    schema = Follow,
    desc = 'only after this completed attack, same target',
  },
})
E.tactics = Schema:new('attack tactics', {
  policy = { type = 'string', default = 'context', values = { 'context' } },
  repeatPenalty = { type = 'number', default = 0.25, min = 0, max = 1 },
  moves = { type = 'table', required = true, list = Move },
})
E.phase = Schema:new('encounter phase', {
  id = { type = 'string', required = true },
  at = { type = 'number', min = 0, max = 1, desc = 'enter at this share of current maximum HP' },
  refill = { type = 'number', min = 0, desc = 'new HP stock, share of spawn HP including tier' },
  recovery = { type = 'number', default = 1.2, min = 0 },
  transitionPose = { type = 'string', desc = 'named atlas pose on the recovery clock' },
  pace = { type = 'number', default = 1, min = 1, desc = 'cooldowns only, never windup/recovery' },
  speed = { type = 'number', default = 1, min = 0 },
  ideal = { type = 'number', min = 0, desc = 'preferred walking distance in this phase (m)' },
  tactics = { type = 'table', schema = E.tactics },
})
local function tactics(spec, ids, path)
  if not spec then
    return
  end
  assert(#spec.moves > 0, path .. ': at least one choice required')
  local seen = {}
  for i, move in ipairs(spec.moves) do
    local where = path .. '.moves[' .. i .. ']'
    assert(ids[move.attack], where .. ': unknown attack ' .. move.attack)
    assert(not seen[move.attack], where .. ': repeated attack ' .. move.attack)
    seen[move.attack] = true
    assert(move.weight > 0, where .. '.weight: must be positive')
    assert(move.fromTier % 1 == 0, where .. '.fromTier: expected integer')
    local attack = ids[move.attack]
    if move.after then
      assert(ids[move.after.attack], where .. '.after: unknown attack ' .. move.after.attack)
      assert(move.after.attack ~= move.attack, where .. '.after: cannot follow itself')
      assert(move.after.within > 0, where .. '.after.within: must be positive')
    end
    assert(
      math.max(move.min, attack.minRange) <= math.min(move.max or attack.range, attack.range),
      where .. ': no usable distance'
    )
  end
  -- Author finite strings, never a cycle that can hide the final opening.
  local edges = {}
  for _, move in ipairs(spec.moves) do
    assert(
      not move.after or seen[move.after.attack],
      path .. ': follow-up predecessor not in moves'
    )
    edges[move.attack] = move.after and move.after.attack or nil
  end
  for id in pairs(edges) do
    local visited, nextId = {}, id
    while nextId do
      assert(not visited[nextId], path .. ': cyclic follow-up chain')
      visited[nextId], nextId = true, edges[nextId]
    end
  end
end
function E.validate(def, path)
  local ids = {}
  for _, attack in ipairs(def.attacks) do
    ids[attack.id] = attack
  end
  tactics(def.tactics, ids, path .. '.tactics')
  if not def.phases then
    return
  end
  assert(#def.phases >= 2, path .. '.phases: need at least two phases')
  local seen = {}
  for i, phase in ipairs(def.phases) do
    local where = path .. '.phases[' .. i .. ']'
    assert(not seen[phase.id], where .. ': repeated phase id ' .. phase.id)
    seen[phase.id] = true
    if i == 1 then
      assert(phase.at == nil and phase.refill == nil, where .. ': first phase uses spawn health')
    else
      assert(phase.at ~= nil and phase.at < 1, where .. '.at: required, below one')
      assert(phase.refill == nil or phase.refill > 0, where .. '.refill: must be positive')
      assert(phase.at > 0 or phase.refill ~= nil, where .. ': exhausted stock requires refill')
    end
    tactics(phase.tactics, ids, where .. '.tactics')
  end
end
return E

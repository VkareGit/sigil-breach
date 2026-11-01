-- Rounds in the weapon and a reserve to load them from.
local Schema = require('src.core.schema')
local M = { reloads = true }
M.schema = Schema:new('magazine', {
  kind = { type = 'string', required = true },
  capacity = { type = 'number', required = true, min = 1 },
  startReserve = { type = 'number', required = true, min = 0 },
  maxReserve = { type = 'number', required = true, min = 0 },
  packSize = { type = 'number', required = true, min = 1 },
  unitPrice = { type = 'number', default = 3, min = 0 },
})
function M.check(spec, path)
  for _, key in ipairs({ 'capacity', 'startReserve', 'maxReserve', 'packSize' }) do
    assert(spec[key] % 1 == 0, path .. '.' .. key .. ': expected integer')
  end
  assert(spec.startReserve <= spec.maxReserve, path .. ': reserve exceeds maximum')
end
function M.newState(spec)
  return { mag = spec.capacity, reserve = spec.startReserve }
end
function M.valid(spec, state)
  local mag, reserve = state.mag, state.reserve
  return type(mag) == 'number'
    and mag >= 0
    and mag <= spec.capacity
    and mag == math.floor(mag)
    and type(reserve) == 'number'
    and reserve >= 0
    and reserve <= spec.maxReserve
    and reserve == math.floor(reserve)
end
function M.canFire(_, state)
  return state.mag > 0
end
function M.spend(_, state, count)
  local rounds = math.min(count, state.mag)
  state.mag = state.mag - rounds
  return rounds
end
function M.full(spec, state)
  return state.mag >= spec.capacity or state.reserve <= 0
end
function M.stocked(_, state)
  return (state.reserve or 0) > 0
end
function M.pending(spec, state)
  return math.min(spec.capacity - state.mag, state.reserve)
end
function M.load(spec, state)
  local amount = math.max(0, M.pending(spec, state))
  state.mag = state.mag + amount
  state.reserve = state.reserve - amount
  return amount
end
function M.room(spec, state)
  return spec.maxReserve - state.reserve
end
function M.refill(spec, state, amount, cap)
  local before = state.reserve
  state.reserve = math.min(cap or spec.maxReserve, before + amount)
  return state.reserve - before
end
function M.fill(spec, state)
  state.mag, state.reserve = spec.capacity, spec.maxReserve
end
function M.clear(_, state)
  state.mag, state.reserve = 0, 0
end
function M.restock(spec, state)
  state.reserve = spec.startReserve
end
function M.left(_, state)
  return state.mag + state.reserve
end
function M.meter(spec, state)
  return state.mag, state.reserve, spec.capacity
end
function M.offer(spec)
  return spec.packSize, spec.unitPrice, spec.maxReserve
end
function M.pack(state)
  return { mag = state.mag, reserve = state.reserve }
end
function M.list(saved)
  return { saved.mag, saved.reserve }
end
function M.unpack(spec, a, b, number)
  return { mag = number(a, 0, spec.capacity, true), reserve = number(b, 0, spec.maxReserve, true) }
end
return M

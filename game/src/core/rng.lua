-- Deterministic random streams (xorshift32). A session owns two:
--   sim      seeded per session; the only randomness the simulation may use
--            (replays, golden master and lockstep depend on it).
--   present  for particles and sound variation; free to differ per run.
local bit = require('bit')
local Class = require('src.core.class')
local Rng = Class:extend('Rng')
function Rng:init(seed)
  self:seed(seed or 1)
end
function Rng:seed(seed)
  seed = math.floor(tonumber(seed) or 1) % 4294967296 -- constant: 2^32, the state's range
  self.state = bit.tobit(seed == 0 and 2463534242 or seed) -- constant: xorshift32's own seed
end
-- The stream's state as a save keeps it: a whole number of 32 bits, never 0.
function Rng:get()
  return self.state
end
function Rng.valid(state)
  return type(state) == 'number' and state ~= 0 and bit.tobit(state) == state
end
-- The stream taken up exactly where a save left it (PLAN Z2a).
function Rng:set(state)
  assert(Rng.valid(state), 'invalid random state')
  self.state = state
end
-- Uniform in [0, 1).
function Rng:random()
  local x = self.state
  x = bit.bxor(x, bit.lshift(x, 13)) -- constant: xorshift32 shift
  x = bit.bxor(x, bit.rshift(x, 17)) -- constant: xorshift32 shift
  x = bit.bxor(x, bit.lshift(x, 5))
  self.state = x
  return (x % 4294967296) / 4294967296 -- constant: 2^32
end
-- Uniform in [a, b).
function Rng:range(a, b)
  return a + (b - a) * self:random()
end
return Rng

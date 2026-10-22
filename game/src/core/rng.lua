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
  seed = math.floor(tonumber(seed) or 1) % 4294967296
  self.state = bit.tobit(seed == 0 and 2463534242 or seed)
end
-- Uniform in [0, 1).
function Rng:random()
  local x = self.state
  x = bit.bxor(x, bit.lshift(x, 13))
  x = bit.bxor(x, bit.rshift(x, 17))
  x = bit.bxor(x, bit.lshift(x, 5))
  self.state = x
  return (x % 4294967296) / 4294967296
end
-- Uniform in [a, b).
function Rng:range(a, b)
  return a + (b - a) * self:random()
end
return Rng

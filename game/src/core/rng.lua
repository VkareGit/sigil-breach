-- Deterministic random streams (xorshift32). A session owns two:
--   sim      seeded per session; the only randomness the simulation may use
--            (replays, golden master and lockstep depend on it).
--   present  for particles and sound variation; free to differ per run.
local bit = require('bit')
local Class = require('src.core.class')
local Rng = Class:extend('Rng')
Rng.largest = 4294967295 -- constant: 2^32 - 1, the largest seed and state
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
-- A seed a way can draw and keep: a whole number from 1 to 2^32 - 1.
function Rng.validSeed(seed)
  return type(seed) == 'number' and seed >= 1 and seed <= Rng.largest and seed % 1 == 0
end
-- The low 32 bits of a product of two 32-bit words, from 16-bit halves (a double holds
-- 53 bits, a product of two words needs 64).
local function multiply(a, b)
  a, b = a % 4294967296, b % 4294967296 -- constant: 2^32
  local al, bl = a % 65536, b % 65536 -- constant: 2^16, a half word
  local ah, bh = (a - al) / 65536, (b - bl) / 65536 -- constant: 2^16
  return bit.tobit(al * bl + ((ah * bl + al * bh) % 65536) * 65536) -- constant: 2^16
end
-- A seed spread over all 32 bits (MurmurHash3's finaliser, a bijection that keeps 0 at 0):
-- xorshift32 from a small seed starts with rolls near zero; seeds 1 to 1000 all give a first
-- roll under 0.07 (PLAN Z2b). Only a way's own seed goes through it; the sessions' fixed
-- seed 1 keeps its stream (golden master, replays).
function Rng.mix(seed)
  local h = bit.tobit(seed % 4294967296) -- constant: 2^32
  h = multiply(bit.bxor(h, bit.rshift(h, 16)), 0x85ebca6b) -- constant: fmix32 shift and multiplier
  h = multiply(bit.bxor(h, bit.rshift(h, 13)), 0xc2b2ae35) -- constant: fmix32 shift and multiplier
  return bit.bxor(h, bit.rshift(h, 16)) % 4294967296 -- constant: fmix32 shift, 2^32
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

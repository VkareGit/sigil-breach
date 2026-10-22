-- Countdown timers: fields that fall to 0 with time (stun, cooldowns,
-- flashes). One helper instead of hand-written max(0, x - dt) everywhere.
local Timers = {}
local max = math.max
function Timers.down(value, dt)
  return max(0, (value or 0) - dt)
end
-- Count every named field of t down by dt (missing fields count as 0).
function Timers.tick(t, fields, dt)
  for i = 1, #fields do
    local k = fields[i]
    t[k] = max(0, (t[k] or 0) - dt)
  end
end
return Timers

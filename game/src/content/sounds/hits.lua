-- The blow speaks before the chapel answers: bone, stopped iron, split oak.
-- Dry, fixed strikes; no bells, pitch jitter, noise source or delayed attack.
local cos, pi, exp, min, max = math.cos, math.pi, math.exp, math.min, math.max
local R = {}

-- A struck mode starts at full displacement. Unlike Synth.ring's sine,
-- cosine gives a nonzero first sample without borrowing the noise input.
local function mode(t, f, decay)
  return cos(2 * pi * f * t) * exp(-t * decay)
end

-- A small bone clack: inharmonic splinters die before the blunt core.
-- Positive weights sum to one; every mode is bounded by one for t >= 0.
local function bone(t, f, decay)
  return 0.54 * mode(t, f, decay)
    + 0.30 * mode(t, f * 1.58, decay * 1.7)
    + 0.16 * mode(t, f * 2.43, decay * 2.8)
end

local function strike(duration, voice)
  return {
    duration = duration,
    priority = 1,
    make = function(_rate)
      -- No mutable history: overlapping renders cannot colour one another.
      -- Synth.effect may supply its noise arguments; these voices ignore them.
      return function(t, u)
        local release = max(0, min(1, (1 - u) * duration / 0.012))
        return voice(t) * release
      end
    end,
  }
end

-- Flesh: one plain, tightly damped clack; no wet tail or answering strike.
R.hit_tick = strike(0.080, function(t)
  return bone(t, 2160, 105) * 0.60
end)

-- Stopped by plate or ward: a closed, uneven iron cluster, lower and duller
-- than bone. Its stubborn short buzz says resistance, not penetration.
R.hit_armor = strike(0.130, function(t)
  return mode(t, 1280, 65) * 0.29 + mode(t, 1715, 85) * 0.20 + mode(t, 2860, 130) * 0.11
end)

-- A surviving head hit: the same bone, raised and given one hard splinter.
-- The extra edge is brief enough to keep a burst from becoming a whistle.
R.hit_head = strike(0.105, function(t)
  return bone(t, 2960, 95) * 0.50 + mode(t, 6370, 280) * 0.10
end)

-- Killing blow: the bright fracture seats into a heavy wooden block.
-- Integrated frequency falls 820 -> 520 Hz with an 8 ms time constant;
-- the brief settling of the wood adds weight without a bass gunshot.
-- No later strike, tuned interval or ringing bronze to contest a medal.
R.kill_confirm = strike(0.340, function(t)
  local wood = cos(2 * pi * (520 * t + 2.4 * (1 - exp(-t / 0.008)))) * exp(-t * 17)
  return bone(t, 2540, 75) * 0.36 + wood * 0.18 + mode(t, 1117, 32) * 0.06
end)

-- Each recipe's absolute weights total 0.60, including the unit-bounded
-- bone cluster. Decays and release only reduce that bound, at every time.
-- All terms start positive: the actual peak is 0.60 at t = 0 at any rate.
-- No limiter, normalisation pass or dependence on Synth.effect's clamp.
return R

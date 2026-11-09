-- Brief rewards in the chapel: bronze, pipes and struck iron, without words.
-- Each make owns its reflections. No pitch jitter: the ladder keeps its tune.
return function(Synth)
  local sin, pi, exp, min, max = math.sin, math.pi, math.exp, math.min, math.max
  local ring = Synth.ring
  -- They must carry over gunfire: the loudest stays near 0.6.
  local GAIN = 1.7
  local R = {}

  -- Unit-bounded partial sums. The bright, inharmonic edge dies first; no hum
  -- an octave below the prime, leaving the powder reports their low end.
  local function bronze(t, at, f, decay)
    return 0.68 * ring(t, at, f, decay)
      + 0.22 * ring(t, at, f * 2, decay * 1.5)
      + 0.10 * ring(t, at, f * 2.76, decay * 2.4)
  end
  local function pipe(t, at, f, decay)
    return 0.80 * ring(t, at, f, decay)
      + 0.16 * ring(t, at, f * 2, decay * 1.4)
      + 0.04 * ring(t, at, f * 3, decay * 2)
  end
  local function chapel(duration, voice)
    return {
      duration = duration,
      priority = 1,
      make = function(rate)
        local walls = Synth.reflections(rate, { { 0.043, 0.10 }, { 0.087, 0.05 } })
        return function(t, u, noise, low, slower, high)
          local dry = voice(t, high)
          local release = max(0, min(1, (1 - u) * duration / 0.025))
          -- Reflections have gain <= 1.15. Every recipe stays below 0.60,
          -- including |high| <= 1.48; no reliance on clip or effect's clamp.
          return walls(dry) * release * GAIN
        end
      end,
    }
  end

  -- One family: an accented opening, a fifth, then an octave and a crown.
  -- The whole register climbs D, E, F, G; open fifths lead into fuller crowns.
  -- At 105 ms spacing and decay >= 11, the bell sum is bounded by
  -- 0.21 / (1 - exp(-11 * 0.105)), even with infinitely many strikes.
  local function ladder(duration, pitches, decay, crown)
    return chapel(duration, function(t, high)
      local bells = 0
      for k, f in ipairs(pitches) do
        bells = bells + bronze(t, (k - 1) * 0.105, f, decay) * (k == 1 and 0.21 or 0.19)
      end
      local triumph = crown
          and (pipe(t, 0.42, 783.9909, 8) * 0.05 + pipe(t, 0.42, 1174.6591, 8) * 0.04)
        or 0
      return bells + triumph + high * 0.04 * exp(-t * 380)
    end)
  end
  R.medal_diptych = ladder(0.46, { 587.3295, 880 }, 14, false)
  R.medal_triptych = ladder(0.60, { 659.2551, 987.7666, 1318.5102 }, 13, false)
  R.medal_tetraptych = ladder(0.76, { 698.4565, 1046.5023, 1396.9129, 1760 }, 12, false)
  R.medal_polyptych =
    ladder(0.94, { 783.9909, 1174.6591, 1567.9817, 1864.6550, 2349.3181 }, 11, true)

  -- Mercy: a gentle descending pipe cadence, A5-E5-D5, seated on the final.
  R.medal_absolved = chapel(0.56, function(t, high)
    return pipe(t, 0, 880, 15) * 0.16
      + pipe(t, 0.12, 659.2551, 14) * 0.12
      + pipe(t, 0.24, 587.3295, 10) * 0.18
      + high * 0.025 * exp(-t * 450)
  end)

  -- Iron deflected upwards, then a tiny two-part glint. Integrated frequency:
  -- 1450 Hz at impact, approaching 2450 Hz with a 12 ms time constant.
  R.medal_parry = chapel(0.34, function(t, high)
    local turn = sin(2 * pi * (2450 * t - 12 * (1 - exp(-t / 0.012)))) * exp(-t * 35) * 0.18
    return turn
      + ring(t, 0.045, 2349.3181, 24) * 0.10
      + ring(t, 0.045, 3322.4376, 42) * 0.06
      + high * 0.035 * exp(-t * 500)
  end)

  -- One piercing stroke, three close splinters: a fast falling metallic rake,
  -- not the ladder's measured bells. The partials open upwards behind it.
  R.medal_one_shot = chapel(0.43, function(t, high)
    local pierce = sin(2 * pi * (900 * t + 18 * (1 - exp(-t * 50)))) * exp(-t * 45) * 0.13
    return pierce
      + bronze(t, 0, 1760, 22) * 0.12
      + bronze(t, 0.028, 2093.0045, 24) * 0.10
      + bronze(t, 0.056, 2637.0205, 20) * 0.08
      + high * 0.03 * exp(-t * 420)
  end)

  -- At death's edge: two choked midrange knocks, answered by an open fifth.
  -- A heartbeat rhythm without a bass heartbeat competing with the guns.
  R.medal_last_rites = chapel(0.68, function(t, high)
    return pipe(t, 0, 587.3295, 38) * 0.12
      + pipe(t, 0.08, 587.3295, 38) * 0.09
      + bronze(t, 0.18, 880, 10) * 0.17
      + pipe(t, 0.18, 587.3295, 8) * 0.06
      + high * 0.03 * exp(-t * 400)
  end)

  -- The headshot: one clean, high pin of silver; no extra notes to count.
  R.medal_smitten = chapel(0.28, function(t, high)
    return ring(t, 0, 1760, 24) * 0.23 + ring(t, 0, 3520, 45) * 0.075 + high * 0.025 * exp(-t * 600)
  end)

  -- Muzzle against the body: a dry wooden clack with a short iron edge.
  -- Its weight is in the midrange, not a second gunshot or a sub-bass thump.
  R.medal_point_blank = chapel(0.27, function(t, high)
    return ring(t, 0, 780, 50) * 0.20
      + ring(t, 0, 1170, 70) * 0.13
      + ring(t, 0, 1910, 90) * 0.07
      + high * 0.05 * exp(-t * 150)
  end)
  return R
end

-- Material voices for the chapel and its inhabitants. Filtered air, iron and
-- stone; no modern sirens or spoken incantations. Rendered once, then pooled.
return function(Synth)
  local sin, pi, exp, min = math.sin, math.pi, math.exp, math.min
  local R = {}
  local ironOnsets, ironGains = { 0.025, 0.11, 0.24 }, { 0.17, 0.1, 0.035 }
  local chainOnsets, chainGains = { 0.02, 0.16, 0.39, 0.67 }, { 0.24, 0.17, 0.09, 0.04 }
  local function breath(duration, throat, air, pulses)
    return {
      duration = duration,
      priority = 3,
      make = function(rate)
        local chest = Synth.resonator(throat, 2.4, rate)
        local mouth = Synth.resonator(air, 1.8, rate)
        return function(t, u, noise, low)
          local envelope = min(1, t / 0.035) * min(1, (1 - u) * 20)
          local rhythm = pulses > 0 and (0.4 + 0.6 * sin(pi * pulses * u) ^ 2) or (0.35 + 0.65 * u)
          return Synth.clip(
            (
              chest(noise) * 1.3
              + mouth(noise) * 0.28
              + low * 0.4
              + sin(2 * pi * throat * 0.25 * t) * 0.08
            )
              * envelope
              * rhythm
          ) * 0.5
        end
      end,
    }
  end
  local function rupture(duration, pitch, grit, metallic)
    return {
      duration = duration,
      priority = 2,
      make = function(rate)
        local hall = Synth.reflections(rate, { { 0.073, 0.28 }, { 0.19, 0.19 }, { 0.36, 0.1 } })
        local stone = Synth.resonator(360, 1.3, rate)
        return function(t, u, noise, low, slow)
          local body = sin(2 * pi * (pitch * t + 9 * (1 - exp(-t * 12)))) * exp(-t * 9) * 0.35
          local dust = (stone(noise) * 0.6 + low * 0.5 + slow * 0.6) * exp(-t * grit)
          local iron = metallic > 0 and metallic * Synth.mail(t, ironOnsets, ironGains) or 0
          return Synth.clip(hall((body + dust + iron) * min(1, t / 0.003))) * min(1, (1 - u) * 8)
        end
      end,
    }
  end
  R.ash_fan_warning = breath(0.62, 250, 1100, 3)
  R.ash_lance_warning = breath(0.62, 135, 650, 0)
  R.ash_spear_warning = breath(0.59, 430, 1700, 0)
  R.furnace_warning = breath(0.52, 180, 820, 2)
  R.antler_warning = breath(0.47, 190, 500, 1)
  R.charge_warning = breath(0.62, 110, 730, 3)
  R.return_warning = breath(0.52, 280, 600, 2)
  R.cross_warning = breath(0.67, 620, 2100, 3)
  R.ash_fan_release = rupture(0.75, 76, 6, 0)
  R.ash_spear_release = rupture(0.55, 105, 11, 0)
  R.ash_eruption = rupture(1.1, 48, 4.5, 0)
  R.ground_sunder = rupture(0.85, 38, 6, 0.2)
  R.antler_rush = rupture(0.65, 62, 9, 0.65)
  R.storm_release = {
    duration = 0.32,
    priority = 2,
    make = function(rate)
      local air = Synth.resonator(2300, 1.2, rate)
      return function(t, u, noise, low)
        return Synth.clip((air(noise) * 0.7 + low * 0.4) * sin(pi * u) ^ 2 * exp(-t * 7))
      end
    end,
  }
  R.binding_release = rupture(1.6, 34, 3.5, 1)
  R.ash_arrival = rupture(1.9, 32, 2.4, 0.25)
  R.storm_arrival = rupture(1.7, 45, 2.8, 0.7)
  R.boss_collapse = rupture(1.8, 30, 3, 0.65)
  R.chain_settle = {
    duration = 1.5,
    priority = 0,
    make = function(rate)
      local hall = Synth.reflections(rate, { { 0.12, 0.3 }, { 0.31, 0.19 } })
      return function(t, u)
        return hall(Synth.mail(t, chainOnsets, chainGains)) * min(1, (1 - u) * 7)
      end
    end,
  }
  R.stone_creak = {
    duration = 2.1,
    priority = 0,
    make = function(rate)
      local stone = Synth.resonator(165, 4, rate)
      return function(t, u, noise, low)
        return Synth.clip(
          (stone(noise) * 1.4 + low * 0.15)
            * sin(pi * u) ^ 2
            * (0.45 + 0.55 * sin(2 * pi * 13 * t) ^ 2)
        ) * 0.5
      end
    end,
  }
  R.altar_embers = {
    duration = 2.4,
    priority = 0,
    make = function(rate)
      local coal = Synth.resonator(900, 1.4, rate)
      local pop = 0
      local decay = exp(-1 / (rate * 0.009))
      return function(t, u, noise, low)
        pop = noise > 0.999 and 1 or pop * decay
        return Synth.clip(low * 0.2 + coal(noise) * pop * 0.8)
          * 0.45
          * min(1, t / 0.25)
          * min(1, (1 - u) * 6)
      end
    end,
  }
  return R
end

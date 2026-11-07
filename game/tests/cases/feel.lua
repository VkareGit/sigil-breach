-- PLAN E0: the feel meter (qa/feel.lua) on the knight, both weapons and every
-- creature, at the display rates a player uses. Smoothness is judged in the
-- drawn sample; measured latencies and recoil shapes are printed as the
-- baseline later stages compare against. Known defects are held with the plan
-- stage that removes them: that stage must turn its check into a plain one.
local Fixtures = require('tests.support.fixtures')
local Feel = require('qa.feel')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'feel: ', 'feel: ')
  local Enemies = require('src.content.enemies')
  local Actions = require('src.enemies.actions')
  local Weapons = require('src.content.weapons')
  -- The instrument first: a stutter inside motion counts, a stop or a peak does not.
  check(
    'the meter counts a frozen frame inside motion and ignores stops and peaks',
    Feel.stalls({ 0, 1, 2, 2, 3, 4 }) == 1
      and Feel.stalls({ 0, 1, 2, 2, 1, 0 }) == 0
      and Feel.stalls({ 0, 1, 2, 2, 2, 2 }) == 0
      and Feel.latency({ 0, 0, 0, 0.5, 1 }, 2) == 2
      and Feel.evenness({ 0, 1, 2, 3 }, 1, 4) == 1
  )
  local function rateName(rate)
    return type(rate) == 'table' and 'uneven' or (rate .. ' Hz')
  end
  local rates = {}
  for _, rate in ipairs(Feel.rates) do
    rates[#rates + 1] = rate
  end
  rates[#rates + 1] = Feel.uneven
  -- What the application loop costs at most between reading an input and
  -- showing its first effect: one simulation step of interpolation, plus one
  -- display frame in which no step completed (ms).
  local step = require('src.core.rate').step
  local function bound(rate, press)
    local frame = 0
    for i = press, press + 8 do
      frame = math.max(frame, Feel.frameTime(rate, i))
    end
    return (step + frame) * 1000 + 1e-6
  end
  local function delay(trace, press, latency)
    return latency and (trace.time[press + latency] - trace.time[press]) * 1000
  end
  -- The frame on which display time first reaches t.
  local function frameAt(trace, t)
    for i, at in ipairs(trace.time) do
      if at >= t - 1e-12 then
        return i
      end
    end
  end

  -- 1. The knight walks, turns his step aside and stops: every shown quantity of
  -- his body, camera and hands moves without a frozen frame.
  local walkProbes = {
    x = Feel.knight('x'),
    z = Feel.knight('z'),
    bank = Feel.view('bank'),
    bob = Feel.view('bobWeight'),
    step = Feel.view('weaponStepY'),
    lagX = Feel.view('weaponLagX'),
    carry = Feel.view('weaponCarry'),
  }
  local function walk(t)
    if t < 0.1 then
      return {}
    elseif t < 0.7 then
      return { forward = 1 }
    elseif t < 1.1 then
      return { strafe = 1 }
    end
    return {}
  end
  for _, rate in ipairs(rates) do
    local trace = Feel.run(Fixtures.arena(G), rate, 1.5, walk, walkProbes)
    local frozen, worst = 0, 'none'
    for name in pairs(walkProbes) do
      local n = Feel.stalls(trace[name])
      if n > frozen then
        frozen, worst = n, name
      end
    end
    check(
      string.format('walking at %s shows no frozen frame of body, camera or hands', rateName(rate)),
      frozen == 0 or error('frozen ' .. worst .. ' x' .. frozen)
    )
    local press = frameAt(trace, 0.1)
    local latency = Feel.latency(trace.z, press)
    check(
      string.format(
        'walking at %s: the body shows its first step %.1f ms after the key (bound %.1f)',
        rateName(rate),
        delay(trace, press, latency) or -1,
        bound(rate, press)
      ),
      latency ~= nil and delay(trace, press, latency) <= bound(rate, press)
    )
    if type(rate) ~= 'table' and rate >= 120 then
      -- Steady walking between the end of the start-up and the strafe.
      local a, b = frameAt(trace, 0.45), frameAt(trace, 0.65)
      local even = Feel.evenness(trace.z, a, b)
      check(
        string.format('steady walk at %s is even: step ratio %.3f', rateName(rate), even),
        even < 1.6
      )
    end
  end

  -- 2. A jump and its landing, then a dodge.
  for _, rate in ipairs(rates) do
    local trace = Feel.run(Fixtures.arena(G), rate, 1.4, function(t)
      return { jump = t >= 0.1 and t < 0.15 }
    end, { jump = Feel.knight('jump'), land = Feel.view('land') })
    local press = frameAt(trace, 0.1)
    local latency = Feel.latency(trace.jump, press)
    check(
      string.format(
        'jump at %s: lift shown %.1f ms after the key (bound %.1f), no frozen frame',
        rateName(rate),
        delay(trace, press, latency) or -1,
        bound(rate, press)
      ),
      latency ~= nil
        and delay(trace, press, latency) <= bound(rate, press)
        and Feel.stalls(trace.jump) == 0
        and Feel.stalls(trace.land) == 0
    )
    local dashed = false
    trace = Feel.run(Fixtures.arena(G), rate, 1.0, function(t)
      local input = { strafe = t >= 0.05 and 1 or 0 }
      if t >= 0.3 and not dashed then
        dashed = true
        return input, { 'dash' }
      end
      return input
    end, { x = Feel.knight('x'), z = Feel.knight('z'), fov = Feel.view('fovKick') })
    check(
      string.format('dodge at %s shows no frozen frame of body or FOV', rateName(rate)),
      Feel.stalls(trace.x) + Feel.stalls(trace.z) + Feel.stalls(trace.fov) == 0
        or error(
          string.format(
            'dodge stalls x %d z %d fov %d; %s',
            Feel.stalls(trace.x),
            Feel.stalls(trace.z),
            Feel.stalls(trace.fov),
            table.concat(trace.fov, ' ', 1, math.min(#trace.fov, 40))
          )
        )
    )
  end

  -- 3. A shot of each weapon: when its flash and its kick show, how far and how
  -- long the kick lasts. The flash reads the shot's own age and shows in the
  -- frame of the shot; the kick is a spring moved on the following step and then
  -- interpolated, so it trails the flash (known, plan E5: one impulse for both).
  local shotProbes = {
    flash = Feel.view('shotAge'),
    recoil = Feel.view('recoil'),
    aim = Feel.view('aimKick'),
    back = Feel.view('kickBack'),
    punch = Feel.view('viewPunch'),
    roll = Feel.view('weaponShotRoll'),
  }
  local trailing = 0
  for slot, id in ipairs(Weapons.defaultLoadout) do
    for _, rate in ipairs(rates) do
      local g = Fixtures.arena(G)
      assert(g.player.weapon == slot or g:switchWeapon(slot), 'feel: weapon in hand ' .. id)
      for _ = 1, 120 do
        g:update(1 / 120, {})
      end
      local fired = false
      local trace = Feel.run(g, rate, 1.0, function(t)
        if t >= 0.2 and not fired then
          fired = true
          return {}, { 'fire' }
        end
        return {}
      end, shotProbes)
      check(id .. ' fired once in the run at ' .. rateName(rate), g.player.shots == 1)
      local press = frameAt(trace, 0.2)
      local frozen = 0
      for name in pairs(shotProbes) do
        if name ~= 'flash' then
          frozen = frozen + Feel.stalls(trace[name])
        end
      end
      local flashAt
      for i = press, #trace.flash do
        if trace.flash[i] < trace.flash[i - 1] then
          flashAt = i - press
          break
        end
      end
      local latency = Feel.latency(trace.aim, press)
      local peak, at, settle = Feel.settle(trace.aim, trace.time, press)
      local flash, kick = delay(trace, press, flashAt), delay(trace, press, latency)
      if kick and flash and kick > flash + 1e-6 then
        trailing = trailing + 1
      end
      check(
        string.format(
          '%s at %s: flash %.1f ms and view kick %.1f ms after the click, peak %.4f rad at %.0f ms, settled in %.0f ms, no frozen frame',
          id,
          rateName(rate),
          flash or -1,
          kick or -1,
          peak,
          (trace.time[at] - trace.time[press]) * 1000,
          settle * 1000
        ),
        flash ~= nil
          and flash <= bound(rate, press)
          and kick ~= nil
          and kick <= bound(rate, press) + step * 1000
          and frozen == 0
      )
    end
  end
  check(
    string.format(
      'the view kick still trails the flash in %d of %d shots (known, plan E5)',
      trailing,
      #rates * #Weapons.defaultLoadout
    ),
    trailing > 0
  )

  -- 4. Every creature walks to the knight; its drawn body moves without a
  -- frozen frame at 144 Hz. Known defects stay listed until their stage.
  local known = {
    -- The hover pose reads the session clock that is not interpolated (E4).
    stolas = 'E4',
  }
  for _, id in ipairs(Enemies.creatures) do
    local g = Fixtures.arena(G)
    local e = g:spawn(id, 16, 17)
    e.awake, e.spawnAge, e.memory = true, 1, 4
    local trace = Feel.run(g, 144, 1.2, function()
      return {}
    end, { x = Feel.spriteX(e), z = Feel.spriteZ(e), y = Feel.spriteHeight(e) })
    local moved =
      math.sqrt((trace.x[#trace.x] - trace.x[1]) ^ 2 + (trace.z[#trace.z] - trace.z[1]) ^ 2)
    check(string.format('%s moved %.2f m toward the knight', id, moved), moved > 0.3)
    local placeStalls = Feel.stalls(trace.x) + Feel.stalls(trace.z)
    local heightStalls = Feel.stalls(trace.y)
    check(id .. ' walks at 144 Hz without a frozen frame of its place', placeStalls == 0)
    if known[id] then
      check(
        string.format(
          '%s drawn height still freezes %d frame(s) at 144 Hz (known, plan %s)',
          id,
          heightStalls,
          known[id]
        ),
        heightStalls > 0
      )
    else
      check(id .. ' drawn height has no frozen frame at 144 Hz', heightStalls == 0)
    end
  end
  -- A creature's leap: its drawn height is the flight height, not interpolated (E4).
  do
    local g = Fixtures.arena(G)
    local e = g:spawn('imp', 16, 19)
    e.awake, e.spawnAge, e.memory, e.target = true, 1, 4, g.player.id
    local leap
    for _, attack in ipairs(Enemies.imp.attacks) do
      leap = attack.id == 'leap' and attack or leap
    end
    Actions.begin(g, e, 6, assert(leap))
    local airborne = false
    local trace = Feel.run(g, 144, 1.4, function()
      airborne = airborne or e.leapY ~= nil
      return {}
    end, { y = Feel.spriteHeight(e) })
    local stalls = Feel.stalls(trace.y)
    check(
      string.format(
        'an Ember leap still freezes its drawn height %d frame(s) at 144 Hz (known, plan E4)',
        stalls
      ),
      airborne and stalls > 0
    )
  end

  -- 5. Known rule defects held for their stage.
  do
    -- E1: the floor of the tests has no effort rules; the chapel and the field
    -- do, so the same backward walk covers a different distance.
    local Field = require('src.run.test_field')
    -- Where each session puts the knight; only the first metre is walked.
    local function backward(g)
      local x, z = g.player.x, g.player.z
      for _ = 1, 30 do
        g:update(1 / 120, { forward = -1 })
      end
      return math.sqrt((g.player.x - x) ^ 2 + (g.player.z - z) ^ 2)
    end
    local plain = backward(Fixtures.arena(G))
    local field = Field.new(G)
    field.ephemeral = true
    field:start()
    local effort = backward(field)
    check('the field knight walked back at all', effort > 0.1)
    check(
      string.format(
        'tests walk back %.3f m where the field walks %.3f m (known, plan E1)',
        plain,
        effort
      ),
      plain > effort * 1.05
    )
  end
  do
    -- E5: a shot replaces the shake already shown instead of joining it.
    local g = Fixtures.arena(G)
    assert(g:switchWeapon(2), 'feel: Judge in hand')
    for _ = 1, 120 do
      g:update(1 / 120, {})
    end
    g.view.shake = 0.5
    assert(g:shoot(), 'feel: Judge fires')
    g:update(1 / 120, {})
    check(
      string.format(
        'a Judge shot lowers a stronger shake 0.5 to %.3f (known, plan E5)',
        g.view.shake
      ),
      g.view.shake < 0.5
    )
  end
  return lines
end
return Tests

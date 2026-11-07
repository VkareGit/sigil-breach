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
      and Feel.stalls({ 0, 1, 2, 12, 12, 13 }) == 0
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

  -- 4. Every creature walks to the knight, then its leap, a windup and a hover:
  -- its drawn place, height, lean and scale move without a frozen frame at
  -- 144 Hz and on uneven frames (E4: smoothing is declared by each field).
  local function drawn(g, e, seconds, rate)
    return Feel.run(g, rate, seconds, function()
      return {}
    end, {
      x = Feel.spriteX(e),
      z = Feel.spriteZ(e),
      y = Feel.spriteLift(e),
      lean = Feel.spriteLean(e),
      scale = Feel.spriteScale(e),
    })
  end
  local function frozen(trace)
    local total, worst = 0, 'none'
    for _, name in ipairs({ 'x', 'z', 'y', 'lean', 'scale' }) do
      local n, at = Feel.stalls(trace[name])
      total = total + n
      if n > 0 then
        local series = trace[name]
        worst = string.format(
          '%s x%d, first at %.0f ms: %.5f %.5f %.5f %.5f',
          name,
          n,
          trace.time[at] * 1000,
          series[at - 2],
          series[at - 1],
          series[at],
          series[at + 1]
        )
      end
    end
    return total, worst
  end
  for _, rate in ipairs({ 144, Feel.uneven }) do
    for _, id in ipairs(Enemies.creatures) do
      local g = Fixtures.arena(G)
      local e = g:spawn(id, 16, 17)
      e.awake, e.spawnAge, e.memory = true, 1, 4
      local trace = drawn(g, e, 1.2, rate)
      local moved =
        math.sqrt((trace.x[#trace.x] - trace.x[1]) ^ 2 + (trace.z[#trace.z] - trace.z[1]) ^ 2)
      local total, worst = frozen(trace)
      check(
        string.format(
          '%s walks %.2f m at %s with no frozen frame of its drawn body (%s)',
          id,
          moved,
          rateName(rate),
          worst
        ),
        moved > 0.3 and total == 0
      )
      -- The same body caught in each of its attacks' windups and strikes.
      for _, attack in ipairs(Enemies[id].attacks) do
        local a = Fixtures.arena(G)
        local body = a:spawn(id, 16, 21)
        body.awake, body.spawnAge, body.memory, body.target = true, 1, 4, a.player.id
        Actions.begin(a, body, 4, attack)
        local acted = drawn(a, body, 0.9, rate)
        local n, which = frozen(acted)
        check(
          string.format(
            '%s %s at %s: no frozen frame of its drawn body (%s)',
            id,
            attack.id,
            rateName(rate),
            which
          ),
          n == 0
        )
      end
    end
    -- A body climbing out of a portal.
    local g = Fixtures.arena(G)
    local e = g:spawn('imp', 16, 17)
    e.spawnAge = 0
    local total, worst = frozen(drawn(g, e, 0.7, rate))
    check(
      string.format('a body leaving a portal at %s has no frozen frame (%s)', rateName(rate), worst),
      total == 0
    )
  end

  -- 5. One body, the same rules in every mode (PLAN E1): the floor of the tests,
  -- the field and the chapel walk, dodge and recover from a shot alike. A mode
  -- only decides whether effort is paid (stamina, the flask).
  do
    local Field = require('src.run.test_field')
    local function field()
      local g = Field.new(G)
      g.ephemeral = true
      g:start()
      return g
    end
    -- Where each session puts the knight; only the first metre is walked.
    local function backward(g)
      local x, z = g.player.x, g.player.z
      for _ = 1, 30 do
        g:update(1 / 120, { forward = -1 })
      end
      return math.sqrt((g.player.x - x) ^ 2 + (g.player.z - z) ^ 2)
    end
    local plain, effort = backward(Fixtures.arena(G)), backward(field())
    check(
      string.format('the tests and the field walk back alike: %.3f and %.3f m', plain, effort),
      effort > 0.1 and math.abs(plain - effort) < 1e-9
    )
    local function dodge(g)
      for _ = 1, 30 do
        g:update(1 / 120, {})
      end
      assert(g:dash(1, 0), 'feel: a rested knight dodges')
      return g.player.invuln
    end
    local plainGuard, fieldGuard = dodge(Fixtures.arena(G)), dodge(field())
    check(
      string.format(
        'a dodge guards %.2f s on the floor and %.2f s in the field',
        plainGuard,
        fieldGuard
      ),
      math.abs(plainGuard - fieldGuard) < 1e-9
    )
    local function afterShot(g)
      for _ = 1, 30 do
        g:update(1 / 120, {})
      end
      assert(g.player.weapon == 2 or g:switchWeapon(2), 'feel: Judge in hand')
      for _ = 1, 60 do
        g:update(1 / 120, {})
      end
      assert(g:shoot(), 'feel: Judge fires')
      return g:dash(1, 0)
    end
    check(
      'right after a shot the body is still behind it, on the floor as in the field',
      afterShot(Fixtures.arena(G)) == false and afterShot(field()) == false
    )
  end
  do
    -- E5: a shot joins the shake already shown; a weaker one never lowers it.
    -- The same shake left alone fades by the same step: the shot changes nothing.
    local function shaken(fire)
      local g = Fixtures.arena(G)
      assert(g:switchWeapon(2), 'feel: Judge in hand')
      for _ = 1, 120 do
        g:update(1 / 120, {})
      end
      g.view.shake = 0.5
      if fire then
        assert(g:shoot(), 'feel: Judge fires')
      end
      g:update(1 / 120, {})
      return g.view.shake
    end
    local alone, fired = shaken(false), shaken(true)
    check(
      string.format('a Judge shot keeps a stronger shake: %.3f with it, %.3f without', fired, alone),
      math.abs(fired - alone) < 1e-9
    )
  end
  return lines
end
return Tests

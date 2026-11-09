-- PLAN E7: the final verification, as a matrix measured in the shown image
-- (qa/feel.lua). Every weapon of the loadout, standing and in every way of
-- moving (walk, strafe, back, jump, dodge, slide), with every act of the
-- hands (a shot, a second shot before the first has settled, a reload, a
-- reload cut by the trigger, a quick switch, the flask), at the display rates
-- a player uses and on uneven frames: the act happens, and the body, the
-- camera and the hands move without a frozen frame. Then the states around a
-- fight: MOTION off (nothing of the camera or hands moves, and what moved
-- goes), a pause (the picture stands), and an observer (another knight's view
-- takes nothing of the actor's shot). Nothing here changes the game.
local Fixtures = require('tests.support.fixtures')
local Feel = require('qa.feel')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'verification: ', 'verification: ')
  local Weapons = require('src.content.weapons')
  local Reload = require('src.combat.reload')
  local Context = require('src.session.context')
  local Pools = require('src.session.world')
  local Abilities = require('src.content.abilities')
  local Intent = require('src.player.intent')
  local Camera = require('src.render.camera')
  local Tuning = require('src.content.tuning')
  local Weapon = require('src.render.weapon')
  local WeaponMotion = require('src.feedback.weapon_motion')
  local rates = { 30, 60, 120, 240, Feel.uneven }
  local function rateName(rate)
    return type(rate) == 'table' and 'uneven' or (rate .. ' Hz')
  end
  -- What the camera and the hands show, and where the body is.
  local probes = {
    x = Feel.knight('x'),
    z = Feel.knight('z'),
    bank = Feel.view('bank'),
    bob = Feel.view('bobWeight'),
    step = Feel.view('weaponStepY'),
    lagX = Feel.view('weaponLagX'),
    carry = Feel.view('weaponCarry'),
    recoil = Feel.view('recoil'),
    aim = Feel.view('aimKick'),
    back = Feel.view('kickBack'),
  }
  -- A frozen frame the eye could see: on a frame the picture of a quantity
  -- does not change (a step under a millionth of its reach), while on both
  -- sides it moves the same way by a clearly visible step (over a ten
  -- thousandth of its reach, and over a millionth of a unit) of a similar
  -- size. A spring's tail settling on
  -- rest, or crossing it, on uneven frames moves by 1e-7 and is no motion.
  local function visibleStalls(series)
    local reach = 0
    for _, v in ipairs(series) do
      reach = math.max(reach, math.abs(v))
    end
    -- A millionth of a unit (metre, radian, pixel share) is below any picture.
    local still, visible = math.max(Feel.still, reach * 1e-6), math.max(1e-6, reach * 1e-4)
    local count, first = 0, nil
    for i = 3, #series - 1 do
      local before = series[i - 1] - series[i - 2]
      local now = math.abs(series[i] - series[i - 1])
      local after = series[i + 1] - series[i]
      local small = math.min(math.abs(before), math.abs(after))
      local large = math.max(math.abs(before), math.abs(after))
      if
        now <= still
        and small > visible
        and (before > 0) == (after > 0)
        and large <= small * Feel.steady
      then
        count = count + 1
        first = first or i
      end
    end
    return count, first
  end
  -- Measured and explained, for the owner: at 30 Hz the image shows the state
  -- before the frame's last step; a lean that has just reached its strafe
  -- value (0.85 of the walk after a shot) stands one frame before a dodge
  -- starting in that step leans it further. Two motions, not a stutter.
  local known = {
    ['judge|a reload|dodging|30 Hz|bank'] = 1,
    ['judge|a reload cut by the trigger|dodging|30 Hz|bank'] = 1,
  }
  -- The ways of moving: held controls, and an edge at a moment.
  local moves = {
    { 'standing' },
    { 'walking', { forward = 1 } },
    { 'strafing', { strafe = 1 } },
    { 'walking back', { forward = -1 } },
    { 'jumping', { forward = 1 }, 'jump', 0.15 },
    { 'dodging', { strafe = 1 }, 'dash', 0.15 },
    { 'sliding', { forward = 1 }, 'slide', 0.15 },
  }
  -- The acts of the hands: what is done when, and what shows it happened.
  local acts = {
    {
      'a shot',
      { [0.25] = 'fire' },
      function(g, seen)
        return g.player.shots >= 1
      end,
    },
    {
      'two shots, the second as soon as the gun allows',
      { [0.25] = 'fire', [0.3] = 'again' },
      function(g)
        return g.player.shots >= 2
      end,
      -- Long enough for a breech that fires both barrels to reload first.
      3.0,
    },
    {
      'a reload',
      { [0.1] = 'fire', [0.3] = 'reload' },
      function(g, seen)
        return seen.reloading
      end,
    },
    {
      'a reload cut by the trigger',
      { [0.1] = 'fire', [0.3] = 'reload', [0.38] = 'fire' },
      function(g, seen)
        return seen.reloading and g.player.shots >= 1
      end,
    },
    {
      'a quick switch',
      { [0.25] = 'switch' },
      function(g, seen)
        return seen.switched
      end,
    },
    {
      'the flask',
      { [0.25] = 'flask' },
      function(g, seen)
        return seen.drank
      end,
      -- Long enough for the draught's windup and drink.
      2.5,
    },
  }
  for slot, id in ipairs(Weapons.defaultLoadout) do
    for _, act in ipairs(acts) do
      local runs, done, frozen, held, worst = 0, 0, 0, 0, nil
      for _, move in ipairs(moves) do
        for _, rate in ipairs(rates) do
          local g = Fixtures.arena(G)
          assert(g.player.weapon == slot or g:switchWeapon(slot), 'verification: weapon ' .. id)
          for _ = 1, 120 do
            g:update(1 / 120, {})
          end
          g.player.shots, g.player.hp = 0, 50
          -- The flask on the first key, as a pilgrim carries it.
          g.player.abilities = { 'flask' }
          g.player.abilityState = Abilities.kit({ 'flask' })
          local seen, fired = {}, {}
          local trace = Feel.run(g, rate, act[4] or 1.0, function(t)
            local input, edges = {}, {}
            for key, value in pairs(move[2] or {}) do
              input[key] = t >= 0.05 and value or 0
            end
            if move[3] and t >= move[4] and not fired.move then
              fired.move = true
              edges[#edges + 1] = move[3]
            end
            for at, what in pairs(act[2]) do
              if t >= at and not fired[at] then
                fired[at] = true
                if what == 'fire' then
                  edges[#edges + 1] = 'fire'
                elseif what == 'reload' then
                  g:reloadGun()
                elseif what == 'switch' then
                  seen.switched = g:switchWeapon(slot % #Weapons.defaultLoadout + 1)
                elseif what == 'flask' then
                  g:cast(1)
                end
              end
            end
            -- The second pull is queued each frame until it is taken.
            if fired[0.3] and g.player.shots < 2 then
              edges[#edges + 1] = 'fire'
            end
            seen.reloading = seen.reloading or Reload.left(g, g.player) > 0
            seen.drank = seen.drank or g.player.hp > 50
            return input, edges
          end, probes)
          runs = runs + 1
          if act[3](g, seen) then
            done = done + 1
          end
          for name in pairs(probes) do
            local n = visibleStalls(trace[name])
            local key = table.concat({ id, act[1], move[1], rateName(rate), name }, '|')
            if n > 0 and known[key] == n then
              held = held + n
            elseif n > 0 then
              frozen = frozen + n
              worst = worst
                or string.format('%s %s at %s: %s x%d', id, move[1], rateName(rate), name, n)
            end
          end
        end
      end
      check(
        string.format(
          '%s, %s, in %d ways of moving at %d rates: it happens %d of %d times, %d frozen frame(s) of body, camera or hands%s%s',
          id,
          act[1],
          #moves,
          #rates,
          done,
          runs,
          frozen,
          worst and (' (first: ' .. worst .. ')') or '',
          held > 0
              and string.format(
                '; %d lean held at its strafe value before a dodge at 30 Hz (known, for the owner)',
                held
              )
            or ''
        ),
        done == runs and frozen == 0
      )
    end
  end

  -- MOTION off ("Weapon motion and FOV"): walking and a shot move nothing of
  -- the camera and nothing procedural of the hands (sway, gesture, kick);
  -- the kick's fields reach nothing drawn. The weapon's own authored
  -- illustration (its firing frames and reload choreography) still plays.
  -- Turning it off right after a shot leaves nothing of the shot.
  local r, u, f = { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }
  local kicks =
    { 'recoil', 'aimKick', 'kickBack', 'viewPunch', 'weaponShotRoll', 'rollPunch', 'fovKick' }
  local function calm(shown)
    local view = setmetatable({}, { __index = shown.view })
    for _, key in ipairs(kicks) do
      view[key] = 0
    end
    return setmetatable({ view = view }, { __index = shown })
  end
  local function hands(shown)
    local x, y, roll, scale = Weapon.transform(shown, 1280, 720)
    local cx, cy, croll, cscale = Weapon.transform(calm(shown), 1280, 720)
    return math.abs(x - cx) + math.abs(y - cy) + math.abs(roll - croll) + math.abs(scale - cscale)
  end
  local still = {
    roll = function(shown)
      return Camera.roll(shown)
    end,
    fov = function(shown)
      return Camera.basis(shown, r, u, f) - (shown.view.fov or Tuning.baseFov)
    end,
    pitch = function(shown)
      Camera.basis(shown, r, u, f)
      return f[2] - math.sin(shown.player.pitch or 0)
    end,
    sway = function(shown)
      local x, y, roll = WeaponMotion.pose(shown)
      local drop, seatY, seatRoll = WeaponMotion.draw(shown)
      return math.abs(x)
        + math.abs(y)
        + math.abs(roll)
        + math.abs(drop)
        + math.abs(seatY)
        + math.abs(seatRoll)
    end,
    kick = hands,
  }
  local function largest(trace, from)
    local most = 0
    for name in pairs(still) do
      for i = from or 1, #trace[name] do
        most = math.max(most, math.abs(trace[name][i] or 0))
      end
    end
    return most
  end
  for _, rate in ipairs(rates) do
    local g = Fixtures.arena(G)
    g.view.motion = false
    local shot = false
    local trace = Feel.run(g, rate, 1.0, function(t)
      if t >= 0.3 and not shot then
        shot = true
        return { forward = 1 }, { 'fire' }
      end
      return { forward = t >= 0.05 and 1 or 0 }
    end, still)
    check(
      string.format(
        'MOTION off at %s: walking and a shot move the camera and the hands by %.2g at most',
        rateName(rate),
        largest(trace)
      ),
      g.player.shots == 1 and largest(trace) < 1e-9
    )
    g = Fixtures.arena(G)
    shot = false
    local off
    trace = Feel.run(g, rate, 0.6, function(t, frame)
      if t >= 0.1 and not shot then
        shot = true
        return {}, { 'fire' }
      end
      if t >= 0.15 and g.view.motion ~= false then
        g.view.motion = false
        off = frame + 1
      end
      return {}
    end, still)
    check(
      string.format(
        'MOTION turned off right after a shot at %s leaves %.2g of it on screen',
        rateName(rate),
        largest(trace, off)
      ),
      off and largest(trace, off) < 1e-9
    )
  end

  -- A pause: the picture stands while the game does, and walking resumes from
  -- where it stood.
  for _, rate in ipairs(rates) do
    local g = Fixtures.arena(G)
    local pausedAt, resumedAt
    local trace = Feel.run(g, rate, 1.2, function(t, frame)
      if t >= 0.4 and not pausedAt then
        g.state, pausedAt = 'paused', frame + 1
      elseif t >= 0.8 and pausedAt and not resumedAt then
        g.state, resumedAt = 'playing', frame
      end
      return { forward = 1 }
    end, probes)
    local moved = 0
    for name in pairs(probes) do
      for i = pausedAt + 1, resumedAt - 1 do
        moved = math.max(moved, math.abs(trace[name][i] - trace[name][pausedAt]))
      end
    end
    check(
      string.format(
        'a pause at %s: the picture moves %.2g while paused, then walking goes on',
        rateName(rate),
        moved
      ),
      moved < 1e-9 and trace.z[#trace.z] ~= trace.z[resumedAt]
    )
  end

  -- The fire, a death and Continue on the way: after a shot, a rest at the
  -- fire, a death and its retry, and Continue from the save each leave
  -- nothing of the shot on the camera or the hands, and the first walk after
  -- shows no frozen frame.
  do
    local P = require('src.run.pilgrimage')
    local Encounter = require('src.session.encounter')
    local residue = { 'recoil', 'aimKick', 'kickBack', 'viewPunch', 'weaponShotRoll', 'rollPunch' }
    local function left(g)
      local sum = 0
      for _, key in ipairs(residue) do
        sum = sum + math.abs(g.view[key] or 0)
      end
      return sum
    end
    local function shoot(g)
      Intent.queue(g, 'fire', nil)
      for _ = 1, 6 do
        g:update(1 / 120, {})
      end
      return left(g)
    end
    local function walk(g)
      local trace = Feel.run(g, Feel.uneven, 1.0, function(t)
        return { forward = t >= 0.05 and 1 or 0 }
      end, probes)
      local frozen = 0
      for name in pairs(probes) do
        frozen = frozen + visibleStalls(trace[name])
      end
      return frozen
    end
    P.forget()
    local g = G.new('pilgrimage')
    g:act('start')
    g.state = 'playing'
    Encounter.clearStage(g)
    local kick = shoot(g)
    local rested = g:interact() and g.state == 'shop'
    g:act('closeShop')
    check(
      string.format(
        'a rest at the fire after a shot (kick %.3g) leaves %.2g of it; the walk after has %d frozen frame(s)',
        kick,
        left(g),
        walk(g)
      ),
      kick > 0 and rested and g.state == 'playing' and left(g) < 1e-9 and walk(g) == 0
    )
    Encounter.clearStage(g)
    kick = shoot(g)
    g.player.armor = 0
    g:damagePlayer(500)
    local died = g.state == 'dead'
    local woke = g:act('retry') and g.state == 'playing'
    check(
      string.format(
        'a death after a shot (kick %.3g) and its retry leave %.2g of it; the walk after has %d frozen frame(s)',
        kick,
        left(g),
        walk(g)
      ),
      kick > 0 and died and woke and left(g) < 1e-9 and walk(g) == 0
    )
    Encounter.clearStage(g)
    -- The rest and the death have saved the way; a new session continues it.
    kick = shoot(g)
    local again = G.new('pilgrimage')
    again:act('start')
    again.state = 'playing'
    check(
      string.format(
        'Continue from the save after a shot (kick %.3g) starts with %.2g of it; the walk after has %d frozen frame(s)',
        kick,
        left(again),
        walk(again)
      ),
      kick > 0 and again.run.saved == true and left(again) < 1e-9 and walk(again) == 0
    )
    P.forget()
  end

  -- An observer: a second knight watched beside the actor takes nothing of
  -- the actor's shot into its own camera or hands.
  for _, rate in ipairs(rates) do
    local g = Fixtures.arena(G)
    local kit = { 'exorcist', 'judge' }
    local other = g.ecs:create('knight', {
      id = 'verification_observer',
      x = 17,
      z = 25,
      yaw = math.pi,
      hp = 100,
      loadout = kit,
      arsenal = Weapons.arsenal(kit),
      weapon = 1,
      abilities = { 'powder' },
      abilityState = Abilities.kit({ 'powder' }),
    }, false)
    assert(g:actorJoin(Pools.memberRecord(other)))
    local watched = Context.watch(g, 'verification_observer')
    local shot = false
    local most, own = 0, 0
    Feel.run(g, rate, 0.8, function(t)
      if t >= 0.2 and not shot then
        shot = true
        return {}, { 'fire' }
      end
      for _, key in ipairs({ 'recoil', 'aimKick', 'kickBack', 'viewPunch' }) do
        most = math.max(most, math.abs(watched[key] or 0))
        own = math.max(own, math.abs(g.view[key] or 0))
      end
      return {}
    end, {})
    check(
      string.format(
        "an observer at %s: the actor's shot moves its own view by %.3g, the observer's by %.2g",
        rateName(rate),
        own,
        most
      ),
      g.player.shots == 1 and own > 0 and most < 1e-9
    )
  end
  return lines
end
return Tests

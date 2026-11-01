-- Interrupted break-action reloads preserve the completed transaction, not a
-- guess from the live rounds that were already in the barrels when opened.
local Fixtures = require('tests.support.fixtures')
local Reload = require('src.combat.reload')
local Weapons = require('src.content.weapons')
local Tuning = require('src.content.tuning')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'breech reload: ', 'breech reload: ')
  local near = Fixtures.within(1e-8)
  local definition = Weapons.get('exorcist')
  local timing = Tuning.reload.breech
  local epsilon = 1e-6
  local function fresh(mag, reserve, open)
    local g = Fixtures.arena(G)
    local state = Weapons.state(g)
    state.mag, state.reserve, state.open, state.loaded = mag, reserve, open or false, false
    return g, state
  end
  local function advanceTo(g, age)
    Reload.update(g, age - Reload.age(g))
  end
  local function pause(g, route)
    if route == 'swap' then
      assert(g:switchWeapon(2))
      assert(g:switchWeapon(1))
    else
      Reload.cancel(g)
      assert(g:reloadGun())
    end
  end
  local g, state = fresh(1, 1)
  assert(g:reloadGun())
  Reload.update(g, 0.40)
  pause(g, 'swap')
  check(
    'one live shell and one reserve still resume insertion after a manual reload swap',
    near(g.player.reloadOffset, timing.resume.open)
      and state.mag == 1
      and state.reserve == 1
      and state.open
      and not state.loaded
  )
  Reload.update(g, Tuning.shotgunCycle)
  check(
    'the reported partial-magazine swap finishes with both shells, no lost reserve',
    state.mag == 2 and state.reserve == 0 and not state.open and not state.loaded
  )
  for mag = 0, definition.ammo.capacity do
    for _, reserve in ipairs({ 0, 1, definition.ammo.capacity, definition.ammo.maxReserve }) do
      for _, route in ipairs({ 'cancel', 'swap' }) do
        local label = string.format('mag=%d reserve=%d via %s', mag, reserve, route)
        -- An already-open action can always close, including a dry or full
        -- action. Normal partial magazines start with the actual open event.
        local alreadyOpen = mag == definition.ammo.capacity or reserve == 0
        g, state = fresh(mag, reserve, alreadyOpen)
        assert(g:reloadGun())
        advanceTo(g, Tuning.reloadLoadTime - epsilon)
        pause(g, route)
        local before = state.open
          and not state.loaded
          and not Reload.mechanism(g, 1).primed(state)
          and state.mag == mag
          and state.reserve == reserve
          and near(g.player.reloadOffset, timing.resume.open)
        advanceTo(g, Tuning.reloadLoadTime + epsilon)
        local amount = math.min(definition.ammo.capacity - mag, reserve)
        local inserted = state.open
          and state.loaded
          and Reload.mechanism(g, 1).primed(state)
          and state.mag == mag + amount
          and state.reserve == reserve - amount
        check(
          'pre-transaction pause preserves and then fills actual chambers: ' .. label,
          before and inserted
        )
        pause(g, route)
        local resumed = near(g.player.reloadOffset, timing.resume.loaded) and state.loaded
        Reload.update(g, Tuning.shotgunCycle)
        check(
          'post-transaction pause only closes and conserves total ammunition: ' .. label,
          resumed
            and state.mag == mag + amount
            and state.reserve == reserve - amount
            and state.mag + state.reserve == mag + reserve
            and not state.open
            and not state.loaded
            and g.player.reload == 0
        )
      end
    end
  end
  -- A zero-round transaction still happened. Ammo acquired while the open
  -- action is paused belongs to the next reload, not an invented second load.
  g, state = fresh(0, 0, true)
  assert(g:reloadGun())
  advanceTo(g, Tuning.reloadLoadTime + epsilon)
  Reload.cancel(g)
  state.reserve = 1
  assert(g:reloadGun())
  Reload.update(g, Tuning.shotgunCycle)
  check(
    'empty completed transaction is not replayed after acquiring a new shell',
    state.mag == 0 and state.reserve == 1 and not state.open and not state.loaded
  )
  assert(g:reloadGun())
  Reload.update(g, Tuning.shotgunCycle)
  check('a new cycle can insert that acquired shell once', state.mag == 1 and state.reserve == 0)
  g, state = fresh(1, 1)
  assert(g:reloadGun())
  advanceTo(g, timing.open - epsilon)
  check(
    'firing interruption before opening closes and clears transaction state without ammo changes',
    Reload.interrupt(g)
      and state.mag == 1
      and state.reserve == 1
      and not state.open
      and not state.loaded
      and g.player.reload == 0
  )
  assert(g:reloadGun())
  advanceTo(g, timing.close + epsilon)
  check(
    'close clears the transaction marker before the timeline finishes',
    not state.open and not state.loaded and g.player.reload > 0
  )
  return lines
end
return Tests

-- Painted chambers follow the actual magazine transaction, including a partial
-- reserve and an interrupted reload. No second animation/ammo clock is involved.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local Art = require('src.content.weapon_art')
  local Sampler = require('src.render.weapon_art')
  local Visual = require('src.render.weapon')
  local Weapons = require('src.content.weapons')
  local Reload = require('src.combat.reload')
  local Schema = require('src.core.schema')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local lines = {}
  local check = Fixtures.checker(lines, 'painted rounds: ', 'painted rounds: ')
  local near = Fixtures.within(1e-8)
  -- Production sheets: a pose that paints its chambers covers every count
  -- from empty to capacity with leaf variants; a sheet painted without
  -- chamber variants (the v16 iron) shows one drawing for any count.
  -- Merely proving a synthetic catalogue does not prove an imported sheet.
  for _, production in ipairs({ 'exorcist', 'judge' }) do
    local art = Art.get(production)
    local capacity = Weapons.get(production).capacity
    check(
      production .. ' production art composes with its weapon',
      pcall(Art.validateWeapon, Weapons.get(production))
    )
    for pose, frame in ipairs(art.frames) do
      if frame.rounds then
        for rounds = 0, capacity do
          local selected = art.frames[Art.variant(art, pose, rounds)]
          check(
            production .. ' pose ' .. frame.id .. ' selects its authored count ' .. rounds,
            #frame.rounds == capacity + 1
              and selected.id:match('_rounds_(%d+)$') == tostring(rounds)
              and not selected.rounds
          )
        end
      end
    end
  end
  -- The source of a production pose's painted rounds, if any.
  local function source(id, name)
    local art = Art.get(id)
    local names = art.frameNames
    return names[name] and art.frames[names[name]].roundsSource
  end
  -- A simultaneous loader depicts incoming rounds, not old live rounds in
  -- the cylinder. The transaction itself still belongs to combat/reload.
  -- (Only a sheet that paints a loader: content/weapon_art.lua 'pending'.)
  local loaders = source('judge', 'insert_first') == 'pending'
      and { { 0, 6 }, { 0, 1 }, { 3, 1 }, { 5, 3 }, { 6, 0 }, { 0, 0 } }
    or {}
  for _, ammunition in ipairs(loaders) do
    local g = Fixtures.arena(G)
    g.player.weapon, g.view.shotAge, g.view.swapAge = 2, 10, 1
    local state = Weapons.state(g)
    local initial, reserve = ammunition[1], ammunition[2]
    state.mag, state.reserve = initial, reserve
    state.open, state.loaded = reserve == 0, false
    assert(g:reloadGun())
    local pending = math.min(6 - initial, reserve)
    local label = string.format('mag=%d reserve=%d', initial, reserve)
    for _, phase in ipairs({
      { age = 0.72, name = 'insert_first' },
      { age = 0.87, name = 'insert_second' },
      { age = 1.08, name = 'seat' },
    }) do
      Reload.update(g, phase.age - Reload.age(g))
      local before = Integrity.capture(g)
      local selected = Art.get('judge').frames[Sampler.frame(g)]
      check(
        'speedloader ' .. phase.name .. ' shows the pending transfer only: ' .. label,
        selected.id == phase.name .. '_rounds_' .. pending
          and state.mag == initial
          and state.reserve == reserve
          and not state.loaded
          and not Integrity.difference(before, Integrity.capture(g))
      )
    end
    Reload.cancel(g)
    check(
      'cancelling before insertion puts the loader away and shows retained rounds: ' .. label,
      Art.get('judge').frames[Sampler.frame(g)].id == 'open_rounds_' .. initial
    )
    assert(g:switchWeapon(1) and g:switchWeapon(2))
    check(
      'swapping back reconstructs the pending loader from the same ammunition: ' .. label,
      Art.get('judge').frames[Sampler.frame(g)].id == 'insert_first_rounds_' .. pending
    )
    Reload.update(g, 1.17 - Reload.age(g))
    check(
      'the simultaneous transaction replaces the loader with actual loaded chambers: ' .. label,
      state.mag == initial + pending
        and state.reserve == reserve - pending
        and state.loaded
        and Art.get('judge').frames[Sampler.frame(g)].id
          == 'loaded_rounds_' .. (initial + pending)
    )
    Reload.cancel(g)
    check(
      'post-transaction pause keeps cylinder contents and never resurrects the loader: ' .. label,
      Art.get('judge').frames[Sampler.frame(g)].id == 'loaded_rounds_' .. (initial + pending)
    )
    assert(g:switchWeapon(1) and g:switchWeapon(2))
    check(
      'post-transaction swap resumes closure with the actual chamber count: ' .. label,
      Art.get('judge').frames[Sampler.frame(g)].id == 'loaded_rounds_' .. (initial + pending)
    )
  end
  -- The breech takes its shells one by one: the hand brings the first, then
  -- the first sits in its chamber while the hand brings the second, then
  -- both are pressed home. One missing shell never paints a phantom second.
  -- The simulation still loads the whole pair at once (reloadLoadTime).
  -- (Only a sheet that paints shells pushed home one by one: 'loading'.)
  local breeches = source('exorcist', 'insert_second') == 'loading'
      and { { 0, 6, 0, 1, 2 }, { 0, 1, 0, 0, 1 }, { 1, 6, 1, 1, 2 } }
    or {}
  for _, ammunition in ipairs(breeches) do
    local g = Fixtures.arena(G)
    g.player.weapon, g.view.shotAge, g.view.swapAge = 1, 10, 1
    local state = Weapons.state(g)
    state.mag, state.reserve = ammunition[1], ammunition[2]
    state.open, state.loaded = ammunition[1] > 0, false
    assert(g:reloadGun())
    local label = string.format('mag=%d reserve=%d', ammunition[1], ammunition[2])
    for index, phase in ipairs({
      { age = 0.42, name = 'insert_first' },
      { age = 0.50, name = 'insert_second' },
      { age = 0.57, name = 'seat' },
    }) do
      Reload.update(g, phase.age - Reload.age(g))
      local selected = Art.get('exorcist').frames[Sampler.frame(g)]
      check(
        'breech ' .. phase.name .. ' shows shells pushed home so far: ' .. label,
        selected.id == phase.name .. '_rounds_' .. ammunition[2 + index]
          and state.mag == ammunition[1]
          and not state.loaded
      )
    end
  end
  local id = 'trial_painted_rounds'
  local entry = Schema.copy(Art.get('judge'))
  local base = {}
  for index = 1, 16 do
    base[index] = entry.frames[index]
    base[index].rounds = nil
    base[index].roundsSource = nil
  end
  entry.frames = base
  local variants = { 'rounds_zero', 'rounds_one', 'rounds_two' }
  for index, name in ipairs(variants) do
    local frame = Schema.copy(entry.frames[7])
    frame.id, frame.muzzle = name, nil
    entry.frames[#entry.frames + 1] = frame
  end
  entry.frames[7].rounds, entry.frames[12].rounds = variants, variants
  entry.frames[7].muzzle, entry.frames[12].muzzle = nil, nil
  entry.placement = { 10, -5 }
  entry.open = { empty = 'open', primed = 'loaded' }
  entry.phases.reload = {
    { finish = 1.16, frame = 'open' },
    { finish = 1.85, frame = 'loaded' },
  }
  local ok, problem = xpcall(function()
    local function invalid(label, change)
      local bad = Schema.copy(entry)
      change(bad)
      check(
        label,
        not pcall(Art.register, 'trial_bad_rounds', bad) and not Art.entries.trial_bad_rounds
      )
    end
    invalid('sparse round-count variants fail atomically', function(bad)
      bad.frames[7].rounds = { [1] = variants[1], [3] = variants[3] }
    end)
    invalid('noninteger variant indices fail atomically', function(bad)
      bad.frames[7].rounds[0] = variants[1]
    end)
    invalid('unknown ammunition selector fails atomically', function(bad)
      bad.frames[7].roundsSource = 'invented'
    end)
    invalid('an ammunition selector needs actual variants', function(bad)
      bad.frames[1].roundsSource = 'pending'
    end)
    invalid('unknown named variants fail atomically', function(bad)
      bad.frames[7].rounds[2] = 'missing'
    end)
    invalid('self cycles fail atomically', function(bad)
      bad.frames[7].rounds[1] = 'open'
    end)
    invalid('indirect variant chains fail atomically', function(bad)
      bad.frames[17].rounds = { 'loaded' }
    end)
    invalid('firing poses still require a measured muzzle', function(bad)
      bad.frames[2].muzzle = nil
    end)
    invalid('nonfinite placement fails atomically', function(bad)
      bad.placement[1] = math.huge
    end)
    invalid('ejection anchors outside the illustration fail atomically', function(bad)
      bad.frames[7].eject = { 9999, 0 }
    end)
    invalid('interrupted close phases require normalized completion', function(bad)
      bad.phases.interruptedClose = { { finish = 1.1, frame = 'closing' } }
    end)
    invalid('interrupted close phases require valid named poses', function(bad)
      bad.phases.interruptedClose = { { finish = 1, frame = 'missing_close_pose' } }
    end)
    local registered = Art.register(id, entry)
    check('reload leaves can omit a meaningless muzzle point', not registered.frames[17].muzzle)
    Fixtures.words({ round_count_fixture = 'ROUND COUNT FIXTURE' })
    Weapons.define({
      extends = Weapons.get('judge'),
      id = id,
      name = 'round_count_fixture',
      art = id,
      capacity = 2,
      startReserve = 1,
    })
    check(
      'presentation composition accepts complete zero-to-capacity coverage',
      pcall(Art.validateWeapon, Weapons.get(id))
    )
    local incomplete = Schema.copy(Weapons.get(id))
    incomplete.capacity = 3
    check(
      'capacity expansion requires its additional painted chamber state',
      not pcall(Art.validateWeapon, incomplete)
    )
    Snapshot.invalidateDefinitions()
    Visual.loadAtlases()
    local g = Fixtures.arena(G)
    local slot = Weapons.give(g, id)
    g:switchWeapon(slot)
    local state = Weapons.state(g)
    g.view.shotAge, g.view.swapAge = 10, 1
    state.mag, state.reserve, state.open, state.loaded = 1, 1, true, false
    check('one remaining live round remains visible in the open cylinder', Sampler.frame(g) == 18)
    local before = Integrity.capture(g)
    Sampler.frame(g)
    check(
      'selecting painted chamber content never changes simulation',
      not Integrity.difference(before, Integrity.capture(g))
    )
    check('open reload starts from its actual mechanical resume point', Reload.start(g, false))
    check('partial contents persist before the ammunition transaction', Sampler.frame(g) == 18)
    Reload.update(g, 0.48)
    check(
      'the load transaction immediately selects the actual two rounds',
      state.mag == 2 and state.reserve == 0 and Sampler.frame(g) == 19
    )
    Reload.cancel(g)
    check(
      'cancelled loaded-open state keeps its correct two-round pose',
      state.open and Sampler.frame(g) == 19
    )
    g:switchWeapon(1)
    g:switchWeapon(slot)
    check(
      'weapon swap resumes the same loaded chamber contents',
      state.mag == 2 and Sampler.frame(g) == 19
    )
    Reload.cancel(g)
    state.mag, state.reserve, state.open, state.loaded = 0, 1, true, false
    check('empty open chambers choose the zero-round leaf', Sampler.frame(g) == 17)
    Reload.start(g, false)
    Reload.update(g, 0.48)
    check(
      'a reserve of one paints one chamber, never a full cylinder',
      state.mag == 1 and state.reserve == 0 and Sampler.frame(g) == 18
    )
    check(
      'a reload pose without muzzle does not invent a muzzle flash',
      Visual.muzzlePhase(g) == nil
    )
    local place = registered.placement
    local x, y = Visual.transform(g, 800, 450)
    registered.placement = nil
    local baseX, baseY = Visual.transform(g, 800, 450)
    registered.placement = place
    local scale = 450 * registered.screenScale / registered.cellWidth
    check(
      'source-pixel placement keeps the true grip independent of screen alignment',
      near(x - baseX, place[1] * scale) and near(y - baseY, place[2] * scale)
    )
    local drawn, original = nil, love.graphics.draw
    love.graphics.draw = function(...)
      local args = { ... }
      if args[1] == Visual.images[id] then
        drawn = args[2]
      end
      return original(...)
    end
    local rendered, renderError = pcall(Visual.draw, g, 800, 450, { 1, 1, 1 })
    love.graphics.draw = original
    assert(rendered, renderError)
    check('real GPU draw selects the partial-round rectangle', drawn == Visual.quads[id][18])
    Reload.cancel(g)
    state.mag, state.open, state.loaded = 1, true, false
    Reload.start(g, false)
    Reload.interrupt(g)
    check(
      'preload interrupt closes mechanically without granting rounds',
      state.mag == 1 and not state.open and g.player.reload == 0
    )
    state.open, state.mag = true, 3
    check(
      'uncovered contents fail loudly instead of clamping to a false drawing',
      not pcall(Sampler.frame, g)
    )
    local function interruptedCylinder()
      local session = Fixtures.arena(G)
      session.player.weapon, session.elapsed = 2, 2
      session.view.swapAge = 1
      local cylinder = Weapons.state(session)
      cylinder.mag, cylinder.reserve = 1, 1
      assert(Reload.start(session, false))
      Reload.update(session, 0.85)
      assert(not Reload.interrupt(session))
      return session, cylinder
    end
    local closing, cylinder = interruptedCylinder()
    local beforeClose = Integrity.capture(closing)
    local readyAt, mag, reserve = cylinder.readyAt, cylinder.mag, cylinder.reserve
    check(
      'trigger interrupt starts the actual remaining-round open pose before readiness',
      Sampler.frame(closing)
          == Art.variant(Art.get('judge'), Art.frame(Art.get('judge'), 'open'), 1)
        and not cylinder.open
        and near(readyAt, 2.25)
        and mag == 1
        and reserve == 1
    )
    check(
      'sampling interrupted closure is read only',
      not Integrity.difference(beforeClose, Integrity.capture(closing))
    )
    closing.elapsed = 2.13
    check(
      'the existing quarter-second close clock reaches its named closing pose',
      Sampler.frame(closing) == Art.frame(Art.get('judge'), 'closing')
    )
    closing.elapsed = 2.23
    check(
      'interrupted closure returns through the authored final hand pose',
      Sampler.frame(closing) == Art.frame(Art.get('judge'), 'return_ready')
    )
    closing.elapsed = 2.25
    require('src.feedback.transients').beforeCombat(closing, 0)
    check(
      'at mechanical readiness the override expires without transferring ammo or changing cooldown',
      not closing.view.interruptedClose
        and Sampler.frame(closing) == Art.frame(Art.get('judge'), 'ready')
        and cylinder.readyAt == readyAt
        and cylinder.mag == mag
        and cylinder.reserve == reserve
    )
    local swapped = interruptedCylinder()
    swapped:switchWeapon(1)
    swapped:switchWeapon(2)
    check(
      'switching away and back cannot revive an interrupted close',
      not swapped.view.interruptedClose
    )
    local reset = interruptedCylinder()
    require('src.player.feel').init(reset)
    check('session feel reset clears the old close presentation', not reset.view.interruptedClose)
    local shot = interruptedCylinder()
    require('src.feedback.weight').shot(shot, Weapons.inHand(shot), 1)
    check('a new shot clears interrupted close presentation', not shot.view.interruptedClose)
    local fired = Fixtures.arena(G)
    assert(fired:shoot())
    Reload.update(fired, 0.27)
    local shell = assert(fired.view.shells[1], 'real breech opening must release its spent cases')
    local neverShown = Schema.copy(shell)
    local casingFrame = Art.get('exorcist').frames[Visual.sourceFrame(fired)]
    local x, y, angle, growth = Visual.transform(fired, 800, 450)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    local pixels = 450 * Art.get('exorcist').screenScale / Art.get('exorcist').cellWidth * growth
    local dx = (casingFrame.eject[1] - casingFrame.grip[1]) * pixels
    local dy = (casingFrame.eject[2] - casingFrame.grip[2]) * pixels
    local initialLife = shell.life
    local beforeCasing = Integrity.capture(fired)
    local sx, sy = Visual.shellPosition(fired, shell, 800, 450)
    check(
      'spent case starts at the transformed painted breech',
      near(sx, x + math.cos(angle) * dx - math.sin(angle) * dy + shell.x)
        and near(sy, y + math.sin(angle) * dx + math.cos(angle) * dy + shell.y)
    )
    check(
      'binding the effect does not consume life or modify gameplay',
      shell.life == initialLife and not Integrity.difference(beforeCasing, Integrity.capture(fired))
    )
    fired.view.recoil, fired.view.weaponShotRoll = 3, 0.2
    fired:switchWeapon(2)
    local heldX, heldY = Visual.shellPosition(fired, shell, 800, 450)
    check(
      'a bound case never follows later hand motion or a different weapon',
      near(heldX, sx) and near(heldY, sy)
    )
    shell.x, shell.life = shell.x + 10, shell.life - 0.1
    local movedX, movedY = Visual.shellPosition(fired, shell, 800, 450)
    check(
      'case flight remains owned by its transient trajectory',
      near(movedX, sx + 10) and near(movedY, sy) and near(shell.life, initialLife - 0.1)
    )
    local largeX, largeY = Visual.shellPosition(fired, shell, 1600, 900)
    check(
      'resize preserves the bound origin and trajectory proportion',
      near(largeX, movedX * 2) and near(largeY, movedY * 2)
    )
    check(
      'a swap before first display never launches an old case from the new gun',
      Visual.shellPosition(fired, neverShown, 800, 450) == nil
        and neverShown.hidden
        and not neverShown.originX
    )
    local rectangle = love.graphics.rectangle
    local widths = {}
    love.graphics.rectangle = function(mode, x, y, width, height, ...)
      if mode == 'fill' and width == 4 and height == 10 then
        local ax, ay = love.graphics.transformPoint(0, 0)
        local bx, by = love.graphics.transformPoint(width, 0)
        widths[#widths + 1] = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
      end
      return rectangle(mode, x, y, width, height, ...)
    end
    local scaled, scaleError = pcall(function()
      fired.view.shells = { shell }
      Visual.draw(fired, 800, 450, { 1, 1, 1 })
      Visual.draw(fired, 1600, 900, { 1, 1, 1 })
    end)
    love.graphics.rectangle = rectangle
    assert(scaled, scaleError)
    check(
      'the casing illustration scales with its trajectory on resize',
      #widths == 2 and math.abs(widths[2] - widths[1] * 2) < 0.0001
    )
    local queued = Fixtures.arena(G)
    assert(queued:shoot())
    queued.bus:beginStep()
    Reload.update(queued, 0.27)
    queued:switchWeapon(2)
    queued.bus:flush()
    local delayed = queued.view.shells[1]
    check(
      'queued ejection retains the emitting weapon after reload cancellation and swap',
      delayed and delayed.weapon == 'exorcist' and Weapons.idAt(queued) == 'judge'
    )
    check(
      'a queued old-weapon case cannot bind to the newly selected illustration',
      delayed and Visual.shellPosition(queued, delayed, 800, 450) == nil and delayed.hidden
    )
  end, debug.traceback)
  Weapons.registry:unregister(id)
  Art.unregister(id)
  Snapshot.invalidateDefinitions()
  Visual.loadAtlases()
  assert(ok, problem)
  return lines
end
return Tests

-- A deliberately reordered five-frame firearm atlas and an independent
-- three-frame equipment gesture exercise real GPU draws and reload transactions.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Schema = require('src.core.schema')
  local Art = require('src.content.weapon_art')
  local Equipment = require('src.content.equipment_art')
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local Reload = require('src.combat.reload')
  local Visual = require('src.render.weapon')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local Serialize = require('src.core.serialize')
  local lines = {}
  local check = Fixtures.checker(lines, 'hand art extension: ', 'hand art extension: ')
  local near = Fixtures.within(1e-8)
  local id, hands = 'trial_five_poses', 'trial_three_hands'
  local originalDraw = love.graphics.draw
  local originals = { Visual.images.exorcist, Visual.images.judge, Visual.chargeImage }
  local beforeArt = Serialize.encode(Art.get('judge'))
  local ok, problem = xpcall(function()
    local entry = Schema.copy(Art.get('judge'))
    local frames = {}
    for i, source in ipairs({ 16, 2, 8, 12, 1 }) do
      frames[i] = entry.frames[source]
      -- This fixture deliberately has five rectangles; chamber variants from
      -- the production sheet are tested separately by weapon_rounds.
      frames[i].rounds = nil
    end
    entry.frames = frames
    entry.frames[2].muzzle = { 91, 76 }
    entry.ready, entry.reloadComplete = frames[5].id, frames[1].id
    entry.open = { empty = frames[3].id, primed = frames[4].id }
    entry.phases = {
      fire = { { finish = 0.15, frame = frames[2].id } },
      reload = {
        { finish = 1.16, frame = frames[3].id },
        { finish = 1.55, frame = frames[4].id },
        { finish = 1.85, frame = frames[1].id },
      },
    }
    entry.reloadMotion = { { 0, 0, 0, 0 }, { 1.85, 3, 2, 0.01 } }
    local registered = Art.register(id, entry)
    check(
      'registration compiles names without mutating the source or parent',
      registered.frameNames[entry.ready] == 5
        and registered.frameNames[entry.reloadComplete] == 1
        and Serialize.encode(Art.get('judge')) == beforeArt
        and registered ~= entry
    )
    local function invalid(label, change)
      local bad = Schema.copy(entry)
      change(bad)
      local accepted = pcall(Art.register, 'trial_invalid_art', bad)
      check(label, not accepted and Art.entries.trial_invalid_art == nil)
    end
    invalid('missing named phase fails atomically', function(bad)
      bad.phases.fire[1].frame = 'absent'
    end)
    invalid('duplicate frame names fail atomically', function(bad)
      bad.frames[2].id = bad.frames[1].id
    end)
    invalid('out of bounds rectangle fails atomically', function(bad)
      bad.frames[1].rect[3] = bad.width + 1
    end)
    invalid('out of bounds muzzle fails atomically', function(bad)
      bad.frames[2].muzzle[1] = 9999
    end)
    invalid('NaN timing fails atomically', function(bad)
      bad.phases.fire[1].finish = 0 / 0
    end)
    invalid('reversed reload motion fails atomically', function(bad)
      bad.reloadMotion[2][1] = 0
    end)
    local hand = Schema.copy(Equipment.getAtlas('powder'))
    hand.frames, hand.worldFrames = { hand.frames[4], hand.frames[2], hand.frames[3] }, nil
    hand.position = { x = 0.67, y = 0.92, biasY = 7, exitY = 0.14, exitPower = 3 }
    Equipment.registerAtlas(hands, hand)
    Equipment.register(hands, {
      atlas = hands,
      duration = 0.42,
      phases = {
        { finish = 0.12, frame = 'release' },
        { finish = 0.30, frame = 'ignite' },
        { finish = 0.42, frame = 'follow' },
      },
    })
    check(
      'a used atlas cannot be removed beneath its gesture',
      not pcall(Equipment.unregisterAtlas, hands)
    )
    Visual.loadAtlases()
    check(
      'loader supports five source rectangles and another hand atlas',
      #Visual.quads[id] == 5 and #Visual.handAtlases[hands].quads == 3
    )
    check(
      'different layouts share identical PNG sampling without duplicate GPU images',
      Visual.images[id] == Visual.images.judge
        and Visual.handAtlases[hands].image == Visual.chargeImage
    )
    check(
      'extending the catalogue reuses current production GPU images',
      Visual.images.exorcist == originals[1]
        and Visual.images.judge == originals[2]
        and Visual.chargeImage == originals[3]
    )
    Fixtures.words({ trial_atlas = 'TRIAL ATLAS' })
    Weapons.define({
      extends = Weapons.get('judge'),
      id = id,
      name = 'trial_atlas',
      art = id,
      capacity = 3,
      startReserve = 3,
      fire = { autoReload = false },
    })
    local item = Schema.copy(Abilities:get('powder'))
    item.id, item.hands, item.action.id = hands, hands, hands
    Abilities.define(item)
    Snapshot.invalidateDefinitions()
    local g = Fixtures.arena(G)
    g:switchWeapon(Weapons.give(g, id))
    g.player.cooldown = 0
    g.view.swapAge, g.view.shotAge = 1, 10
    local state = Weapons.state(g)
    check('ready uses named fifth frame instead of hardcoded frame one', Visual.sourceFrame(g) == 5)
    check(
      'real trigger selects custom recoil and spends ordinary ammunition',
      g:shoot() and Visual.sourceFrame(g) == 2 and state.mag == 2
    )
    local draws = {}
    love.graphics.draw = function(...)
      local args = { ... }
      if
        args[1] == Visual.images[id]
        or args[1] == Visual.muzzleImage
        or args[1] == Visual.handAtlases[hands].image
      then
        draws[#draws + 1] = args
      end
      return originalDraw(...)
    end
    local before = Integrity.capture(g)
    Visual.draw(g, 800, 450, { 1, 1, 1 })
    check(
      'actual draw uses the third atlas and its custom recoil rectangle',
      #draws == 2 and draws[1][1] == Visual.images[id] and draws[1][2] == Visual.quads[id][2]
    )
    local gun, flash = draws[1], draws[2]
    local frame = registered.frames[2]
    local dx, dy =
      (frame.muzzle[1] - frame.grip[1]) * gun[6], (frame.muzzle[2] - frame.grip[2]) * gun[7]
    local x = math.floor(gun[3] + math.cos(gun[5]) * dx - math.sin(gun[5]) * dy + 0.5)
    local y = math.floor(gun[4] + math.sin(gun[5]) * dx + math.cos(gun[5]) * dy + 0.5)
    check(
      'actual muzzle effect follows the custom painted anchor through the gun transform',
      flash[3] == x
        and flash[4] == y
        and flash[2] == Visual.muzzleFrames[registered.style.muzzle[1].frame].quad
    )
    check(
      'drawing custom firearm cannot advance the simulation',
      not Integrity.difference(before, Integrity.capture(g))
    )
    g.view.shotAge, g.player.cooldown = 10, 0
    state.mag, state.reserve = 0, 1
    assert(Reload.start(g, false))
    Reload.update(g, 1.15)
    check(
      'custom atlas remains empty before the actual ammunition transaction',
      Visual.sourceFrame(g) == 3 and state.mag == 0
    )
    Reload.update(g, 0.02)
    check(
      'partial load selects named loaded pose only after the real transaction',
      Visual.sourceFrame(g) == 4 and state.mag == 1 and state.reserve == 0
    )
    Reload.cancel(g)
    check(
      'cancelling partial reload preserves the open loaded illustration',
      Visual.sourceFrame(g) == 4 and state.open
    )
    assert(Reload.start(g, false))
    Reload.update(g, 2)
    check(
      'resumed partial reload finishes without manufacturing ammunition',
      Visual.sourceFrame(g) == 5 and state.mag == 1 and not state.open
    )
    state.reserve = 1
    assert(Reload.start(g, false))
    Reload.update(g, 0.5)
    local mag, reserve = state.mag, state.reserve
    Reload.interrupt(g)
    check(
      'interrupt closes the same physical action without spending or loading',
      g.player.reload == 0
        and not state.open
        and state.mag == mag
        and state.reserve == reserve
        and Visual.sourceFrame(g) == 5
    )
    Abilities.give(g, hands)
    check('second equipment slot selects an independent three-frame hand atlas', g:cast(2))
    local index, _, _, atlas = Visual.throwFrame(g)
    check(
      'gesture resolves its named release after rectangle reordering',
      index == 3 and atlas == hands
    )
    draws = {}
    Visual.draw(g, 800, 450, { 1, 1, 1 })
    local actual = draws[#draws]
    check(
      'actual hand draw uses its own position grip and image',
      actual[1] == Visual.handAtlases[hands].image
        and actual[2] == Visual.handAtlases[hands].quads[3]
        and near(actual[3], 800 * hand.position.x)
        and near(actual[4], 450 * hand.position.y + hand.position.biasY)
        and actual[8] == hand.frames[3].grip[1]
        and actual[9] == hand.frames[3].grip[2]
    )
    for _ = 1, 20 do
      g:update(1 / 120, {})
    end
    check('independent hand phase advances from the cast clock', Visual.throwFrame(g) == 2)
    before = Integrity.capture(g)
    renderer:draw(g, 1280, 720)
    check(
      'full scene integrates both custom atlases without simulation writes',
      not Integrity.difference(before, Integrity.capture(g))
    )
  end, debug.traceback)
  love.graphics.draw = originalDraw
  Weapons.registry:unregister(id)
  Abilities:unregister(hands)
  Art.unregister(id)
  Art.unregister('trial_invalid_art')
  Equipment.unregister(hands)
  Equipment.unregisterAtlas(hands)
  Visual.loadAtlases()
  Snapshot.invalidateDefinitions()
  assert(ok, problem)
  check(
    'unloading test-only content restores production atlas count',
    #Art.ids == 2 and Visual.atlases[id] == nil and Visual.handAtlases[hands] == nil
  )
  return lines
end
return Tests

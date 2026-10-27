-- Plan v11 E5: two actual canvases of one world. The same simulation has
-- independent hands, HUD and feedback, and a viewer may leave its actor.
-- These trials use public commands, then compare the canonical simulation
-- before and after drawing; presentation is not allowed to become gameplay.
local Fixtures = require('tests.support.fixtures')
local Tests = {}

function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'view-context: ', 'view-context: ')
  local near = Fixtures.within(1e-8)
  local Context = require('src.session.context')
  local Pools = require('src.session.world')
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local Integrity = require('src.session.integrity')
  local Journal = require('src.session.journal')
  local FX = require('src.feedback.effects')
  local P = require('src.render.presentation')
  local Camera = require('src.render.camera')
  local Art = require('src.render.weapon_art')
  local Input = require('src.app.input')
  local Skin = require('src.ui.skin')
  local UI = require('src.ui.interface')
  local lg = love.graphics
  local dt = 1 / 120

  local function arena()
    local g = G.new('classic')
    g.testing = true
    g:start()
    Pools.clear(g, 'enemies')
    Pools.clear(g, 'pickups')
    g.player.x, g.player.z, g.player.yaw = 16, 25, math.pi
    g.player.hp = 83
    return g
  end
  local function join(g)
    local kit = { 'exorcist', 'judge' }
    local knight = g.ecs:create('knight', {
      id = 'view_trial_b',
      x = 16,
      z = 25,
      yaw = math.pi,
      hp = 47,
      loadout = kit,
      arsenal = Weapons.arsenal(kit),
      weapon = 2,
      abilities = { 'powder' },
      abilityState = Abilities.kit({ 'powder' }),
    }, false)
    assert(g:actorJoin(Pools.memberRecord(knight)))
    return Pools.get(g, 'view_trial_b')
  end
  -- Redirect only the final composition, not the world's low-resolution
  -- canvas. HUD and postprocessing really reach two separate render targets.
  local function render(g, name)
    local target = lg.newCanvas(1280, 720)
    local ownPresent, present = rawget(renderer, 'present'), renderer.present
    local originalText = Skin.text
    local oldMouse, oldScreen, oldAudit, oldFields = UI.useMouse, UI.screen, Skin.audit, Skin.fields
    local texts = {}
    Skin.text = function(value, ...)
      texts[tostring(value)] = true
      return originalText(value, ...)
    end
    renderer.present = function(self, shown, w, h)
      lg.setCanvas(target)
      lg.origin()
      lg.clear(0, 0, 0, 1)
      return present(self, shown, w, h)
    end
    UI.useMouse, UI.screen = false, 'playing'
    lg.push('all')
    local ok, problem = pcall(function()
      renderer:draw(g, 1280, 720)
      UI.draw(g, 1280, 720, {
        sensitivity = 1,
        motion = true,
        music = 1,
        fov = 100,
        hints = false,
        muted = true,
      })
    end)
    lg.pop()
    renderer.present, Skin.text = ownPresent, originalText
    UI.useMouse, UI.screen, Skin.audit, Skin.fields = oldMouse, oldScreen, oldAudit, oldFields
    if not ok then
      target:release()
      error(problem)
    end
    local data = target:newImageData()
    target:release()
    if name then
      local file = assert(io.open(require('qa.output').path(name), 'wb'))
      local encoded = data:encode('png')
      file:write(encoded:getString())
      file:close()
      encoded:release()
    end
    local bytes = data:getString()
    data:release()
    return bytes, texts
  end

  local g = arena()
  local a, b = g.player, join(g)
  local before = Integrity.capture(g)
  Context.watch(g, b.id)
  local va, vb = Context.of(g, a), Context.of(g, b)
  check('the controlled view keeps the original session identity', va == g)
  check(
    'two contexts keep actor and viewer explicit without changing control',
    Context.actor(vb) == b and Context.viewer(vb) == b and g.player == a
  )
  check(
    'watching changes no simulation field',
    not Integrity.difference(before, Integrity.capture(g))
  )
  check("hands use each actor's own weapon", Art.idOf(va) == 'exorcist' and Art.idOf(vb) == 'judge')
  local cleanA = render(va)
  check(
    "an actual shot by B starts only B's recoil and discharge animation",
    g:shoot(nil, b.id)
      and vb.view.shotAge == 0
      and vb.view.muzzle > 0
      and vb.view.recoilV > 0
      and (va.view.muzzle or 0) == 0
      and (va.view.recoilV or 0) == 0
  )
  g:damageBody(b, 10, b.x + 1, b.z, { base = 10, impact = 0 })
  check(
    "a blow to B lights only B's damage overlay",
    vb.view.hurt > 0 and (va.view.hurt or 0) == 0 and b.hp < 47 and a.hp == 83
  )

  local stain = FX.stain(vb, 16, 23.5, 1.4, 'imp')
  local blood = FX.emit(vb, 'blood', 16, 0.9, 23.5, 1.1)
  check(
    'world stains and blood are one shared collection in both contexts',
    va.view.decals == vb.view.decals
      and va.view.effects == vb.view.effects
      and va.view.decals[#va.view.decals] == stain
      and va.view.effects[#va.view.effects] == blood
  )
  before = Integrity.capture(g)
  local imageA, textA = render(va, 'view-context-a.png')
  local imageB, textB = render(vb, 'view-context-b.png')
  local againA = render(va)
  check(
    'two canvases show different hands and HUD values',
    imageA ~= imageB and textA['83'] and textB[tostring(math.ceil(b.hp))]
  )
  check('the other actor sees the shared world effect without receiving recoil', imageA ~= cleanA)
  check('drawing B cannot contaminate the next draw of A', imageA == againA)
  check(
    'drawing both canvases does not advance the world or the effect clocks',
    blood.age == 0 and stain.age == 0 and not Integrity.difference(before, Integrity.capture(g))
  )

  -- A camera need not be a controllable body. It sees from its own explicit
  -- height; the knight whose HUD it accompanies remains A.
  local demon = g:spawn('imp', 16, 20)
  demon.dummy, demon.spawnAge = true, 1
  local viewer = { x = 20, y = 3.2, z = 24, yaw = -2.2, pitch = -0.12 }
  local free = Context.of(g, a, viewer)
  before = Integrity.capture(g)
  local freeImage, freeText = render(free)
  check(
    "the free camera draws from its own origin with A's HUD and hands",
    near(renderer.camera[1], viewer.x)
      and near(renderer.camera[2], viewer.y)
      and near(renderer.camera[3], viewer.z)
      and freeText['83']
      and Art.idOf(free) == 'exorcist'
      and freeImage ~= imageA
  )
  local r, u, f = {}, {}, {}
  Camera.basis(free, r, u, f)
  check(
    'free-camera aim comes from its viewer, not the actor',
    near(f[1], math.sin(viewer.yaw) * math.cos(viewer.pitch))
      and near(f[2], math.sin(viewer.pitch))
      and near(f[3], math.cos(viewer.yaw) * math.cos(viewer.pitch))
  )
  local placement = renderer:enemyPlacement(free, demon)
  check(
    'the actual painted demon turns toward the viewer, not the HUD owner',
    near(placement.yaw, math.atan2(viewer.x - demon.x, viewer.z - demon.z))
      and not near(placement.yaw, math.atan2(a.x - demon.x, a.z - demon.z))
  )
  -- Exercise the real spatial cue route without playing another test sound.
  local Audio = require('src.audio.audio')
  local originalAt, listener = Audio.playAt, nil
  Audio.playAt = function(_, _, _, eye)
    listener = eye
  end
  local cueOK, cueError = pcall(require('src.feedback.install').cue, free, 'hit', 0.3, 16, 20)
  Audio.playAt = originalAt
  assert(cueOK, cueError)
  check('a spatial sound uses the free viewer as its listener', listener == viewer)
  -- Three lights compete for two projectile slots. This fixture only changes
  -- the rendered pool, never the session's authoritative projectiles.
  local lights = {
    { x = 16, y = 1, z = 25 },
    { x = 20, y = 1, z = 24 },
    { x = 19, y = 1, z = 24 },
  }
  local function lightProbe(context)
    return setmetatable({ ecs = false, bullets = lights }, { __index = context })
  end
  renderer.lighting:update(lightProbe(va))
  local actorLight = renderer.lighting.positions[15][1]
  renderer.lighting:update(lightProbe(free))
  check(
    'projectile lights are chosen around the viewer instead of the actor',
    actorLight == 16 and renderer.lighting.positions[15][1] == 20
  )
  check(
    'a free-camera draw leaves the authoritative world untouched',
    not Integrity.difference(before, Integrity.capture(g))
  )
  b.x = 19
  local observer = Context.of(g, a, b)
  render(observer)
  check(
    'another knight can be the viewer while A still owns hands and HUD',
    Context.actor(observer) == a
      and Context.viewer(observer) == b
      and near(renderer.camera[1], b.x)
      and Art.idOf(observer) == 'exorcist'
  )

  -- Both actors interpolate, even when B is sampled before A. A raw mouse
  -- direction stays current; the prior positional sample belongs to the view.
  P.capture(g)
  local oldAX, oldBX = a.x, b.x
  a.x, b.x = a.x + 2, b.x - 4
  b.yaw = b.yaw + 0.12
  before = Integrity.capture(g)
  local sampleB, sampleA = P.sample(vb, 0.5), P.sample(va, 0.5)
  check(
    'each watched actor interpolates its own position and keeps current aim',
    near(Context.actor(sampleA).x, oldAX + 1)
      and near(Context.actor(sampleB).x, oldBX - 2)
      and near(Context.actor(sampleB).yaw, b.yaw)
  )
  check(
    'sampling all views does not move either authoritative actor',
    not Integrity.difference(before, Integrity.capture(g))
  )
  P.capture(free)
  local cameraX = viewer.x
  viewer.x = viewer.x + 2
  local sampledFree = P.sample(free, 0.5)
  check(
    'two viewers of A keep separate camera and actor histories',
    near(Context.viewer(sampledFree).x, cameraX + 1)
      and near(Context.actor(sampledFree).x, a.x)
      and near(Context.actor(P.sample(va, 0.5)).x, oldAX + 1)
      and near(Context.actor(P.sample(vb, 0.5)).x, oldBX - 2)
  )

  local device = {
    held = function(name)
      return name == 'forward' and 1 or 0
    end,
    mouseDown = function()
      return true
    end,
  }
  local input = Input.new(b.id, device)
  input:present(g, vb)
  local command = input:sample(g)
  local own = command.actors and command.actors[b.id]
  check(
    "a bound device produces only its actor's intent and shot observation",
    own
      and own.forward == 1
      and own.shoot
      and own.fireCommand
      and not command.shoot
      and not command.forward
  )

  -- Disposal must leave shared effects alive; reopening a viewport must not
  -- resurrect old flashes. These are presentation operations, not commands.
  local shared = g.view.effects
  before = Integrity.capture(g)
  Context.unwatch(g, b.id)
  check(
    'closing B releases its personal view and preserves world effects',
    Context.watched(g)[b.id] == nil and g.view.effects == shared
  )
  Context.watch(g, b.id)
  vb = Context.of(g, b)
  check(
    'reopening B resets its private hurt/recoil and interpolation',
    (vb.view.hurt or 0) == 0
      and (vb.view.muzzle or 0) == 0
      and (vb.view.recoilV or 0) == 0
      and vb.view.presentationPrevious == nil
  )
  check(
    'opening and closing a view cannot alter simulation state',
    not Integrity.difference(before, Integrity.capture(g))
  )
  vb.view.hurt, va.view.hurt = 0.8, 0.6
  check('control can pass to B', g:actorControl(b.id))
  local former = Context.view(g, a)
  check(
    'control transfer clears personal transients and keeps world FX',
    Context.actor(g) == b
      and (g.view.hurt or 0) == 0
      and (not former or (former.hurt or 0) == 0)
      and g.view.effects == shared
  )

  local deathGame = arena()
  local doomed = join(deathGame)
  Context.watch(deathGame, doomed.id)
  Context.view(deathGame, doomed).hurt = 0.7
  deathGame.view.hurt = 0.25
  deathGame:damageBody(doomed, 10000, doomed.x + 1, doomed.z, { base = 10000, impact = 0 })
  local deadView = Context.view(deathGame, doomed)
  check(
    "B dying resets B's presentation without clearing A's overlay",
    doomed.hp <= 0
      and deathGame.state == 'playing'
      and deathGame.view.hurt == 0.25
      and (not deadView or ((deadView.hurt or 0) == 0 and deadView.presentationPrevious == nil))
  )
  -- The production step queues presentation until after simulation. A queued
  -- KnightHit must not resurrect the hurt flash already cleared by death.
  local deferred = arena()
  local falling = join(deferred)
  Context.watch(deferred, falling.id)
  deferred.view.hurt = 0.25
  deferred.bus:beginStep()
  deferred:damageBody(falling, 10000, falling.x + 1, falling.z, { base = 10000, impact = 0 })
  deferred.bus:flush()
  local fallenView = Context.view(deferred, falling)
  check(
    "deferred damage feedback cannot resurrect a dead actor's personal transients",
    falling.hp == 0
      and deferred.view.hurt == 0.25
      and (not fallenView or ((fallenView.hurt or 0) == 0 and (fallenView.shake or 0) == 0))
  )

  -- Detached cameras can outnumber actors. Their registry must stop retaining
  -- obsolete actors/viewers when a viewport closes or control changes.
  local lifecycle = arena()
  local firstActor, secondActor = lifecycle.player, join(lifecycle)
  Context.watch(lifecycle, secondActor.id)
  local camera1 = { x = 18, y = 3, z = 23, yaw = math.pi, pitch = 0 }
  local camera2 = { x = 20, y = 4, z = 23, yaw = math.pi, pitch = 0 }
  Context.of(lifecycle, firstActor, camera1)
  Context.of(lifecycle, firstActor, camera2)
  Context.of(lifecycle, firstActor, secondActor)
  Context.of(lifecycle, secondActor, firstActor)
  check(
    'an unknown context actor is rejected instead of falling back to the controlled knight',
    not pcall(Context.of, lifecycle, 'missing_actor')
  )
  check(
    'four detached actor/viewer pairs retain four histories',
    #Context.observers(lifecycle) == 4
  )
  Context.unobserve(lifecycle, firstActor, camera1)
  Context.unobserve(lifecycle, firstActor, camera1)
  check(
    'detaching one viewer is idempotent and keeps the other three',
    #Context.observers(lifecycle) == 3
  )
  Context.unwatch(lifecycle, secondActor.id)
  local remaining = Context.observers(lifecycle)
  check(
    'unwatch removes references to a knight as both actor and viewer',
    #remaining == 1 and remaining[1].actor == firstActor.id and remaining[1].viewer == camera2
  )
  -- Recreate two separate A cameras, then switch to previously unwatched B.
  Context.of(lifecycle, firstActor, camera1)
  assert(lifecycle:actorControl(secondActor.id))
  local lifeBefore = Integrity.capture(lifecycle)
  local captureOK = pcall(P.capture, lifecycle)
  check(
    'control transfer discards old detached viewers before the next capture',
    captureOK
      and #Context.observers(lifecycle) == 0
      and not Integrity.difference(lifeBefore, Integrity.capture(lifecycle))
  )

  local motionGame = arena()
  local motionActor = join(motionGame)
  Context.watch(motionGame, motionActor.id)
  local motionB = Context.of(motionGame, motionActor)
  local motionFree = Context.of(motionGame, motionGame.player, camera1)
  local motionFreeB = Context.of(motionGame, motionActor, camera2)
  motionGame.view.recoil, motionGame.view.swayX, motionGame.view.hurt = 0.7, 0.1, 0.3
  motionB.view.recoil, motionB.view.swayX, motionB.view.hurt = 0.8, 0.2, 0.6
  P.capture(motionGame)
  P.capture(motionFree)
  P.capture(motionFreeB)
  before = Integrity.capture(motionGame)
  require('src.player.feel').clearMotion(motionGame)
  check(
    'disabling motion clears all watched and detached camera histories immediately',
    motionGame.view.recoil == 0
      and motionB.view.recoil == 0
      and motionGame.view.swayX == 0
      and motionB.view.swayX == 0
      and motionGame.view.presentationPrevious == nil
      and motionB.view.presentationPrevious == nil
      and motionFree.view.presentationPrevious == nil
      and motionFreeB.view.presentationPrevious == nil
  )
  check(
    'clearing motion preserves combat feedback and authoritative actor state',
    motionGame.view.hurt == 0.3
      and motionB.view.hurt == 0.6
      and not Integrity.difference(before, Integrity.capture(motionGame))
  )
  local Field = require('src.run.test_field')
  local resetGame = Field.new(G)
  resetGame.testing = true
  local resetActor = join(resetGame)
  Context.watch(resetGame, resetActor.id)
  resetGame.view.hurt = 0.5
  FX.emit(resetGame, 'blood', 16, 0.9, 23.5, 1.1)
  Field.reset(resetGame)
  check(
    'a new session run discards watched personal states and old effects',
    next(Context.watched(resetGame)) == nil
      and (resetGame.view.hurt or 0) == 0
      and #resetGame.view.effects == 0
  )

  -- A recorded trial with a watched B replays with no secondary viewport:
  -- the journal carries actor commands, never a camera or a personal flash.
  local recorded = arena()
  local journal = Journal.record(recorded)
  local other = join(recorded)
  Context.watch(recorded, other.id)
  for tick = 1, 60 do
    if tick == 1 then
      recorded:shoot(nil, other.id)
    end
    if tick == 20 then
      recorded:shoot()
    end
    recorded:update(dt, { actors = { [other.id] = { forward = tick < 15 and 1 or 0 } } })
  end
  Journal.stop(recorded)
  local decoded = Journal.decode(Journal.encode(journal))
  local replay = arena()
  local ok, problem = pcall(Journal.replay, replay, decoded)
  local difference = ok
    and Integrity.difference(Integrity.capture(recorded), Integrity.capture(replay))
  check(
    'journal v5 replays the two-view trial bit for bit without those views: '
      .. tostring(problem or difference or 'equal'),
    decoded.header.version == 5 and ok and not difference
  )

  -- Keyboard/mouse handlers must cross the same journal boundary as manual
  -- commands: an optional actor is an id, never the mutable ECS body table.
  local function inputTrial(bound)
    local trial = arena()
    local knight = bound and join(trial) or trial.player
    local driver = bound and Input.new(knight.id) or Input.new()
    local app = { game = trial, settings = { sensitivity = 1 } }
    local log = Journal.record(trial)
    local oldRelative = love.mouse.getRelativeMode
    love.mouse.getRelativeMode = function()
      return true
    end
    local inputOK, inputError = pcall(function()
      -- An unwatched bound actor is legal: look still works, absent cosmetic
      -- springs do not create a viewport or prevent recording the command.
      driver:mousemoved(app, 640, 300, 10, 5)
      driver:keypressed(app, '2', '2', false)
      for _ = 1, 60 do
        trial:update(dt, {})
      end
      driver:mousepressed(app, 640, 300, 1)
      driver:keypressed(app, 'r', 'r', false)
      driver:keypressed(app, 'q', 'q', false)
      driver:wheelmoved(app, 0, 1)
      driver:keypressed(app, '1', '1', false)
      for _ = 1, 240 do
        trial:update(dt, {})
      end
    end)
    love.mouse.getRelativeMode = oldRelative
    Journal.stop(trial)
    assert(inputOK, inputError)
    local loaded = Journal.decode(Journal.encode(log))
    local destination = arena()
    if bound then
      join(destination)
    end
    local replayOK, replayError = pcall(Journal.replay, destination, loaded)
    local diff = replayOK
      and Integrity.difference(Integrity.capture(trial), Integrity.capture(destination))
    check(
      (bound and 'bound' or 'default')
        .. ' keyboard/mouse commands replay bit for bit: '
        .. tostring(replayError or diff or 'equal'),
      replayOK and not diff
    )
    local actorSlots = { look = 3, shoot = 2, reloadGun = 1, cast = 2, switchWeapon = 2 }
    local checked, idsOnly = {}, true
    for _, entry in ipairs(loaded.entries) do
      local slot = actorSlots[entry[1]]
      if slot then
        checked[entry[1]] = true
        idsOnly = idsOnly and (entry[2][slot] == (bound and knight.id or nil))
      end
    end
    check(
      (bound and 'bound' or 'default') .. ' input preserves the actor-id command contract',
      idsOnly
        and checked.look
        and checked.shoot
        and checked.reloadGun
        and checked.cast
        and checked.switchWeapon
    )
  end
  inputTrial(false)
  inputTrial(true)

  -- Borrowed answers are distinct for actors and interpolated samples, but
  -- a command at unchanged simulation time invalidates the entire session.
  local Queries = require('src.run.queries')
  local Modes = require('src.run.modes')
  local queryGame = arena()
  local queryActor = join(queryGame)
  Context.watch(queryGame, queryActor.id)
  local queryB = Context.of(queryGame, queryActor)
  P.capture(queryGame)
  local contexts = { queryGame, queryB, P.sample(queryGame, 0.5), P.sample(queryB, 0.5) }
  local mode = Modes.of(queryGame)
  local originalRunView = mode.runView
  -- Exercise the mode contract's actor-sensitive extension point. Restore
  -- it even if a regression assertion fails; no production mode is added.
  mode.runView = function(shown, out)
    local actor = Context.actor(shown)
    out.actor, out.health = actor.id, actor.hp
    return out
  end
  local queryOK, queryError = pcall(function()
    local borrowed, copies = {}, {}
    for i, shown in ipairs(contexts) do
      borrowed[i] = Queries.run(shown)
      copies[i] = Queries.copy(borrowed[i])
      assert(Queries.valid(shown, borrowed[i]))
      assert(borrowed[i].actor == (i % 2 == 1 and queryGame.player.id or queryActor.id))
      assert(borrowed[i].health == (i % 2 == 1 and 83 or 47))
      for j = 1, i - 1 do
        assert(borrowed[j] ~= borrowed[i])
      end
    end
    local time = queryGame.time
    queryGame:act('qa_query_invalidation')
    assert(queryGame.time == time)
    for i, shown in ipairs(contexts) do
      assert(not Queries.valid(shown, borrowed[i]))
      assert(copies[i].actor == (i % 2 == 1 and queryGame.player.id or queryActor.id))
      assert(copies[i].health == (i % 2 == 1 and 83 or 47))
      assert(Queries.valid(shown, Queries.run(shown)))
    end
  end)
  mode.runView = originalRunView
  check(
    'same-time mode commands invalidate A, B and sampled queries without mixing actors: '
      .. tostring(queryError or 'isolated and invalidated'),
    queryOK
  )
  return lines
end

return Tests
